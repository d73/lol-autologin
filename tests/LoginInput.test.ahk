#Requires AutoHotkey v2.0
#Include ../LoginInput.ahk

; Run: AutoHotkey64.exe /ErrorStdOut /CP65001 tests/LoginInput.test.ahk
; These deterministic OS stubs never read credentials, open Riot, or type into apps.
state := 0
checks := 0
try {
    ResetState()
    SendLoginCredentials(100, "dummy-user", "^!+#{Enter}")
    Assert(state.sent.Length = 5, "normal flow sends five operations")
    Assert(state.sent[2].text && state.sent[2].value = "dummy-user", "username is literal text")
    Assert(state.sent[4].text && state.sent[4].value = "^!+#{Enter}", "password is literal text")
    Assert(state.sent[2].target = 101 && state.sent[4].target = 102, "each field gets its own captured control")

    ResetState()
    state.active := 999
    ExpectFailure(() => SendLoginCredentials(100, "dummy-user", "dummy-password"))
    Assert(state.sent.Length = 0, "initial focus loss sends nothing")

    ; Lose focus after username, Tab, and password respectively.
    Loop 3 {
        ResetState()
        state.loseOnSleep := A_Index
        ExpectFailure(() => SendLoginCredentials(100, "dummy-user", "dummy-password"))
        Assert(state.sent.Length = A_Index + 1, "focus loss at pause " A_Index " stops the remaining sequence")
    }

    ResetState()
    state.loseOnCheck := 8 ; after the final guard immediately before password delivery
    ExpectFailure(() => SendLoginCredentials(100, "dummy-user", "dummy-password"))
    Assert(state.sent.Length = 4, "focus race prevents subsequent Enter")
    Assert(state.sent[4].active = 999 && state.sent[4].target = 102, "password still targets Riot when focus changes after the guard")

    ResetState()
    state.failFocusLookup := true
    ExpectFailure(() => SendLoginCredentials(100, "dummy-user", "dummy-password"))
    Assert(state.sent.Length = 0, "unavailable control aborts without a global fallback")

    ResetState()
    state.focused := ""
    SendLoginInput(100, "dummy-password", true)
    Assert(state.sent[1].target = 100, "window-based client uses the captured Riot HWND")

    ResetState()
    state.failTextSend := true
    ExpectFailure(() => SendLoginInput(100, "dummy-password", true))
    Assert(state.sent.Length = 0, "target disappearing during send aborts without fallback")

    ResetState()
    state.failTextSend := true
    try SendLoginInput(100, "dummy-secret", true, "entering the password")
    catch as err {
        Assert(err is LoginInputError, "failure uses a credential-safe error")
        Assert(InStr(err.Message, "entering the password") && !InStr(err.Message, "dummy-secret"), "failure names the step without exposing the argument")
    }

    FileAppend("PASS: " checks " assertions`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message "`n", "**")
    ExitApp(1)
}

ResetState() {
    global state
    state := {active: 100, focused: "Edit1", sent: [], sleeps: 0, guards: 0,
        loseOnSleep: 0, loseOnCheck: 0, failFocusLookup: false, failTextSend: false}
}

Assert(condition, message) {
    global checks
    checks += 1
    if !condition
        throw Error(message)
}

ExpectFailure(callback) {
    failed := false
    try callback()
    catch
        failed := true
    Assert(failed, "operation must abort")
}

WinActive(hwnd) {
    global state
    Assert(hwnd = 100, "focus check uses the captured window")
    state.guards += 1
    result := state.active = hwnd ? hwnd : 0
    if state.guards = state.loseOnCheck
        state.active := 999
    return result
}

WinExist(hwnd) {
    return hwnd = 100 ? hwnd : 0
}

ControlGetFocus(hwnd) {
    global state
    Assert(hwnd = 100, "focus lookup is scoped to Riot")
    if state.failFocusLookup
        throw TargetError("Dummy target disappeared")
    return state.focused
}

ControlGetHwnd(control, hwnd) {
    Assert(hwnd = 100, "control resolution is scoped to Riot")
    return control = "Edit1" ? 101 : 102
}

ControlSend(value, target) {
    global state
    state.sent.Push({value: value, target: target, text: false, active: state.active})
    if value = "{Tab}"
        state.focused := "Edit2"
}

ControlSendText(value, target) {
    global state
    if state.failTextSend
        throw TargetError("Dummy target disappeared: " value)
    state.sent.Push({value: value, target: target, text: true, active: state.active})
}

Sleep(ms) {
    global state
    state.sleeps += 1
    if state.sleeps = state.loseOnSleep
        state.active := 999
}

Send(*) {
    throw Error("Global Send must never be used")
}

SendText(*) {
    throw Error("Global SendText must never be used")
}
