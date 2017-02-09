#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#pragma IndependentModule = Utilities
#include <Peak Functions>
#include <PeakFunctions2>

// available Functions from WM <Peak Functions>
// fVoigtFit, fLorentzianFit, fGaussFit ...
Function/WAVE FitGauss(wv, [wvXdata, wvCoef, verbose])
	WAVE wv, wvXdata
	WAVE/WAVE wvCoef
	variable verbose

	variable center, height, fwhm, width, area
	variable i, numPeaks, V_FitError
	string myFunctions
	variable cleanup = 0

	if(ParamIsDefault(verbose))
		verbose = 0
	endif

	if(ParamIsDefault(wvCoef))
		if(ParamIsDefault(wvXdata))
			WAVE/WAVE wvCoef = BuildCoefWv(wv, verbose = verbose)
		else
			WAVE/WAVE wvCoef = BuildCoefWv(wv, wvXdata = wvXdata, verbose = verbose)
		endif
		cleanup = 1 // delete coef waves
	endif
	myFunctions = BuildFitStringGauss(wvCoef)

	V_FitError = 0
	if(ParamIsDefault(wvXdata))
		FuncFit/Q=1/M=2 {string = myFunctions} wv
	else
		FuncFit/Q=1/M=2 {string = myFunctions} wv/X=wvXdata
	endif
	if(V_FitError != 0)
		KillWaveOfWaves(wvCoef)
		return $("")
	endif
	WAVE M_Covar

	numPeaks = DimSize(wvCoef, 0)
	Make/FREE/WAVE/N=(numPeaks) wvPeakParam
	Make/FREE/D/N=(4,3) peakParam
	MatrixOP/FREE totalCovar=getDiag(M_Covar,0)
	for(i = 0; i < numPeaks; i += 1)
		Make/FREE/N=3 covar = totalCovar[3*i + p]
		MatrixOP/FREE covar=diagonal(covar)
		GaussPeakParams(wvCoef[i], covar, peakParam)
		wvPeakParam[i] = peakParam
	endfor

	WAVE/WAVE wvPeakParamOut = RemoveFitErrors(wvPeakParam)
	WAVEClear wvPeakParam
	Duplicate/FREE wvPeakParamOut, wvPeakParam

	numPeaks = DimSize(wvPeakParam, 0)
	if(verbose && (numPeaks > 0))
		printf "method \tnr \tcenter \theight \tFWHM \t\tarea\r"
		for(i = 0; i < numPeaks; i += 1)
			WAVE peakParam = wvPeakParam[i]
			center = peakParam[0][0]
			fwhm   = peakParam[3][0]
			height = peakParam[1][0]
			area   = peakParam[2][0]
			printf "FuncFit \t%d \t%.4f \t%.4f \t%.4f \t%.4f\r", i, center, height, fwhm, area
			center = peakParam[0][1]
			fwhm   = peakParam[3][1]
			height = peakParam[1][1]
			area   = peakParam[2][1]
			printf "Error \t\t%d \t%.4f \t%.4f \t%.4f \t%.4f\r", i, center, height, fwhm, area
		endfor
	endif

	if(cleanup)
		KillWaveOfWaves(wvCoef)
	endif

	if(numPeaks == 0)
		return $""
	endif
	return wvPeakParam
End

static Constant twoSqrtLn2 = 1.66510922231539537641 // printf "%.20f\r", sqrt(ln(2)) * 2

Function CalculateFWHM(width)
	variable width

	//return width * (2 * sqrt(ln(2)))
	return width * twoSqrtLn2
End

static Function KillWaveOfWaves(wv)
	WAVE/WAVE wv

	variable i, numItems

	numItems = Dimsize(wv, 0)
	for(i = 0; i < numItems; i += 1)
		WAVE/Z killme = wv[i]
		KillWaves/Z killme
	endfor
End

