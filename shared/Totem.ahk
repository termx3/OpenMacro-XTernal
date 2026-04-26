#Requires AutoHotkey v2.0

GetHotbarTotems() {
    totems := []
    seen := Map()
    hotbar := GetHotbarGui()

    if !hotbar
        return totems

    for itemAddr in ReadChildren(hotbar) {
        if (ReadClassName(itemAddr) != "ImageButton" || ReadInstanceName(itemAddr) != "ItemTemplate")
            continue

        toolName := ReadHotbarItemName(itemAddr)
        if !IsSupportedAutoTotem(toolName)
            continue

        if seen.Has(toolName)
            continue

        seen[toolName] := true
        totems.Push(toolName)
    }

    return totems
}

HasHotbarTotem(totemName) {
    return FindHotbarItemByName(totemName) ? true : false
}

GetHotbarItemSlotKey(itemName) {
    itemAddr := FindHotbarItemByName(itemName)
    if !itemAddr
        return ""

    return ReadHotbarItemSlotKey(itemAddr)
}

SelectHotbarSlot(slotKey) {
    if (slotKey = "")
        return false

    SendInput("{" slotKey "}")
    Sleep(75)
    return true
}

UseHotbarSlot(slotKey) {
    if !SelectHotbarSlot(slotKey)
        return false

    Click()
    Sleep(75)
    return true
}

UseEquippedHotbarItem() {
    Click()
    Sleep(75)
    AutoTotemDebugLog("clicked equipped hotbar item")
    return true
}

GetAutoTotemWaitMs() {
    return 30000
}

GetAutoTotemDebugLogPath() {
    global APPDATA_DIR
    return APPDATA_DIR "\autototem.log"
}

StartAutoTotemDebugSession() {
    global ENV
    if (ENV != "dev")
        return

    try {
        path := GetAutoTotemDebugLogPath()
        if FileExist(path)
            FileDelete(path)

        FileAppend(
            "=== Auto Totem Debug Session | " FormatTime(, "yyyy-MM-dd HH:mm:ss")
            . " | wait_ms=" GetAutoTotemWaitMs() " ===`n",
            path,
            "UTF-8-RAW"
        )
    }
}

AutoTotemDebugLog(message, includeSnapshot := true) {
    global ENV
    if (ENV != "dev")
        return

    try {
        line := FormatTime(, "HH:mm:ss") "." Format("{:03}", Mod(A_TickCount, 1000)) " | " message
        if includeSnapshot
            line .= " | " AutoTotemDebugMacroState()

        FileAppend(line "`n", GetAutoTotemDebugLogPath(), "UTF-8-RAW")
    }
}

AutoTotemDebugMacroState() {
    global Macro

    return "phase=" Macro.phase
        . " totemState=" Macro.totemState
        . " pending=" Macro.totemPending
        . " blocked=" Macro.totemBlockedUntilCatchEnd
        . " nightCovered=" Macro.totemNightCovered
        . " needsRod=" Macro.totemNeedsRodReequip
}

AutoTotemDebugClean(text) {
    text := StrReplace(text, "`r", " ")
    text := StrReplace(text, "`n", " ")
    text := StrReplace(text, "|", "/")
    return text
}

AutoTotemDebugProbe(context) {
    global ENV
    if (ENV != "dev")
        return

    cycleText := AutoTotemDebugClean(GetWorldStatusText("4_cycle"))
    eventText := AutoTotemDebugClean(GetWorldStatusText("2_event"))
    weatherText := AutoTotemDebugClean(GetWorldStatusText("3_weather"))
    equippedTool := AutoTotemDebugClean(GetEquippedToolName())

    AutoTotemDebugLog(
        context
        . " | cycle=[" cycleText "]"
        . " event=[" eventText "]"
        . " weather=[" weatherText "]"
        . " equipped=[" equippedTool "]",
        false
    )
}

GetCharacterModel() {
    workspace := GetWorkspaceRoot()
    if !workspace
        return 0

    localPlayer := GetLocalPlayer()
    if !localPlayer
        return 0

    playerName := ReadInstanceName(localPlayer)
    if (playerName = "" || playerName = "<null>")
        return 0

    return FindChildByName(workspace, playerName)
}

GetEquippedToolName() {
    character := GetCharacterModel()
    if !character
        return ""

    for childAddr in ReadChildren(character) {
        if (ReadClassName(childAddr) = "Tool")
            return ReadInstanceName(childAddr)
    }

    return ""
}

IsAnythingEquipped() {
    character := GetCharacterModel()
    if !character
        return false

    for childAddr in ReadChildren(character) {
        if (ReadClassName(childAddr) = "Tool")
            return true
    }

    return false
}

IsRodEquipped() {
    equippedTool := GetEquippedToolName()
    if (equippedTool = "")
        return false

    rodName := GetHotbarRodName()
    if (rodName != "")
        return (equippedTool = rodName)

    return InStr(equippedTool, "Rod") ? true : false
}

EnsureRodEquipped() {
    if IsRodEquipped() {
        AutoTotemDebugLog("rod already equipped, skipping slot 1")
        return true
    }

    ok := SelectHotbarSlot("1")
    AutoTotemDebugLog("rod not equipped, sent slot 1 success=" ok)
    return ok
}

