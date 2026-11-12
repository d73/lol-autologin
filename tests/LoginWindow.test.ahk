#Requires AutoHotkey v2.0
#Include ../LoginInput.ahk

; Deterministic startup-window replacement tests; no apps or credentials used.
attempts := 0
mode := "replace"
try {
    if ActivateRiotLoginWindow() != 300 || attempts != 3
        throw Error("Must reacquire after replacement during activation and active wait.")
    attempts := 0
    mode := "missing"
    ExpectFailure()
    if attempts != 1
        throw Error("A missing login window must stop.")
    attempts := 0
    mode := "always-replace"
    ExpectFailure()
    if attempts != 3
        throw Error("Replacement retries must be bounded.")
    attempts := 0
    mode := "inactive"
    ExpectFailure()
    if attempts != 1
        throw Error("A surviving window that cannot gain focus must stop.")
    FileAppend("PASS: 4 startup-window scenarios`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message "`n", "**")
    ExitApp(1)
}

ExpectFailure() {
    failed := false
    try ActivateRiotLoginWindow()
    catch LoginInputError
        failed := true
    if !failed
        throw Error("Expected a safe startup error.")
}

WinWait(group, text := "", timeout := 0) {
    global attempts, mode
    attempts += 1
    if group != "ahk_group RiotLogin" || timeout != 2
        throw Error("Startup wait must be scoped and bounded.")
    return mode = "missing" ? 0 : attempts * 100
}

WinActivate(hwnd) {
    global mode
    if mode = "always-replace" || (mode = "replace" && hwnd = 100)
        throw TargetError("Fixture splash window was replaced.")
}

WinWaitActive(hwnd, text := "", timeout := 0) {
    global mode
    return mode = "replace" && hwnd = 300 ? hwnd : 0
}

WinExist(hwnd) {
    global mode
    return mode = "inactive" ? hwnd : 0
}
