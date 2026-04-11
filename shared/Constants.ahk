#Requires AutoHotkey v2.0

MAJOR_VER       := "v0"
FULL_VER        := "v0.0.6"
ROBLOX_VER      := "version-26c90be22e0d4758"
GITHUB_OWNER    := "termx3"
GITHUB_REPO     := "OpenMacro-XTernal"
VERSION_URL     := "https://raw.githubusercontent.com/" GITHUB_OWNER "/" GITHUB_REPO "/main/version.txt"
TAG_ZIP_BASE_URL := "https://github.com/" GITHUB_OWNER "/" GITHUB_REPO "/archive/refs/tags/"
UPDATE_RELAUNCH_ARG := "--post-update"
ROBLOX_INSTANCE := "RobloxPlayerBeta.exe"
H_PROCESS       := 0
RBLX_PID        := 0
RBLX_BASE       := 0
OFFSETS         := Map()
OFFSETS_PATH    := A_ScriptDir "\settings\offsets.json"

APPDATA_DIR   := EnvGet("APPDATA") "\OpenMacro\XTernal"
CONFIGS_DIR   := APPDATA_DIR "\configs"
SETTINGS_PATH := APPDATA_DIR "\settings.json"
POST_UPDATE_FLAG_PATH := APPDATA_DIR "\post-update.txt"
POST_UPDATE_ACK_PATH  := APPDATA_DIR "\post-update-ack.txt"

ROD           := ""
SETTINGS        := LoadSettings()

ENV             := SETTINGS["env"]
HOTKEYS         := SETTINGS["hotkeys"]
UPDATE          := SETTINGS["update"]
MAIN            := SETTINGS["main"]
APPEARANCE      := SETTINGS["appearance"]

LoadSettings() {
    settingsPath := APPDATA_DIR "\settings.json"

    if (!FileExist(settingsPath)) {
        defaults := GetDefaultSettings()
        _WriteSettingsFile(settingsPath, defaults)
        return defaults
    }

    try {
        jsonData := FileRead(settingsPath)
        settings := JSON.parse(jsonData)

        if (!settings.Has("custom_theme"))
            settings["custom_theme"] := settings["appearance"].Clone()

        return settings
    } catch as err {
        throw Error("Failed to load settings: " err.Message)
    }
}

GetDefaultSettings() {
    defaults := Map()

    defaults["appearance"] := Map(
        "accent_color", "5aa9ff",
        "bg_color", "0f1115",
        "border_color", "2a2f3a",
        "text_color", "f5f7fa"
    )

    defaults["env"] := "prod"

    defaults["hotkeys"] := Map(
        "fix_roblox", "F2",
        "reload", "F3",
        "start_macro", "F1"
    )

    defaults["main"] := Map(
        "close_threshold", 0.06,
        "derivative_gain", 0.55,
        "edge_boundary", 0.1,
        "neutral_duty_cycle", 0.5,
        "prediction_strength", 7.5,
        "proportional_gain", 0.42,
        "resilience", 0.0,
        "update_rate", 21,
        "velocity_damping", 38
    )

    defaults["last_config"] := ""
    defaults["last_theme"] := "Default"
    defaults["custom_theme"] := Map(
        "accent_color", "5aa9ff",
        "bg_color", "0f1115",
        "text_color", "f5f7fa",
        "border_color", "2a2f3a"
    )

    defaults["update"] := Map(
        "auto_update", 1,
        "show_confirmation", 0
    )

    return defaults
}

_WriteSettingsFile(path, data) {
    dir := RegExReplace(path, "\\[^\\]+$")
    if (!DirExist(dir))
        DirCreate(dir)

    try {
        file := FileOpen(path, "w")
        file.Write(JSON.stringify(data, 4))
        file.Close()
    } catch as err {
        throw Error("Failed to write settings file: " err.Message)
    }
}

GetBuiltInThemes() {
    themes := Map()

    themes["Default"] := Map(
        "accent_color", "5aa9ff",
        "bg_color", "0f1115",
        "text_color", "f5f7fa",
        "border_color", "2a2f3a"
    )

    themes["Crimson"] := Map(
        "accent_color", "ff4c4c",
        "bg_color", "1a0a0a",
        "text_color", "f5e6e6",
        "border_color", "3a1f1f"
    )

    themes["Emerald"] := Map(
        "accent_color", "3ddfa0",
        "bg_color", "0a1512",
        "text_color", "e6f5ef",
        "border_color", "1f3a2d"
    )

    themes["Amber"] := Map(
        "accent_color", "ffb347",
        "bg_color", "15120a",
        "text_color", "f5f0e6",
        "border_color", "3a331f"
    )

    themes["Lavender"] := Map(
        "accent_color", "b388ff",
        "bg_color", "120e18",
        "text_color", "ede6f5",
        "border_color", "2d1f3a"
    )

    themes["Arctic"] := Map(
        "accent_color", "88cfff",
        "bg_color", "e8edf2",
        "text_color", "1a1e24",
        "border_color", "c0c8d4"
    )

    themes["Slate"] := Map(
        "accent_color", "78909c",
        "bg_color", "1e272e",
        "text_color", "cfd8dc",
        "border_color", "37474f"
    )

    return themes
}
