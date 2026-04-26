#Requires AutoHotkey v2.0

LoadOffsets() {
    global OFFSETS, OFFSETS_PATH

    if (!FileExist(OFFSETS_PATH)) {
        throw Error("offsets.json not found at: " OFFSETS_PATH)
    }

    try {
        jsonData := FileRead(OFFSETS_PATH)
    } catch as err {
        throw Error("Failed to read offsets.json: " err.Message)
    }

    try {
        parsed := JSON.parse(jsonData)
    } catch as err {
        throw Error("JSON parsing failed: " err.Message)
    }

    if !(parsed is Map) {
        temp := Map()
        for k, v in parsed
            temp[k] := v
        OFFSETS := temp
    } else {
        OFFSETS := parsed
    }
    
    if (!OFFSETS.Has("FakeDataModelPointer")) {
        throw Error("FakeDataModelPointer not found in offsets")
    }
}

AreOffsetsLoaded() {
    global OFFSETS
    return (OFFSETS is Map) && OFFSETS.Count && OFFSETS.Has("FakeDataModelPointer")
}

ResetRobloxAttachmentState() {
    global H_PROCESS, RBLX_PID, RBLX_BASE, OFFSETS, ROD
    global g_CachedDataModel, g_CachedLocalPlayer, g_CachedPlayerGui
    global g_CachedWorkspaceRoot, g_CachedWorldStatuses, g_CachedHotbarGui

    g_CachedDataModel := 0
    g_CachedLocalPlayer := 0
    g_CachedPlayerGui := 0
    g_CachedWorkspaceRoot := 0
    g_CachedWorldStatuses := 0
    g_CachedHotbarGui := 0

    if (H_PROCESS)
        DllCall("CloseHandle", "Ptr", H_PROCESS)
    H_PROCESS := 0
    RBLX_PID := 0
    RBLX_BASE := 0
    OFFSETS := Map()
    ROD := ""
}

IsCachedAddrValid(addr, expectedName) {
    if (!addr)
        return false

    try {
        name := ReadInstanceName(addr)
    } catch {
        return false
    }

    return (name = expectedName)
}

IsRobloxAttached() {
    global H_PROCESS, RBLX_PID, RBLX_BASE

    currentPid := GetRobloxPID()
    return (currentPid && currentPid = RBLX_PID && H_PROCESS && RBLX_BASE) ? true : false
}

IsMemoryReady() {
    return IsRobloxAttached() && AreOffsetsLoaded()
}

AttachToRoblox(pid := 0) {
    global RBLX_PID, RBLX_BASE, ROD, H_PROCESS

    pid := pid ? pid : GetRobloxPID()
    if !pid
        throw Error("Roblox is not running.")

    ResetRobloxAttachmentState()
    RBLX_PID := pid

    try {
        RBLX_BASE := GetProcessBase(pid)
        if (!RBLX_BASE)
            throw Error("Failed to attach to Roblox.")

        LoadOffsets()
        ROD := GetHotbarRodName()
        return true
    } catch as err {
        ResetRobloxAttachmentState()
        throw Error(err.Message)
    }
}

EnsureRobloxReady(showMessage := true, attemptAttach := true) {
    currentPid := GetRobloxPID()

    if !currentPid {
        ResetRobloxAttachmentState()
        UpdateRobloxUiState()
        if showMessage
            MsgBox("Roblox is not running. Open Roblox first to use this feature.", "Roblox Not Found")
        return false
    }

    if IsMemoryReady() {
        UpdateRobloxUiState()
        return true
    }

    if !attemptAttach {
        if showMessage
            MsgBox("Roblox is not attached. Open Roblox and try again, or press Fix Roblox.", "Roblox Not Attached")
        return false
    }

    try {
        AttachToRoblox(currentPid)
        UpdateRobloxUiState()
        return true
    } catch as err {
        UpdateRobloxUiState()
        if showMessage
            MsgBox(err.Message, "Roblox Attachment")
        return false
    }
}

GetDataModel() {
    global OFFSETS, H_PROCESS, RBLX_BASE, g_CachedDataModel

    if (g_CachedDataModel)
        return g_CachedDataModel

    if (!AreOffsetsLoaded() || !H_PROCESS || !RBLX_BASE)
        return 0

    fakeDataModelOffset := OFFSETS["FakeDataModelPointer"] + 0
    fakeDataModel := ReadPointer(RBLX_BASE + fakeDataModelOffset)

    if (!fakeDataModel)
        return 0

    dataModelOffset := OFFSETS["FakeDataModelToDataModel"] + 0
    dataModel := ReadPointer(fakeDataModel + dataModelOffset)

    if (dataModel)
        g_CachedDataModel := dataModel

    return dataModel
}

GetPlayers() {
    dataModel := GetDataModel()
    
    if !dataModel
        return 0
    
    children := ReadChildren(dataModel)
    
    for childPtr in children {
        className := ReadClassName(childPtr)
        if (className = "Players")
            return childPtr
    }
    
    return 0
}

GetLocalPlayer() {
    global OFFSETS, g_CachedLocalPlayer

    if (g_CachedLocalPlayer)
        return g_CachedLocalPlayer

    players := GetPlayers()
    if !players
        return 0

    localPlayerOffset := OFFSETS["LocalPlayer"] + 0
    localPlayer := ReadPointer(players + (localPlayerOffset))

    if (localPlayer)
        g_CachedLocalPlayer := localPlayer

    return localPlayer
}

FindPlayerGui() {
    global g_CachedPlayerGui

    if (g_CachedPlayerGui)
        return g_CachedPlayerGui

    localPlayer := GetLocalPlayer()
    if (!localPlayer)
        return 0

    children := ReadChildren(localPlayer)

    for childPtr in children {
        className := ReadClassName(childPtr)
        if (className = "PlayerGui") {
            g_CachedPlayerGui := childPtr
            return childPtr
        }
    }

    return 0
}

