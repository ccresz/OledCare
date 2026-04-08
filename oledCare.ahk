DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
#Requires AutoHotkey v2.0
#SingleInstance Force
InstallMouseHook
InstallKeybdHook

#Include "turnOffMonitor.ahk"
#Include "getMonitorIndexFromWindow.ahk"

; --- Logging utility ---
logPath := A_ScriptDir "\oledCare.log"
verboseLog := false  ; will be set from config below
Log(msg) {
	global logPath
	timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
	try FileAppend(timestamp " | " msg "`n", logPath)
}
LogVerbose(msg) {
	global verboseLog
	if (verboseLog)
		Log(msg)
}
; --- Scroll wheel resets idle timer (AHK doesn't count scroll as activity by default) ---
~WheelUp::
~WheelDown::
~WheelLeft::
~WheelRight::
{
	return  ; the ~ prefix passes the event through; firing the hotkey resets A_TimeIdlePhysical
}

Log("========== OledCare Started ==========")

; ============================================================
; Config
; ============================================================
configPath := A_ScriptDir "\config.ini"
configExamplePath := A_ScriptDir "\config.ini.example"
if !FileExist(configPath) {
	if FileExist(configExamplePath) {
		Log("config.ini not found, falling back to " configExamplePath)
		configPath := configExamplePath
	} else {
		Log("ERROR: Neither config.ini nor config.ini.example found in " A_ScriptDir)
		MsgBox "config.ini not found in " A_ScriptDir ".`nCopy config.ini.example to config.ini and edit it for your setup."
		ExitApp
	}
}

cfg := LoadConfig(configPath)
verboseLog := cfg["verboseLog"]
A_MaxHotkeysPerInterval := cfg["maxHotkeysPerInterval"]
Log("Config loaded: " ConfigToString(cfg))

; ============================================================
; Monitor detection
; ============================================================
Log("MonitorGetCount=" MonitorGetCount())
oledNumber := FindOledMonitor(cfg)
Log("Final oledNumber=" oledNumber)

; ============================================================
; State — single Map shared across timer callbacks
; ============================================================
state := Map(
	"oledNumber", oledNumber,
	"mouseMoved", 0,
	"guiMaximized", 0,
	"myGui", "",
	"myID", "",
	"dimTop", 0,
	"screenCenter", 0,
	"monitorWidth", cfg["oledDefaultWidth"],
	"monitorHeight", cfg["oledDefaultHeight"],
	"fullMonitorWidth", cfg["oledDefaultWidth"],
	"fullMonitorHeight", cfg["oledDefaultHeight"],
	"guiH", cfg["taskbarIconHeight"]
)

; ============================================================
; GUI initialisation & timer
; ============================================================
if (oledNumber != -1) {
	InitGui(oledNumber, cfg, state)
	SetTimer () => CoverIt(cfg, state), cfg["timerIntervalMs"]
	Log("GUI shown and timer started (interval=" cfg["timerIntervalMs"] "ms)")
}
return

; ############################################################
;  FUNCTIONS
; ############################################################

; --- Config loading -----------------------------------------------------------

LoadConfig(path) {
	c := Map()
	c["verboseLog"]           := IniRead(path, "Logging", "VerboseLog", "false") = "true"
	c["singleMonitorIsOled"]  := IniRead(path, "Monitor", "SingleMonitorIsOled", "false") = "true"
	c["oledMonitorModelName"] := IniRead(path, "Monitor", "OledMonitorModelName", "AW3423DWF")
	c["oledMonitorModelName2"]:= IniRead(path, "Monitor", "OledMonitorModelName2", "Samsung OLED Display")
	c["oledDefaultWidth"]     := Integer(IniRead(path, "Monitor", "OledDefaultWidth", "3440"))
	c["oledDefaultHeight"]    := Integer(IniRead(path, "Monitor", "OledDefaultHeight", "1440"))
	c["taskbarIconWidth"]     := Integer(IniRead(path, "Taskbar", "TaskbarIconWidth", "32"))
	c["taskbarIconHeight"]    := Integer(IniRead(path, "Taskbar", "TaskbarIconHeight", "48"))
	c["coverTransparency"]    := Integer(IniRead(path, "Display", "CoverTransparency", "225"))
	c["dimmingTransparency"]  := Integer(IniRead(path, "Display", "DimmingTransparency", "252"))
	c["timeIdleSeconds"]      := Integer(IniRead(path, "Idle", "TimeIdleSeconds", "30"))
	c["turnOffMode"]          := IniRead(path, "Idle", "TurnOffMode", "overlay")
	c["livelyPath"]           := IniRead(path, "Lively", "CommandUtilityPath", "")

	; GUI layout
	c["timerIntervalMs"]      := Integer(IniRead(path, "GUI", "TimerIntervalMs", "500"))
	c["guiHorizontalPadding"] := Integer(IniRead(path, "GUI", "GuiHorizontalPadding", "34"))
	c["guiCenteringOffset"]   := Integer(IniRead(path, "GUI", "GuiCenteringOffset", "4"))
	c["overlayWidthAdjust"]   := Integer(IniRead(path, "GUI", "OverlayWidthAdjustment", "3"))
	c["maxHotkeysPerInterval"]:= Integer(IniRead(path, "GUI", "MaxHotkeysPerInterval", "200"))

	; Idle multipliers with validation
	defOverlay := 1.2, defTurnOff := 6.0
	c["overlayMultiplier"] := Float(IniRead(path, "Idle", "OverlayMultiplier", String(defOverlay)))
	c["turnOffMultiplier"] := Float(IniRead(path, "Idle", "TurnOffMultiplier", String(defTurnOff)))
	if (c["overlayMultiplier"] <= 1.0) {
		Log("WARNING: OverlayMultiplier=" c["overlayMultiplier"] " <= 1.0, using default " defOverlay)
		c["overlayMultiplier"] := defOverlay
	}
	if (c["turnOffMultiplier"] <= c["overlayMultiplier"]) {
		Log("WARNING: TurnOffMultiplier=" c["turnOffMultiplier"] " <= OverlayMultiplier, using default " defTurnOff)
		c["turnOffMultiplier"] := defTurnOff
	}
	return c
}

ConfigToString(c) {
	return "oledMonitorModelName=" c["oledMonitorModelName"]
		. " oledMonitorModelName2=" c["oledMonitorModelName2"]
		. " oledDefaultWidth=" c["oledDefaultWidth"]
		. " oledDefaultHeight=" c["oledDefaultHeight"]
		. " taskbarIconWidth=" c["taskbarIconWidth"]
		. " taskbarIconHeight=" c["taskbarIconHeight"]
		. " coverTransparency=" c["coverTransparency"]
		. " dimmingTransparency=" c["dimmingTransparency"]
		. " timeIdleSeconds=" c["timeIdleSeconds"]
		. " turnOffMode=" c["turnOffMode"]
		. " overlayMultiplier=" c["overlayMultiplier"]
		. " turnOffMultiplier=" c["turnOffMultiplier"]
		. " timerIntervalMs=" c["timerIntervalMs"]
		. " guiHorizontalPadding=" c["guiHorizontalPadding"]
		. " guiCenteringOffset=" c["guiCenteringOffset"]
		. " overlayWidthAdjust=" c["overlayWidthAdjust"]
		. " singleMonitorIsOled=" (c["singleMonitorIsOled"] ? "true" : "false")
		. " verboseLog=" (c["verboseLog"] ? "true" : "false")
		. " livelyPath=" c["livelyPath"]
}

; --- WMI helper ---------------------------------------------------------------

WmiStringValue(obj) {
	if (Type(obj) = "String")
		return obj
	result := ""
	for char in obj
		result .= Chr(char)
	return result
}

; --- Monitor detection --------------------------------------------------------

FindOledMonitor(cfg) {
	if (MonitorGetCount() = 1) {
		return cfg["singleMonitorIsOled"] ? 1 : -1
	}

	; Query WMI for monitor friendly names
	wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\" A_ComputerName "\root\wmi")
	for monitor in wmi.ExecQuery("Select * from WmiMonitorID") {
		fname := WmiStringValue(monitor.UserFriendlyName)
		iname := WmiStringValue(monitor.InstanceName)
		pcode := WmiStringValue(monitor.ProductCodeID)
		mname := WmiStringValue(monitor.ManufacturerName)
		Log("WMI Monitor: fname=" fname " iname=" iname " pcode=" pcode " mname=" mname)
	}

	; Enumerate display devices and find the OLED by model name
	OledName := ""
	idx := 0
	While EnumDisplayDevices(idx, &dev0) {
		EnumDisplayDevices(idx, &dev1, 1)
		Log("EnumDisplayDevices[" idx "]: DeviceName=" dev0["DeviceName"] " DeviceString=" dev0["DeviceString"] " StateFlags=" dev0["StateFlags"])
		Log("EnumDisplayDevices[" idx "] EDD: DeviceName=" dev1["DeviceName"] " DeviceID=" dev1["DeviceID"])

		for k, v in dev1 {
			if (!IsSet(v))
				continue
			if (InStr(v, cfg["oledMonitorModelName"]) || InStr(v, cfg["oledMonitorModelName2"])) {
				Log("EnumDisplayDevices: matched model name in value=" v " at index=" idx)
				OledName := dev1["DeviceName"]
			}
		}
		idx++
	}

	; Clean up the display name for matching
	OledName := "\\.\" . RegExReplace(OledName, ".*(DISPLAY\d+).*", "$1")
	Log("OledName after regex=" OledName)

	; Strategy 1: Exact match
	Loop MonitorGetCount() {
		name := MonitorGetName(A_Index)
		Log("MonitorGetName(" A_Index ")=" name)
		if (OledName = name) {
			Log("Exact match found: oledNumber=" A_Index)
			return A_Index
		}
	}

	; Strategy 2: Substring match
	Loop MonitorGetCount() {
		if (InStr(OledName, MonitorGetName(A_Index))) {
			Log("Substring match found: oledNumber=" A_Index)
			return A_Index
		}
	}

	; Strategy 3: Position-based fallback (OLED to the left of primary)
	Loop MonitorGetCount() {
		MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
		Log("Position fallback: Monitor " A_Index " Left=" Left " Top=" Top " Right=" Right " Bottom=" Bottom)
		if (Left = -cfg["oledDefaultWidth"]) {
			Log("Position fallback match: oledNumber=" A_Index)
			return A_Index
		}
	}

	return -1
}

; --- GUI initialisation -------------------------------------------------------

InitGui(oledNumber, cfg, state) {
	MonitorGet(oledNumber, &MonLeft, &MonTop, &MonRight, &MonBottom)
	Log("Full Monitor bounds: Left=" MonLeft " Top=" MonTop " Right=" MonRight " Bottom=" MonBottom)

	MonitorGetWorkArea(oledNumber, &WL, &WT, &WR, &WB)
	Log("WorkArea: Left=" WL " Top=" WT " Right=" WR " Bottom=" WB)

	taskbarHeight := MonBottom - WB
	Log("Detected taskbar height=" taskbarHeight)

	mw := WR - WL
	mh := WB - WT
	fmw := MonRight - MonLeft
	fmh := MonBottom - MonTop
	guiH := (taskbarHeight > 0) ? taskbarHeight : cfg["taskbarIconHeight"]
	dimTop := MonBottom - guiH
	center := Integer(WL + (mw / 2))

	winOnCount := GetMonitorWindowCount(oledNumber)
	guiW := (winOnCount * cfg["taskbarIconWidth"]) + cfg["guiHorizontalPadding"]
	guiX := Integer(center - (guiW / 2) + cfg["taskbarIconWidth"] - cfg["guiCenteringOffset"])

	Log("monitorWidth=" mw " monitorHeight=" mh " fullMonitorWidth=" fmw " fullMonitorHeight=" fmh)
	Log("screenCenter=" center " guiX=" guiX " dimTop=" dimTop " guiW=" guiW " guiH=" guiH)

	; Store computed values in state
	state["monitorWidth"]      := mw
	state["monitorHeight"]     := mh
	state["fullMonitorWidth"]  := fmw
	state["fullMonitorHeight"] := fmh
	state["screenCenter"]      := center
	state["dimTop"]            := dimTop
	state["guiH"]              := guiH

	myGui := Gui()
	myGui.Opt("-Caption +ToolWindow +E0x20 -DPIScale")
	myGui.BackColor := "000000"
	myID := WinGetID(myGui)
	WinSetAlwaysOnTop 1, myID
	WinSetTransparent cfg["coverTransparency"], myID
	myGui.Show("X" guiX " Y" dimTop " W" guiW " H" guiH)

	try {
		WinGetPos &aX, &aY, &aW, &aH, myID
		Log("Actual GUI position: X=" aX " Y=" aY " W=" aW " H=" aH)
	}
	WinShow myID

	state["myGui"] := myGui
	state["myID"]  := myID
}

; --- Main timer callback ------------------------------------------------------

CoverIt(cfg, state) {
	myID := state["myID"]
	oledNumber := state["oledNumber"]

	; Check if the OLED monitor is still connected
	if (oledNumber > MonitorGetCount()) {
		; Monitor was disconnected — hide overlay and reset state
		if (!state.Has("monitorLost") || state["monitorLost"] = 0) {
			Log("Monitor " oledNumber " disconnected (MonitorGetCount=" MonitorGetCount() "). Hiding overlay.")
			state["monitorLost"] := 1
			WinHide myID
			if (state["guiMaximized"] = 1) {
				state["myGui"].Restore()
				state["guiMaximized"] := 0
			}
			ShowCursor()
			ResumeLively(cfg)
			state["mouseMoved"] := 0
		}
		return
	}

	; Monitor is back — re-detect index (it may have changed) and reinitialise
	if (state.Has("monitorLost") && state["monitorLost"] = 1) {
		newOledNumber := FindOledMonitor(cfg)
		if (newOledNumber = -1) {
			LogVerbose("Monitor count restored but OLED not found yet, waiting...")
			return
		}
		Log("Monitor reconnected as index " newOledNumber " (was " oledNumber "). Reinitialising GUI.")
		state["oledNumber"] := newOledNumber
		state["monitorLost"] := 0
		oledNumber := newOledNumber
		InitGui(oledNumber, cfg, state)
		myID := state["myID"]
	}

	timeIdleMin := cfg["timeIdleSeconds"] * 1000
	isFull := IsActiveWindowFullScreen(myID, state)

	if (!isFull) {
		inactiveFS := hasFullScreenWindow(oledNumber, state["fullMonitorWidth"], state["fullMonitorHeight"])
		isFull := (inactiveFS && inactiveFS != myID)
	}
	LogVerbose("coverIt: isFull=" isFull)

	if (isFull) {
		OnFullScreenDetected(cfg, state)
	} else if (A_TimeIdlePhysical > timeIdleMin) {
		OnIdle(oledNumber, cfg, state, timeIdleMin)
	} else {
		OnActive(oledNumber, cfg, state)
	}
}

IsActiveWindowFullScreen(myID, state) {
	activeWindow := WinExist("A")
	if (!activeWindow || !WinActive(activeWindow) || activeWindow = myID)
		return false
	try {
		winTitle := WinGetTitle(activeWindow)
		style := WinGetStyle(winTitle)
		WinGetPos &X, &Y, &winW, &winH, winTitle
		result := ((style & 0x20800000) = 0 and winW >= state["fullMonitorWidth"] and winH >= state["fullMonitorHeight"])
		LogVerbose("IsActiveWindowFullScreen: '" winTitle "' " winW "x" winH " full=" result)
		return result
	}
	return false
}

OnFullScreenDetected(cfg, state) {
	WinHide state["myID"]
	state["mouseMoved"] := 0
	WinSetTransparent cfg["coverTransparency"], state["myID"]
	if (state["guiMaximized"] = 1) {
		state["guiMaximized"] := 0
		state["myGui"].Restore()
		ShowCursor()
		ResumeLively(cfg)
	}
}

OnIdle(oledNumber, cfg, state, timeIdleMin) {
	myID := state["myID"]
	WinShow myID
	WinSetAlwaysOnTop 1, myID

	if (state["mouseMoved"] = 0) {
		CoordMode "Mouse", "Screen"
		MouseMove (A_ScreenWidth // 2), (A_ScreenHeight // 2)
		state["mouseMoved"] := 1
		HideCursor()
		return
	}

	if (A_TimeIdlePhysical > (timeIdleMin * cfg["overlayMultiplier"])) {
		if (state["guiMaximized"] = 0) {
			WinSetTransparent cfg["dimmingTransparency"], myID
			state["myGui"].Maximize()
			state["guiMaximized"] := 1
			PauseLively(cfg)
			return
		}
		if (A_TimeIdlePhysical > (timeIdleMin * cfg["turnOffMultiplier"])) {
			if (cfg["turnOffMode"] = "real")
				TurnOff(oledNumber)
			else
				WinSetTransparent 255, myID  ; fully opaque black = OLED pixels off
		}
	}
}

OnActive(oledNumber, cfg, state) {
	myID := state["myID"]
	WinShow myID
	WinSetAlwaysOnTop 1, myID
	state["mouseMoved"] := 0

	if (state["guiMaximized"] = 1) {
		state["myGui"].Restore()
		state["guiMaximized"] := 0
		ShowCursor()
		ResumeLively(cfg)
	} else {
		WinSetTransparent cfg["coverTransparency"], myID
		ShowCursor()
		if (cfg["turnOffMode"] = "real")
			TurnOn(oledNumber)
		guiW := state["monitorWidth"] + cfg["overlayWidthAdjust"]
		guiX := Integer(state["screenCenter"] - (guiW / 2) + cfg["taskbarIconWidth"] - cfg["guiHorizontalPadding"])
		WinMove(guiX, state["dimTop"], guiW, state["guiH"], myID)
	}
}

; --- Display device enumeration -----------------------------------

EnumDisplayDevices(iDevNum, &DISPLAY_DEVICEA:="", dwFlags:=0) {
	Static EDD_GET_DEVICE_INTERFACE_NAME := 0x00000001
		, byteCount     := 4+4+((32+128+128+128)*2)
		, offset_cb     := 0
		, offset_DeviceName   := 4,                length_DeviceName   := 32
		, offset_DeviceString := 4+(32*2),          length_DeviceString := 128
		, offset_StateFlags   := 4+((32+128)*2)
		, offset_DeviceID     := 4+4+((32+128)*2),  length_DeviceID    := 128
		, offset_DeviceKey    := 4+4+((32+128+128)*2), length_DeviceKey := 128

	DISPLAY_DEVICEA := ""
	if (iDevNum ~= "\D" || (dwFlags != 0 && dwFlags != EDD_GET_DEVICE_INTERFACE_NAME))
		return false
	lpDisplayDevice := Buffer(byteCount, 0)
	NumPut("UInt", byteCount, lpDisplayDevice, offset_cb)
	if !DllCall("EnumDisplayDevices", "Ptr", 0, "UInt", iDevNum, "Ptr", lpDisplayDevice.Ptr, "UInt", 0)
		return false
	if (dwFlags = EDD_GET_DEVICE_INTERFACE_NAME) {
		DeviceName := StrGet(lpDisplayDevice.Ptr + offset_DeviceName, length_DeviceName)
		lpDisplayDevice.__New(byteCount, 0)
		NumPut("UInt", byteCount, lpDisplayDevice, offset_cb)
		lpDevice := Buffer(length_DeviceName * 2, 0)
		StrPut(DeviceName, lpDevice, length_DeviceName)
		DllCall("EnumDisplayDevices", "Ptr", lpDevice.Ptr, "UInt", 0, "Ptr", lpDisplayDevice.Ptr, "UInt", dwFlags)
	}
	For k in (DISPLAY_DEVICEA := Map("cb",0,"DeviceName","","DeviceString","","StateFlags",0,"DeviceID","","DeviceKey","")) {
		Switch k {
			case "cb","StateFlags": DISPLAY_DEVICEA[k] := NumGet(lpDisplayDevice, offset_%k%, "UInt")
			default:                DISPLAY_DEVICEA[k] := StrGet(lpDisplayDevice.Ptr + offset_%k%, length_%k%)
		}
	}
	return true
}

; --- Lively wallpaper control -------------------------------------------------

PauseLively(cfg) {
	if (cfg["livelyPath"] = "")
		return
	try Run(cfg["livelyPath"] ' --play false',, "Hide")
}

ResumeLively(cfg) {
	if (cfg["livelyPath"] = "")
		return
	try Run(cfg["livelyPath"] ' --play true',, "Hide")
}

; --- Cursor visibility --------------------------------------------------------

HideCursor() {
	andMask := Buffer(4, 0xFF)  ; AND mask: all 1s = transparent
	xorMask := Buffer(4, 0x00)  ; XOR mask: all 0s = no inversion
	blankCursor := DllCall("CreateCursor", "Ptr", 0, "Int", 0, "Int", 0
		, "Int", 1, "Int", 1, "Ptr", andMask.Ptr, "Ptr", xorMask.Ptr, "Ptr")
	; Standard system cursor IDs (OCR_* constants)
	static cursorIDs := [
		32512,  ; OCR_NORMAL / IDC_ARROW
		32513,  ; OCR_IBEAM
		32514,  ; OCR_WAIT
		32515,  ; OCR_CROSS
		32516,  ; OCR_UP / IDC_UPARROW
		32631,  ; undocumented/legacy
		32640,  ; OCR_SIZE (obsolete)
		32641,  ; OCR_ICON (obsolete)
		32642,  ; OCR_SIZENWSE
		32643,  ; OCR_SIZENESW
		32644,  ; OCR_SIZEWE
		32645,  ; OCR_SIZENS
		32646,  ; OCR_SIZEALL
		32648,  ; OCR_NO
		32649,  ; OCR_HAND
		32650,  ; OCR_APPSTARTING
		32651   ; OCR_HELP
	]
	for id in cursorIDs {
		copy := DllCall("CopyImage", "Ptr", blankCursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
		DllCall("SetSystemCursor", "Ptr", copy, "UInt", id)
	}
	DllCall("DestroyCursor", "Ptr", blankCursor)
}

ShowCursor() {
	; SPI_SETCURSORS = 0x0057 — restores all system cursors from registry defaults
	DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)
}