// MPFXGaussPeak style coef wave
Function/WAVE BuildCoefWv(wv, [wvXdata, peaks, verbose, dfr])
	WAVE wv, wvXdata, peaks
	variable verbose
	DFREF dfr

	variable center, height, fwhm, width
	variable i, numPeaks
	DFREF saveDFR
	string coefName

	if(ParamIsDefault(verbose))
		verbose = 0
	endif
	if(ParamIsDefault(dfr))
		dfr = GetDataFolderDFR()
	endif

	// use peakFind for parameters
	if(ParamIsDefault(peaks))
		if(ParamIsDefault(wvXdata))
			WAVE peaks = Utilities#PeakFind(wv)
		else
			WAVE peaks = Utilities#PeakFind(wv, wvXdata = wvXdata)
		endif
	endif

	// save peaks in coef wave in MPFXGaussPeak style
	saveDFR = GetDataFolderDFR()
	SetDataFolder dfr
	numPeaks = DimSize(peaks, 0)
	Make/FREE/WAVE/N=(numPeaks) wvCoef
	for(i = 0; i < numPeaks; i += 1)
		coefName = UniqueName("coef", 1, 0)
		Make/D/N=3 dfr:$coefName/WAVE=coef

		center = peaks[i][%wavelength]
		width = peaks[i][%width]
		height = peaks[i][%height]
		coef = {center, width , height}

		wvCoef[i] = coef
	endfor
	SetDataFolder saveDFR

	if(verbose && (numPeaks > 0))
		printf "method \tnr \tcenter \theight \tFWHM \t\tarea\r"
		for(i = 0; i < numPeaks; i += 1)
			WAVE coef = wvCoef[i]
			center = peaks[i][%wavelength]
			height = peaks[i][%height]
			fwhm  = CalculateFWHM(peaks[i][%width])
			printf "start \t%d \t%.4f \t%.4f \t%.4f\r", i, center, height, fwhm
		endfor
	endif

	return wvCoef
End

// MPFXGaussPeak Fun String
static Function/S BuildFitStringGauss(wvCoef)
	WAVE/WAVE wvCoef

	variable i, numFitfunctions
	string myFunctions = ""

	numFitfunctions = DimSize(wvCoef, 0)
	for(i = 0; i < numFitfunctions; i += 1)
		WAVE coef = wvCoef[i]
		myFunctions += "{MPFXGaussPeak, "
		myFunctions += GetWavesDataFolder(coef, 2)
		myFunctions += "}"
	endfor

	return myFunctions
End

// assumes MPFXGaussPeak style peak parameter wave
static Function/WAVE RemoveFitErrors(wvPeakParam)
	WAVE/WAVE wvPeakParam

	variable i, numPeaks

	Make/FREE/N=4 error
	Duplicate/FREE wvPeakParam wv

	numPeaks = DimSize(wv, 0)
	for(i = numPeaks - 1; i > -1; i -= 1)
		WAVE peakParam = wvPeakParam[i]
		// remove peaks when error too high
		error[] = (peakParam[p][1] / peakParam[p][0])^2
		if(sqrt(sum(error)) > 0.10)
			DeletePoints/M=0 i, 1, wv
			continue
		endif
		// remove nan and inf
		error[] = numtype(peakParam[p][1])
		if(sum(error) > 0)
			DeletePoints/M=0 i, 1, wv
			continue
		endif
		// no negative peaks
		error[] = peakParam[p][0] < 0 ? 1 : 0
		if(sum(error) > 0)
			DeletePoints/M=0 i, 1, wv
			continue
		endif
		if(peakParam[0][0] < 0)
			print peakParam[0][0], peakParam[0][1]
			print error
		endif
	endfor

	return wv
End

Function/WAVE SmoothBackground(wv, [fraction])
	WAVE wv
	variable fraction

	variable numSmooth

	if(ParamIsDefault(fraction))
		fraction = 2^5
	endif

	Duplicate/FREE wv smoothed
	numSmooth = DimSize(smoothed, 0) / fraction
	Smooth/M=0/MPCT=50 numSmooth, smoothed
	Loess/Z/SMTH=0.25 srcWave=smoothed

	return smoothed
