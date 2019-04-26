#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// return a concatenated list
Function/S ConcatenateLists(list1, list2)
	String list1, list2

	list1 = AddTrailingListSeparator(list1)
	list2 = AddTrailingListSeparator(list2)

	return list1 + list2
End

// add a list spearator to the end of the current list
//
// also see RemoveEnding(str  [, endingStr ])
//
// @param list    input list
// @param listSep [optional] defaults to semicolon
Function/S AddTrailingListSeparator(list, [listSep])
	String list, listSep

	if(ParamIsDefault(listSep))
		listSep = ";"
	endif

	if(ItemsInList(list) == 0)
		return ""
	endif

	if(!!cmpstr(list[(strlen(list) - 1), strlen(list)], listSep))
		list = list + listSep
	endif

	return list
End
