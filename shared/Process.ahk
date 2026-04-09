#Requires AutoHotkey v2.0

GetRobloxPID() {
    global ROBLOX_INSTANCE
    return ProcessExist(ROBLOX_INSTANCE)
}

GetProcessBase(pid) {
    global H_PROCESS
    static PROCESS_QUERY_INFORMATION := 0x0400
    static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
    static PROCESS_VM_READ := 0x0010
    static LIST_MODULES_ALL := 0x03

    access := PROCESS_QUERY_INFORMATION | PROCESS_VM_READ
    H_PROCESS := DllCall("OpenProcess", "UInt", access, "Int", false, "UInt", pid, "Ptr")

    if !H_PROCESS
        H_PROCESS := DllCall("OpenProcess", "UInt", PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, "Int", false, "UInt", pid, "Ptr")

    if !H_PROCESS
        throw Error("Failed to open process " pid " (Error: " A_LastError ")")

    hMods := Buffer(A_PtrSize * 1024)
    cbNeeded := 0

    enumResult := DllCall("psapi\EnumProcessModulesEx"
        , "Ptr", H_PROCESS
        , "Ptr", hMods.Ptr
        , "UInt", hMods.Size
        , "UInt*", &cbNeeded
        , "UInt", LIST_MODULES_ALL)

    if !enumResult
        throw Error("Failed to enumerate modules for process " pid " (Error: " A_LastError ")")

    return NumGet(hMods, 0, "UPtr")
}