End

// http://www.igorexchange.com/node/6824
//
// Akima.ipf: Routines to implement Akima-spline fitting, based on
// H. Akima, Journ. ACM, Vol 17, No 4, 1970 p 589-602
// M. Bongard, 11/17/09
//
// used functions from M. Bongard: CalcIota, CalcEndPoints --> CalcEndPoints5point, Akima
ThreadSafe static Function CalcIota(knotX, knotY[, dWave])
	WAVE knotX // knot X locations
	WAVE knotY // knot Y locations
	WAVE dWave // Destination wave reference for iotas

	if(!WaveExists(knotX) || !WaveExists(knotY))
		Print "CalcIota: ERROR -- requisite waves do not exist! Aborting..."
		return -1
	endif

	if(numpnts(knotX) != numpnts(knotY))
		Print "CalcIota: ERROR -- knot waves must have same number of points! Aborting..."
		return -1
	endif

	Variable numKnots = numpnts(knotX)

	if(numKnots < 5)
		Print "CalcIota: ERROR -- Akima spline algorithm requires at least 5 knots. Aborting..."
		return -1
	endif

	// Make intermediate ai, bi, mi arrays
	Make/D/FREE/N=(numKnots + 4)  kX, kY

	Variable i, j
	for(i = 2, j = 0; j < numKnots; i += 1, j += 1)
		kX[i] = knotX[j]
		kY[i] = knotY[j]
	endfor

	// Handle end-point extrapolation
	Make/D/FREE/N=5 endX, endY
	// RHS: end points are last three in dataset
	Variable endStartPt
	// RHS
	endStartPt = numPnts(kX) - 5
	endX = kX[p + endStartPt]
	endY = kY[p + endStartPt]

	CalcEndPoints(endX, endY)

	kX[numpnts(kX)-2] = endX[3]
	kX[numpnts(kX)-1] = endX[4]
	kY[numpnts(kX)-2] = endY[3]
	kY[numpnts(kX)-1] = endY[4]

	// LHS: end points are first three in dataset, but reversed in ordering
	// (i.e. point 3 in Akima's notation == index 0)
	endX = 0
	endY = 0

	for(i = 0, j = 2; i < 3; i += 1, j -= 1)
		endX[j] = knotX[i]
		endY[j] = knotY[i]
	endfor

	CalcEndPoints(endX, endY)

	kX[1] = endX[3]
	kX[0] = endX[4]
	kY[1] = endY[3]
	kY[0] = endY[4]

	// kX, kY are now properly populated, along with all necessary extrapolated endpoints
	// computed as specified in Akima1970

	Make/D/FREE/N=(numKnots + 4 - 1)  mK
	mK = (kY[p + 1] - kY[p]) / (kX[p + 1] - kX[p])

	Make/O/N=(numKnots) knotIota

	Variable denom, m1,m2,m3,m4
	for(i = 2, j = 0; j < numKnots; i += 1, j += 1)
		m1 = mK[i - 2]
		m2 = mK[i - 1]
		m3 = mK[i]
		m4 = mK[i + 1]

		denom = abs(m4 - m3) + abs(m2 - m1)
		if(denom == 0)
			knotIota[j] = 0.5 * (m2 + m3)
			continue
		endif

		knotIota[j] = ( abs(m4 - m3)*m2 + abs(m2 - m1)*m3 ) / denom
	endfor

	if(!ParamIsDefault(dWave))
		// Overwrite input destination wave with new iotas
		Duplicate/O knotIota, dWave
		Killwaves/Z knotIota
	endif
End

