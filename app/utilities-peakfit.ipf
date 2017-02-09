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
