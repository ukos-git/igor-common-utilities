#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include <Peak AutoFind>

// PeakFind Functions based on WM procedure and swnt-absorption.
// https://github.com/ukos-git/igor-swnt-absorption

// see AutomaticallyFindPeaks from WM's <Peak AutoFind>
Function/Wave PeakFind(wavInput, [wvXdata, noiselevel, smoothingFactor, minPeakPercent, maxPeaks, verbose])
	Wave wavInput, wvXdata
	Variable noiselevel, smoothingFactor, minPeakPercent, maxPeaks
	variable verbose

	Variable pBegin, pEnd
	Variable/C estimates

	Variable numColumns

	Variable peaksFound
	String newName

	if (ParamIsDefault(verbose))
		verbose = 0
	endif
	if(ParamIsDefault(maxPeaks))
		maxPeaks = 10
	endif
	if(ParamIsDefault(noiselevel))
		noiselevel = 1 // relative value
	endif
	if((ParamIsDefault(smoothingFactor)) || numtype(smoothingFactor) != 0)
		smoothingFactor = 1 // relative value
	endif
	if(ParamIsDefault(minPeakPercent))
		minPeakPercent = 5
	endif

	numColumns = Dimsize(wavInput, 1)
	if(numColumns == 1)
		numColumns = 0
	endif
	if(numColumns == 0)
		Duplicate/FREE wavInput wvYdata
		Redimension/N=(-1, 0) wvYdata
		if(ParamIsDefault(wvXdata))
			Make/FREE/N=(DimSize(wvYdata, 0)) wvXdata = DimOffset(wvYdata, 0) + p * DimDelta(wvYdata, 0)
		endif
	elseif(numColumns > 1)
		Duplicate/FREE/R=[][0] wavInput wvYdata
		Duplicate/FREE/R=[][1] wavInput wvXdata
		Redimension/N=(-1,0) wvYdata, wvXdata
	else
		print "unhandled exception at column number in PeakFind"
		abort
	endif

	Make/FREE/N=(maxPeaks,7) wavOutput

	// label columns of wave for readability
	SetDimLabel 1, 0, location, wavOutput
	SetDimLabel 1, 1, height, wavOutput
	SetDimLabel 1, 2, fwhm, wavOutput
	SetDimLabel 1, 3, positionY, wavOutput
	SetDimLabel 1, 4, positionX, wavOutput
	SetDimLabel 1, 5, widthL, wavOutput // from WM: somewhat free width left and right
	SetDimLabel 1, 6, widthR, wavOutput

	// input parameters for WM's AutoFindPeaksNew
	pBegin = 0
	pEnd = DimSize(wvYdata, 0) - 1

	WaveStats/Q wvYdata
	noiselevel = noiselevel * V_adev
	smoothingFactor = smoothingFactor * round(DimSize(wvYdata, 0) / 128)

	peaksFound = AutoFindPeaksNew(wvYdata, pBegin, pEnd, noiseLevel, smoothingFactor, maxPeaks)
	WAVE W_AutoPeakInfo // output of AutoFindPeaksNew

	if(verbose > 2)
		print "== peakFind =="
		printf "peaks: \t %d\r", peaksFound
		printf "smooth: \t %.1f\r", smoothingFactor
		printf "noise: \t %.4f\r", noiseLevel
	endif

	if(peaksFound > 0)
		// Remove too-small peaks
		peaksFound = TrimAmpAutoPeakInfo(W_AutoPeakInfo, minPeakPercent / 100)
	endif

	if(peaksFound > 0)
		Redimension/N=(peaksFound, -1) wavOutput

		// save peak positions in input wave
		wavOutput[][%positionX] = W_AutoPeakInfo[p][0]
		wavOutput[][%positionY] = wvYdata[wavOutput[p][%positionX]]

		// The x values in W_AutoPeakInfo are still actually points, not X
		AdjustAutoPeakInfoForX(W_AutoPeakInfo, wvYdata, wvXdata)
		wavOutput[][%location] = W_AutoPeakInfo[p][0]

		// save all data from WM procedure
		wavOutput[][%fwhm]  = W_AutoPeakInfo[p][1]
		wavOutput[][%height] = W_AutoPeakInfo[p][2]
		wavOutput[][%widthL] = W_AutoPeakInfo[p][3]
		wavOutput[][%widthR] = W_AutoPeakInfo[p][4]
	endif

	if(peaksFound == 0)
		// magic !
		WAVE smoothed = SmoothWave(wvYdata, smoothingFactor)
		WaveStats/Q/M=1 smoothed
		Redimension/N=(1, -1) wavOutput
		wavOutput = NaN
		wavOutput[0][%location] = V_maxRowLoc == -1 ? NaN : wvXdata[V_maxRowLoc]
		wavOutput[0][%fwhm] = abs((wvXdata[0] - wvXdata[DimSize(wvXdata, 0) - 1]) / 2) // pure magic
		wavOutput[0][%height] = V_max
		peaksFound = 1
	endif

	SortColumns/KNDX={1,0} sortWaves=wavOutput
	return wavOutput
