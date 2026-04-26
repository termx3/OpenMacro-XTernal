#Requires AutoHotkey v2.0

global VERSION_CHECK_COOLDOWN_MS := 60000
global _LastVersionCheckAt := 0

CheckRobloxVersionMismatch(pid) {
    global _LastVersionCheckAt, VERSION_CHECK_COOLDOWN_MS

    if (!pid)
        return

    if (_LastVersionCheckAt && (A_TickCount - _LastVersionCheckAt) < VERSION_CHECK_COOLDOWN_MS)
        return

    _LastVersionCheckAt := A_TickCount

    try {
        runningHash := GetRunningRobloxVersionHash(pid)
        latestHash := GetLatestRobloxVersionHash()

        if (runningHash != latestHash)
            MsgBox("Version mismatch detected.`n`nRunning: " runningHash "`nLatest:  " latestHash, "Version Warning")
    } catch as err {
        MsgBox("Version check failed: " err.Message "`n`nProceeding with re-attach.", "Version Warning")
    }
}

StartMacro() {
    global Macro

    if (Macro.cycleEnabled) {
        Macro.cycleEnabled := false
        StopMacroCycle("OFF")
        return
    }

    if !EnsureRobloxReady(true, true)
        return

    UpdateRobloxUiState()

    if (!IsAnythingEquipped()) {
        SendInput("t")
        Sleep(200)
    }

    Macro.cycleEnabled := true

    if (Macro.phase = "OFF" || Macro.phase = "DONE" || Macro.phase = "FAILED")
        StartMacroCycle()
}

FixRoblox() {
    pid := GetRobloxPID()
    if (!pid) {
        ResetRobloxAttachmentState()
        ClearMacroPhaseCache()
        UpdateRobloxUiState()
        MsgBox("Roblox not found.")
        return
    }

    ClearMacroPhaseCache()

    CheckRobloxVersionMismatch(pid)

    try {
        AttachToRoblox(pid)
        UpdateRobloxUiState()
        MsgBox("Roblox attachment refreshed.")
    } catch as err {
        UpdateRobloxUiState()
        MsgBox(err.Message, "Roblox Attachment")
    }
}

ReloadMacro() {
    Reload()
}

class HotkeyManager {
    static activeHotkeys := Map()

    static RegisterAll(settings) {
        hotkeys := settings["hotkeys"]
        this.Register(hotkeys["start_macro"], (*) => StartMacro())
        this.Register(hotkeys["fix_roblox"], (*) => FixRoblox())
        this.Register(hotkeys["reload"], (*) => ReloadMacro())
    }

    static Register(key, callback) {
        if (key = "")
            return

        Hotkey(key, callback)
        this.activeHotkeys[key] := callback
    }

    static ChangeHotkey(oldKey, newKey, callback) {
        if (oldKey = newKey)
            return

        if (oldKey != "" && this.activeHotkeys.Has(oldKey)) {
            Hotkey(oldKey, "Off")
            this.activeHotkeys.Delete(oldKey)
        }

        this.Register(newKey, callback)
    }
}
