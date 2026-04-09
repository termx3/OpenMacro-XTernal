#Requires AutoHotkey v2.0

CheckForAvailableUpdate() {
    if (GetUpdaterBlockReason() != "")
        return ""

    try {
        remoteVersion := Trim(FetchTextUrl(VERSION_URL), " `t`r`n")

        if !IsValidVersionString(remoteVersion)
            return ""

        if (CompareVersions(remoteVersion, FULL_VER) <= 0)
            return ""

        if !IsTagPackageReachable(remoteVersion)
            return ""

        return remoteVersion
    } catch {
        return ""
    }
}

BeginUpdateInstall(version, showErrors := false) {
    tempRoot := ""
    helperPath := ""

    try {
        if (blockReason := GetUpdaterBlockReason()) != ""
            throw Error(blockReason)

        if !IsValidVersionString(version)
            throw Error("Invalid update version.")

        if (CompareVersions(version, FULL_VER) <= 0)
            throw Error("No newer update is available.")

        if !IsTagPackageReachable(version)
            throw Error("The tagged update package is not available yet.")

        tempRoot := CreateUpdateTempRoot(version)
        zipPath := tempRoot "\update.zip"
        extractDir := tempRoot "\staged"

        DownloadBinaryFile(BuildTagZipUrl(version), zipPath)

        if !ExtractZipToDirectory(zipPath, extractDir)
            throw Error("Failed to extract the downloaded update package.")

        stageRoot := FindStagedAppRoot(extractDir)
        if (stageRoot = "")
            throw Error("The downloaded update is missing required app files.")

        if !ValidateStagedUpdate(stageRoot, version)
            throw Error("The staged update does not match the requested version.")

        helperPath := CreateUpdateHelper(version, tempRoot, stageRoot)

        if !LaunchUpdateHelper(helperPath)
            throw Error("Failed to launch the external updater helper.")

        return true
    } catch as err {
        CleanupUpdateArtifacts(tempRoot, helperPath)

        if (showErrors)
            MsgBox("Unable to start update " version ": " err.Message, "Update Error")

        return false
    }
}

RecordSuccessfulUpdateLaunch() {
    global UPDATE

    if (A_Args.Length < 2)
        return

    if (A_Args[1] != UPDATE_RELAUNCH_ARG)
        return

    updatedVersion := Trim(A_Args[2], " `t`r`n")

    if !IsValidVersionString(updatedVersion)
        return

    if (updatedVersion != FULL_VER)
        return

    EnsurePostUpdateFlagDir()

    try {
        if FileExist(POST_UPDATE_ACK_PATH)
            FileDelete(POST_UPDATE_ACK_PATH)

        FileAppend(updatedVersion, POST_UPDATE_ACK_PATH, "UTF-8-RAW")
    } catch {
    }

    if !UPDATE["show_confirmation"]
        return

    try {
        if FileExist(POST_UPDATE_FLAG_PATH)
            FileDelete(POST_UPDATE_FLAG_PATH)

        FileAppend(updatedVersion, POST_UPDATE_FLAG_PATH, "UTF-8-RAW")
    } catch {
    }
}

ConsumePostUpdateVersion() {
    EnsurePostUpdateFlagDir()

    if !FileExist(POST_UPDATE_FLAG_PATH)
        return ""

    try {
        version := Trim(FileRead(POST_UPDATE_FLAG_PATH), " `t`r`n")
    } catch {
        version := ""
    }

    try FileDelete(POST_UPDATE_FLAG_PATH)

    if !IsValidVersionString(version)
        return ""

    return version
}

GetUpdaterBlockReason() {
    global ENV

    if (ENV = "dev")
        return "Updater is disabled in the dev environment."

    if IsProtectedInstallTree(A_ScriptDir)
        return "Updater is disabled for git working trees."

    return ""
}

IsProtectedInstallTree(path) {
    currentPath := path

    while (currentPath != "") {
        if HasGitMetadata(currentPath)
            return true

        SplitPath(currentPath, , &parentPath)
        if (parentPath = currentPath)
            break

        currentPath := parentPath
    }

    return false
}

HasGitMetadata(path) {
    return DirExist(path "\.git") || FileExist(path "\.git")
}

CreateHttpRequest() {
    request := ComObject("WinHttp.WinHttpRequest.5.1")
    request.SetTimeouts(5000, 5000, 15000, 15000)
    return request
}

