#pragma IndependentModule= Utilities
#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#pragma IndependentModule = Utilities

#include <Peak Functions>
#include <PeakFunctions2>

Function/WAVE DuplicateWaveOfWaves(wv)
	WAVE/WAVE wv

	Variable i, numItems

	numItems = DimSize(wv, 0)
	Make/FREE/WAVE/N=(numItems) wvOut
	for(i = 0; i < numItems; i += 1)
		WAVE item = wv[i]
		Duplicate/FREE item temp
		wvOut[i] = temp
	endfor
	return wvOut
End

Function/WAVE restoreWaveOfWaves(original, backup)
	WAVE/WAVE original, backup

	Variable i, numItems

	numItems = DimSize(original, 0)
	for(i = 0; i < numItems; i += 1)
		WAVE backupWave = backup[i]
		WAVE originalWave = original[i]
		originalWave = backupWave
	endfor
End

// available Functions from WM <Peak Functions>
// fVoigtFit, fLorentzianFit, fGaussFit ...
Function/WAVE FitGauss(wv, [wvXdata, wvCoef, verbose, cleanup])
	WAVE wv, wvXdata
	WAVE/WAVE wvCoef
	variable verbose
	variable cleanup

	variable V_FitError
	string myFunctions

	verbose = ParamIsDefault(verbose) ? 0 : !!verbose
	cleanup = ParamIsDefault(cleanup) ? 0 : !!cleanup

	if(ParamIsDefault(wvCoef))
		if(ParamIsDefault(wvXdata))
			WAVE/WAVE wvCoef = BuildCoefWv(wv, verbose = verbose)
		else
			WAVE/WAVE wvCoef = BuildCoefWv(wv, wvXdata = wvXdata, verbose = verbose)
		endif
		cleanup = 1 // delete coef waves
	endif
	WAVE/WAVE wvCoefFallback = DuplicateWaveOfWaves(wvCoef)

	myFunctions = BuildFitStringGauss(wvCoef)

	V_FitError = 0
	if(ParamIsDefault(wvXdata))
		FuncFit/Q=1/M=2 {string = myFunctions} wv
	else
		FuncFit/Q=1/M=2 {string = myFunctions} wv/X=wvXdata
	endif
	if(V_FitError != 0)
		if(verbose)
			print "Error in FitGauss: FuncFit returned no result. Fallback to initial coef."
		endif
		restoreWaveOfWaves(wvCoef, wvCoefFallback)
	endif
	WAVE/Z M_Covar
	WAVE/Z peakParam = GaussCoefToPeakParam(wvCoef, wvCovar = M_Covar, verbose = verbose)
	if(!WaveExists(peakParam))
		restoreWaveOfWaves(wvCoef, wvCoefFallback)
		WAVE/Z peakParam = GaussCoefToPeakParam(wvCoefFallback) 
	endif
	if(!WaveExists(peakParam))
		if(verbose)
			print "Error in FitGauss: no result."
		endif
	endif
	
	if(cleanup)
		KillWaveOfWaves(wvCoef)
		KillWaves/Z M_Covar
	endif
	
	return peakParam
End
	
Function/WAVE GaussCoefToPeakParam(wvCoef, [wvCovar, verbose])
	WAVE/WAVE wvCoef
	WAVE wvCovar
	variable verbose
	
	variable location, height, fwhm, width, area
	variable i, numPeaks
	
	if(ParamIsDefault(verbose))
		verbose = 0
	endif
	
	numPeaks = DimSize(wvCoef, 0)
	
	if(ParamIsDefault(wvCovar) || !WaveExists(wvCovar) || DimSize(wvCovar, 0) != numPeaks * 3)
		Make/FREE/N=(numPeaks * 3, numPeaks * 3) wvCovar = 0
	endif

	Make/FREE/WAVE/N=(numPeaks) wvPeakParam
	MatrixOP/FREE totalCovar=getDiag(wvCovar,0)
	for(i = 0; i < numPeaks; i += 1)
		Make/FREE/D/N=(4,3) peakParam
		Make/FREE/N=3 covar = totalCovar[3*i + p]
		MatrixOP/FREE covar=diagonal(covar)
		WAVE coef = wvCoef[i]
		GaussPeakParams(coef, covar, peakParam)
		peakParam[2][1] = numType(peakParam[2][0]) != 0 ? 0 : peakParam[2][1]
		wvPeakParam[i] = peakParam
	endfor

	WAVE/WAVE wvPeakParamOut = RemoveFitErrors(wvPeakParam, verbose = verbose)
	WAVEClear wvPeakParam
	Duplicate/FREE wvPeakParamOut, wvPeakParam

	numPeaks = DimSize(wvPeakParam, 0)
	if(verbose && (numPeaks > 0))
		if(verbose > 1)
			printf "method \tnr \tlocation \theight \tFWHM \t\tarea\r"
		endif
		for(i = 0; i < numPeaks; i += 1)
			WAVE peakParam = wvPeakParam[i]
			location = peakParam[0][0]
			fwhm   = peakParam[3][0]
			height = peakParam[1][0]
			area   = peakParam[2][0]
			printf "FuncFit \t%d \t%.4f \t%.4f \t%.4f \t%.4f\r", i, location, height, fwhm, area
			location = peakParam[0][1]
			fwhm   = peakParam[3][1]
			height = peakParam[1][1]
			area   = peakParam[2][1]
			printf "Error \t\t%d \t%.4f \t%.4f \t%.4f \t%.4f\r", i, location, height, fwhm, area
		endfor
	endif

	if(numPeaks == 0)
		return $""
	endif
	return wvPeakParam