ThreadSafe static Function CalcEndPoints(kX, kY, [xStart, yStart, xEnd, yEnd])
	WAVE kX, kY // knot X,Y coordinate locations
	variable xStart, yStart, xEnd, yEnd // manual endpoints

	variable i, numPoints

	numPoints = DimSize(kX, 0)
	if(numPoints == 5)
		return CalcEndPoints5point(kX, kY)
	endif

	if(numPoints != DimSize(kY, 0))
		print "CalcEndPoints: Size Missmatch of coordinate waves"
	endif

	if(ParamIsDefault(xStart))
		xStart = WaveMin(kX)
	endif
	if(ParamIsDefault(yStart))
		yStart = kY[(x2pnt(kX, xStart))]
	endif
	if(ParamIsDefault(xEnd))
		xEnd = WaveMax(kX)
	endif
	if(ParamIsDefault(yEnd))
		yEnd = kY[(x2pnt(kX, xEnd))]
	endif

	// trim invalid endpoints
	for(i = numPoints - 1; i > 0; i -= 1)
		if(kX[i] > xEnd)
			kX[i] = xEnd
			kY[i] = yEnd
		else
			break
		endif
	endfor
	if(numPoints != i + 1)
		numPoints = i + 1
		Redimension/N=(numPoints) kX, kY
	endif

	// insert valid start point
	if(kX[0] > xStart)
		Redimension/N=(numPoints + 1) kX
		kX[inf, 1] = kX[(p - 1)]
		kY[inf, 1] = kY[(p - 1)]
		kX[0] = xStart
		kY[0] = yStart
	endif
End
// Given: 5-point knot wave knotX, knotY, with i=[0,2] representing the last three
// knot locations from data, compute end knots i=[3,4] appropriately.
ThreadSafe static Function CalcEndPoints5point(kX, kY)
	WAVE kX, kY // knot X,Y coordinate locations, respectively

	// Sanity checks
	if( (numPnts(kX) != numpnts(kY)) || numpnts(kX) != 5)
		Print "CalcEndPoints: ERROR -- must have 5 points in knot wave! Aborting..."
		return -1
	endif

	// First, compute X locations of knots, according to relations in eq. 8 of Akima1970:
	kX[3] = kX[1] + kX[2] - kX[0]
	kX[4] = 2*kX[2] - kX[0]

	// Now all kX are known, so let's set up the line segment slope waves
	// ai, bi, mi of eq. (12)-(14).
	Make/N=4/FREE ai, bi, mi

	ai = kX[p+1] - kX[p]
	// ai is now determined completely

	bi = kY[p + 1] - kY[p]
	mi = bi/ai
	// bi, mi determined on i=[0,1]

	// Determine remainder of quantities by applying solutions of eq (9)
	kY[3] = (2*mi[1] - mi[0])*(kX[3] - kX[2]) + kY[2]
	mi[2] = (kY[3] - kY[2]) / (kX[3] - kX[2])

	kY[4] = (2*mi[2] - mi[1])*(kX[4] - kX[3]) + kY[3]
	mi[3] = (kY[4] - kY[3]) / (kX[4] - kX[3])
End

ThreadSafe static Function Akima(x, knotX, knotY, knotIota)
	Variable x
	WAVE knotX, knotY, knotIota

	Variable i1, i2

	// Find where x
	Variable done = 0
	i2 = -1
	Variable numKnots = numpnts(knotX)
	do
		i2 += 1

		if(knotX[i2] == x)
			return knotY[i2]
		endif

		done = (knotX[i2] > x) ? 1 : 0

	while(!done && (i2 < numKnots))
	i1 = i2 - 1

	Variable x1, x2, y1, y2, iota1, iota2
	x1 = knotX[i1]
	y1 = knotY[i1]
	iota1 = knotIota[i1]

	x2 = knotX[i2]
	y2 = knotY[i2]
	iota2 = knotIota[i2]

	Variable p0, p1, p2, p3, tmp
	p0 = y1
	p1 = iota1
	p2 = ( 3 * (y2 - y1)/(x2 - x1) - 2*iota1 - iota2 ) / (x2 - x1)
	p3 = (iota1 + iota2 - 2 * (y2 - y1)/(x2 - x1)) / (x2 - x1)^2

	tmp = x - x1

	return p0 + p1 * tmp + p2 * tmp^2 + p3*tmp^3
