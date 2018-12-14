#pragma IndependentModule= Utilities

#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function/WAVE getTopWindowImage()
	String topWindowImages =	ImageNameList("",";")

	if(ItemsInList(topWindowImages) == 0)
		print "Utilities#getTopWindowImage: no Image found in top graph"
		return $""
	endif

	WAVE/Z image = ImageNameToWaveRef("", StringFromList(0, topWindowImages))
	if(!WaveExists(image))
		print "Utilities#getTopWindowImage: image wave does not exist."
		return $""
	endif

	return image
End

Function/WAVE getTopWindowWave()
	string itemName, itemsList
	Variable numItems

	String topWindowImages =	ImageNameList("", ";")
	String topWindowTraces =	TraceNameList("", ";", 1)
	Variable numImages = ItemsInList(topWindowImages)

	itemsList = ConcatenateLists(topWindowImages, topWindowTraces)
	numItems = ItemsInList(itemsList)

	if(numItems == 0)
		print "No traces found in top graph"
		return $""
	endif

	itemName = StringFromList(0, itemsList)
	if(!!numImages)
		return ImageNameToWaveRef("", itemName)
	endif
	return TraceNameToWaveRef("", itemName)
End

// set the (0,0) position within an image to the cursor position
Function SetScaleToCursor()
	Variable offsetX, offsetY, aExists

	WAVE/Z image = getTopWindowImage()
	if(!WaveExists(image))
		print "Utilities#SetScaleToCursor: image wave does not exist."
		return 0
	endif

	aExists = strlen(CsrInfo(A)) > 0
	if(!aExists)
		print "Utilities#SetScaleToCursor: Cursor A not in Graph"
		return 0
	endif

	offsetX = pcsr(A) * DimDelta(image, 0)
	offsetY = qcsr(A) * DimDelta(image, 1)
	AddWaveScaleOffset(image, offsetX, offsetY, relative = 0)
End

// rescale wave offset in x and y dimension
//
// @param [optional] specify whether the offset should be relative to the current offset or absolute
Function AddWaveScaleOffset(wv, offsetX, offsetY, [relative])
	WAVE wv
	Variable offsetX, offsetY
	Variable relative

	relative = ParamIsDefault(relative) ? 1 : !!relative

	if(relative)
		SetScale/P x, DimOffset(wv, 0) - offsetX, DimDelta(wv, 0), wv
		SetScale/P y, DimOffset(wv, 1) - offsetY, DimDelta(wv, 1), wv
	else
		SetScale/P x, - offsetX, DimDelta(wv, 0), wv
		SetScale/P y, - offsetY, DimDelta(wv, 1), wv
	endif
End

// save the graph window as png and as pxp
//
// @param win        name of graph as string
// @param customName [optional, default=win] name for output graph file.
//                   for Experiment.pxp the naming pattern is given by Experiment_customName.[png|pxp]
//                   Leave blank to get Experiment
// @param savePXP    save the graph window using SaveGraphCopy
Function saveWindow(win, [customName, savePXP])
	String win, customName
	Variable savePXP

	String expName, baseName
	Variable error = 0

	if(ParamIsDefault(savePXP))
		savePXP = 0
	endif

	DoWindow $win
	if(!V_flag)
		print "saveWindow: No such window: " + win
		return 1
	endif

	baseName = IgorInfo(1)
	if(ParamIsDefault(customName))
		baseName += "_" + win
	else
		if(strlen(customName) > 0)
			basename += "_"
		else
			savePXP = 0
		endif
		baseName += customName
	endif

	SavePICT/Z/WIN=$win/O/P=home/E=-5/B=288 as baseName + ".png"
	error = error | V_flag

	if(savePXP)
		SaveGraphCopy/Z/W=$win/O/P=home as baseName + ".pxp"
		error = error | V_flag
	endif

	return error
End