SendHttpRequest(method, url, headers := "", redirectCount := 0) {
    if (redirectCount >= 5)
        throw Error("Too many redirects for " url)

    request := CreateHttpRequest()
    request.Open(method, url, false)
    request.SetRequestHeader("User-Agent", GITHUB_REPO " Updater")

    if (headers is Map) {
        for name, value in headers
            request.SetRequestHeader(name, value)
    }

    request.Send()

    if (request.Status >= 300 && request.Status < 400) {
        try {
            location := request.GetResponseHeader("Location")
        } catch {
            location := ""
        }

        if (location != "")
            return SendHttpRequest(method, ResolveRedirectUrl(url, location), headers, redirectCount + 1)
    }

    return request
}

ResolveRedirectUrl(baseUrl, redirectUrl) {
    if RegExMatch(redirectUrl, "i)^[a-z][a-z0-9+\-.]*://")
        return redirectUrl

    if (SubStr(redirectUrl, 1, 1) = "/") {
        if RegExMatch(baseUrl, "i)^(https?://[^/]+)", &origin)
            return origin[1] redirectUrl
    }

    if RegExMatch(baseUrl, "i)^(.*/)[^/]*$", &parent)
        return parent[1] redirectUrl

    return redirectUrl
}

FetchTextUrl(url) {
    request := SendHttpRequest("GET", url)

    if !IsSuccessfulHttpStatus(request.Status)
        throw Error("HTTP " request.Status " returned for " url)

    return request.ResponseText
}

DownloadBinaryFile(url, destinationPath) {
    request := SendHttpRequest("GET", url)

    if !IsSuccessfulHttpStatus(request.Status)
        throw Error("HTTP " request.Status " returned for " url)

    stream := ComObject("ADODB.Stream")
    stream.Type := 1
    stream.Open()
    stream.Write(request.ResponseBody)
    stream.Position := 0
    stream.SaveToFile(destinationPath, 2)
    stream.Close()
}

IsSuccessfulHttpStatus(status) {
    return status >= 200 && status < 300
}

IsTagPackageReachable(version) {
    if !IsValidVersionString(version)
        return false

    return IsUrlReachable(BuildTagZipUrl(version))
}

IsUrlReachable(url) {
    try {
        request := SendHttpRequest("HEAD", url)
        if (request.Status >= 200 && request.Status < 400)
            return true
    } catch {
    }

    try {
        request := SendHttpRequest("GET", url, Map("Range", "bytes=0-0"))
        if (request.Status >= 200 && request.Status < 400)
            return true
    } catch {
    }

    return false
}

IsValidVersionString(version) {
    return RegExMatch(version, "^v\d+\.\d+\.\d+$")
}

ParseVersion(version) {
    if !IsValidVersionString(version)
        throw Error("Invalid version string: " version)

    parts := StrSplit(SubStr(version, 2), ".")
    return [parts[1] + 0, parts[2] + 0, parts[3] + 0]
}

CompareVersions(leftVersion, rightVersion) {
    leftParts := ParseVersion(leftVersion)
    rightParts := ParseVersion(rightVersion)

    Loop 3 {
        if (leftParts[A_Index] > rightParts[A_Index])
            return 1

        if (leftParts[A_Index] < rightParts[A_Index])
            return -1
    }

    return 0
}

BuildTagZipUrl(version) {
    return TAG_ZIP_BASE_URL version ".zip"
}

CreateUpdateTempRoot(version) {
    uniqueId := A_Now "_" DllCall("GetTickCount64", "Int64")
    tempRoot := A_Temp "\OpenMacro-XTernal-Update-" version "-" uniqueId
    DirCreate(tempRoot)
    return tempRoot
}

ExtractZipToDirectory(zipPath, destinationPath) {
    DirCreate(destinationPath)

    powershellPath := A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe"
    command := "Expand-Archive -LiteralPath " ToPowerShellLiteral(zipPath)
        . " -DestinationPath " ToPowerShellLiteral(destinationPath)
        . " -Force"

    exitCode := RunWait(
        '"' powershellPath '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "' command '"',
        ,
        "Hide"
    )

    return exitCode = 0
}

ToPowerShellLiteral(value) {
    return "'" StrReplace(value, "'", "''") "'"
}

