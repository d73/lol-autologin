#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; League of Legends profile picker + auto-login
;   - Pick a profile -> launches Riot Client for LoL -> types username/password
;   - Credentials are stored in Windows Credential Manager (not in this file),
;     so nothing sensitive gets synced to Google Drive / GitHub.
;   - The profile list is read from Credential Manager; each profile is a Riot
;     username. Use "+ Add account" to add one.
;   - Right-click a profile to change its password or remove it.
; ============================================================================

RIOT_CLIENT    := "C:\Riot Games\Riot Client\RiotClientServices.exe"
LAUNCH_ARGS    := "--launch-product=league_of_legends --launch-patchline=live --allow-direct-launch"
LOGIN_DELAY_MS := 3000                   ; wait for login form to render; raise if typing starts too early
CRED_PREFIX    := "AHK_LoL_"
LEAGUE_TIMEOUT_S := 120                  ; how long to wait for the League client before giving up on closing Riot Client

GroupAdd("RiotLogin", "ahk_exe Riot Client.exe")   ; current client
GroupAdd("RiotLogin", "ahk_exe RiotClientUx.exe")  ; older client

ShowPicker()

ShowPicker() {
    picker := Gui("+AlwaysOnTop -MinimizeBox", "League of Legends")
    picker.SetFont("s11", "Segoe UI")
    profiles := ListProfiles()
    picker.AddText("w220 Center", profiles.Length ? "Choose a profile" : "No accounts saved yet")
    for name in profiles {
        btn := picker.AddButton("w220 h40", name)
        btn.OnEvent("Click", PickProfile.Bind(picker, name))
        btn.OnEvent("ContextMenu", ShowProfileMenu.Bind(picker, name))
    }
    picker.AddButton("w220 h30", "+ Add account").OnEvent("Click", (*) => AddAccount(picker))
    picker.SetFont("s8 cGray")
    picker.AddText("w220 Center", "Right-click a profile to change password or remove")
    picker.OnEvent("Close", (*) => ExitApp())
    picker.OnEvent("Escape", (*) => ExitApp())
    picker.Show()
}

; Rebuild the picker after the profile list changes
RefreshPicker(picker) {
    picker.Destroy()
    ShowPicker()
}

ListProfiles() {
    profiles := []
    for target in CredList(CRED_PREFIX "*")
        profiles.Push(SubStr(target, StrLen(CRED_PREFIX) + 1))
    return SortArray(profiles)
}

ShowProfileMenu(picker, name, *) {
    ; +OwnDialogs keeps prompts above the always-on-top picker; it's per-thread,
    ; so it has to be set inside each menu callback
    m := Menu()
    m.Add("Change password", (*) => (picker.Opt("+OwnDialogs"), PromptPassword(name)))
    m.Add("Remove account", (*) => (picker.Opt("+OwnDialogs"), RemoveAccount(picker, name)))
    m.Show()
}

AddAccount(picker) {
    picker.Opt("+OwnDialogs")
    user := InputBox("Riot username:", "LoL Login", "w300 h120")
    if user.Result != "OK" || (name := Trim(user.Value)) = ""
        return
    if PromptPassword(name)
        RefreshPicker(picker)
}

RemoveAccount(picker, name) {
    if MsgBox("Remove '" name "' and its saved password?", "LoL Login", "YesNo Icon?") != "Yes"
        return
    DllCall("Advapi32.dll\CredDeleteW", "Str", CRED_PREFIX name, "UInt", 1, "UInt", 0, "Int")
    RefreshPicker(picker)
}

PickProfile(picker, name, *) {
    cred := CredRead(CRED_PREFIX name)
    if !cred
        return
    picker.Destroy()
    LaunchAndLogin(cred.username, cred.password)
    ExitApp()
}

; Profile name is the Riot username, so only the password is asked for
PromptPassword(username) {
    pass := InputBox("Password for '" username "':", "LoL Login", "Password w300 h120")
    if pass.Result != "OK" || pass.Value = ""
        return
    if !CredWrite(CRED_PREFIX username, username, pass.Value) {
        MsgBox("Failed to save password to Windows Credential Manager.", "LoL Login", "Icon!")
        return
    }
    MsgBox("Password saved for '" username "'.", "LoL Login", "Iconi T2")
    return {username: username, password: pass.Value}
}

