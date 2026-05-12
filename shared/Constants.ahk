#Requires AutoHotkey v2.0

MAJOR_VER       := "v0"
FULL_VER        := "v0.2.24"
ROBLOX_VER      := "version-bf6344c9c23446bf"
GITHUB_OWNER        := "termx3"
GITHUB_REPO         := "OpenMacro-XTernal"
; GITHUB_REPO       := "Canary-OpenMacro-XTernal" ; Canary channel
VERSION_URL         := "https://raw.githubusercontent.com/" GITHUB_OWNER "/" GITHUB_REPO "/main/version.txt"
TAG_ZIP_BASE_URL    := "https://github.com/" GITHUB_OWNER "/" GITHUB_REPO "/archive/refs/tags/"
UPDATE_RELAUNCH_ARG := "--post-update"
ROBLOX_INSTANCE := "RobloxPlayerBeta.exe"
H_PROCESS       := 0
RBLX_PID        := 0
RBLX_BASE       := 0
OFFSETS         := Map()
OFFSETS_PATH    := A_ScriptDir "\settings\offsets.json"

g_CachedDataModel      := 0
g_CachedLocalPlayer    := 0
g_CachedPlayerGui      := 0
g_CachedWorkspaceRoot  := 0
g_CachedWorldStatuses  := 0
g_CachedHotbarGui      := 0

APPDATA_DIR   := EnvGet("APPDATA") "\OpenMacro\XTernal"
CONFIGS_DIR   := APPDATA_DIR "\configs"
SETTINGS_PATH := APPDATA_DIR "\settings.json"
POST_UPDATE_FLAG_PATH   := APPDATA_DIR "\post-update.txt"
POST_UPDATE_ACK_PATH    := APPDATA_DIR "\post-update-ack.txt"
UPDATE_CHECK_CACHE_PATH := APPDATA_DIR "\update-check-cache.json"
UPDATE_CHECK_TTL        := 300

ROD           := ""
SETTINGS        := LoadSettings()

ENV             := SETTINGS["env"]
HOTKEYS         := SETTINGS["hotkeys"]
UPDATE          := SETTINGS["update"]
MAIN            := SETTINGS["main"]
MAIN["auto_appraise_enabled"] := 0
APPEARANCE      := SETTINGS["appearance"]

MigrateAllConfigs()

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
        changed := false

        if (!settings.Has("custom_theme")) {
            settings["custom_theme"] := settings["appearance"].Clone()
            changed := true
        }

        if (!settings.Has("last_migrated_version")) {
            settings["last_migrated_version"] := ""
            changed := true
        }

        defaultMain := GetDefaultSettings()["main"]
        for key, val in defaultMain {
            if (!settings["main"].Has(key)) {
                settings["main"][key] := val
                changed := true
            }
        }

        if (PruneObsoleteMainSettings(settings["main"]))
            changed := true

        if (NormalizeMainSettings(settings["main"]))
            changed := true

        if (settings.Has("hotkeys") && !settings["hotkeys"].Has("stop_appraise")) {
            fixKey    := settings["hotkeys"].Has("fix_roblox") ? settings["hotkeys"]["fix_roblox"] : "F3"
            reloadKey := settings["hotkeys"].Has("reload")     ? settings["hotkeys"]["reload"]     : "F4"
            if (fixKey = "F2") {
                settings["hotkeys"]["fix_roblox"] := "F3"
                if (reloadKey = "F3")
                    settings["hotkeys"]["reload"] := "F4"
            }
            settings["hotkeys"]["stop_appraise"] := "F2"
            changed := true
        }

        if (changed)
            _WriteSettingsFile(settingsPath, settings)

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
        "start_macro", "F1",
        "stop_appraise", "F2",
        "fix_roblox", "F3",
        "reload", "F4"
    )

    defaults["main"] := Map(
        "derivative_gain", 0.55,
        "edge_boundary", 0.1,
        "neutral_duty_cycle", 0.5,
        "prediction_strength", 7.5,
        "proportional_gain", 0.42,
        "update_rate", 21,
        "velocity_damping", 38,
        "cast_mode", "short",
        "cast_power_custom", 96.0,
        "cast_timeout_ms", 15000,
        "pre_cast_delay_ms", 0,
        "post_cast_delay_ms", 150,
        "cast_on_timeout", 1,
        "fishing_action_delay_ms", 0,
        "completion_threshold", 99.7,
        "shake_interval_ms", 25,
        "auto_appraise_mutation", "Mythical",
        "auto_appraise_click_x", "",
        "auto_appraise_click_y", "",
        "auto_totem_enabled", 0,
        "auto_totem_name", "Aurora Totem",
        "auto_totem_mode", "expire",
        "auto_totem_interval_sec", 900,
        "webhook_url", "",
        "webhook_enabled", 0,
        "webhook_summary_interval_min", 30,
        "webhook_summary_fish", 1,
        "webhook_summary_success_rate", 1,
        "webhook_summary_rod", 1,
        "webhook_summary_config", 1,
        "webhook_summary_totem_state", 1,
        "webhook_summary_totem_pops", 1,
        "webhook_summary_session_time", 1,
        "webhook_summary_cast_timeouts", 1,
        "webhook_alert_totem_failed", 1
    )

    defaults["last_config"] := ""
    defaults["last_migrated_version"] := ""
    defaults["last_theme"] := "Default"
    defaults["custom_theme"] := Map(
        "accent_color", "5aa9ff",
        "bg_color", "0f1115",
        "text_color", "f5f7fa",
        "border_color", "2a2f3a"
    )

    defaults["update"] := Map(
        "auto_update", 0,
        "show_confirmation", 1
    )

    return defaults
}

GetObsoleteMainSettings() {
    return [
        "close_threshold",
        "fishing_end_grace_ms",
        "post_catch_delay_ms",
        "post_totem_delay_ms",
        "auto_appraise_max_cash",
        "auto_appraise_click_delay_ms",
        "auto_appraise_check_delay_ms",
        "auto_appraise_retry_delay_ms",
        "auto_appraise_enabled",
		"resilience"
    ]
}

GetMinCastTimeoutMs() {
    return 5000
}

PruneObsoleteMainSettings(mainSettings) {
    changed := false

    for _, key in GetObsoleteMainSettings() {
        if (mainSettings.Has(key)) {
            mainSettings.Delete(key)
            changed := true
        }
    }

    return changed
}

NormalizeMainSettings(mainSettings) {
    changed := false

    if (mainSettings.Has("cast_timeout_ms") && IsNumber(mainSettings["cast_timeout_ms"])) {
        normalized := Max(GetMinCastTimeoutMs(), Round(mainSettings["cast_timeout_ms"] + 0))
        if (normalized != mainSettings["cast_timeout_ms"]) {
            mainSettings["cast_timeout_ms"] := normalized
            changed := true
        }
    }

    if (mainSettings.Has("auto_appraise_mutation")) {
        normalized := Trim(mainSettings["auto_appraise_mutation"])
        if (normalized = "")
            normalized := "Mythical"
        if (normalized != mainSettings["auto_appraise_mutation"]) {
            mainSettings["auto_appraise_mutation"] := normalized
            changed := true
        }
    }

    for _, key in ["auto_appraise_click_x", "auto_appraise_click_y"] {
        if (!mainSettings.Has(key))
            continue

        value := Trim(mainSettings[key])
        normalized := (value != "" && IsNumber(value)) ? Round(value + 0) : ""
        if (normalized != mainSettings[key]) {
            mainSettings[key] := normalized
            changed := true
        }
    }

    return changed
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