FindStagedAppRoot(extractDir) {
    if IsValidStagedAppRoot(extractDir)
        return extractDir

    Loop Files, extractDir "\*", "D" {
        if IsValidStagedAppRoot(A_LoopFilePath)
            return A_LoopFilePath
    }

    return ""
}

IsValidStagedAppRoot(candidatePath) {
    return FileExist(candidatePath "\Main.ahk")
        && DirExist(candidatePath "\shared")
        && DirExist(candidatePath "\ui")
        && DirExist(candidatePath "\library")
}

ValidateStagedUpdate(stageRoot, expectedVersion) {
    return IsValidStagedAppRoot(stageRoot)
        && GetPackageVersion(stageRoot) = expectedVersion
}

GetPackageVersion(rootPath) {
    versionPath := rootPath "\version.txt"
    constantsPath := rootPath "\shared\Constants.ahk"

    if FileExist(versionPath) {
        try {
            version := Trim(FileRead(versionPath), " `t`r`n")
            if IsValidVersionString(version)
                return version
        } catch {
        }
    }

    if FileExist(constantsPath) {
        try {
            constantsText := FileRead(constantsPath)
            if RegExMatch(constantsText, 'm)^\s*FULL_VER\s*:=\s*"([^"]+)"', &match) {
                version := match[1]
                if IsValidVersionString(version)
                    return version
            }
        } catch {
        }
    }

    return ""
}

