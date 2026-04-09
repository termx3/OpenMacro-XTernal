#Requires AutoHotkey v2.0

MAJOR_VER       := "v0"
FULL_VER        := "v0.0.3"
ROBLOX_VER      := "version-689e359b09ad43b0"
ROBLOX_INSTANCE := "RobloxPlayerBeta.exe"
H_PROCESS       := 0
RBLX_PID        := 0
RBLX_BASE       := 0
OFFSETS         := Map()
OFFSETS_PATH    := "settings\offsets.json"
DC_INV_LIN      := ""
ROD           := ""
SETTINGS        := LoadSettings()

ENV             := SETTINGS["env"]
HOTKEYS         := SETTINGS["hotkeys"]
UPDATE          := SETTINGS["update"]
MAIN            := SETTINGS["main"]
APPEARANCE      := SETTINGS["appearance"]

LoadSettings() {
    settingsPath := "settings\settings.json"
    
    if (!FileExist(settingsPath)) {
        throw Error("settings.json not found at: " settingsPath)
    }
    
    try {
        jsonData := FileRead(settingsPath)
        return JSON.parse(jsonData)
    } catch as err {
        throw Error("Failed to load settings: " err.Message)
    }
}
