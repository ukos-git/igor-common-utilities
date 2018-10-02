#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#pragma IndependentModule = Utilities
#include <Peak AutoFind>

// PeakFind Functions based on WM procedure and swnt-absorption.
// https://github.com/ukos-git/igor-swnt-absorption

// see AutomaticallyFindPeaks from WM's <Peak AutoFind>
Function/Wave PeakFind(wavInput, [wvXdata, sorted, redimensioned, differentiate2, noiselevel, smoothingFactor, minPeakPercent, maxPeaks, verbose])
	Wave wavInput, wvXdata
	Variable sorted, redimensioned, differentiate2
	Variable noiselevel, smoothingFactor, minPeakPercent, maxPeaks
	variable verbose

	Variable pBegin, pEnd
	Variable/C estimates

	Variable numColumns

	Variable peaksFound
	String newName

	if (ParamIsDefault(redimensioned))
		redimensioned = 0
	endif
	if (ParamIsDefault(sorted))
		sorted = 0
	endif
	if (ParamIsDefault(differentiate2))
		differentiate2 = 0
	endif
	if (ParamIsDefault(verbose))
		verbose = 0
	endif
	if(ParamIsDefault(maxPeaks))
		maxPeaks = 10
	endif

	numColumns = Dimsize(wavInput, 1)
	if(numColumns == 1)
		Redimension/N=(-1, 0) wavInput
		numColumns = 0
	endif
	if(numColumns == 0)
		if(ParamIsDefault(wvXdata))
			Wave/Z wvXdata = $("_calculated_")
		endif
		if(differentiate2)
			wave wavYdata = Differentiate2Wave(wavInput, 10)
			wavYdata *= -1
		else
			Wave wavYdata = wavInput
		endif
	elseif(numColumns > 1)
		Duplicate/FREE/R=[][0] wavInput wavYdata
		Duplicate/FREE/R=[][1] wavInput wvXdata
		Redimension/N=(-1,0) wavYdata, wvXdata
	else
		print "unhandled exception at column number in PeakFind"
		abort
	endif

	Make/FREE/N=(maxPeaks,7) wavOutput

	// label columns of wave for readability
	SetDimLabel 1, 0, wavelength, wavOutput
	SetDimLabel 1, 1, height, wavOutput
	SetDimLabel 1, 2, width, wavOutput
	SetDimLabel 1, 3, positionY, wavOutput
	SetDimLabel 1, 4, positionX, wavOutput
	SetDimLabel 1, 5, widthL, wavOutput // from WM: somewhat free width left and right
	SetDimLabel 1, 6, widthR, wavOutput

	// input parameters for WM's AutoFindPeaksNew
	pBegin = 0
	pEnd = DimSize(wavYdata, 0) - 1

	if(ParamIsDefault(minPeakPercent))
		minPeakPercent = 5
	endif
	try
		estimates = EstPeakNoiseAndSmfact(wavYdata, pBegin, pEnd)
	catch
		estimates = cmplx(0.01, 1)
	endtry
	if(ParamIsDefault(noiselevel))
		noiselevel = real(estimates)
	endif
	if((ParamIsDefault(smoothingFactor)) || (numtype(smoothingFactor) != 0))
		smoothingFactor = imag(estimates)
	endif
	if(!(noiselevel>0))
		noiselevel = 0.01
	endif

	peaksFound = AutoFindPeaksNew(wavYdata, pBegin, pEnd, noiseLevel, smoothingFactor, maxPeaks)
	WAVE W_AutoPeakInfo // output of AutoFindPeaksNew

	if(verbose > 2)
		print "== peakFind =="
		printf "peaks: \t %d\r", peaksFound
		printf "smooth: \t %.1f\r", smoothingFactor
		printf "noise: \t %.4f\r", noiseLevel
	endif

	// Remove too-small peaks
	if(peaksFound > 0)
		peaksFound = TrimAmpAutoPeakInfo(W_AutoPeakInfo, minPeakPercent / 100)
	endif

	// Redimension to number of peaks
	Redimension/N=(peaksFound, -1) wavOutput

	// process peaks
	if(peaksFound > 0)
		// save peak positions in input wave
		wavOutput[][%positionX] = W_AutoPeakInfo[p][0]
		if(differentiate2)
			if (numColumns == 0)
				wavOutput[][%positionY] = wavInput[wavOutput[p][%positionX]]
			elseif(numColumns == 3)
				wavOutput[][%positionY] = wavInput[wavOutput[p][%positionX]][0]
			endif
		else
			wavOutput[][%positionY] = wavYdata[wavOutput[p][%positionX]]
		endif

		// The x values in W_AutoPeakInfo are still actually points, not X
		AdjustAutoPeakInfoForX(W_AutoPeakInfo, wavYdata, wvXdata)
		wavOutput[][%wavelength] = W_AutoPeakInfo[p][0]

		// save all data from WM procedure
		wavOutput[][%width]	 = W_AutoPeakInfo[p][1]
		wavOutput[][%height] = W_AutoPeakInfo[p][2]
		wavOutput[][%widthL] = W_AutoPeakInfo[p][3]
		wavOutput[][%widthR] = W_AutoPeakInfo[p][4]
	endif

	if((sorted) && (peaksFound > 0)) // sort is not multidimensional aware
		Make/FREE/N=(Dimsize(wavOutput, 0)) zero = wavOutput[p][0]
		Make/FREE/N=(Dimsize(wavOutput, 0)) one = wavOutput[p][1]
		Make/FREE/N=(Dimsize(wavOutput, 0)) two = wavOutput[p][2]
		Make/FREE/N=(Dimsize(wavOutput, 0)) three = wavOutput[p][3]
		Make/FREE/N=(Dimsize(wavOutput, 0)) four = wavOutput[p][4]
		Make/FREE/N=(Dimsize(wavOutput, 0)) five = wavOutput[p][5]
		Make/FREE/N=(Dimsize(wavOutput, 0)) six = wavOutput[p][6]

		Sort zero, zero, one, two, three, four, five, six
		wavOutput[][0] = zero[p]
		wavOutput[][1] = one[p]
		wavOutput[][2] = two[p]
		wavOutput[][3] = three[p]
		wavOutput[][4] = four[p]
		wavOutput[][5] = five[p]
		wavOutput[][6] = six[p]
	endif

	if (redimensioned)
		Redimension/N=(-1,4) wavOutput
	endif

	if(differentiate2)
		wavYdata *= -1
	endif

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

	if (numSmooth>0)
		if (Dimsize(wavInput, 1) == 3)
			Duplicate/R=[][0]/FREE wavInput intensity
			Redimension/N=(-1,0) intensity
			Smooth numSmooth, intensity
			wavOutput[][0] = intensity[p]
		else
			Smooth numSmooth, wavOutput
		endif
	endif

	return wavOutput
End
