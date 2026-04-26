/*
OpenMacro XTernal
Copyright © 2026 (@anorexc) on Discord. All rights reserved.

This software is source available. You are granted a limited, non-exclusive, non-transferable, revocable license to:
- Access and view the source code
- Study and learn from the source code
- Use the software for personal, non-commercial purposes
- Make modifications for your own personal use (these modifications remain your property but cannot be distributed)

Restrictions:
- You may NOT redistribute the software or any modified version, in source or binary form.
- You may NOT use the software for any commercial purpose (including but not limited to selling, offering as a service, or incorporating into a commercial product).
- You may NOT create public forks, sublicense, or republish the code or substantial portions of it.
- You may NOT remove or alter this license notice or copyright statements.

Contributions:
By submitting any contribution (code, documentation, etc.), you agree that your contribution is
licensed under the terms of this license and that yarn retains full rights to use, modify, and incorporate it.
You do not retain ownership rights that allow you to license or distribute the contribution independently in a way that conflicts with these terms.
*/

#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

#Include library\JSON.ahk
#Include shared\Constants.ahk
#Include shared\Settings.ahk
#Include shared\Update.ahk
#Include shared\Process.ahk
#Include shared\Read.ahk
#Include shared\Memory.ahk
#Include shared\Totem.ahk
#Include shared\Hotkeys.ahk
#Include shared\Fish.ahk
#Include shared\Webhook.ahk
#Include library\Discord\DiscordBuilder.ahk
#Include ui\Dialogs\UpdateDialog.ahk
#Include ui\Dialogs\PostUpdateDialog.ahk
#Include ui\Dialogs\AdvSettingsDialog.ahk
#Include ui\Gui.ahk

global Macro := CreateFishingMacro()
global Controller := FishingController()

if HandleStartupUpdate()
    ExitApp()

HotkeyManager.RegisterAll(SETTINGS)

try {
    Initialize()
    RecordSuccessfulUpdateLaunch()
} catch as err {
    MsgBox(err.Message, "Startup Error")
    ExitApp(1)
}

ShowPendingPostUpdateDialog()
GetGui()

Initialize() {
    global RBLX_PID, RBLX_BASE, ROD, Macro

    EnsureAppDataDirs()
    StartAutoTotemDebugSession()

    if (rbxPid := GetRobloxPID()) {
        CheckRobloxVersionMismatch(rbxPid)

        if !EnsureRobloxReady(false, true) {
            AutoTotemDebugLog("startup attach failed; continuing unattached", false)
            MsgBox("Roblox was detected, but XTernal could not attach. The app will still open. Use Fix Roblox or start the macro again after Roblox is ready.", "Roblox Attachment")
        }
    }

    AutoTotemDebugLog("initialize complete | rod=[" ROD "]", false)
    SetTimer(MacroLoop, MAIN["update_rate"])
}

HandleStartupUpdate() {
    remoteVersion := CheckForAvailableUpdate()

    if (remoteVersion = "")
        return false

    if (UPDATE["auto_update"])
        return BeginUpdateInstall(remoteVersion)

    return GetUpdDialog(FULL_VER, remoteVersion)
}

ShowPendingPostUpdateDialog() {
    updatedVersion := ConsumePostUpdateVersion()

    if (updatedVersion = "")
        return

    if UPDATE["show_confirmation"]
        GetPostUpdateDialog(updatedVersion)
}

[:: Reload()
