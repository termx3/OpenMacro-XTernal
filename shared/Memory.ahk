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

GetDataModel() {
    global OFFSETS, H_PROCESS, RBLX_BASE
    
    fakeDataModelOffset := OFFSETS["FakeDataModelPointer"] + 0
    fakeDataModel := ReadPointer(RBLX_BASE + fakeDataModelOffset)
    
    if (!fakeDataModel)
        return 0
    
    dataModelOffset := OFFSETS["FakeDataModelToDataModel"] + 0
    dataModel := ReadPointer(fakeDataModel + dataModelOffset)
    
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
    global OFFSETS
    
    players := GetPlayers()
    if !players
        return 0
    
    localPlayerOffset := OFFSETS["LocalPlayer"] + 0
    localPlayer := ReadPointer(players + (localPlayerOffset))
    return localPlayer
}

FindPlayerGui() {
    localPlayer := GetLocalPlayer()
    if (!localPlayer)
        return 0
    
    children := ReadChildren(localPlayer)
    
    for childPtr in children {
        className := ReadClassName(childPtr)
        if (className = "PlayerGui")
            return childPtr
    }
    
    return 0
}

GetWorkspaceRoot() {
    dataModel := GetDataModel()
    if (!dataModel)
        return 0

    for childPtr in ReadChildren(dataModel) {
        name := ReadInstanceName(childPtr)
        className := ReadClassName(childPtr)
        if (name = "Workspace" || className = "Workspace")
            return childPtr
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
    backpack := GetBackpackGui()
    if !backpack
        return 0

    return FindChildByName(backpack, "Hotbar")
}

GetHotbarRodName() {
    hotbar := GetHotbarGui()
    if !hotbar
        return ""

    for _, slotPtr in ReadChildren(hotbar) {
        toolNameLabel := FindChildByName(slotPtr, "ToolName")
        if !toolNameLabel
            continue

        toolText := Trim(ReadGuiText(toolNameLabel))
        if (toolText != "")
            return toolText
    }

    return ""
}