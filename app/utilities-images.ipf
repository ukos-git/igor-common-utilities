#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#include "utilities-lists"

// from https://github.com/plotly/Igor-Pro-Graph-Converter
#include "Plotly"

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
Function saveWindow(win, [customName, saveImages, savePXP, saveIBW, saveJSON, path])
	String win, customName, path
	Variable saveImages, savePXP, saveIBW, saveJSON

	String expName, baseName
	Variable error = 0

	if(ParamIsDefault(savePXP))
		savePXP = 0
	endif
	if(ParamIsDefault(saveIBW))
		saveIBW = 0
	endif
	if(ParamIsDefault(path))
		path = "home"
	endif
	if(ParamIsDefault(saveJSON))
		saveJSON = 1
	endif
	if(ParamIsDefault(saveImages))
		saveImages = 1
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

	if(saveImages)
		SavePICT/Z/WIN=$win/O/P=$path/E=-5/B=288 as baseName + ".png"
		error = error | V_flag
		SavePICT/Z/WIN=$win/O/P=$path/E=-8/B=288 as baseName + ".pdf"
		error = error | V_flag
		SavePICT/Z/WIN=$win/O/P=$path/E=-9/B=288 as baseName + ".svg"
		error = error | V_flag
	endif

	if(savePXP)
		SaveGraphCopy/Z/W=$win/O/P=$path as baseName + ".pxp"
		error = error | V_flag
	endif

	if(saveIBW)
		String imageList = ImageNameList(win, ";")
		WAVE/T images = ListtoTextWave(imageList, ";")
		Make/FREE/WAVE/N=(DimSize(images, 0)) waves = ImageNameToWaveRef(win, images[p])

		if(DimSize(waves, 0) == 0)
			String traceList = TraceNameList(win, ";", 0x001)
			WAVE/T traces = ListtoTextWave(traceList, ";")
			Make/FREE/WAVE/N=(DimSize(traces, 0)) waves = TraceNameToWaveRef(win, traces[p])
		endif

		Save/C/O/P=$path waves[0] as baseName + ".ibw"
	endif

	if(saveJSON)
		Graph2Plotly(graph = win, output = basename + ".json", skipSend = 1, writeFile = 1)
	endif

	return error
End

Function SaveWindows()
	String windows = WinList("*", ";", "WIN:1;VISIBLE:1")
	Variable i, numWindows = ItemsInList(windows)
	
	for(i = 0; i < numWindows; i += 1)
		SaveWindow(StringFromList(i, windows))
	endfor
End

// Call a function named export() before quitting the experiment.
//
// from https://github.com/byte-physics/igor-unit-testing-framework/blob/master/procedures/unit-testing-autorun.ipf
// Copyright 2013-2017 byte physics and contributors
// {

// automatically call the function export() after startup
// close hook would not be working together with Quit/N right now
static Function AfterFileOpenHook(refNum, file, pathName, type, creator, kind)
	variable refNum, kind
	string file, pathName, type, creator

	string funcList
	variable err
	
	if(!AutorunMode())
		return 0
	endif

	funcList = FunctionList("export", ";", "KIND:2,NPARAMS:0,WIN:[ProcGlobal]")
	if(ItemsInList(funcList) == 1)
		FuncRef PROTO_EXPORT f = $StringFromList(0, funcList)
		err = GetRTError(1)
		try
			f(); AbortOnRTE
		catch
			err = GetRTError(1)
			print "The export() function aborted with an RTE."
		endtry
	else
		try
			SaveWindows(); AbortOnRTE
		catch
			err = GetRTError(1)
			print "The export() function aborted with an RTE."
		endtry
		
	endif

	Execute/P/Q "QUIT/N"
End

Function PROTO_EXPORT()
End

/// Return 1 if in outrun mode
Function AutorunMode()
	string baseName = IgorInfo(1)
	GetFileFolderInfo/Q/Z/P=home baseName + ".autorun"

	if(!V_flag)
		return 1
	endif

	return 0
End

// }
