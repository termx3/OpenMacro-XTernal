#Requires AutoHotkey v2.0

global WebhookSession := {
    startedAt: 0,
    lastSummaryAt: 0
}

SendWebhookPost(url, payload) {
    if (url = "")
        return 0

    try {
        wr := ComObject("WinHttp.WinHttpRequest.5.1")
        wr.Open("POST", url "?with_components=true", false)
        wr.SetRequestHeader("Content-Type", "application/json")
        wr.Send(payload)
        return wr.Status
    } catch {
        return 0
    }
}

GetWebhookAccentColor() {
    global APPEARANCE
    hex := APPEARANCE["accent_color"]
    try
        return Integer("0x" hex)
    catch
        return 0x5aa9ff
}

FormatSessionRuntime(ms) {
    if (ms < 0)
        ms := 0

    totalSeconds := ms // 1000
    hours := totalSeconds // 3600
    minutes := Mod(totalSeconds, 3600) // 60
    seconds := Mod(totalSeconds, 60)

    if (hours > 0)
        return Format("{}h {}m {}s", hours, minutes, seconds)
    if (minutes > 0)
        return Format("{}m {}s", minutes, seconds)
    return Format("{}s", seconds)
}

GetTotemStateText() {
    global MAIN
    if !MAIN["auto_totem_enabled"]
        return "Disabled"

    mode := MAIN["auto_totem_mode"]
    if (mode = "interval")
        return "Enabled (interval " MAIN["auto_totem_interval_sec"] "s)"
    return "Enabled (on expire)"
}

BuildSummaryPayload() {
    global Macro, MAIN, SETTINGS, ROD, WebhookSession

    runtimeMs := WebhookSession.startedAt ? (A_TickCount - WebhookSession.startedAt) : 0

    headerText := "## XTernal Summary"
    if (MAIN["webhook_summary_session_time"])
        headerText .= "`n**Session runtime:** " FormatSessionRuntime(runtimeMs)

    statLines := []
    if (MAIN["webhook_summary_fish"]) {
        statLines.Push("**Caught:** " Macro.fishCaughtCount)
        statLines.Push("**Lost:** " Macro.fishLostCount)
    }
    if (MAIN["webhook_summary_success_rate"]) {
        total := Macro.fishCaughtCount + Macro.fishLostCount
        rate := total > 0 ? (Macro.fishCaughtCount / total) * 100.0 : 0.0
        statLines.Push("**Success Rate:** " Format("{:.1f}", rate) "%")
    }
    if (MAIN["webhook_summary_cast_timeouts"])
        statLines.Push("**Cast Timeouts:** " Macro.castTimeoutCount)
    if (MAIN["webhook_summary_totem_pops"])
        statLines.Push("**Totems Popped:** " Macro.totemPopCount)

    identityLines := []
    if (MAIN["webhook_summary_rod"])
        identityLines.Push("**Rod:** " (ROD != "" ? ROD : "---"))
    if (MAIN["webhook_summary_config"]) {
        cfg := SETTINGS.Has("last_config") ? SETTINGS["last_config"] : ""
        identityLines.Push("**Config:** " (cfg != "" ? cfg : "---"))
    }
    if (MAIN["webhook_summary_totem_state"])
        identityLines.Push("**Auto Totem:** " GetTotemStateText())

    innerComponents := []
    innerComponents.Push(Map("type", 10, "content", headerText))

    if (statLines.Length > 0) {
        innerComponents.Push(Map("type", 14))
        innerComponents.Push(Map("type", 10, "content", JoinLines(statLines)))
    }

    if (identityLines.Length > 0) {
        innerComponents.Push(Map("type", 14))
        innerComponents.Push(Map("type", 10, "content", JoinLines(identityLines)))
    }

    container := Map(
        "type", 17,
        "accent_color", GetWebhookAccentColor(),
        "components", innerComponents
    )

    payload := Map(
        "flags", 32768,
        "components", [container]
    )

    return JSON.stringify(payload)
}

JoinLines(lines) {
    out := ""
    for i, line in lines
        out .= (i = 1 ? "" : "`n") line
    return out
}

SendSummaryWebhook() {
    global MAIN, WebhookSession

    if !MAIN["webhook_enabled"]
        return

    url := MAIN["webhook_url"]
    if (url = "")
        return

    intervalMin := Max(1, MAIN["webhook_summary_interval_min"] + 0)
    intervalMs := intervalMin * 60 * 1000

    if (WebhookSession.lastSummaryAt && (A_TickCount - WebhookSession.lastSummaryAt) < intervalMs)
        return

    if (WebhookSession.startedAt = 0)
        return

    payload := BuildSummaryPayload()
    SendWebhookPost(url, payload)
    WebhookSession.lastSummaryAt := A_TickCount
}

SendInstantAlert(title, desc, color := 0xff4c4c) {
    global MAIN

    if !MAIN["webhook_enabled"]
        return

    url := MAIN["webhook_url"]
    if (url = "")
        return

    content := "## " title
    if (desc != "")
        content .= "`n" desc

    container := Map(
        "type", 17,
        "accent_color", color,
        "components", [Map("type", 10, "content", content)]
    )

    payload := Map(
        "flags", 32768,
        "components", [container]
    )

    SendWebhookPost(url, JSON.stringify(payload))
}
