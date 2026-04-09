#Requires AutoHotkey v2.0
#Include Components\Border.ahk
#Include Components\Button.ahk
#Include Components\InfoPopup.ahk
#Include Dialogs\AddMutationDialog.ahk
#Include Dialogs\ConfigDialogs.ahk

GetGui() {
    global FULL_VER, ROBLOX_VER, RBLX_BASE, RBLX_PID, ENV, ROD, APPEARANCE
    global StatusText, PowerText, ProgressText

    Accent     := APPEARANCE["accent_color"]
    BgColor    := APPEARANCE["bg_color"]
    TextColor  := APPEARANCE["text_color"]
    BorderColor := APPEARANCE["border_color"]
    SubColor   := DimHex(TextColor, 0.6)

    Border.DefaultColor := "0x" BorderColor

    button.DefaultTextColor := "0x" TextColor
    button.DefaultBg := "0x" Accent
    
    Accent := APPEARANCE["accent_color"]
    
    DCLogoPath := A_ScriptDir "\images\DiscordLogo.png"

    mg := Gui("AlwaysOnTop +Border")
    mg.BackColor := "0x" BgColor
    mg.Title := "OpenMacro Xternal | " FULL_VER
    mg.SetFont(, "Segoe UI")

    RobloxStatus := mg.AddText("x295 y3 w200 h15 c" TextColor, "PID: " RBLX_PID)
    RobloxStatus.SetFont("s9 bold")

    MainTab := mg.AddTab3("x0 y0 w400 h600 c" Accent, ["Home", "Appraisal", "Settings", "Changelog", "Credits"])
    MainTab.SetFont("bold")
    blockedTabIndex := 2
    lastAllowedTab := 1
    revertingBlockedTab := false
    MainTab.OnEvent("Change", HandleMainTabChange)

    MainTab.UseTab(1)
    mg.AddGroupBox("x10 y30 w380 h225 c" TextColor, "Adjustments").SetFont("s9 bold")

    mg.AddText("x20 y50 w150 h20 c" TextColor, "Update rate").SetFont("s10")
    UpdateRateHelp := mg.AddText("x140 y51 w50 h20 c" Accent, "what?")
    UpdateRateHelp.SetFont("underline")
    UpdateRateHelp.OnEvent("Click", (*) => InfoPopup.Show("Update Rate", "Controls how often the macro updates its balancing decisions in milliseconds. Lower values react faster but can click too often. Higher values feel smoother but may respond more slowly."))
        UpdateRate := mg.AddEdit("x250 y50 w40 h20", MAIN["update_rate"])
    mg.AddText("x300 y50 w85 h20 c" TextColor, "1 - 35").SetFont("s9")

    mg.AddText("x20 y75 w150 h20 c" TextColor, "Prediction Strength").SetFont("s10")
    PredictionStrengthHelp := mg.AddText("x140 y76 w50 h20 c" Accent, "what?")
    PredictionStrengthHelp.SetFont("underline")
    PredictionStrengthHelp.OnEvent("Click", (*) => InfoPopup.Show("Prediction Strength", "Controls how far ahead the macro predicts the player bar's movement. Higher values look further ahead and react earlier. Lower values feel more direct but can lag behind fast changes."))
        PredictionStrength := mg.AddEdit("x250 y75 w40 h20", Format("{:.1f}", MAIN["prediction_strength"]))
    mg.AddText("x300 y75 w85 h20 c" TextColor, "1.0 - 20.0").SetFont("s9")

    mg.AddText("x20 y100 w150 h20 c" TextColor, "Close threshold").SetFont("s10")
    CloseThresholdHelp := mg.AddText("x140 y101 w50 h20 c" Accent, "what?")
    CloseThresholdHelp.SetFont("underline")
    CloseThresholdHelp.OnEvent("Click", (*) => InfoPopup.Show("Close Threshold", "How close the fish and player bar positions must be before the macro switches into fine balancing. Lower values require tighter alignment. Higher values start balancing sooner."))
        CloseThreshold := mg.AddEdit("x250 y100 w40 h20", Format("{:.2f}", MAIN["close_threshold"]))
    mg.AddText("x300 y100 w85 h20 c" TextColor, "0.01 - 0.10").SetFont("s9")

    mg.AddText("x20 y125 w150 h20 c" TextColor, "Neutral duty cycle").SetFont("s10")
    NDCycleHelp := mg.AddText("x140 y126 w50 h20 c" Accent, "what?")
    NDCycleHelp.SetFont("underline")
    NDCycleHelp.OnEvent("Click", (*) => InfoPopup.Show("Neutral duty cycle", "Sets the base hold-versus-release bias while balancing. Higher values hold more often. Lower values release more often."))
        NDCycle := mg.AddEdit("x250 y125 w40 h20", Format("{:.1f}", MAIN["neutral_duty_cycle"]))
    mg.AddText("x300 y125 w85 h20 c" TextColor, "0.20 - 0.60").SetFont("s9")

    mg.AddText("x20 y150 w150 h20 c" TextColor, "Velocity Damping").SetFont("s10")
    VelocityDampingHelp := mg.AddText("x140 y151 w50 h20 c" Accent, "what?")
    VelocityDampingHelp.SetFont("underline")
    VelocityDampingHelp.OnEvent("Click", (*) => InfoPopup.Show("Velocity Damping", "How fast the player bar can be moving before the macro stops fine balancing and switches back to stronger correction. Lower values react sooner. Higher values keep floating longer."))
        VelocityDamping := mg.AddEdit("x250 y150 w40 h20", MAIN["velocity_damping"])
    mg.AddText("x300 y150 w85 h20 c" TextColor, "10 - 60").SetFont("s9")

    mg.AddText("x20 y175 w150 h20 c" TextColor, "Proportional gain").SetFont("s10")
    ProportionalGainHelp := mg.AddText("x140 y176 w50 h20 c" Accent, "what?")
    ProportionalGainHelp.SetFont("underline")
    ProportionalGainHelp.OnEvent("Click", (*) => InfoPopup.Show("Proportional Gain", "How strongly the macro reacts to position error. Higher values correct harder. Lower values feel softer but can drift more."))
        ProportionalGain := mg.AddEdit("x250 y175 w40 h20", Format("{:.2f}", MAIN["proportional_gain"]))
    mg.AddText("x300 y175 w85 h20 c" TextColor, "0.10 - 1.50").SetFont("s9")

    mg.AddText("x20 y200 w150 h20 c" TextColor, "Derivative gain").SetFont("s10")
    DerivativeGainHelp := mg.AddText("x140 y201 w50 h20 c" Accent, "what?")
    DerivativeGainHelp.SetFont("underline")
    DerivativeGainHelp.OnEvent("Click", (*) => InfoPopup.Show("Derivative Gain", "How strongly the macro reacts to movement speed. Higher values damp swaying more. Too high can make the control feel twitchy."))
        DerivativeGain := mg.AddEdit("x250 y200 w40 h20", Format("{:.2f}", MAIN["derivative_gain"]))
    mg.AddText("x300 y200 w85 h20 c" TextColor, "0.00 - 1.00").SetFont("s9")

    mg.AddText("x20 y225 w150 h20 c" TextColor, "Edge boundary").SetFont("s10")
    EdgeBoundaryHelp := mg.AddText("x140 y226 w50 h20 c" Accent, "what?")
    EdgeBoundaryHelp.SetFont("underline")
    EdgeBoundaryHelp.OnEvent("Click", (*) => InfoPopup.Show("Edge Boundary", "How close the bar can get to either edge before the macro stops balancing and forces recovery. Higher values play safer. Lower values allow more edge tolerance."))
        EdgeBoundary := mg.AddEdit("x250 y225 w40 h20", Format("{:.2f}", MAIN["edge_boundary"]))
    mg.AddText("x300 y225 w85 h20 c" TextColor, "0.02 - 0.30").SetFont("s9")

    UpdateRate.OnEvent("LoseFocus", (*) => ValidateAndSaveMain("update_rate", UpdateRate, 1, 35, true, 0))
    PredictionStrength.OnEvent("LoseFocus", (*) => ValidateAndSaveMain("prediction_strength", PredictionStrength, 1.0, 20.0, false, 1))
    CloseThreshold.OnEvent("LoseFocus", (*) => ValidateAndSaveMain("close_threshold", CloseThreshold, 0.01, 0.10, false, 2))
    NDCycle.OnEvent("LoseFocus", (*) => ValidateAndSaveMain("neutral_duty_cycle", NDCycle, 0.20, 0.60, false, 2))
    VelocityDamping.OnEvent("LoseFocus", (*) => ValidateAndSaveMain("velocity_damping", VelocityDamping, 10.0, 60.0, true, 0))
    ProportionalGain.OnEvent("LoseFocus", (*) => ValidateAndSaveMain("proportional_gain", ProportionalGain, 0.10, 1.50, false, 2))
    DerivativeGain.OnEvent("LoseFocus", (*) => ValidateAndSaveMain("derivative_gain", DerivativeGain, 0.00, 1.00, false, 2))
    EdgeBoundary.OnEvent("LoseFocus", (*) => ValidateAndSaveMain("edge_boundary", EdgeBoundary, 0.02, 0.30, false, 2))

    mg.AddGroupBox("x10 y260 w380 h160 c" TextColor, "Main").SetFont("s9 bold")

    mg.AddText("x20 y280 w150 h20 c" TextColor, "Rod resilience").SetFont("s10")
    RodResilienceHelp := mg.AddText("x140 y280 w50 h20 c" Accent, "what?")
    RodResilienceHelp.SetFont("underline")
    RodResilienceHelp.OnEvent("Click", (*) => InfoPopup.Show("Rod Resilience", "you should know this"))
        Resilience := mg.AddEdit("x250 y280 w40 h20", Format("{:.2f}", MAIN["resilience"]))
    mg.AddText("x300 y282 w85 h20 c" TextColor, "15% -> 0.15")

    mg.AddText("x20 y305 w150 h20 c" TextColor, "Rod Equipped").SetFont("s10")
    global RodEquipped := mg.AddText("x140 y305 w150 h100 c" TextColor, ROD)
    RodEquipped.SetFont("s10")
    CheckEquippedBtn := mg.AddText("x300 y307 w50 h20 c" Accent, "Check")
    CheckEquippedBtn.SetFont("underline")
    CheckEquippedBtn.OnEvent("Click", (*) => UpdateEquippedRod())

    StatusText := mg.AddText("x20 y345 w150 h20 c" TextColor, "Status: ---")
    StatusText.SetFont("s10")

    PowerText := mg.AddText("x20 y370 w150 h20 c" TextColor, "Power: ---")
    PowerText.SetFont("s10")

    ProgressText := mg.AddText("x20 y390 w150 h20 c" TextColor, "Progress: ---")
    ProgressText.SetFont("s10")

    mg.AddGroupBox("x10 y425 w380 h90 c" TextColor, "Info").SetFont("s9 bold")

    mg.AddText("x20 y445 w150 h20 c" TextColor, "Start Macro: " HOTKEYS["start_macro"]).SetFont("s10")
    mg.AddText("x20 y465 w150 h20 c" TextColor, "Fix Roblox: " HOTKEYS["fix_roblox"]).SetFont("s10")
    mg.AddText("x20 y485 w150 h20 c" TextColor, "Reload: " HOTKEYS["reload"]).SetFont("s10")
    ChangeHotkeysBtn := mg.AddText("x320 y488 w65 h20 c" Accent, "Change 🡒")
    ChangeHotkeysBtn.SetFont("s10 underline")
    ChangeHotkeysBtn.OnEvent("Click", (*) => MainTab.Choose(3))

    mg.AddGroupBox("x10 y520 w380 h70 c" TextColor, "Config").SetFont("s9 bold")

    configList := ListConfigs()
    ddlItems := configList.Length > 0 ? configList : ["No configs"]
    ConfigDDL := mg.AddDDL("x20 y540 w160 h200", ddlItems)
    lastConfig := SETTINGS.Has("last_config") ? SETTINGS["last_config"] : ""
    if (lastConfig != "" && configList.Length > 0) {
        try ControlChooseString(lastConfig, ConfigDDL)
        catch
            ConfigDDL.Choose(1)
    } else {
        ConfigDDL.Choose(1)
    }

    LoadConfigBtn := button(mg, "Load", 190, 540, {
        w: 42,
        h: 22,
        bg: Accent
    })
    LoadConfigBtn.OnEvent("Click", (*) => OnLoadConfig(ConfigDDL))

    SaveConfigBtn := button(mg, "Save", 237, 540, {
        w: 42,
        h: 22,
        bg: Accent
    })
    SaveConfigBtn.OnEvent("Click", (*) => OnSaveConfig(ConfigDDL))

    NewConfigBtn := button(mg, "New", 284, 540, {
        w: 42,
        h: 22,
        bg: Accent
    })
    NewConfigBtn.OnEvent("Click", (*) => OnNewConfig(ConfigDDL))

    DeleteConfigBtn := button(mg, "Del", 331, 540, {
        w: 42,
        h: 22,
        bg: Accent
    })
    DeleteConfigBtn.OnEvent("Click", (*) => OnDeleteConfig(ConfigDDL))
    
    OpenConfigsBtn := mg.AddText("x20 y565 w80 h20 c" Accent, "Open folder")
    OpenConfigsBtn.SetFont("underline")
    OpenConfigsBtn.OnEvent("Click", (*) => Run("explorer.exe `"" CONFIGS_DIR "`""))

    MainTab.UseTab(2)
    mg.AddGroupBox("x10 y30 w380 h120 c" TextColor, "Settings").SetFont("s9 bold")

    AutoAppraise := mg.AddCheckbox("x20 y48 w20 h20")
    mg.AddText("x40 y50 w340 h20 c" TextColor, "Master Switch").SetFont("s9")
    MasterSwitchHelp := mg.AddText("x340 y50 w40 h20 c" Accent, "What?")
    MasterSwitchHelp.SetFont("underline")
    MasterSwitchHelp.OnEvent("Click", (*) => InfoPopup.Show("Master Switch", "When the master switch is off, starting the macro will begin fishing. When it is on, starting the macro will attempt to appraise."))
    Border(mg, 20, 71, 360, 1)

    mg.AddText("x20 y86 w100 h20 c" TextColor, "Mutation").SetFont("s10")
    AutoAppraiseMutation := mg.AddDDL("x260 y85 h100", ["Mythical", "Abyssal", "Glossy", "Electric", "Negative", "Amber", "Fossilized", "Silver", "Darkened", "Scorched", "Albino", "Lunar", "Mosaic", "Translucent", "Shiny", "Big", "Midas", "Hexed", "Frozen", "Sparkling"])
    
    AddMutationButton := mg.AddText("x230 y85 h20 w20 cWhite Center +0x200 +Border +Background0x171717", "+")
    AddMutationButton.SetFont("bold")
    AddMutationButton.OnEvent("Click", AddMutationClicked)

    AutoAppraiseMutationHelp := mg.AddText("x100 y88 h20 c" Accent, "What?")
    AutoAppraiseMutationHelp.SetFont("underline")
    AutoAppraiseMutationHelp.OnEvent("Click", (*) => InfoPopup.Show("Mutation", "Pick your desired mutation, which the macro will get"))

    mg.AddText("x20 y115 w100 h20 c" TextColor, "Max C$").SetFont("s10")
    AutoAprraiseMaxCash := mg.AddEdit("x260 y114 w120 h20")

    AutoAppraiseMaxCashHelp := mg.AddText("x100 y118 h20 c" Accent, "What?")
    AutoAppraiseMaxCashHelp.SetFont("underline")
    AutoAppraiseMaxCashHelp.OnEvent("Click", (*) => InfoPopup.Show("Max C$", "Set a limit on how much C$ the macro can spend trying to roll your desired mutation before stopping"))

    MainTab.UseTab(3)

    UpdateHeader := mg.AddText("x10 y25 w400 h40 c" TextColor, "Update Settings")
    UpdateHeader.SetFont("s15")
    border(mg, 10, 60, 380, 1)

    AutoUpdate := mg.AddCheckbox("x10 y70 w20 h20")
    AutoUpdate.Value := UPDATE["auto_update"]
    mg.AddText("x30 y71 w400 h20 cFFFFFF", "Automatic updates").SetFont("s9")
    mg.AddText("x30 y90 w400 h20 c646464", "Updates install silently in the background")
    
    ShowPostUpdateDialog := mg.AddCheckbox("x10 y110 w20 h20")
    ShowPostUpdateDialog.Value := UPDATE["show_confirmation"]

    AutoUpdate.OnEvent("Click", (ctrl, *) => (
        UPDATE["auto_update"] := ctrl.Value,
        SaveSettingsFile()
    ))
    ShowPostUpdateDialog.OnEvent("Click", (ctrl, *) => (
        UPDATE["show_confirmation"] := ctrl.Value,
        SaveSettingsFile()
    ))

    mg.AddText("x30 y111 w400 h20 cFFFFFF", "Show update confirmation").SetFont("s9")
    mg.AddText("x30 y130 w400 h20 c646464", "Display a success message after updates install")

    AccessabilityHeader:= mg.AddText("x10 y155 w400 h40 c" TextColor, "Accessability")
    AccessabilityHeader.SetFont("s15")
    border(mg, 10, 190, 380, 1)

    StartMacroKey := mg.AddHotkey("x10 y200 w30 h20", SETTINGS["hotkeys"]["start_macro"])
    StartMacroKey.OnEvent("Change", (ctrl, *) => UpdateHotkey("start_macro", ctrl))
    mg.AddText("x50 y199 w100 h20 c" TextColor, "Start Macro").SetFont("s11")
    mg.AddText("x50 y220 w250 h25 c646464", "Change the hotkey with which you start the macro.")

    FixRbxKey := mg.AddHotkey("x10 y260 w30 h20", SETTINGS["hotkeys"]["fix_roblox"])
    FixRbxKey.OnEvent("Change", (ctrl, *) => UpdateHotkey("fix_roblox", ctrl))
    mg.AddText("x50 y259 w100 h20 c" TextColor, "Fix Roblox").SetFont("s11")
    mg.AddText("x50 y279 w250 h25 c646464", "Change the hotkey with which you attempt fixes to roblox related issues.")
    FixRbxHelpBtn := mg.AddText("x125 y262 w100 h20 c" Accent, "Learn More")
    FixRbxHelpBtn.SetFont("s9 underline")
    FixRbxHelpBtn.OnEvent("Click", (*) => InfoPopup.Show("Roblox fixes", "XTernal attempts to resize && relocate roblox to a specific position and size to reduce computing power while runtime"))

    ReloadKey := mg.AddHotkey("x10 y320 w30 h20", SETTINGS["hotkeys"]["reload"])
    ReloadKey.OnEvent("Change", (ctrl, *) => UpdateHotkey("reload", ctrl))
    mg.AddText("x50 y319 w100 h20 c" TextColor, "Reload").SetFont("s11")
    mg.AddText("x50 y339 w250 h25 c646464", "Change the hotkey with which you reload the macro.")

    AppearanceHeader := mg.AddText("x10 y380 w400 h40 c" TextColor, "Appearance")
    AppearanceHeader.SetFont("s15")
    border(mg, 10, 415, 380, 1)

    mg.AddText("x10 y422 w80 h20 c" TextColor, "Theme").SetFont("s10")
    builtInThemes := GetBuiltInThemes()
    themeNames := []
    for name, _ in builtInThemes
        themeNames.Push(name)
    themeNames.Push("Custom")

    ThemeDDL := mg.AddDDL("x260 y420 w110 h200", themeNames)
    lastTheme := SETTINGS.Has("last_theme") ? SETTINGS["last_theme"] : "Custom"
    if (lastTheme != "") {
        try ControlChooseString(lastTheme, ThemeDDL)
        catch
            ThemeDDL.Choose(themeNames.Length)
    } else {
        ThemeDDL.Choose(themeNames.Length)
    }

    mg.AddText("x10 y452 w100 h20 c" TextColor, "Accent color").SetFont("s10")
    AccentInput := mg.AddEdit("x260 y451 w80 h20", APPEARANCE["accent_color"])
    AccentSwatch := mg.AddText("x350 y451 w20 h20 +Border Background" APPEARANCE["accent_color"], "")

    mg.AddText("x10 y479 w100 h20 c" TextColor, "Background").SetFont("s10")
    BgInput := mg.AddEdit("x260 y478 w80 h20", APPEARANCE["bg_color"])
    BgSwatch := mg.AddText("x350 y478 w20 h20 +Border Background" APPEARANCE["bg_color"], "")

    mg.AddText("x10 y506 w100 h20 c" TextColor, "Text color").SetFont("s10")
    TextInput := mg.AddEdit("x260 y505 w80 h20", APPEARANCE["text_color"])
    TextSwatch := mg.AddText("x350 y505 w20 h20 +Border Background" APPEARANCE["text_color"], "")

    mg.AddText("x10 y533 w100 h20 c" TextColor, "Border color").SetFont("s10")
    BorderInput := mg.AddEdit("x260 y532 w80 h20", APPEARANCE["border_color"])
    BorderSwatch := mg.AddText("x350 y532 w20 h20 +Border Background" APPEARANCE["border_color"], "")
    appearanceFields := [
        {key: "accent_color", ctrl: AccentInput, swatch: AccentSwatch, label: "Accent color"},
        {key: "bg_color", ctrl: BgInput, swatch: BgSwatch, label: "Background"},
        {key: "text_color", ctrl: TextInput, swatch: TextSwatch, label: "Text color"},
        {key: "border_color", ctrl: BorderInput, swatch: BorderSwatch, label: "Border color"}
    ]

    ThemeDDL.OnEvent("Change", (*) => ApplyThemePreset(ThemeDDL, builtInThemes, appearanceFields))

    ApplyAppearanceBtn := button(mg, "Apply", 290, 562, {
        w: 80,
        h: 25,
        bg: Accent
    })
    ApplyAppearanceBtn.OnEvent("Click", (*) => ApplyAppearanceChanges(appearanceFields, ThemeDDL))

    mg.AddText("x10 y565 w240 h20 c" SubColor, "Press Apply to save and reload.")


    MainTab.UseTab(4)
        mg.AddText("x10 y30 w300 h100 c" TextColor, "Version " FULL_VER).SetFont("s15 bold italic")
        mg.AddText("x270 y33 w120 h50 c" TextColor, "April 8, 2026").SetFont("s12 bold")

        mg.AddText("x15 y70 w300 h100 c" TextColor, "Latest Changes").SetFont("s13 bold")
        mg.AddText("x15 y95 w280 h80 c" TextColor, 
            "• Added UI color and appearance customization`n"
            . "• Began work on auto-appraisal`n"
            . "• Locked the Appraisal tab while development continues`n"
            . "• Updated for Roblox " ROBLOX_VER)
            .SetFont("s11")

    MainTab.UseTab(5)
    mg.AddText("x10 y30 w300 h40 c" TextColor, "OpenMacro XTernal").SetFont("s15 bold")
    mg.AddText("x10 y60 w300 h40 c" TextColor, "Designed, developed && maintained by Misery").SetFont("s10")

    mg.AddText("x10 y580 w300 h30 c" TextColor, "© 2026 Misery. All rights reserved.")

    CreditsDiscordLink := mg.AddText("x275 y580 w200 h30 c" Accent, "Official Discord Server")
    CreditsDiscordLink.SetFont("underline")
    CreditsDiscordLink.OnEvent("Click", (*) => Run("https://discord.gg/d2gqxEUx7U"))

    CreditsWebLink := mg.AddText("x10 y560 w200 h20 c" Accent, "Official Website")
    CreditsWebLink.SetFont("underline")
    CreditsWebLink.OnEvent("Click", (*) => Run("https://discord.gg/d2gqxEUx7U"))

    mg.Show("w400 h600 y100 x1100")
    UpdateMacroStatus("OFF", "---", "---")
    MainTab.Choose(1)
    lastAllowedTab := MainTab.Value

    mg.OnEvent("Close", (*) => ExitApp())

    AddMutationClicked(*) {
        newMutation := Trim(GetAddMutationDialog())
        if (newMutation = "")
            return

        AutoAppraiseMutation.Add([newMutation])
        ControlChooseString(newMutation, AutoAppraiseMutation)
    }

    HandleMainTabChange(ctrl, *) {
        if (revertingBlockedTab)
            return

        if (ctrl.Value = blockedTabIndex) {
            revertingBlockedTab := true
            ctrl.Choose(lastAllowedTab)
            revertingBlockedTab := false
            return
        }

        lastAllowedTab := ctrl.Value
    }
}

ApplyThemePreset(ddl, themes, appearanceFields) {
    global SETTINGS, APPEARANCE
    themeName := ddl.Text

    if (themeName = "Custom") {
        customTheme := SETTINGS.Has("custom_theme") ? SETTINGS["custom_theme"] : APPEARANCE
        for field in appearanceFields {
            if (customTheme.Has(field.key)) {
                field.ctrl.Value := customTheme[field.key]
                field.swatch.Opt("Background" customTheme[field.key])
            }
        }
        return
    }

    if (!themes.Has(themeName))
        return

    theme := themes[themeName]

    for field in appearanceFields {
        if (theme.Has(field.key)) {
            field.ctrl.Value := theme[field.key]
            field.swatch.Opt("Background" theme[field.key])
        }
    }
}

ApplyAppearanceChanges(appearanceFields, themeDDL := "") {
    global SETTINGS, APPEARANCE

    pendingColors := Map()
    hasChanges := false

    for field in appearanceFields {
        raw := StrUpper(Trim(field.ctrl.Value))

        if !RegExMatch(raw, "^[0-9A-F]{6}$") {
            field.ctrl.Value := APPEARANCE[field.key]
            field.ctrl.Focus()
            MsgBox("Please enter a valid 6-character hex color for " field.label " (e.g. FF0000).", "Invalid Color")
            return
        }

        pendingColors[field.key] := raw
        hasChanges := hasChanges || (raw != APPEARANCE[field.key])
    }

    for field in appearanceFields {
        color := pendingColors[field.key]
        field.ctrl.Value := color
        field.swatch.Opt("Background" color)
    }

    if !hasChanges
        return

    for key, color in pendingColors {
        APPEARANCE[key] := color
        SETTINGS["appearance"][key] := color
    }

    if (themeDDL != "") {
        SETTINGS["last_theme"] := themeDDL.Text
        if (themeDDL.Text = "Custom") {
            for key, color in pendingColors
                SETTINGS["custom_theme"][key] := color
        }
    }

    SaveSettingsFile()
    ReloadMacro()
}

UpdateEquippedRod() {
    global ROD, RodEquipped
    ROD := GetHotbarRodName()
    RodEquipped.Text := ROD
}

UpdateMacroStatus(status := "", power := "", progress := "") {
    global StatusText, PowerText, ProgressText

    if IsSet(StatusText) && StatusText
        StatusText.Value := "Status: " (status = "" ? "---" : status)

    if IsSet(PowerText) && PowerText
        PowerText.Value := "Power: " (power = "" ? "---" : power)

    if IsSet(ProgressText) && ProgressText
        ProgressText.Value := "Progress: " (progress = "" ? "---" : progress)
}

UpdateHotkey(name, ctrl) {
    global SETTINGS

    newKey := ctrl.Value
    oldKey := SETTINGS["hotkeys"][name]

    if (newKey = oldKey)
        return

    if (newKey != "") {
        actionNames := Map(
            "start_macro", "Start Macro",
            "fix_roblox", "Fix Roblox",
            "reload", "Reload"
        )

        for actionName, assignedKey in SETTINGS["hotkeys"] {
            if (actionName != name && assignedKey = newKey) {
                ctrl.Value := oldKey
                MsgBox(
                    newKey " is already assigned to " actionNames[actionName] ". Please choose a different key.",
                    "Hotkey Conflict"
                )
                return
            }
        }
    }

    callback := (name = "start_macro") ? (*) => StartMacro()
              : (name = "fix_roblox") ? (*) => FixRoblox()
              : (*) => ReloadMacro()

    HotkeyManager.ChangeHotkey(oldKey, newKey, callback)
    SETTINGS["hotkeys"][name] := newKey

    SaveSettingsFile()
    TrayTip("Saved Hotkey locally.", "Settings", "Mute")
}

OnLoadConfig(ddl) {
    if (ddl.Text = "No configs")
        return

    LoadConfig(ddl.Text)
}

OnSaveConfig(ddl) {
    if (ddl.Text = "No configs")
        return

    SaveConfig(ddl.Text)
    ShowConfigSavedDialog(ddl.Text)
}

OnNewConfig(ddl) {
    name := Trim(ShowConfigNameInput())

    if (name = "")
        return

    if (ddl.Text != "No configs") {
        existingConfigs := ListConfigs()
        for cfg in existingConfigs {
            if (cfg = name) {
                ShowConfigAlert("Duplicate Name", "A config named '" name "' already exists.")
                return
            }
        }
    }

    SaveConfig(name)

    if (ddl.Text = "No configs") {
        ddl.Delete()
        ddl.Add([name])
    } else {
        ddl.Add([name])
    }

    ControlChooseString(name, ddl)
}

OnDeleteConfig(ddl) {
    if (ddl.Text = "No configs")
        return

    name := ddl.Text

    if (!ShowConfigConfirmDialog(name))
        return

    DeleteConfig(name)

    ddl.Delete()
    remaining := ListConfigs()

    if (remaining.Length = 0) {
        ddl.Add(["No configs"])
        ddl.Choose(1)
    } else {
        ddl.Add(remaining)
        ddl.Choose(1)
    }
}

DimHex(hex, factor) {
    r := Round(Integer("0x" SubStr(hex, 1, 2)) * factor)
    g := Round(Integer("0x" SubStr(hex, 3, 2)) * factor)
    b := Round(Integer("0x" SubStr(hex, 5, 2)) * factor)
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}
