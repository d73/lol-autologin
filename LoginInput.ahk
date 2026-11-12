#Requires AutoHotkey v2.0

class LoginInputError extends Error {
}

SendLoginCredentials(riotHwnd, username, password) {
    ; The existing login flow assumes the username field starts focused.
    SendLoginInput(riotHwnd, "{Ctrl down}a{Ctrl up}", false, "clearing the username")
    SendLoginInput(riotHwnd, username, true, "entering the username")
    Sleep(150)
    SendLoginInput(riotHwnd, "{Tab}", false, "moving to the password")
    Sleep(150)
    SendLoginInput(riotHwnd, password, true, "entering the password")
    Sleep(150)
    SendLoginInput(riotHwnd, "{Enter}", false, "submitting the login")
}

SendLoginInput(riotHwnd, value, isText := false, step := "sending input") {
    if !WinExist(riotHwnd)
        throw LoginInputError("The Riot window closed or was replaced before " step ".")
    if !WinActive(riotHwnd)
        throw LoginInputError("Riot Client lost focus before " step ".")

    ; Resolve focus only within the captured Riot window, never the active window.
    ; Chromium clients may expose a focused child or handle input on the window.
    try {
        focusedControl := ControlGetFocus(riotHwnd)
        targetHwnd := focusedControl ? ControlGetHwnd(focusedControl, riotHwnd) : riotHwnd
    } catch as err {
        throw LoginInputError("Could not locate Riot's input control before " step " (" Type(err) ").")
    }
    if !WinActive(riotHwnd)
        throw LoginInputError("Riot Client lost focus before " step ".")

    ; Targeted messages stay on this HWND even if another app gains focus between
    ; the check and the send. Never fall back to global Send/SendText.
    try {
        if isText
            ControlSendText(value, targetHwnd)
        else
            ControlSend(value, targetHwnd)
    } catch as err {
        ; Built-in errors can contain argument values. Show only a safe error type.
        throw LoginInputError("Could not deliver input while " step " (" Type(err) ").")
    }
}
