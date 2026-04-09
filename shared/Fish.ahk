#Requires AutoHotkey v2.0

CreateFishingMacro() {
    return {
        phase: "OFF",
        powerPercent: "",
        progressPercent: "",
        isHolding: false,
        castThreshold: 96.0,
        castWaitTimeoutMs: 15000,
        doneShownMs: 750,
        fishingEndGraceMs: 100,
        castStartedAt: 0,
        castReleasedAt: 0,
        castBarSeen: false,
        fishingLostAt: 0,
        doneAt: 0,
        shakingIntervalMs: 25,
        lastShakedAt: 0,
        ActivatedUiNav: false,
        cycleEnabled: false
    }
}

MacroLoop() {
    global Macro

    switch Macro.phase {
        case "CASTING":
            UpdateCastingPhase()
        case "CASTED":
            UpdateCastedPhase()
        case "SHAKE":
            UpdateShakePhase()
        case "FISHING":
            UpdateFishingPhase()
        case "DONE":
            if ((A_TickCount - Macro.doneAt) >= Macro.doneShownMs) {
                if (Macro.cycleEnabled)
                    StartMacroCycle()
                else
                    StopMacroCycle("OFF")
            }
        case "OFF":
    }

    UpdateMacroStatus(
        Macro.phase,
        (Macro.powerPercent = "" ? "---" : Macro.powerPercent "%"),
        (Macro.progressPercent = "" ? "---" : Macro.progressPercent "%")
    )
}

