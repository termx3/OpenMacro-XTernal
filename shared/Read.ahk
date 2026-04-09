#Requires AutoHotkey v2.0
#Include  ..\library\JSON.ahk

ReadPointer(address) {
    global H_PROCESS
    buf := Buffer(A_PtrSize, 0)

    success := DllCall("ReadProcessMemory"
        , "Ptr", H_PROCESS
        , "Ptr", address
        , "Ptr", buf.Ptr
        , "UPtr", A_PtrSize
        , "UPtr*", 0)

    if !success
        return 0

    return NumGet(buf, 0, "UPtr")
}

ReadInt(address) {
    global H_PROCESS
    buf := Buffer(4, 0)

    success := DllCall("ReadProcessMemory"
        , "Ptr", H_PROCESS
        , "Ptr", address
        , "Ptr", buf.Ptr
        , "UInt", 4
        , "UInt*", 0)

    if !success
        return 0

    return NumGet(buf, 0, "Int")
}

ReadByte(address) {
    global H_PROCESS
    buf := Buffer(1, 0)

    success := DllCall("ReadProcessMemory"
        , "Ptr", H_PROCESS
        , "Ptr", address
        , "Ptr", buf.Ptr
        , "UInt", 1
        , "UInt*", 0)

    if !success
        return 0

    return NumGet(buf, 0, "UChar")
}

ReadString(address) {
    global H_PROCESS, OFFSETS

    length := ReadInt(address + (OFFSETS["StringLength"] + 0))

    if (length <= 0 || length > 1000)
        return ""

    dataAddr := address

    if (length > 15)
        dataAddr := ReadPointer(address)

    if !dataAddr
        return ""

    buf := Buffer(length + 1, 0)

    success := DllCall("ReadProcessMemory"
        , "Ptr", H_PROCESS
        , "Ptr", dataAddr
        , "Ptr", buf.Ptr
        , "UPtr", length
        , "UPtr*", 0)

    if !success
        return ""

    return StrGet(buf, length, "UTF-8")
}

ReadInstanceName(instanceAddr) {
    global OFFSETS
    
    nameOffset := OFFSETS["Name"] + 0
    namePtr := ReadPointer(instanceAddr + nameOffset)
    
    if (!namePtr)
        return "<null>"
    
    return ReadString(namePtr)
}

ReadClassName(instanceAddr) {
    global OFFSETS
    
    classDescOffset := OFFSETS["ClassDescriptor"] + 0
    classDesc := ReadPointer(instanceAddr + classDescOffset)
    
    if (!classDesc)
        return "<unknown>"
    
    classNameOffset := OFFSETS["ClassDescriptorToClassName"] + 0
    classNamePtr := ReadPointer(classDesc + classNameOffset)
    
    if (!classNamePtr)
        return "<unknown>"
    
    return ReadString(classNamePtr)
}

ReadChildren(instanceAddr) {
    global OFFSETS

    children := []

    childrenOffset := OFFSETS["Children"] + 0
    listPtr := ReadPointer(instanceAddr + childrenOffset)

    if !listPtr
        return children

    arrayStart := ReadPointer(listPtr)
    arrayEnd := ReadPointer(listPtr + 8)

    if (!arrayStart || !arrayEnd || arrayEnd <= arrayStart)
        return children

    entrySize := 0x10
    numChildren := (arrayEnd - arrayStart) // entrySize

    if (numChildren < 0 || numChildren > 1000)
        return children

    currentAddr := arrayStart
    Loop numChildren {
        childPtr := ReadPointer(currentAddr)
        if childPtr
            children.Push(childPtr)
        currentAddr += entrySize
    }

    return children
}

ReadFloat(address) {
    global H_PROCESS
    
    buf := Buffer(4, 0)
    success := DllCall("ReadProcessMemory"
        , "Ptr", H_PROCESS
        , "Ptr", address
        , "Ptr", buf.Ptr
        , "UInt", 4
        , "UInt*", 0)
    
    if (!success)
        return 0.0
    
    return NumGet(buf, 0, "Float")
}

ReadDouble(address) {
    global H_PROCESS

    buf := Buffer(8, 0)
    success := DllCall("ReadProcessMemory"
        , "Ptr", H_PROCESS
        , "Ptr", address
        , "Ptr", buf.Ptr
        , "UInt", 8
        , "UInt*", 0)

    if (!success)
        return 0.0

    return NumGet(buf, 0, "Double")
}

FindChildByName(instanceAddr, name) {
    for childPtr in ReadChildren(instanceAddr) {
        if (ReadInstanceName(childPtr) = name)
            return childPtr
    }
    return 0
}

ReadParent(instanceAddr) {
    global OFFSETS
    return ReadPointer(instanceAddr + (OFFSETS["Parent"] + 0))
}

ReadBytes(address, size) {
    global H_PROCESS

    buf := Buffer(size, 0)

    ok := DllCall("ReadProcessMemory"
        , "Ptr", H_PROCESS
        , "Ptr", address
        , "Ptr", buf.Ptr
        , "UPtr", size
        , "UPtr*", 0)

    if !ok
        return 0

    return buf
}

BufferToHex(buf, size := 64) {
    out := ""
    count := Min(buf.Size, size)

    Loop count {
        b := NumGet(buf, A_Index - 1, "UChar")
        out .= Format("{:02X}", b)
        if (A_Index < count)
            out .= " "
    }

    return out
}

ReadCString(address, maxLen := 128, encoding := "UTF-8") {
    buf := ReadBytes(address, maxLen)
    if !buf
        return ""

    return StrGet(buf, maxLen, encoding)
}