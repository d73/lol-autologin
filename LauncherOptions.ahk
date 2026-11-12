#Requires AutoHotkey v2.0

ReadCloseRiotOption(settingsFile) {
    try return IniRead(settingsFile, "Launcher", "CloseRiotAfterLeagueStarts", "1") = "1"
    catch
        return true
}

WriteCloseRiotOption(settingsFile, enabled) {
    SplitPath(settingsFile, , &settingsDir)
    if settingsDir
        DirCreate(settingsDir)
    IniWrite(enabled ? "1" : "0", settingsFile, "Launcher", "CloseRiotAfterLeagueStarts")
}

CloseRiotClientWhenLeagueStarts(enabled, timeoutSeconds) {
    if !enabled
        return
    if !WinWait("ahk_exe LeagueClientUx.exe", , timeoutSeconds)
        return  ; League didn't open (e.g. wrong password) - leave Riot Client up.
    Sleep(5000)  ; Let League finish its handoff before closing the Riot Client UI.
    ; Only the UI processes are closed; League still needs RiotClientServices.exe.
    for exe in ["Riot Client.exe", "RiotClientUx.exe"]
        while ProcessExist(exe)
            if !ProcessClose(exe)
                break
}
