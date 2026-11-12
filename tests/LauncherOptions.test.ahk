#Requires AutoHotkey v2.0
#Include ../LauncherOptions.ahk

settingsFile := A_ScriptDir "\.launcher-option-" DllCall("GetCurrentProcessId") ".ini"
ownsFile := false
waitCalls := 0
leagueExists := false
closed := []
try {
    if FileExist(settingsFile)
        throw Error("Temporary test file already exists.")
    if !ReadCloseRiotOption(settingsFile)
        throw Error("Missing setting must preserve enabled behavior.")
    WriteCloseRiotOption(settingsFile, false)
    ownsFile := true
    if ReadCloseRiotOption(settingsFile)
        throw Error("Disabled choice did not persist.")
    WriteCloseRiotOption(settingsFile, true)
    if !ReadCloseRiotOption(settingsFile)
        throw Error("Enabled choice did not persist.")

    CloseRiotClientWhenLeagueStarts(false, 120)
    if waitCalls || closed.Length
        throw Error("Disabled cleanup must neither wait nor close processes.")
    CloseRiotClientWhenLeagueStarts(true, 120)
    if waitCalls != 1 || closed.Length
        throw Error("Missing League must leave Riot running.")
    leagueExists := true
    CloseRiotClientWhenLeagueStarts(true, 120)
    if waitCalls != 2 || closed.Length != 2 || closed[1] != "Riot Client.exe" || closed[2] != "RiotClientUx.exe"
        throw Error("Enabled cleanup must close only the two Riot UI processes.")
    FileDelete(settingsFile)
    FileAppend("PASS: option defaults, persistence and three cleanup scenarios`n", "*")
    ExitApp(0)
} catch as err {
    if ownsFile && FileExist(settingsFile)
        FileDelete(settingsFile)
    FileAppend("FAIL: " err.Message "`n", "**")
    ExitApp(1)
}

WinWait(target, text := "", timeout := 0) {
    global waitCalls, leagueExists
    if target != "ahk_exe LeagueClientUx.exe" || timeout != 120
        throw Error("Cleanup wait must target League with the configured timeout.")
    waitCalls += 1
    return leagueExists ? 123 : 0
}

Sleep(ms) {
    if ms != 5000
        throw Error("Enabled cleanup must preserve the handoff delay.")
}

ProcessExist(exe) {
    global closed
    for name in closed
        if name = exe
            return 0
    return 1
}

ProcessClose(exe) {
    global closed
    closed.Push(exe)
    return 1
}
