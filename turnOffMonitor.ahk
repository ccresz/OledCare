GetMonitorHandle(MonitorNumber := "") {
	static MONITOR_DEFAULTTONULL := 0
	static MONITOR_DEFAULTTOPRIMARY := 1
	static MONITOR_DEFAULTTONEAREST := 2

	if (MonitorNumber) {
		; Enum for monitor handles and get the MonitorNumber-th handle
		;H_MON_MEM := 0
		;VarSetStrCapacity(&H_MON_MEM, 40)  ; Alloc some memory for the monitor handles
		H_MON_MEM:=Buffer(40, 0)
		Callback := CallbackCreate(MONITOR_ENUM_PROC) ; Create a callback for EnumDisplayMonitors to pass the monitor handles to
		DllCall("EnumDisplayMonitors", "UInt", 0, "UInt", 0, "UPtr", Callback, "UPtr", H_MON_MEM.Ptr) ; Call EnumDisplayMonitors with null for the first two params to enum for all monitors, and the address of our memory to put handles into
		hMon := NumGet(H_MON_MEM.Ptr, (MonitorNumber - 1) * 4, "UInt") ; Get the MonitorNumber-th 4 byte handle out of the memory pool
	}
	else {
		; Else, use the primary monitor
		hMon := DllCall("MonitorFromPoint", "UInt", 0, "UInt", MONITOR_DEFAULTTOPRIMARY)
	}

	; Get Physical Monitor from handle
	PHYSICAL_MONITOR := Buffer(4 + (128 * 2), 0) ;   HANDLE hPhysicalMonitor; WCHAR szPhysicalMonitorDescription[128];

	DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR", "UInt", hMon, "UInt", 1, "UPtr", PHYSICAL_MONITOR.Ptr)
	; Return the handle to the physical monitor (offset 0, 4 bytes)

	return NumGet(PHYSICAL_MONITOR.Ptr, 0, "UInt")
}
DestroyMonitorHandle(hMon) {
	DllCall("dxva2\DestroyPhysicalMonitor", "UPtr", hMon)
}
MONITOR_ENUM_PROC(hMon, hDC, lpRect, lParam) {
	; EnumDisplayMonitors will call, passing the monitor handle, null, a bouding rectangle and the fourth value we passed to it
	; In this case, the extra fourth value is an address in memory where we can store the monitor handles
	loop {
		if (NumGet(lParam+0, (A_Index - 1) * 4, "UInt") = 0) {
			Offset := (A_Index - 1) * 4
			Break
		}
	}
	; Loop through our memory until we've 4 free bytes
	NumPut("UInt", hMon, lParam+0, Offset)
	; Put the monitor handle into the free memory
	return true
}
TurnOff(MonitorNumber := "") {
	static VCP_POWERMODE := 0xD6
	hMon := GetMonitorHandle(MonitorNumber)

	DllCall("dxva2\SetVCPFeature", "UPtr", hMon, "Char", VCP_POWERMODE, "UInt", 4)

	DestroyMonitorHandle(hMon)
	return
}
TurnOn(MonitorNumber := "") {
	static VCP_POWERMODE := 0xD6
	hMon := GetMonitorHandle(MonitorNumber)

	DllCall("dxva2\SetVCPFeature", "UPtr", hMon, "Char", VCP_POWERMODE, "UInt", 1)

	DestroyMonitorHandle(hMon)
	return
}

Pause::TurnOff(4)
ScrollLock::TurnOn(4)