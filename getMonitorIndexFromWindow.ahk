GetMonitorIndexFromWindow(windowHandle)
{
	monitorIndex := 1
	monitorInfo := Buffer(40, 0)
	NumPut("ptr", 40, monitorInfo)

	if (monitorHandle := DllCall("MonitorFromWindow", "uint", windowHandle, "uint", 0x2))
		&& DllCall("GetMonitorInfo", "uint", monitorHandle, "UPtr", monitorInfo.ptr)
	{
		monitorLeft   := NumGet(monitorInfo,  4, "Int")
		monitorTop    := NumGet(monitorInfo,  8, "Int")
		monitorRight  := NumGet(monitorInfo, 12, "Int")
		monitorBottom := NumGet(monitorInfo, 16, "Int")

		Loop MonitorGetCount() {
			MonitorGet(A_Index, &tempMonLeft, &tempMonTop, &tempMonRight, &tempMonBottom)
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
	winCount := 0
	try {
		for currentHWND in WinGetList() {
			title := WinGetTitle(currentHWND)
			if (title = "" || title = "oledCare.ahk")
				continue
			if (GetMonitorIndexFromWindow(currentHWND) = monitorIndex)
				++winCount
		}
	}
	return winCount
}

hasFullScreenWindow(monitorIndex, monitorWidth, monitorHeight)
{
	static excludedClasses := ["Progman", "WorkerW"]
	try {
		for currentHWND in WinGetList() {
			winTitle := WinGetTitle(currentHWND)
			if (winTitle = "" || winTitle = "oledCare.ahk" || winTitle = "Program Manager")
				continue
			if (GetMonitorIndexFromWindow(currentHWND) != monitorIndex)
				continue
			winClass := WinGetClass(currentHWND)
			isExcluded := false
			for cls in excludedClasses {
				if (winClass = cls) {
					isExcluded := true
					break
				}
			}
			if (isExcluded)
				continue
			style := WinGetStyle(currentHWND)
			WinGetPos(&X, &Y, &winW, &winH, currentHWND)
			if ((style & 0x20800000) = 0 and winW >= monitorWidth and winH >= monitorHeight) {
				LogVerbose("hasFullScreenWindow: MATCH hwnd=" currentHWND " title='" winTitle "' class='" winClass "' style=" style " W=" winW " H=" winH)
				return currentHWND
			}
		}
	}
	return false
}

;MsgBox (GetMonitorWindowCount(2))
