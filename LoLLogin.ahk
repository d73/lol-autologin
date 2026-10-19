#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; League of Legends profile picker + auto-login
;   - Pick a profile -> launches Riot Client for LoL -> types username/password
;   - Credentials are stored in Windows Credential Manager (not in this file),
;     so nothing sensitive gets synced to Google Drive / GitHub.
;   - First time you pick a profile you'll be asked for its username/password.
;   - Right-click a profile button to change its saved credentials.
; ============================================================================

PROFILES       := ["gotutl", "noultyet"]     ; display names (rename as you like)
RIOT_CLIENT    := "C:\Riot Games\Riot Client\RiotClientServices.exe"
LAUNCH_ARGS    := "--launch-product=league_of_legends --launch-patchline=live --allow-direct-launch"
LOGIN_DELAY_MS := 3000                   ; wait for login form to render; raise if typing starts too early
CRED_PREFIX    := "AHK_LoL_"

GroupAdd("RiotLogin", "ahk_exe Riot Client.exe")   ; current client
GroupAdd("RiotLogin", "ahk_exe RiotClientUx.exe")  ; older client

ShowPicker()

ShowPicker() {
    picker := Gui("+AlwaysOnTop -MinimizeBox", "League of Legends")
    picker.SetFont("s11", "Segoe UI")
    picker.AddText("w220 Center", "Choose a profile")
    for name in PROFILES {
        btn := picker.AddButton("w220 h40", name)
        btn.OnEvent("Click", PickProfile.Bind(picker, name))
        btn.OnEvent("ContextMenu", (ctrl, *) => PromptCredentials(ctrl.Text))
    }
    picker.SetFont("s8 cGray")
    picker.AddText("w220 Center", "Right-click a profile to edit its login")
    picker.OnEvent("Close", (*) => ExitApp())
    picker.OnEvent("Escape", (*) => ExitApp())
    picker.Show()
}

PickProfile(picker, name, *) {
    cred := CredRead(CRED_PREFIX name)
    if !cred
        cred := PromptCredentials(name)
    if !cred
        return
    picker.Destroy()
    LaunchAndLogin(cred.username, cred.password)
    ExitApp()
}

PromptCredentials(name) {
    user := InputBox("Riot username for '" name "':", "LoL Login", "w300 h120")
    if user.Result != "OK" || user.Value = ""
        return
    pass := InputBox("Password for '" user.Value "':", "LoL Login", "Password w300 h120")
    if pass.Result != "OK" || pass.Value = ""
        return
    if !CredWrite(CRED_PREFIX name, user.Value, pass.Value) {
        MsgBox("Failed to save credentials to Windows Credential Manager.", "LoL Login", "Icon!")
        return
    }
    return {username: user.Value, password: pass.Value}
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
