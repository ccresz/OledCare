GetMonitorIndexFromWindow(windowHandle)
{
	; Starts with 1.
	monitorIndex := 1

	;VarSetCapacity(monitorInfo, 40) //v1
	;NumPut(40, monitorInfo) //v1
	;if (monitorHandle := DllCall("MonitorFromWindow", "uint", windowHandle, "uint", 0x2)) && DllCall("GetMonitorInfo", "uint", monitorHandle, "uint", &monitorInfo) //v1
	monitorInfo := Buffer(40, 0)
	;monitorInfo := 0
	;VarSetStrCapacity(&monitorInfo, 40)
	NumPut("ptr", 40, monitorInfo)
	
	if (monitorHandle := DllCall("MonitorFromWindow", "uint", windowHandle, "uint", 0x2)) 
		&& DllCall("GetMonitorInfo", "uint", monitorHandle, "UPtr", monitorInfo.ptr) 
	{
		monitorLeft   := NumGet(monitorInfo,  4, "Int")
		monitorTop    := NumGet(monitorInfo,  8, "Int")
		monitorRight  := NumGet(monitorInfo, 12, "Int")
		monitorBottom := NumGet(monitorInfo, 16, "Int")
		workLeft      := NumGet(monitorInfo, 20, "Int")
		workTop       := NumGet(monitorInfo, 24, "Int")
		workRight     := NumGet(monitorInfo, 28, "Int")
		workBottom    := NumGet(monitorInfo, 32, "Int")
		isPrimary     := NumGet(monitorInfo, 36, "Int") & 1

		Loop MonitorGetCount() {
			MonitorGet(A_Index, &tempMonLeft, &tempMonTop, &tempMonRight, &tempMonBottom)

			; Compare location to determine the monitor index.
			if ((monitorLeft = tempMonLeft) and (monitorTop = tempMonTop)
				and (monitorRight = tempMonRight) and (monitorBottom = tempMonBottom))
			{
				monitorIndex := A_Index
				break
			}
		}
	}
	
	return monitorIndex
}

GetMonitorWindowCount(monitorIndex)
{
	winList := WinGetList()
	winTitleMsg := ""
	winCount := 0
	for currentHWND in winList {
		;MsgBox (WinGetTitle(currentHWND) . " HWND: " . currentHWND)
		monIndex := GetMonitorIndexFromWindow(currentHWND)
		if (monIndex = monitorIndex && WinGetTitle(currentHWND) != "taskbarDimV2.2.ahk" && WinGetTitle(currentHWND) != "") {
			;MsgBox (WinGetTitle(currentHWND) . " Monitor: " . monIndex)
			++winCount
		}
		;winTitleMsg .= WinGetTitle(currentHWND) . " Monitor: " . monIndex
	}

	return winCount
}

;MsgBox (GetMonitorWindowCount(2))
