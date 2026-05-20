#Requires AutoHotkey v2.0

;APPRAISE_FIXED_DELAY_MS := 100
APPRAISE_FIXED_RETRY_MS := 500
APPRAISE_SUBVALUES_MAX_RETRIES := 5

IsAutoAppraiseRuntimeEnabled() {
    global MAIN
    return MAIN.Has("auto_appraise_enabled") && MAIN["auto_appraise_enabled"] ? true : false
}

HasAutoAppraiseClickPoint() {
    global MAIN
    return MAIN.Has("auto_appraise_click_x")
        && MAIN.Has("auto_appraise_click_y")
        && Trim(MAIN["auto_appraise_click_x"]) != ""
        && Trim(MAIN["auto_appraise_click_y"]) != ""
        && IsNumber(MAIN["auto_appraise_click_x"])
        && IsNumber(MAIN["auto_appraise_click_y"])
}

ClearAppraiseRuntimeCache() {
    global Macro

    Macro.appraiseSubvaluesAddr := 0
    Macro.appraiseLastClickAt := 0
    Macro.appraiseWaitStartedAt := 0
    Macro.appraiseSubvaluesRetryCount := 0
    Macro.appraiseSubvaluesLastRetryAt := 0
    Macro.appraiseStartCoins := ""
    Macro.appraiseEndCoins := ""
    Macro.appraiseState := "IDLE"
    Macro.appraiseLastError := ""
}

StartAppraiseCycle() {
    global Macro, MAIN

    if (!IsAnythingEquipped()) {
        MsgBox("You have to have a fish selected when appraising.", "Appraisal")
        return false
    }

    if (!HasAutoAppraiseClickPoint()) {
        SetAppraiseStatus("Set a click point before appraising.")
        MsgBox("Set a click point in the Appraisal tab before starting.", "Appraisal")
        return false
    }

    desiredMutation := Trim(MAIN["auto_appraise_mutation"])
    if (desiredMutation = "") {
        SetAppraiseStatus("Choose a desired mutation.")
        MsgBox("Choose a desired mutation before starting.", "Appraisal")
        return false
    }

    ReleaseMouse(true)
    ClearAppraiseRuntimeCache()

    Macro.phase := "APPRAISE"
    Macro.appraiseState := "RESOLVING"
    Macro.cycleEnabled := true
    SetAppraiseStatus("Resolving fish info...")
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")

    try {
        subvaluesAddr := ResolveFishInfoSubvalues()
        if (!subvaluesAddr)
            throw Error("Could not find Workspace/<player>/fishinfo/Info/Subvalues. Hold the fish before appraising.")

        Macro.appraiseStartCoins := ReadCurrentAppraiseCoins()

        if (HasDesiredMutationInCachedSubvalues(desiredMutation)) {
            Macro.cycleEnabled := false
            Macro.phase := "DONE"
            Macro.appraiseState := "DONE"
            SetAppraiseStatus(desiredMutation " mutation was already present.")
            UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
            return true
        }

        Macro.appraiseState := "CLICK_FIRST"
        SetAppraiseStatus("Ready.")
        UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
        return true
    } catch as err {
        FailAppraiseCycle(err.Message)
        return false
    }
}

