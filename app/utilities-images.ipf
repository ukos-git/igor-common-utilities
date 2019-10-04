#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#include "utilities-lists"

// from https://github.com/plotly/Igor-Pro-Graph-Converter
#include "Plotly"

Function/WAVE getTopWindowImage()
	String topWindowImages = ImageNameList("",";")

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

	String topWindowImages = ImageNameList("", ";")
	String topWindowTraces = TraceNameList("", ";", 1)
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
// @param savePXP    save the graph window using SaveGraphCopy
Function saveWindow(win, [customName, saveImages, saveUXP, saveVector, savePXP, saveIBW, saveJSON, path])
	String win, customName, path
	Variable saveImages, savePXP, saveUXP, saveIBW, saveJSON, saveVector

	String expName, baseName
	Variable refNum
	Variable error = 0

// graph storage subfolder system similar to uxp with packed experiments
#ifdef IMAGES_EXPORT_PXP
	savePXP = 1
	PathInfo home
	NewPath/C/O/Q/Z saveImagesPath, (S_path + IgorInfo(1))
#else
	if(ParamIsDefault(savePXP))
		savePXP = 0
	endif
#endif

	if(ParamIsDefault(saveUXP))
		saveUXP = 0
	endif
	if(saveUXP)
		customName = ""
		win = "kwTopWin" // can not save individual graphs
		saveImages = 0
	endif
	if(ParamIsDefault(saveIBW))
		saveIBW = 0
	endif
	if(ParamIsDefault(path))
		path = "saveImagesPath"
		PathInfo $path
		if(!V_flag) // workaround for UXP experiments
			PathInfo home
			NewPath/C/O/Q/Z saveImagesPath, S_path
		endif
	endif
	if(ParamIsDefault(saveJSON))
		saveJSON = 0
	endif
	if(ParamIsDefault(saveImages))
		saveImages = 1
	endif
	if(ParamIsDefault(saveVector))
		saveVector = 0
	endif


	DoWindow $win
	if(!V_flag && !saveUXP)
		print "saveWindow: No such window: " + win
		return 1
	endif

	baseName = ""
	if(ParamIsDefault(customName))
		baseName += win
	else
		if(strlen(customName) == 0)
			baseName = IgorInfo(1)
		else
			baseName += customName
		endif
	endif

	if(saveImages)
		SavePICT/Z/WIN=$win/O/P=$path/E=-5/B=288 as baseName + ".png"
		error = error | V_flag
	endif
	if(saveVector)
		SavePICT/Z/WIN=$win/O/P=$path/E=-9/B=288 as baseName + ".svg"
		SavePICT/Z/WIN=$win/O/P=$path/E=-3/S/B=288 as baseName + ".eps"
		error = error | V_flag
	endif

	if(savePXP)
		SaveGraphCopy/Z/W=$win/O/P=$path as baseName + ".pxp"
		error = error | V_flag
		Execute/Q/P ("DoWindow/R " + win)
		Open/T="TEXT"/P=$path/Z refNum as "Procedure.ipf"
		FStatus refNum
		if(V_flag)
			String procText = ReplaceString("\r", ProcedureText("", 0, "Procedure"), "\n") + "\n"
			FBinWrite refNum, procText
			Close refNum
		endif
		Open/P=$path/Z refNum as "history"
		FStatus refNum
		if(V_flag)
			Close refNum
			DoWindow/K HistoryCarbonCopy
			NewNotebook/V=0/F=0/N=HistoryCarbonCopy
			SaveNoteBook/O/S=3/P=$path HistoryCarbonCopy as "history"
		endif
	endif

	if(saveUXP)
		SaveExperiment/P=$path/C/F={0, baseName, 2} as (baseName + ".uxp")
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
		PathInfo $path
		Graph2Plotly(graph = win, output = S_path + basename + ".json", skipSend = 1, writeFile = 1)
	endif

	return error
End

Function SaveWindows(match)
	String match

	String windows = WinList(match, ";", "WIN:1;VISIBLE:1")
	Variable i, numWindows = ItemsInList(windows)

	for(i = 0; i < numWindows; i += 1)
		SaveWindow(StringFromList(i, windows))
	endfor
End
