#Requires AutoHotkey v2.0

StartMacro() {
    global Macro

    Macro.cycleEnabled := !Macro.cycleEnabled

    if (Macro.cycleEnabled) {
        if (Macro.phase = "OFF" || Macro.phase = "DONE" || Macro.phase = "FAILED")
            StartMacroCycle()
    } else {
        StopMacroCycle("OFF")
    }
}

FixRoblox() {
    global RBLX_PID, RBLX_BASE, H_PROCESS

    pid := GetRobloxPID()
    if (!pid) {
        MsgBox("Roblox not found.")
        return
    }

    H_PROCESS := 0
    RBLX_PID := pid
    RBLX_BASE := GetProcessBase(pid)

    if (!RBLX_BASE) {
        MsgBox("Failed to attach to Roblox.")
        return
    }

    try {
        LoadOffsets()
        MsgBox("Roblox attachment refreshed.")
    } catch as err {
        MsgBox("Offset load failed: " err.Message)
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