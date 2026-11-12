#Requires AutoHotkey v2.0

SendLoginCredentials(riotHwnd, username, password) {
    ; The existing login flow assumes the username field starts focused.
    SendLoginInput(riotHwnd, "{Ctrl down}a{Ctrl up}")
    SendLoginInput(riotHwnd, username, true)
    Sleep(150)
    SendLoginInput(riotHwnd, "{Tab}")
    Sleep(150)
    SendLoginInput(riotHwnd, password, true)
    Sleep(150)
    SendLoginInput(riotHwnd, "{Enter}")
}

SendLoginInput(riotHwnd, value, isText := false) {
    if !WinActive(riotHwnd)
        throw Error("Riot Client lost focus.")

    ; Resolve focus only within the captured Riot window, never the active window.
    ; Chromium clients may expose a focused child or handle input on the window.
    focusedControl := ControlGetFocus(riotHwnd)
    targetHwnd := focusedControl ? ControlGetHwnd(focusedControl, riotHwnd) : riotHwnd
    if !WinActive(riotHwnd)
        throw Error("Riot Client lost focus.")

    ; Targeted messages stay on this HWND even if another app gains focus between
    ; the check and the send. Never fall back to global Send/SendText.
    if isText
        ControlSendText(value, targetHwnd)
    else
        ControlSend(value, targetHwnd)
}