End

Function/Wave Differentiate2Wave(wavInput, numSmooth)
	Wave wavInput
	Variable numSmooth

	// smooth and build second derivative
	Wave wavFirst  = DifferentiateWave(wavInput, numSmooth, 0)
	Wave wavSecond = DifferentiateWave(wavFirst, numSmooth, 0)

	return wavSecond
End

Function/WAVE DifferentiateWave(wavInput, numSmooth, type)
	Wave wavInput
	Variable numSmooth, type

	String newName

	Duplicate/FREE wavInput, wavTemp

	// smooth before
	Wave wavSmooth = SmoothWave(wavInput, numSmooth)

	if (Dimsize(wavInput, 1) == 3)
		Duplicate/O/R=[][0]/FREE wavSmooth intensity
		Duplicate/O/R=[][1]/FREE wavSmooth wavelength
		Duplicate/O/R=[][0]/FREE wavSmooth differentiated
		Redimension/N=(-1,0) intensity, wavelength, differentiated
		Differentiate/METH=(type) intensity/D=differentiated/X=wavelength
		wavTemp[][0] = differentiated[p]
	else
		Differentiate/METH=(type) wavSmooth/D=wavTemp
	endif

	// smooth after
	Wave wavOutput = SmoothWave(wavTemp, 0)

	return wavOutput
End

Function/Wave SmoothWave(wavInput, numSmooth)
	Wave wavInput
	Variable numSmooth

	String newName

	Duplicate/FREE wavInput wavOutput

	if(numSmooth > 0)
		Smooth/B=3 numSmooth, wavOutput
	endif

	return wavOutput
End

// @brief find @p level in @p wv and return point range from @p pStart to @p pEnd
Function [ Variable pStart, Variable pEnd ] FindLevelWrapper(WAVE wv, Variable level, [Variable accuracy, Variable verbose])

	verbose = ParamIsDefault(verbose) ? 0 : !!verbose

	if(DimSize(wv, 0) < accuracy)
		pStart = 0
		pEnd = DimSize(wv, 0) - 1
		return [ pStart, pEnd ]
	endif

	FindLevel/Q/P/T=(accuracy) wv, level
	pStart = V_Flag ? 0 : floor(V_levelX)
	pEnd = V_Flag ? DimSize(wv, 0) - 1 : ceil(V_levelX)
	if(verbose)
		printf "level found between %d and %d in wave %s\r", pStart, pEnd, NameOfWave(wv)
	endif
	if(ParamIsDefault(accuracy))
		return [ pStart, pEnd ]
	endif
	do
		pStart = max(0, pStart - 1)
		pEnd = min(pEnd + 1, DimSize(wv, 0) - 1)
	while((pEnd - pStart) < accuracy)

	return [ pStart, pEnd ]
End