CreateUpdateHelper(version, tempRoot, stageRoot) {
    helperPath := A_Temp "\OpenMacro-XTernal-UpdateHelper-" A_Now "_" DllCall("GetTickCount64", "Int64") ".cmd"
    currentPid := DllCall("GetCurrentProcessId")
    mainScriptPath := A_ScriptDir "\Main.ahk"
    q := Chr(34)
    lines := []

    lines.Push("@echo off")
    lines.Push("setlocal")
    lines.Push("set " q "SOURCE_PID=" currentPid q)
    lines.Push("set " q "STAGE_DIR=" EscapeBatchValue(stageRoot) q)
    lines.Push("set " q "INSTALL_DIR=" EscapeBatchValue(A_ScriptDir) q)
    lines.Push("set " q "TEMP_ROOT=" EscapeBatchValue(tempRoot) q)
    lines.Push("set " q "BACKUP_DIR=%TEMP_ROOT%\backup" q)
    lines.Push("set " q "RUNTIME_PATH=" EscapeBatchValue(A_AhkPath) q)
    lines.Push("set " q "MAIN_SCRIPT=" EscapeBatchValue(mainScriptPath) q)
    lines.Push("set " q "UPDATED_VERSION=" EscapeBatchValue(version) q)
    lines.Push("set " q "ACK_PATH=" EscapeBatchValue(POST_UPDATE_ACK_PATH) q)
    lines.Push("set " q "CLEANUP_TEMP=1" q)

    lines.Push("for /L %%I in (1,1,60) do (")
    lines.Push("    tasklist /FI " q "PID eq %SOURCE_PID%" q " 2>nul | find /I " q "%SOURCE_PID%" q " >nul")
    lines.Push("    if errorlevel 1 goto backup_current")
    lines.Push("    ping 127.0.0.1 -n 2 >nul")
    lines.Push(")")
    lines.Push("goto cleanup")

    lines.Push(":backup_current")
    lines.Push("ping 127.0.0.1 -n 3 >nul")
    lines.Push("if exist " q "%BACKUP_DIR%" q " rmdir /s /q " q "%BACKUP_DIR%" q)
    lines.Push("mkdir " q "%BACKUP_DIR%" q " >nul 2>nul")
    lines.Push("robocopy " q "%INSTALL_DIR%" q " " q "%BACKUP_DIR%" q " /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NC /NS /NP >nul")
    lines.Push("set " q "BACKUP_EXIT=%ERRORLEVEL%" q)
    lines.Push("if %BACKUP_EXIT% GEQ 8 goto relaunch_old")

    lines.Push("robocopy " q "%STAGE_DIR%" q " " q "%INSTALL_DIR%" q " /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NC /NS /NP >nul")
    lines.Push("set " q "COPY_EXIT=%ERRORLEVEL%" q)
    lines.Push("if %COPY_EXIT% GEQ 8 goto restore_backup")

    lines.Push("if not exist " q "%INSTALL_DIR%\Main.ahk" q " goto restore_backup")
    lines.Push("if not exist " q "%INSTALL_DIR%\shared" q " goto restore_backup")
    lines.Push("if not exist " q "%INSTALL_DIR%\ui" q " goto restore_backup")
    lines.Push("if not exist " q "%INSTALL_DIR%\library" q " goto restore_backup")
    lines.Push("call :check_installed_version")
    lines.Push("if errorlevel 1 goto restore_backup")

    lines.Push("if exist " q "%ACK_PATH%" q " del /f /q " q "%ACK_PATH%" q " >nul 2>nul")
    lines.Push("cd /d " q "%INSTALL_DIR%" q)
    lines.Push("start " q q " " q "%RUNTIME_PATH%" q " " q "%MAIN_SCRIPT%" q " " UPDATE_RELAUNCH_ARG " " q "%UPDATED_VERSION%" q)
    lines.Push("if errorlevel 1 goto restore_backup")

    lines.Push("for /L %%I in (1,1,20) do (")
    lines.Push("    if exist " q "%ACK_PATH%" q " goto launch_confirmed")
    lines.Push("    ping 127.0.0.1 -n 2 >nul")
    lines.Push(")")
    lines.Push("goto restore_backup")

    lines.Push(":launch_confirmed")
    lines.Push("del /f /q " q "%ACK_PATH%" q " >nul 2>nul")
    lines.Push("goto cleanup")

    lines.Push(":restore_backup")
    lines.Push("robocopy " q "%BACKUP_DIR%" q " " q "%INSTALL_DIR%" q " /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NC /NS /NP >nul")
    lines.Push("set " q "RESTORE_EXIT=%ERRORLEVEL%" q)
    lines.Push("if %RESTORE_EXIT% GEQ 8 set " q "CLEANUP_TEMP=0" q)
    lines.Push("if %RESTORE_EXIT% GEQ 8 goto cleanup")
    lines.Push("goto relaunch_old")

    lines.Push(":relaunch_old")
    lines.Push("cd /d " q "%INSTALL_DIR%" q)
    lines.Push("start " q q " " q "%RUNTIME_PATH%" q " " q "%MAIN_SCRIPT%" q)
    lines.Push("goto cleanup")

    lines.Push(":check_installed_version")
    lines.Push("if exist " q "%INSTALL_DIR%\version.txt" q " (")
    lines.Push("    findstr /R /X /C:" q "%UPDATED_VERSION%" q " " q "%INSTALL_DIR%\version.txt" q " >nul")
    lines.Push("    if not errorlevel 1 exit /b 0")
    lines.Push(")")
    lines.Push("findstr /I /C:" q "FULL_VER" q " " q "%INSTALL_DIR%\shared\Constants.ahk" q " | find /I " q "%UPDATED_VERSION%" q " >nul")
    lines.Push("if errorlevel 1 exit /b 1")
    lines.Push("exit /b 0")

    lines.Push(":cleanup")
    lines.Push("if " q "%CLEANUP_TEMP%" q "==" q "1" q " (")
    lines.Push("    if exist " q "%TEMP_ROOT%" q " rmdir /s /q " q "%TEMP_ROOT%" q)
    lines.Push("    start " q q " powershell -NoProfile -NonInteractive -WindowStyle Hidden -Command " q "Start-Sleep -Seconds 2; Remove-Item -LiteralPath '%~f0' -Force" q " >nul 2>nul")
    lines.Push(")")
    lines.Push("exit /b 0")

    helperContents := ""
    for _, line in lines
        helperContents .= line "`r`n"

    if FileExist(helperPath)
        FileDelete(helperPath)

    FileAppend(helperContents, helperPath, "CP0")
    return helperPath
}

EscapeBatchValue(value) {
    return StrReplace(value, "%", "%%")
}

LaunchUpdateHelper(helperPath) {
    Run(A_ComSpec ' /c ""' helperPath '""', , "Hide", &helperPid)
    return helperPid != 0
}

EnsurePostUpdateFlagDir() {
    if !DirExist(APPDATA_DIR)
        DirCreate(APPDATA_DIR)
}

CleanupUpdateArtifacts(tempRoot, helperPath := "") {
    if (tempRoot != "" && DirExist(tempRoot)) {
        try DirDelete(tempRoot, true)
    }

    if (helperPath != "" && FileExist(helperPath)) {
        try FileDelete(helperPath)
    }
}