#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// create/load and save functions from FILO (igor-file-loader)
// https://github.com/ukos-git/igor-file-loader

Function createSVAR(name, [dfr, set, init])
	String name
	DFREF dfr
	String set, init

	if(ParamIsDefault(dfr))
		dfr = GetDataFolderDFR()
	endif

	SVAR/Z/SDFR=dfr var = $name
	if(!SVAR_EXISTS(var))
		if(ParamIsDefault(init))
			String/G dfr:$name
		else
			String/G dfr:$name = init
		endif
	endif

	if(!ParamIsDefault(set))
		SVAR/SDFR=dfr var = $name
		var = set
	endif
End


Function/S loadSVAR(name, [dfr, defStrVal])
	String name
	DFREF dfr
	String defStrVal

	String pathStr

	if(ParamIsDefault(dfr))
		dfr = GetDataFolderDFR()
	endif
	if(ParamIsDefault(defStrVal))
		defStrVal = ""
	endif

	pathStr = GetDataFolder(1, dfr) + name

	// deprecated.
	SVAR/Z/SDFR=dfr var = $name
	if(!SVAR_EXISTS(var))
		printf "Utilities#loadSVAR() could not find %s\r", pathStr
	endif

	return StrVarOrDefault(pathStr, defStrVal)
End

Function loadNVAR(name, [dfr])
	String name
	DFREF dfr

	if(ParamIsDefault(dfr))
		dfr = GetDataFolderDFR()
	endif

	NVAR/Z/SDFR=dfr var = $name

	return var
End

Function saveSVAR(name, set, [dfr])
	String name, set
	DFREF dfr

	if(ParamIsDefault(dfr))
		dfr = GetDataFolderDFR()
	endif

	SVAR/Z/SDFR=dfr var = $name
	if(!SVAR_EXISTS(var))
		return 0
	endif

	var = set

	return 1
End

Function saveNVAR(name, set, [dfr])
	String name
	Variable set
	DFREF dfr

	if(ParamIsDefault(dfr))
		dfr = GetDataFolderDFR()
	endif

	NVAR/Z/SDFR=dfr var = $name
	if(!NVAR_EXISTS(var))
		return 0
	endif

	var = set

	return 1
End

Function createNVAR(name, [dfr, set, init])
	String name
	DFREF dfr
	Variable set, init

	if(ParamIsDefault(dfr))
		dfr = GetDataFolderDFR()
	endif

	NVAR/Z/SDFR=dfr var = $name
	if(!NVAR_EXISTS(var))
		if(ParamIsDefault(init))
			Variable/G dfr:$name
		else
			Variable/G dfr:$name = init
		endif
	endif

	if(!ParamIsDefault(set))
		NVAR/SDFR=dfr var = $name
		var = set
	endif
End