GetWorkspaceRoot() {
    global g_CachedWorkspaceRoot

    if (g_CachedWorkspaceRoot)
        return g_CachedWorkspaceRoot

    dataModel := GetDataModel()
    if (!dataModel)
        return 0

    for childPtr in ReadChildren(dataModel) {
        name := ReadInstanceName(childPtr)
        className := ReadClassName(childPtr)
        if (name = "Workspace" || className = "Workspace") {
            g_CachedWorkspaceRoot := childPtr
            return childPtr
        }
    }

    return 0
}

ReadPropertyString(instanceAddr, offsetKeys) {
    global OFFSETS

    for _, key in offsetKeys {
        if !OFFSETS.Has(key)
            continue

        offset := OFFSETS[key] + 0

        ptrValue := ReadPointer(instanceAddr + offset)
        if ptrValue {
            text := ReadString(ptrValue)
            if (text != "")
                return text
        }

        directValue := ReadString(instanceAddr + offset)
        if (directValue != "")
            return directValue
    }

    return ""
}

ReadGuiText(instanceAddr) {
    return ReadPropertyString(instanceAddr, ["Text", "TextLabelText", "ContentText"])
}

GetCoreGui() {
    dataModel := GetDataModel()
    if !dataModel
        return 0

    return FindChildByName(dataModel, "CoreGui")
}

GetRobloxGui() {
    coreGui := GetCoreGui()
    if !coreGui
        return 0

    return FindChildByName(coreGui, "RobloxGui")
}

GetBackpackGui() {
    robloxGui := GetRobloxGui()
    if !robloxGui
        return 0

    return FindChildByName(robloxGui, "Backpack")
}

GetHotbarGui() {
    global g_CachedHotbarGui

    if (g_CachedHotbarGui)
        return g_CachedHotbarGui

    lp := GetLocalPlayer()
    if !lp
        return 0

    pg := FindChildByClass(lp, "PlayerGui")
    if !pg
        return 0

    bp := FindChildByName(pg, "backpack")
    if !bp
        return 0

    hotbar := FindChildByName(bp, "hotbar")
    if (hotbar)
        g_CachedHotbarGui := hotbar

    return hotbar
}

GetHotbarRodName() {
    hotbar := GetHotbarGui()
    if !hotbar
        return ""

    fallback := ""

    for slotPtr in ReadChildren(hotbar) {
        if (ReadClassName(slotPtr) != "ImageButton" || ReadInstanceName(slotPtr) != "ItemTemplate")
            continue

        nameInst := FindChildByName(slotPtr, "ItemName")
        if !nameInst
            continue

        toolText := ReadGuiText(nameInst)
        pureRodName := ExtractPureRodName(toolText)
        if (pureRodName != "")
            return pureRodName

        toolText := NormalizeRodDisplayText(toolText)
        if (toolText = "")
            continue

        if (fallback = "")
            fallback := toolText
    }

    return fallback
}

GetHotbarRodDisplayText() {
    hotbar := GetHotbarGui()
    if !hotbar
        return ""

    fallback := ""

    for slotPtr in ReadChildren(hotbar) {
        if (ReadClassName(slotPtr) != "ImageButton" || ReadInstanceName(slotPtr) != "ItemTemplate")
            continue

        nameInst := FindChildByName(slotPtr, "ItemName")
        if !nameInst
            continue

        toolText := NormalizeRodDisplayText(ReadGuiText(nameInst))
        if (toolText = "")
            continue

        if (ExtractPureRodName(toolText) != "" || IsPinionRodText(toolText))
            return toolText

        if (fallback = "")
            fallback := toolText
    }

    return fallback
}

GetKnownRodNames() {
    static rodNames := [
        "Pinion's Aria",
        "Rod Of The Eternal King",
        "Rod Of The Depths",
        "Rod Of Time",
        "Flimsy Rod",
        "Training Rod",
        "Plastic Rod",
        "Steady Rod",
        "Reinforced Rod",
        "Phoenix Rod",
        "Mythical Rod",
        "No-Life Rod",
        "Sunken Rod",
        "Trident Rod",
        "Kings Rod",
        "Wisdom Rod",
        "Toxinburst Rod",
        "The Lost Rod",
        "Riptide Rod",
        "Lucid Rod",
        "Celestial Rod",
        "Seasons Rod",
        "Krampus's Rod",
        "Precision Rod",
        "Resourceful Rod",
        "Toxic Spire Rod",
        "Gardenkeeper Rod",
        "Voyager Rod",
        "Vineweaver Rod"
    ]

    return rodNames
}

NormalizeRodDisplayText(text) {
    text := StrReplace(text, "`r", "`n")
    text := RegExReplace(text, "<[^>]+>")
    text := RegExReplace(text, "[ \t]+", " ")
    text := RegExReplace(text, "\n+", "`n")
    return Trim(text)
}

IsPinionRodText(text) {
    return InStr(StrLower(NormalizeRodDisplayText(text)), "pinion") ? true : false
}

HasPinionHotbarRod() {
    return IsPinionRodText(GetHotbarRodDisplayText())
}

ExtractPureRodName(text) {
    cleanText := NormalizeRodDisplayText(text)
    if (cleanText = "")
        return ""

    for _, rodName in GetKnownRodNames() {
        if (InStr(cleanText, rodName))
            return rodName
    }

    for _, line in StrSplit(cleanText, "`n") {
        line := Trim(line)
        if (line = "")
            continue

        if (line = "Pinion's Aria" || RegExMatch(line, "i)\brod\b"))
            return line
    }

    return ""
}