StopAppraiseCycle(nextPhase := "OFF", status := "Stopped.") {
    global Macro

    ReleaseMouse(true)
    Macro.cycleEnabled := false
    Macro.phase := nextPhase

    if (nextPhase = "OFF")
        ClearAppraiseRuntimeCache()
    else
        Macro.appraiseState := nextPhase

    SetAppraiseStatus(status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
}

UpdateAppraisePhase() {
    global Macro, MAIN, APPRAISE_SUBVALUES_MAX_RETRIES, APPRAISE_FIXED_RETRY_MS

    switch Macro.appraiseState {
        case "CLICK_FIRST":
            SetAppraiseStatus("Clicking 1/2.")
            ClickAppraisePoint()
            Macro.appraiseLastClickAt := A_TickCount
            Macro.appraiseState := "CLICK_SECOND"

        case "CLICK_SECOND":
            if ((A_TickCount - Macro.appraiseLastClickAt) < MAIN["appraise_delay_ms"])
                return

            SetAppraiseStatus("Clicking 2/2.")
            ClickAppraisePoint()
			Macro.appraiseLastClickAt := A_TickCount
			Macro.appraiseWaitStartedAt := A_TickCount
			Macro.appraiseSubvaluesLastRetryAt := A_TickCount
			Macro.appraiseState := "WAIT_RESULT"

        case "WAIT_RESULT":
		
            desiredMutation := Trim(MAIN["auto_appraise_mutation"])
			
            try {
                if (HasDesiredMutationInCachedSubvalues(desiredMutation)) {
                    CompleteAppraiseCycle("Found " desiredMutation ".")
                    return
                }
            } catch as err {
                if (InStr(err.Message, "Subvalues")) {
                    ; Throttle only Subvalues retries with their own delay.
                    if (Macro.appraiseSubvaluesLastRetryAt
                        && (A_TickCount - Macro.appraiseSubvaluesLastRetryAt) < APPRAISE_FIXED_RETRY_MS) {
                        return
                    }

                    Macro.appraiseSubvaluesLastRetryAt := A_TickCount
                    Macro.appraiseSubvaluesRetryCount += 1

                    if (Macro.appraiseSubvaluesRetryCount <= APPRAISE_SUBVALUES_MAX_RETRIES) {
                        SetAppraiseStatus(
                            "Waiting for fish info/Subvalues... "
                            Macro.appraiseSubvaluesRetryCount
                            "/"
                            APPRAISE_SUBVALUES_MAX_RETRIES
                        )
                        return
                    }
                }

                FailAppraiseCycle(err.Message)
                return
            }
			
			Macro.appraiseSubvaluesRetryCount := 0
			Macro.appraiseSubvaluesLastRetryAt := 0

            SetAppraiseStatus("Still looking for " desiredMutation ".")
            Macro.appraiseWaitStartedAt := A_TickCount
            Macro.appraiseState := "WAIT_RETRY"

        case "WAIT_RETRY":
            if ((A_TickCount - Macro.appraiseWaitStartedAt) < MAIN["appraise_delay_ms"])
                return

            SetAppraiseStatus("Retrying.")
            Macro.appraiseWaitStartedAt := 0
            Macro.appraiseState := "CLICK_FIRST"
    }
}

ResolveFishInfoSubvalues() {
    global Macro

    workspace := GetWorkspaceRoot()
    if (!workspace)
        return 0

    localPlayer := GetLocalPlayer()
    if (!localPlayer)
        return 0

    playerName := ReadInstanceName(localPlayer)
    if (playerName = "" || playerName = "<null>")
        return 0

    character := FindChildByName(workspace, playerName)
    if (!character)
        return 0

    fishInfo := FindChildByName(character, "fishinfo")
    if (!fishInfo)
        return 0

    info := FindChildByName(fishInfo, "Info")
    if (!info)
        return 0

    subvalues := FindChildByName(info, "Subvalues")
    if (subvalues)
        Macro.appraiseSubvaluesAddr := subvalues
    else
        Macro.appraiseSubvaluesAddr := 0

    return subvalues
}

ResolveFishInfoSubvaluesOnce() {
    return ResolveFishInfoSubvalues()
}

HasDesiredMutationInCachedSubvalues(desiredMutation) {
    subvaluesAddr := ResolveFishInfoSubvalues()

    if (!subvaluesAddr)
        throw Error("Could not find Workspace/<player>/fishinfo/Info/Subvalues. Hold or re-equip the fish before appraising.")

    desired := NormalizeAppraiseText(desiredMutation)
    if (desired = "")
        return false

    haystack := NormalizeAppraiseText(CollectSubvaluesText(subvaluesAddr))
    return InStr(haystack, desired) ? true : false
}

CollectSubvaluesText(subvaluesAddr) {
    textParts := []
    AppendAppraiseNodeText(textParts, subvaluesAddr)

    for childAddr in ReadChildren(subvaluesAddr) {
        AppendAppraiseNodeText(textParts, childAddr)

        for descendantAddr in ReadChildren(childAddr)
            AppendAppraiseNodeText(textParts, descendantAddr)
    }

    return JoinTextParts(textParts)
}

AppendAppraiseNodeText(textParts, instanceAddr) {
    try {
        className := ReadClassName(instanceAddr)
        if (!IsAppraiseTextCapable(className))
            return

        text := ReadGuiText(instanceAddr)
        if (text = "" && InStr(className, "Value"))
            text := ReadPropertyString(instanceAddr, ["Value"])

        text := Trim(text)
        if (text != "")
            textParts.Push(text)
    } catch {
    }
}

IsAppraiseTextCapable(className) {
    return InStr(className, "Text") || InStr(className, "Value")
}

NormalizeAppraiseText(text) {
    text := StrReplace(text, "`r", "`n")
    text := RegExReplace(text, "<[^>]+>")
    text := RegExReplace(text, "\s+", " ")
    return StrLower(Trim(text))
}

JoinTextParts(textParts) {
    out := ""
    for part in textParts {
        if (out != "")
            out .= " "
        out .= part
    }
    return out
}

GetCurrentAppraiseBonusAttributes() {
    bonusAttributes := []

    try {
        subvaluesAddr := ResolveFishInfoSubvalues()
        if (!subvaluesAddr)
            return bonusAttributes

        haystack := NormalizeAppraiseText(CollectSubvaluesText(subvaluesAddr))
        if (InStr(haystack, "shiny"))
            bonusAttributes.Push("Shiny")
        if (InStr(haystack, "sparkling"))
            bonusAttributes.Push("Sparkling")
    } catch {
    }

    return bonusAttributes
}

JoinAppraiseList(items) {
    out := ""
    for item in items {
        if (out != "")
            out .= ", "
        out .= item
    }
    return out
}

ReadCurrentAppraiseCoins() {
    playerGui := FindPlayerGui()
    if (!playerGui)
        return ""

    hud := FindChildByName(playerGui, "hud")
    if (!hud)
        return ""

    safezone := FindChildByName(hud, "safezone")
    if (!safezone)
        return ""

    coins := FindChildByName(safezone, "coins")
    if (!coins)
        return ""

    return ParseAppraiseCoinsText(ReadGuiText(coins))
}

ParseAppraiseCoinsText(text) {
    digits := RegExReplace(text, "\D")
    if (digits = "")
        return ""

    return digits + 0
}

FormatAppraiseCoins(value) {
    value := Round(value + 0)
    sign := value < 0 ? "-" : ""
    digits := "" Abs(value)
    out := ""

    while (StrLen(digits) > 3) {
        out := "," SubStr(digits, StrLen(digits) - 2, 3) out
        digits := SubStr(digits, 1, StrLen(digits) - 3)
    }

    return sign digits out
}

ClickAppraisePoint() {
    global MAIN

    ReliableScreenClick(
        Round(MAIN["auto_appraise_click_x"] + 0),
        Round(MAIN["auto_appraise_click_y"] + 0)
    )
}

ReliableScreenClick(x, y, wigglePixels := 3, stepDelayMs := 15) {
    previousMode := A_CoordModeMouse
    CoordMode("Mouse", "Screen")

    x := Round(x + 0)
    y := Round(y + 0)
    wigglePixels := Max(1, Round(wigglePixels + 0))
    stepDelayMs := Max(0, Round(stepDelayMs + 0))

    try {
        MouseMove(x, y, 0)
        Sleep(stepDelayMs)
        MouseMove(x + wigglePixels, y, 0)
        Sleep(stepDelayMs)
        MouseMove(x - wigglePixels, y, 0)
        Sleep(stepDelayMs)
        MouseMove(x, y + wigglePixels, 0)
        Sleep(stepDelayMs)
        MouseMove(x, y - wigglePixels, 0)
        Sleep(stepDelayMs)
        MouseMove(x, y, 0)
        Sleep(stepDelayMs)
        Click()
    } finally {
        CoordMode("Mouse", previousMode)
    }
}

CompleteAppraiseCycle(status) {
    global Macro

    Macro.appraiseEndCoins := ReadCurrentAppraiseCoins()
    Macro.cycleEnabled := false
    Macro.appraiseState := "DONE"
    Macro.phase := "DONE"
    SetAppraiseStatus(status)
    SendAppraiseFinishedWebhook(true, status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
}

FailAppraiseCycle(message) {
    global Macro

    Macro.appraiseEndCoins := ReadCurrentAppraiseCoins()
    Macro.cycleEnabled := false
    Macro.appraiseState := "FAILED"
    Macro.appraiseLastError := message
    Macro.phase := "FAILED"
    SetAppraiseStatus(message)
    SendAppraiseFinishedWebhook(false, message)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
}

SendAppraiseFinishedWebhook(success, message) {
    global Macro, MAIN

    desiredMutation := MAIN.Has("auto_appraise_mutation") ? Trim(MAIN["auto_appraise_mutation"]) : "---"

    lines := [
        "**Desired Mutation:** " (desiredMutation != "" ? desiredMutation : "---"),
        "**Result:** " message
    ]

    if (Macro.appraiseStartCoins != "" && Macro.appraiseEndCoins != "") {
        spent := Macro.appraiseStartCoins - Macro.appraiseEndCoins
        lines.Push("**C$ Spent:** " FormatAppraiseCoins(Max(0, spent)) " C$")
    }

    if (success) {
        bonusAttributes := GetCurrentAppraiseBonusAttributes()
        if (bonusAttributes.Length > 0)
            lines.Push("**Bonus Attributes:** " JoinAppraiseList(bonusAttributes))
    }

    title := success ? "Appraisal Finished" : "Appraisal Failed"
    SendInstantAlert(title, JoinLines(lines), GetWebhookAccentColor())
}

SetAppraiseStatus(message) {
    global AppraiseStatusText

    if (IsSet(AppraiseStatusText) && AppraiseStatusText)
        AppraiseStatusText.Value := "Status: " message
}