TryUseHotbarItem(itemName) {
    slotKey := GetHotbarItemSlotKey(itemName)
    if (slotKey = "") {
        AutoTotemDebugLog("missing hotbar item: " itemName)
        return false
    }

    Loop 2 {
        attempt := A_Index
        equippedBefore := GetEquippedToolName()

        if (equippedBefore != itemName) {
            if !SelectHotbarSlot(slotKey) {
                AutoTotemDebugLog("failed selecting hotbar item: " itemName " @ slot " slotKey " attempt=" attempt)
                return false
            }

            Sleep(175)
        }

        Click()
        Sleep(100)

        equippedAfter := GetEquippedToolName()
        AutoTotemDebugLog(
            "used hotbar item: " itemName
            . " @ slot " slotKey
            . " attempt=" attempt
            . " before=[" equippedBefore "]"
            . " after=[" equippedAfter "]"
        )

        if (equippedAfter = itemName || equippedBefore = itemName)
            return true

        Sleep(125)
    }

    AutoTotemDebugLog("failed to confirm hotbar item use: " itemName " @ slot " slotKey)
    return false
}

ResolveWorldStatuses() {
    global g_CachedWorldStatuses

    if (g_CachedWorldStatuses)
        return g_CachedWorldStatuses

    localPlayer := GetLocalPlayer()
    if (!localPlayer)
        return 0

    playerGui := FindChildByClass(localPlayer, "PlayerGui")
    if (!playerGui)
        return 0

    hud := FindChildByName(playerGui, "hud")
    if (!hud)
        return 0

    safezone := FindChildByName(hud, "safezone")
    if (!safezone)
        return 0

    worldStatuses := FindChildByName(safezone, "worldstatuses")
    if (worldStatuses)
        g_CachedWorldStatuses := worldStatuses

    return worldStatuses
}

GetWorldStatusText(statusName) {
    global OFFSETS

    worldStatuses := ResolveWorldStatuses()
    if !worldStatuses
        return ""

    statusAddr := FindChildByName(worldStatuses, statusName)
    if !statusAddr
        return ""

    labelAddr := FindChildByName(statusAddr, "label")
    if !labelAddr
        return ""

    text := ""

    if OFFSETS.Has("TextLabelText")
        text := ReadString(labelAddr + (OFFSETS["TextLabelText"] + 0))

    if (text = "")
        text := ReadGuiText(labelAddr)

    return NormalizeHotbarItemText(text)
}

GetWorldStatusVisible(statusName) {
    global OFFSETS

    worldStatuses := ResolveWorldStatuses()
    if !worldStatuses
        return false

    statusAddr := FindChildByName(worldStatuses, statusName)
    if !statusAddr
        return false

    if OFFSETS.Has("TextLabelVisible")
        return ReadByte(statusAddr + (OFFSETS["TextLabelVisible"] + 0)) ? true : false

    if OFFSETS.Has("FrameVisible")
        return ReadByte(statusAddr + (OFFSETS["FrameVisible"] + 0)) ? true : false

    return true
}

IsNightCycle() {
    cycleText := StrLower(GetWorldStatusText("4_cycle"))
    return InStr(cycleText, "night") ? true : false
}

IsAuroraActive() {
    return IsWorldStatusMatchVisible("2_event", "aurora")
        || IsWorldStatusMatchVisible("3_weather", "aurora")
}

FindHotbarItemByName(itemName) {
    hotbar := GetHotbarGui()
    if !hotbar
        return 0

    for itemAddr in ReadChildren(hotbar) {
        if (ReadClassName(itemAddr) != "ImageButton" || ReadInstanceName(itemAddr) != "ItemTemplate")
            continue

        if (ReadHotbarItemName(itemAddr) = itemName)
            return itemAddr
    }

    return 0
}

ReadHotbarItemName(itemAddr) {
    nameInst := FindChildByName(itemAddr, "ItemName")
    if !nameInst
        return ""

    return NormalizeHotbarItemText(ReadGuiText(nameInst))
}

ReadHotbarItemSlotKey(itemAddr) {
    for childAddr in ReadChildren(itemAddr) {
        childClass := ReadClassName(childAddr)
        childName := ReadInstanceName(childAddr)

        if (childClass = "TextLabel" && childName = "TextLabel")
            return NormalizeHotbarItemText(ReadGuiText(childAddr))
    }

    return ""
}

NormalizeHotbarItemText(text) {
    if (text = "")
        return ""

    return Trim(RegExReplace(text, "<[^>]+>"))
}

IsSupportedAutoTotem(toolName) {
    return (toolName = "Aurora Totem")
}

IsWorldStatusMatchVisible(statusName, needle) {
    if !GetWorldStatusVisible(statusName)
        return false

    return InStr(StrLower(GetWorldStatusText(statusName)), StrLower(needle)) ? true : false
}

FindDescendantByNameAndClass(rootAddr, targetName, targetClass := "") {
    queue := [rootAddr]
    index := 1

    while (index <= queue.Length) {
        current := queue[index]
        index += 1

        currentName := ReadInstanceName(current)
        currentClass := ReadClassName(current)

        if (currentName = targetName && (targetClass = "" || currentClass = targetClass))
            return current

        for childAddr in ReadChildren(current)
            queue.Push(childAddr)
    }

    return 0
}
