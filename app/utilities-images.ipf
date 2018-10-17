#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma IndependentModule = Utilities

Function/WAVE getTopWindowImage()
	String topWindowImages =	ImageNameList("",";")

	if(ItemsInList(topWindowImages) == 0)
		print "no Image found in top graph"
		return $""
	endif

	WAVE/Z image = ImageNameToWaveRef("", StringFromList(0, topWindowImages))
	if(!WaveExists(image))
		print "image wave does not exist."
		return $""
	endif

	return image
End