End

Function/WAVE RemovePeaks(wv, [wvXdata, tolerance])
	WAVE wv, wvXdata
	variable tolerance

	variable numPeaks, numPoints, i, j, k, minBarrier, maxBarrier

	if(ParamIsDefault(wvXdata))
		WAVE wvXdata = createXwave(wv)
	endif
	if(ParamIsDefault(tolerance))
		tolerance = 2 // removes peak +/- 2 * FWHM
	endif

	// get peaks
    WAVE wavMaxima = PeakFind(wv, wvXdata = wvXdata, minPeakPercent = 90, noiselevel = 1, smoothingFactor = 0.5)
    numPeaks = Dimsize(wavMaxima, 0)
    Make/FREE/N=(numPeaks) peaksX = wavMaxima[p][%wavelength]
    Make/FREE/N=(numPeaks) peaksY = wavMaxima[p][%positionY]
    Make/FREE/N=(numPeaks) peaksF = Utilities#CalculateFWHM(wavMaxima[p][%width])
	Sort peaksX, peaksX, peaksY, peaksF

	// remove peaks
	Duplicate/FREE wv wv_nopeaks
	Duplicate/FREE wvXdata wl_nopeaks
	numPoints = DimSize(wv, 0)
	j = -1
	k = 0
	for(i = 0; i < numPoints; i += 1)
		if(wvXdata[i] > maxBarrier)
			do
				if(j == (numPeaks - 1))
					break
				endif
				j += 1
				minBarrier = peaksX[j] - tolerance * peaksF[j]
				maxBarrier = peaksX[j] + tolerance * peaksF[j]
			while(minBarrier < wvXdata[i])
		endif
		if((wvXdata[i] > minBarrier) && (wvXdata[i] < maxBarrier))
			continue
		endif
		wv_nopeaks[k] = wv[i]
		wl_nopeaks[k] = wvXdata[i]
		k += 1
	endfor
	Redimension/N=(k) wv_nopeaks, wl_nopeaks

	// calculate spline over removed region
	Make/FREE knotIota
	CalcIota(wl_nopeaks, wv_nopeaks, dWave = knotIota)
	CalcEndPoints(wl_nopeaks, wv_nopeaks, xStart = wvXdata[0], yStart = wv[0], xEnd = wvXdata[(numPoints - 1)], yEnd = wv[(numPoints - 1)])
	Duplicate/FREE wv wv_akima
	MultiThread wv_akima = Akima(wvXdata, wl_nopeaks, wv_nopeaks, knotIota)

	return wv_akima
End

static Function/WAVE CreateXwave(wv)
	WAVE wv

	variable left, delta, size

	left  = DimOffset(wv, 0)
	delta = DimDelta(wv, 0)
	size  = DimSize(wv, 0)

	Make/FREE/N=(size) xwave = left + p * delta

	return xwave
End

// Median Smoothing for removing Spikes
Function/WAVE RemoveSpikes(wv)
    WAVE wv

	Duplicate/FREE wv spikefree
    Smooth/M=0 3, spikefree

    return spikefree
End

Function/WAVE RemoveBackground(wv, [wvXdata])
	WAVE wv, wvXdata

	if(ParamIsDefault(wvXdata))
		WAVE nopeaks = Utilities#RemovePeaks(wv)
	else
		WAVE nopeaks = Utilities#RemovePeaks(wv, wvXdata = wvXdata)
	endif

	WAVE smoothed = Utilities#SmoothBackground(nopeaks)

	Duplicate/FREE smoothed, nobackground
	nobackground = wv - smoothed

	return nobackground
End