StartMacroCycle() {
    global Macro, Controller

    ReleaseMouse()
    Controller.Reset()

    if (!Macro.ActivatedUiNav) {
        SendInput("\")
        Macro.ActivatedUiNav := true
        Sleep(50)
    }

    Macro.powerPercent := ""
    Macro.progressPercent := ""
    Macro.castStartedAt := A_TickCount
    Macro.castReleasedAt := 0
    Macro.castBarSeen := false
    Macro.fishingLostAt := 0
    Macro.doneAt := 0
    Macro.lastShakedAt := 0
    Macro.phase := "CASTING"

    UpdateMacroStatus("CASTING", "---", "---")
}

StopMacroCycle(nextPhase := "OFF") {
    global Macro, Controller

    finalProgress := Macro.progressPercent

    ReleaseMouse()
    Controller.Reset()

    Macro.powerPercent := ""
    Macro.castStartedAt := 0
    Macro.castReleasedAt := 0
    Macro.castBarSeen := false
    Macro.progressPercent := ""
    Macro.fishingLostAt := 0
    Macro.lastShakedAt := 0
    Macro.doneAt := (nextPhase = "DONE") ? A_TickCount : 0
    Macro.phase := nextPhase

    UpdateMacroStatus(
        Macro.phase,
        "---",
        (nextPhase = "DONE" && finalProgress != "" ? finalProgress "%" : "---")
    )
}

UpdateCastingPhase() {
    global Macro

    Macro.progressPercent := ""
    HoldMouse()

    if (!Macro.castStartedAt)
        Macro.castStartedAt := A_TickCount

    resolved := ResolvePowerBarPath()
    if (!resolved.bar) {
        Macro.powerPercent := "---"

        if ((A_TickCount - Macro.castStartedAt) >= Macro.castWaitTimeoutMs)
            StartMacroCycle()

        return
    }

    Macro.castBarSeen := true

    percent := ReadPowerBarPercent(resolved.bar)
    Macro.powerPercent := Format("{:.1f}", percent)

    if (percent >= Macro.castThreshold) {
        ReleaseMouse()
        Macro.castReleasedAt := A_TickCount
        Macro.phase := "CASTED"
        return
    }

    if ((A_TickCount - Macro.castStartedAt) >= Macro.castWaitTimeoutMs)
        StartMacroCycle()
}

UpdateCastedPhase() {
    global Macro

    Macro.powerPercent := ""
    Macro.progressPercent := ""
    ReleaseMouse()

    if (!Macro.castReleasedAt)
        Macro.castReleasedAt := A_TickCount

    if ((A_TickCount - Macro.castReleasedAt) < 150)
        return

    Macro.lastShakedAt := 0
    Macro.phase := "SHAKE"
}

UpdateShakePhase() {
    global Macro

    Macro.powerPercent := ""
    Macro.progressPercent := ""
    ReleaseMouse()

    if (HasActiveFishingContext()) {
        Macro.lastShakedAt := 0
        Macro.fishingLostAt := 0
        Macro.phase := "FISHING"
        return
    }

    if (!Macro.lastShakedAt || (A_TickCount - Macro.lastShakedAt) >= Macro.shakingIntervalMs) {
        SendInput("{Enter}")
        Macro.lastShakedAt := A_TickCount
    }

    if (Macro.castReleasedAt && (A_TickCount - Macro.castReleasedAt) >= Macro.castWaitTimeoutMs)
        StartMacroCycle()
}

UpdateFishingPhase() {
    global Macro, Controller

    Macro.powerPercent := ""

    progress := GetFishingCompletionPercent()
    Macro.progressPercent := (progress = "" ? "" : Round(progress))

    if (IsFishingCompletionReached()) {
        StopMacroCycle("DONE")
        return
    }

    if (HasActiveFishingContext()) {
        Macro.fishingLostAt := 0
        Controller.Update()
        return
    }

    ReleaseMouse()
    Controller.Reset()

    if (!Macro.fishingLostAt)
        Macro.fishingLostAt := A_TickCount

    if ((A_TickCount - Macro.fishingLostAt) >= Macro.fishingEndGraceMs)
        StopMacroCycle("DONE")
}

HoldMouse() {
    global Macro

    if (Macro.isHolding)
        return

    Send("{LButton down}")
    Macro.isHolding := true
}

ReleaseMouse() {
    global Macro

    if (!Macro.isHolding)
        return

    Send("{LButton up}")
    Macro.isHolding := false
}

ReadFramePosition(frameAddr) {
    global OFFSETS

    base := OFFSETS["FramePositionX"] + 0
    scaleX := ReadFloat(frameAddr + base + 0x0)
    offsetX := ReadInt(frameAddr + base + 0x4)

    return {
        X: scaleX,
        XOffset: offsetX
    }
}

ReadFrameSize(frameAddr) {
    global OFFSETS

    base := OFFSETS["FrameSizeX"] + 0
    scaleX := ReadFloat(frameAddr + base + 0x0)
    offsetX := ReadInt(frameAddr + base + 0x4)

    return {
        X: scaleX,
        XOffset: offsetX
    }
}

GetReelGui() {
    playerGui := FindPlayerGui()
    if (!playerGui)
        return 0

    return FindChildByName(playerGui, "reel")
}

GetReelBarContext() {
    reelGui := GetReelGui()
    if (!reelGui)
        return 0

    barFrame := FindChildByName(reelGui, "bar")
    if (!barFrame)
        return 0

    return {
        bar: barFrame,
        fish: FindChildByName(barFrame, "fish"),
        playerbar: FindChildByName(barFrame, "playerbar")
    }
}

HasActiveFishingContext() {
    ctx := GetReelBarContext()
    return (ctx && ctx.fish && ctx.playerbar) ? true : false
}

GetReelProgressContext() {
    reelGui := GetReelGui()
    if (!reelGui)
        return 0

    controlBar := FindChildByName(reelGui, "bar")
    if (!controlBar)
        return 0

    progressFrame := FindChildByName(controlBar, "progress")
    if (!progressFrame)
        return 0

    progressBar := FindChildByName(progressFrame, "bar")
    if (!progressBar)
        return 0

    return {
        reel: reelGui,
        controlBar: controlBar,
        progress: progressFrame,
        progressBar: progressBar
    }
}

ReadProgressBarPercent(frameAddr) {
    size := ReadFrameSize(frameAddr)
    return Max(0.0, Min(100.0, size.X * 100.0))
}

GetFishingCompletionPercent() {
    ctx := GetReelProgressContext()
    if (!ctx || !ctx.progressBar)
        return ""

    return ReadProgressBarPercent(ctx.progressBar)
}

IsFishingCompletionReached(threshold := 99.7) {
    percent := GetFishingCompletionPercent()
    return (percent != "" && percent >= threshold)
}

IsIndicatorSafe() {
    ctx := GetReelBarContext()
    if (!ctx || !ctx.playerbar || !ctx.fish)
        return ""

    playerbarPos := ReadFramePosition(ctx.playerbar)
    playerbarSize := ReadFrameSize(ctx.playerbar)
    fishPos := ReadFramePosition(ctx.fish)
    fishSize := ReadFrameSize(ctx.fish)

    fishCenter := fishPos.X + (fishSize.X / 2)

    halfWidth := playerbarSize.X / 2
    safeZoneLeft := playerbarPos.X - halfWidth
    safeZoneRight := playerbarPos.X + halfWidth

    return (fishCenter >= safeZoneLeft && fishCenter <= safeZoneRight)
}

ResolvePowerBarPath() {
    workspace := GetWorkspaceRoot()
    if (!workspace)
        return { bar: 0 }

    localPlayer := GetLocalPlayer()
    if (!localPlayer)
        return { bar: 0 }

    playerName := ReadInstanceName(localPlayer)
    if (playerName = "" || playerName = "<null>")
        return { bar: 0 }

    character := FindChildByName(workspace, playerName)
    if (!character)
        return { bar: 0 }

    rootPart := FindChildByName(character, "HumanoidRootPart")
    if (!rootPart)
        return { bar: 0 }

    powerGui := FindChildByName(rootPart, "power")
    if (!powerGui)
        return { bar: 0 }

    bar := FindDescendantFrameByName(powerGui, "bar")
    if (!bar)
        return { bar: 0 }

    return { bar: bar }
}

ReadPowerBarPercent(instanceAddr) {
    global OFFSETS

    base := OFFSETS["FrameSizeX"] + 0
    scaleY := ReadFloat(instanceAddr + base + 0x8)
    percent := scaleY * 100.0

    return Max(0.0, Min(100.0, percent))
}

FindDescendantFrameByName(rootAddr, targetName) {
    queue := [rootAddr]
    index := 1

    while (index <= queue.Length) {
        current := queue[index]
        index += 1

        if (ReadInstanceName(current) = targetName && ReadClassName(current) = "Frame")
            return current

        for childPtr in ReadChildren(current)
            queue.Push(childPtr)
    }

    return 0
}

class FishingController {
    Reset() {
        for _, propName in ["lastPlayerbarPos", "lastFishPos", "pwmAccumulator"] {
            if (this.HasOwnProp(propName))
                this.DeleteProp(propName)
        }
    }

    Update() {
        isSafe := IsIndicatorSafe()
        if (isSafe = "") {
            this.Release()
            return
        }

        fishPos := this.GetFishPosition()
        playerbarPos := this.GetPlayerbarPosition()

        if (fishPos = "" || playerbarPos = "")
            return

        if (!this.HasOwnProp("lastPlayerbarPos"))
            this.lastPlayerbarPos := playerbarPos

        if (!this.HasOwnProp("lastFishPos"))
            this.lastFishPos := fishPos

        playerbarVelocity := playerbarPos - this.lastPlayerbarPos
        this.lastPlayerbarPos := playerbarPos

        fishVelocity := fishPos - this.lastFishPos
        this.lastFishPos := fishPos

        error := fishPos - playerbarPos

        edgeBoundary := MAIN["edge_boundary"]
        if (playerbarPos < edgeBoundary) {
            this.Hold()
            return
        }
        if (playerbarPos > 1 - edgeBoundary) {
            this.Release()
            return
        }

        predictionScale := MAIN["prediction_strength"] * (1.0 - MAIN["resilience"])
        predicted := playerbarPos + (playerbarVelocity * predictionScale)
        predictedError := fishPos - predicted

        closeThreshold := MAIN["close_threshold"]
        sameSideAfterPrediction := (error * predictedError) > 0

        approachingTarget := (error * playerbarVelocity) > 0
        remainingDistance := Max(0.0, Abs(error) - closeThreshold)

        ; full stop fixing and start bleeding speed early
        brakeLookahead := Abs(playerbarVelocity) * 8
        needsPreSlow := approachingTarget && (brakeLookahead >= remainingDistance)

        ; hard fix only when far enough and not yet in the braking zone
        if (Abs(error) > closeThreshold && sameSideAfterPrediction && !needsPreSlow) {
            if (error > 0)
                this.Hold()
            else
                this.Release()
            return
        }

        neutralDuty := MAIN["neutral_duty_cycle"]

        if (needsPreSlow && brakeLookahead > 0) {
            brakeUrgency := 1.0 - Min(1.0, remainingDistance / brakeLookahead)

            if (error > 0) {
                targetDuty := neutralDuty * (1.0 - brakeUrgency)
            } else {
                targetDuty := neutralDuty + ((1.0 - neutralDuty) * brakeUrgency)
            }
        } else {
            ; Normal pwm balancing // fine tracking
            kP := MAIN["proportional_gain"]
            kD := MAIN["derivative_gain"]
            kV := MAIN["velocity_damping"]

            adjustment := (kP * error) + (kD * fishVelocity) - (kV * playerbarVelocity)
            targetDuty := Max(0.0, Min(1.0, neutralDuty + adjustment))
        }

        if (!this.HasOwnProp("pwmAccumulator"))
            this.pwmAccumulator := 0.0

        this.pwmAccumulator += targetDuty
        if (this.pwmAccumulator >= 1.0) {
            this.pwmAccumulator -= 1.0
            this.Hold()
        } else {
            this.Release()
        }
    }

    GetFishPosition() {
        ctx := GetReelBarContext()
        if (!ctx || !ctx.fish)
            return ""

        fishPos := ReadFramePosition(ctx.fish)
        fishSize := ReadFrameSize(ctx.fish)
        return fishPos.X + (fishSize.X / 2)
    }

    GetPlayerbarPosition() {
        ctx := GetReelBarContext()
        if (!ctx || !ctx.playerbar)
            return ""

        playerbarPos := ReadFramePosition(ctx.playerbar)
        return playerbarPos.X
    }

    Hold() {
        HoldMouse()
    }

    Release() {
        ReleaseMouse()
    }
}