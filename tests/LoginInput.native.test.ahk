#Requires AutoHotkey v2.0
#Include ../LoginInput.ahk

; Hidden native Edit controls verify actual ControlSendText message routing.
; Focus discovery is stubbed so this test never activates a window or types globally.
DetectHiddenWindows(true)
target := Gui()
field := target.AddEdit()
decoy := Gui()
decoyField := decoy.AddEdit()
try {
    SendLoginInput(target.Hwnd, "^!+#{Enter} dummy-password", true)
    Sleep(100)
    if field.Value != "^!+#{Enter} dummy-password"
        throw Error("Literal text did not reach the target Edit control.")
    if decoyField.Value != ""
        throw Error("Decoy control received input.")
    FileAppend("PASS: native target received literal text; decoy remained empty`n", "*")
    target.Destroy()
    decoy.Destroy()
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message "`n", "**")
    target.Destroy()
    decoy.Destroy()
    ExitApp(1)
}

WinActive(hwnd) {
    global target
    return hwnd = target.Hwnd ? hwnd : 0
}

ControlGetFocus(hwnd) {
    global target
    if hwnd != target.Hwnd
        throw Error("Focus lookup must target the fixture window.")
    return "Edit1"
}

Send(*) {
    throw Error("Global Send is forbidden in this test")
}

SendText(*) {
    throw Error("Global SendText is forbidden in this test")
}