End

Function/WAVE peakParamToResult(peakParam)
	WAVE/WAVE peakParam

	variable numResults, i

	if(WaveExists(peakParam))
		numResults = DimSize(peakParam, 0)
	endif

	Make/FREE/N=(numResults, 8) result
	SetDimLabel 1, 0, location, result
	SetDimLabel 1, 1, height, result
	SetDimLabel 1, 2, fwhm, result
	SetDimLabel 1, 3, area, result

	SetDimLabel 1, 4, location_err, result
	SetDimLabel 1, 5, height_err, result
	SetDimLabel 1, 6, fwhm_err, result
	SetDimLabel 1, 7, area_err, result

	for(i = 0; i < numResults; i += 1)
		wave peak = peakParam[i]
		result[i][%location] = peak[0][0]
		result[i][%location_err] = peak[0][1]
		result[i][%height] = peak[1][0]
		result[i][%height_err] = peak[1][1]
		result[i][%fwhm] = peak[3][0]
		result[i][%fwhm_err] = peak[3][1]
		result[i][%area] = peak[2][0]
		result[i][%area_err] = peak[2][1]
	endfor

	return result
End

Function/WAVE CreateFitCurve(wvPeakParam, xMin, xMax, size)
	WAVE/WAVE wvPeakParam
	variable xMin, xMax, size

	variable numPeaks, i, step

	Make/N=(size)/FREE wv
	SetScale/I x, xMin, xMax, wv
	step = (xMax - xMin) / (size)
	Make/N=(size)/FREE wvXdata = xMin + p * step

	numPeaks = DimSize(wvPeakParam, 0)
	for(i = 0; i < numPeaks; i += 1)
		WAVE peakParam = wvPeakParam[i]
		WAVE coef = PeakParamToGauss(peakParam)
		Make/FREE/N=(size) singlePeak
		MPFXGaussPeak(coef, singlePeak, wvXdata)
		wv += singlePeak
	endfor

	return wv
End

static Function/WAVE PeakParamToGauss(peakParam)
	WAVE peakParam

	variable location, width, height

	Make/FREE/N=3 coef
	location = peakParam[0][0]
	width    = CalculateWidth(peakParam[3][0])
	height   = peakParam[1][0]
	coef     = {location, width, height}

	return coef
End

static Constant twoSqrtLn2 = 1.66510922231539537641 // printf "%.20f\r", sqrt(ln(2)) * 2

Function CalculateFWHM(width)
	variable width

	//return width * (2 * sqrt(ln(2)))
	return width * twoSqrtLn2
End

Function CalculateWidth(fwhm)
	variable fwhm

	return fwhm / twoSqrtLn2
End

