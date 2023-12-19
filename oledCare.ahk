DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
#Requires AutoHotkey v2.0
#SingleInstance Force
InstallMouseHook
InstallKeybdHook

#Include "turnOffMonitor.ahk"
#Include "getMonitorIndexFromWindow.ahk"

oledNumber:=-1
; The following should be taken from a config file or calculated instead of hardcoded to work with  other monitor models
oledMonitorModelName := "AW3423DWF" 
oledDefaultWidth := 3440
oledDefaultHeight := 1440
taskbarIconWidth := 34 ; Assuming taskbar icons are 34px wide, this is the case using the Start11 app, but again should come from config or function
taskbarIconHeight := 63 ; This is the height of the windows taskbar.

if (MonitorGetCount() = 1) {
	;No need to try to guess the monitor index if is the only one plugged in
	oledNumber := 0
} else {
	wmiMonitorInfo:=Map()
	output:=""
	wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\" A_ComputerName "\root\wmi")
	for monitor in wmi.ExecQuery("Select * from WmiMonitorID") {
		fname := ""
		if(Type(monitor.UserFriendlyName) = "String") {
			fname := monitor.UserFriendlyName
		} else {
			for char in monitor.UserFriendlyName
				fname .= Chr(char)
		}
		iname := ""
		if(Type( monitor.InstanceName) = "String") {
			iname := monitor.InstanceName
		} else {
			for char in monitor.InstanceName
				iname .= Chr(char)
		}
		pcode := ""
		if(Type( monitor.ProductCodeID) = "String") {
			pcode := monitor.ProductCodeID
		} else {
			for char in monitor.ProductCodeID
				pcode .= Chr(char)
		}
		mname := ""
		if(Type( monitor.ManufacturerName) = "String") {
			mname := monitor.ManufacturerName
		} else {
			for char in monitor.ProductCodeID
				mname .= Chr(char)
		}

		if(!IsSet(fname) or StrLen(fname)=0 or fname=""){
			;fname := "Display"
		}
		;msgbox (" :: " . fname)
		;msgbox (" :: " . iname)
		;MsgBox ("fname:: " fname " iname:: "  iname  " pcode:: "  pcode  " mname:: "  mname "`n")
		wmiMonitorInfo[iname] := fname
		;ListVars
		;Pause
		;msgbox (fname)
		;msgbox (iname)
	}
	;MsgBox (output)
	MonitorInfos:=Map()
	OledName:=""
	While EnumDisplayDevices(A_Index-1, &DISPLAY_DEVICEA0)    {
		tp:=""
		if !DISPLAY_DEVICEA0["StateFlags"]
			;continue
		tp:="    1. EnumDisplayDevices`n`n"
		For k,v in DISPLAY_DEVICEA0
			tp.=k " : " v "`n"
		tp.="`n`n`n    2. EnumDisplayDevices with EDD_GET_DEVICE_INTERFACE_NAME`n`n"
		EnumDisplayDevices(A_Index-1, &DISPLAY_DEVICEA1, 1)
		For k,v in DISPLAY_DEVICEA1 {
			DeviceString:=""
			tp.=k " : " v "`n"
			if(isSet(v)){
				if(InStr(v, OledMonitorModelName)) {
					;MsgBox ("Monitor is  " A_Index-1)
					OledName:=DISPLAY_DEVICEA1["DeviceName"]
				}
			}
		}
		MonitorClipboard:=tp
		;if(isSet(tp)){
			;if(InStr(tp, "AW3423DWF")) {
				;MsgBox ("Monitor is number " A_Index-1)
			;}
		;}

		;MsgBox (DISPLAY_DEVICEA0["DeviceName"] " :: " tp)
		if RegExMatch(DISPLAY_DEVICEA1["DeviceID"], "(?<=#).*?(?=#)", &M)
			MonitorInfos[DISPLAY_DEVICEA0["DeviceName"]]:=Map("GUID",M.0, "Wmi",Map("CurrentBrightness",""))
			;MsgBox DISPLAY_DEVICEA0["DeviceName"]
			;MonitorInfos[DISPLAY_DEVICEA0["DeviceName"]]:=Map("GUID",DISPLAY_DEVICEA1["DeviceID"], "Wmi",Map("CurrentBrightness",""))

	}
	; We have seen Display Names come like: \\.\DISPLAY10\Monitor0 or \\.\DISPLAY10\ or \\.\DISPLAY10
	; so this regex extracts the DISPLA10 part so we can do a more precise match, because just looking for
	; the substring will not give you the correct result if you have DISPLAY10 and DISPLAY1 in the list and DISPLAY1
	; is at the bottom of the list or if they are in the opposite order it may break too early out of the loop
	; if you can think of a better way to match the names than just falling back to less and less precise options
	OledName := "\\.\" . RegExReplace(OledName, ".*(DISPLAY\d+).*", "$1")
	;MsgBox ("OledName :: " OledName)
	Loop MonitorGetCount() {
		if(OledName = MonitorGetName(A_Index)) {
			;MsgBox (A_Index " :: " MonitorGetName(A_Index))
			oledNumber:=A_Index
			break
		}
	}
	; If we didn't get a exact match we try to find the substring instead.
	if(oledNumber = -1) {
		Loop MonitorGetCount() {
			;MsgBox (A_Index " :: " MonitorGetName(A_Index))
			if(InStr(OledName, MonitorGetName(A_Index))) {
				oledNumber:=A_Index
				break
			}
		}
	}
	; If even after the substring search we could not find a match (probably the DLL call failed and didn't return results)
	; then we try to guess the monitor by position. This assumes the monitor is positioned to the left of the primary monitor
	; because monitorGet gets coordinates relative to that, if your main monitor is positioned differently you may want to output
	; all the monitor positions and modify this script so it uses the known position of your monitor instead.
	;Msgbox "oledNumber :: " oledNumber
	if(oledNumber = -1){
		Loop MonitorGetCount() {
			MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
			if (Left = -OledDefaultWidth) {
				oledNumber := A_Index
			}
		}
	}
}
; If the monitor is found then run the main functions.
if(oledNumber != -1){
	;Msgbox "oledNumber :: " oledNumber
	mouseMoved := 0 										; variable to keep track if the mouse was moved by this script or the human
	guiMaximized := 0										; variable to keep track if the gui is covering the entire scren or just the taskbar
	monitorWidth := oledDefaultWidth                        ; TODO: call a function to the actual screen width if the monitor is found.
	monitorHeight := oledDefaultHeight                      ; TODO: call a function to the actual screen height if the monitor is found.
	winOnCount := GetMonitorWindowCount(oledNumber)			; variable to keep track of how many apps/icons we are showing on the taskbar
	guiW := winOnCount * taskbarIconWidth					; this will determine the with of the taskbar cover rectangle
	screenCenter := monitorWidth / 2						; the center of the oled display
	guiX := screenCenter + (guiW / 2)						; the calculated X value for the rectangle so it sits on the middle of the taskbar
	MonitorWorkArea := MonitorGetWorkArea(                  ;Get the monitor work area which is the fullscreen coordinates without the taskbar
		oledNumber, 
		&WorkAreaLeft, 
		&WorkAreaTop, 
		&WorkAreaRight, 
		&WorkAreaBottom
	)
	dimTop := WorkAreaBottom - 1             				; taskbar is assumed to start below the work-area
	myGui:= Gui()											; Initialize a new Gui this will basically be a see through rectangle.
	myGui.Opt("-Caption +ToolWindow +E0x20 -DPIScale") 		; No title bar, No taskbar button, Transparent for clicks
	MyGui.BackColor := "000000"								; Base Background color will be black
	myID := WinGetID(myGui)                          		; Get its HWND/handle ID
	WinSetAlwaysOnTop 1, myID				         		; Keep it always on the top
	WinSetTransparent 240, myID            					; Transparency [Range is 99 min which is solid to 255 which is fully transparent]
	WinSetTransColor "000000 240", myID						; Set transparency
	myGui.Show(                                             ; Create a semi-transparent cover window TODO: make the height configurable or calculated based off the work area
		"X-" . guiX . 
		" Y" . dimTop . 
		" W" . guiW . 
		" H" . taskbarIconHeight
	)    
	SetTimer coverIt, 500                     							; Repeat setting it to be on top taskbar
}
return
;MsgBox ("Done")

coverIt(){
	global mouseMoved
	global guiMaximized
	global MyGui
	global myID
	global oledNumber
	global dimTop
	global screenCenter	
	global monitorWidth
	global monitorHeight
	global taskbarIconWidth
	
	timeIdleMin:= 30 * 1000 ; seconds by miliseconds TODO: make this configurable
	isFull := false
	activeWindow := WinExist("A")
	if(activeWindow and WinActive(activeWindow)) { ;if there is an active window check if is fullscreen or not
		try {
			winTitle := WinGetTitle(activeWindow)
			style := WinGetStyle(winTitle)           ; Get active window style and dimensions
			WinGetPos &X, &Y,&winW,&winH, winTitle
			; 0x800000 is WS_BORDER.
			; 0x20000000 is WS_MINIMIZE.
			; check no border and not minimized
			;isfull := ((style & 0x20800000) = 0 and winH >= A_ScreenHeight and winW >= A_ScreenWidth)
			isfull := ((style & 0x20800000) = 0 and winW >= monitorWidth and winH >= monitorHeight) ;TODO: width and height should come from the identified monitor with and height instead of harcoded
		} catch Error as err {
			isfull:=false
		}
	}
    if (isfull and activeWindow!=myID) { ;if there is a fullscreen window and is not our UI dimmer overlay then keep our overlay minimized to avoid dimming the screen while a fullscreen app is running.
        WinHide myID
		MouseMoved := 0
		WinSetTransparent 245, myID
		if(guiMaximized){
			guiMaximized := 0
			MyGui.Restore()
		}
    } else {
        WinShow myID
        WinSetAlwaysOnTop 1, myID     ; Ensure it is still on the top
		If (A_TimeIdlePhysical > timeIdleMin) {
			;TransDegree := WinGetTransparent(myID)
			if (mouseMoved = 0) {
				CoordMode "Mouse", "Screen"
				MouseMove (A_ScreenWidth // 2), (A_ScreenHeight // 2)
				mouseMoved := 1
				; TODO: find a way to hide the cursor instead of moving it outside of the screen, so it behaves like when a fullscreen video is playing
				;sleep(10)
				;BlockInput "MouseMove"
				;DllCall("User32.dll\ShowCursor", "uint", 0)
				;DllCall("User32.dll\HideCaret")
				;MouseGetPos &xpos, &ypos, &hwnd
				;Cursor:= Gui()
				;Cursor.Opt("+Owner" hwnd)
				;Cursor.show("X" . xpos . "Y" . ypos)
			} else {
				if (A_TimeIdlePhysical > (timeIdleMin * 1.2)) {
					;PostMessage 0x0112, 0xF170, 1,, "A" ; -1=on, 2=off, 1=standby
					if (guiMaximized = 0) {
						WinSetTransparent 252, myID
						MyGui.Maximize()
						guiMaximized := 1
					}
					If (A_TimeIdle > (timeIdleMin * 4)) {
						TurnOff(oledNumber)
					}
				}
			}
		} else {
			;PostMessage 0x0112, 0xF170, -1,, "A" ; -1=on, 2=off, 1=standby
			;BlockInput "MouseMoveOff"
			MouseMoved := 0
			if (guiMaximized = 1) {
				MyGui.Restore()
				guiMaximized := 0
			}
			WinSetTransparent 245, myID
			;DllCall("User32.dll\ShowCaret")
			;DllCall("User32.dll\ShowCursor", "uint", 1)
			TurnOn(oledNumber)
			winOnCount := GetMonitorWindowCount(oledNumber)
			guiW := winOnCount * taskbarIconWidth
			guiX := screenCenter + (guiW / 2)
			WinMove(-guiX, dimTop, guiW, 63, myID)

		}
    }
    return
}

EnumDisplayDevices(iDevNum, &DISPLAY_DEVICEA:="", dwFlags:=0)    {
    Static   EDD_GET_DEVICE_INTERFACE_NAME := 0x00000001
            ,byteCount              := 4+4+((32+128+128+128)*2)
            ,offset_cb              := 0
            ,offset_DeviceName      := 4                            ,length_DeviceName      := 32
            ,offset_DeviceString    := 4+(32*2)                     ,length_DeviceString    := 128
            ,offset_StateFlags      := 4+((32+128)*2)
            ,offset_DeviceID        := 4+4+((32+128)*2)             ,length_DeviceID        := 128
            ,offset_DeviceKey       := 4+4+((32+128+128)*2)         ,length_DeviceKey       := 128

    DISPLAY_DEVICEA:=""
    if (iDevNum~="\D" || (dwFlags!=0 && dwFlags!=EDD_GET_DEVICE_INTERFACE_NAME))
        return false
    lpDisplayDevice:=Buffer(byteCount,0)            ,Numput("UInt",byteCount,lpDisplayDevice,offset_cb)
    if !DllCall("EnumDisplayDevices", "Ptr",0, "UInt",iDevNum, "Ptr",lpDisplayDevice.Ptr, "UInt",0)
        return false
    if (dwFlags==EDD_GET_DEVICE_INTERFACE_NAME)    {
        DeviceName:=StrGet(lpDisplayDevice.Ptr+offset_DeviceName, length_DeviceName)
        lpDisplayDevice.__New(byteCount,0)          ,Numput("UInt",byteCount,lpDisplayDevice,offset_cb)
        lpDevice:=Buffer(length_DeviceName*2,0)     ,StrPut(DeviceName, lpDevice,length_DeviceName)
        DllCall("EnumDisplayDevices", "Ptr",lpDevice.Ptr, "UInt",0, "Ptr",lpDisplayDevice.Ptr, "UInt",dwFlags)
    }
    For k in (DISPLAY_DEVICEA:=Map("cb",0,"DeviceName","","DeviceString","","StateFlags",0,"DeviceID","","DeviceKey",""))    {
        Switch k
        {
            case "cb","StateFlags":                 DISPLAY_DEVICEA[k]:=NumGet(lpDisplayDevice, offset_%k%,"UInt")
            default:                                DISPLAY_DEVICEA[k]:=StrGet(lpDisplayDevice.Ptr+offset_%k%, length_%k%)
        }
    }
    return true
}