LaunchAndLogin(username, password) {
    if !FileExist(RIOT_CLIENT) {
        MsgBox("Riot Client not found at:`n" RIOT_CLIENT "`n`nEdit RIOT_CLIENT at the top of the script.", "LoL Login", "Icon!")
        return
    }

    Run('"' RIOT_CLIENT '" ' LAUNCH_ARGS)

    if !WinWait("ahk_group RiotLogin", , 60) {
        MsgBox("Riot Client window didn't appear within 60s.", "LoL Login", "Icon!")
        return
    }
    Sleep(LOGIN_DELAY_MS)
    WinActivate("ahk_group RiotLogin")
    if !WinWaitActive("ahk_group RiotLogin", , 5)
        return

    ; Username field has focus when the login screen opens
    Send("^a")
    SendText(username)
    Sleep(150)
    Send("{Tab}")
    Sleep(150)
    SendText(password)
    Sleep(150)
    Send("{Enter}")

    CloseRiotClientWhenLeagueStarts()
}

; Riot Client's window isn't needed once League's client is up. Only the UI
; processes are closed; RiotClientServices.exe keeps running because League needs it.
CloseRiotClientWhenLeagueStarts() {
    if !WinWait("ahk_exe LeagueClientUx.exe", , LEAGUE_TIMEOUT_S)
        return  ; League didn't open (e.g. wrong password) - leave Riot Client up
    Sleep(5000)  ; let League finish its handoff before pulling the Riot Client UI
    for exe in ["Riot Client.exe", "RiotClientUx.exe"]
        while ProcessExist(exe)
            if !ProcessClose(exe)
                break
}

SortArray(arr) {
    if arr.Length < 2
        return arr
    joined := ""
    for item in arr
        joined .= item "`n"
    return StrSplit(Sort(RTrim(joined, "`n")), "`n")
}

; ---------------------------------------------------------------------------
; Windows Credential Manager helpers (CRED_TYPE_GENERIC)
; View/delete entries in: Control Panel > Credential Manager > Windows Credentials
; ---------------------------------------------------------------------------
CredWrite(target, username, password) {
    cred := Buffer(24 + A_PtrSize * 7, 0)
    NumPut("UInt", 1,                     cred, 4)                  ; Type = GENERIC
    NumPut("Ptr",  StrPtr(target),        cred, 8)                  ; TargetName
    NumPut("UInt", StrLen(password) * 2,  cred, 16 + A_PtrSize * 2) ; CredentialBlobSize
    NumPut("Ptr",  StrPtr(password),      cred, 16 + A_PtrSize * 3) ; CredentialBlob
    NumPut("UInt", 2,                     cred, 16 + A_PtrSize * 4) ; Persist = LOCAL_MACHINE
    NumPut("Ptr",  StrPtr(username),      cred, 24 + A_PtrSize * 6) ; UserName
    return DllCall("Advapi32.dll\CredWriteW", "Ptr", cred, "UInt", 0, "Int")
}

CredRead(target) {
    pCred := 0
    if !DllCall("Advapi32.dll\CredReadW", "Str", target, "UInt", 1, "UInt", 0, "Ptr*", &pCred, "Int")
        return
    username := StrGet(NumGet(pCred, 24 + A_PtrSize * 6, "Ptr"), "UTF-16")
    blobSize := NumGet(pCred, 16 + A_PtrSize * 2, "UInt")
    password := StrGet(NumGet(pCred, 16 + A_PtrSize * 3, "Ptr"), blobSize // 2, "UTF-16")
    DllCall("Advapi32.dll\CredFree", "Ptr", pCred)
    return {username: username, password: password}
}

; Returns the TargetNames of all credentials matching filter (e.g. "AHK_LoL_*")
CredList(filter) {
    targets := [], count := 0, pCreds := 0
    if !DllCall("Advapi32.dll\CredEnumerateW", "Str", filter, "UInt", 0, "UInt*", &count, "Ptr*", &pCreds, "Int")
        return targets
    loop count {
        pCred := NumGet(pCreds, (A_Index - 1) * A_PtrSize, "Ptr")
        targets.Push(StrGet(NumGet(pCred, 8, "Ptr"), "UTF-16"))
    }
    DllCall("Advapi32.dll\CredFree", "Ptr", pCreds)
    return targets
}
