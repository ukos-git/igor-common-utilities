#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma IndependentModule = Utilities
#include "utilities-lists"

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