Function KillWaveOfWaves(wv)
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

	variable location, height, fwhm, width
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
			WAVE peaks = Utilities#PeakFind(wv, verbose = verbose)
		else
			WAVE peaks = Utilities#PeakFind(wv, wvXdata = wvXdata, verbose = verbose)
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

		location = peaks[i][%location]
		width    = peaks[i][%fwhm]
		height   = peaks[i][%height]
		coef = {location, width , height}

		wvCoef[i] = coef
	endfor
	SetDataFolder saveDFR

	if((verbose > 1) && (numPeaks > 0))
		for(i = 0; i < numPeaks; i += 1)
			WAVE coef = wvCoef[i]
			location = peaks[i][%location]
			height = peaks[i][%height]
			fwhm  = CalculateFWHM(peaks[i][%fwhm])
			printf "start \t%d \t%.4f \t%.4f \t%.4f\r", i, location, height, fwhm
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
static Function/WAVE RemoveFitErrors(wvPeakParam, [verbose])
	WAVE/WAVE wvPeakParam
	variable verbose

	variable i, numPeaks, gaussError
	variable lastpeaklocation = 0

	if(ParamIsDefault(verbose))
		verbose = 0
	endif

	Make/FREE/N=4 error
	Duplicate/FREE wvPeakParam wv

	numPeaks = DimSize(wv, 0)
	for(i = numPeaks - 1; i > -1; i -= 1)
		WAVE peakParam = wvPeakParam[i]
		// remove peaks when error too high
		error[] = (peakParam[p][1] / peakParam[p][0])^2
		gaussError = sqrt(sum(error))
		if(gaussError > 0.2)
			DeletePoints/M=0 i, 1, wv
			if(verbose > 1)
				print "deleted peak: too high error"
			endif
			continue
		endif
		// remove nan and inf
		error[] = numtype(peakParam[p][1])
		if(sum(error) > 0)
			DeletePoints/M=0 i, 1, wv
			if(verbose > 1)
				print "deleted peak: nan or inf error"
			endif
			continue
		endif
		// no negative peaks
		error[] = peakParam[p][0] < 0 ? 1 : 0
		if(sum(error) > 0)
			DeletePoints/M=0 i, 1, wv
			continue
		endif
		// no duplicates
		if(lastpeaklocation == floor(peakParam[0][0]))
			if(verbose > 1)
				print "deleted peak: found duplicate. include constraints!"
			endif
			DeletePoints/M=0 i, 1, wv
		endif
		lastpeaklocation = floor(peakParam[0][0])
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
// used functions from M. Bongard: CalcIota, CalcEndPoints, Akima
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

ThreadSafe static Function CorrectEndPoints(kX, kY, [xStart, yStart, xEnd, yEnd])
	WAVE kX, kY // knot X,Y coordinate locations
	variable xStart, yStart, xEnd, yEnd // manual endpoints

	variable i, numPoints

	numPoints = DimSize(kX, 0)
	if(numPoints != DimSize(kY, 0))
		print "CorrectEndPoints: Size Missmatch of coordinate waves"
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
		Redimension/N=(numPoints + 1) kX, kY
		kX[inf, 1] = kX[(p - 1)]
		kY[inf, 1] = kY[(p - 1)]
		kX[0] = xStart
		kY[0] = yStart
	endif
End
// Given: 5-point knot wave knotX, knotY, with i=[0,2] representing the last three
// knot locations from data, compute end knots i=[3,4] appropriately.
ThreadSafe static Function CalcEndPoints(kX, kY)
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

Function/WAVE RemovePeaks(wv, [wvXdata, tolerance, verbose])
	WAVE wv, wvXdata
	variable tolerance, verbose

	variable numPeaks, numPoints, i, j, k, minBarrier, maxBarrier

	if(ParamIsDefault(wvXdata))
		WAVE wvXdata = createXwave(wv)
	endif
	if(ParamIsDefault(tolerance))
		tolerance = 2 // removes peak +/- 2 * FWHM
	endif
	if(ParamIsDefault(verbose))
		verbose = 0
	endif

	// get peaks
	WAVE wavMaxima = PeakFind(wv, wvXdata = wvXdata, minPeakPercent = 20, smoothingFactor = 1, verbose = verbose)
	numPeaks = Dimsize(wavMaxima, 0)
	Make/FREE/N=(numPeaks) peaksX = wavMaxima[p][%location]
	Make/FREE/N=(numPeaks) peaksY = wavMaxima[p][%positionY]
	Make/FREE/N=(numPeaks) peaksF = Utilities#CalculateFWHM(wavMaxima[p][%fwhm])
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
	CorrectEndPoints(wl_nopeaks, wv_nopeaks, xStart = wvXdata[0], yStart = wv[0], xEnd = wvXdata[(numPoints - 1)], yEnd = wv[(numPoints - 1)])
	CalcIota(wl_nopeaks, wv_nopeaks, dWave = knotIota)
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
	Smooth/M=0.01 7, spikefree

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
