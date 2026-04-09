#Requires AutoHotkey v2.0
#Include ..\Components\Border.ahk
#Include ..\Components\Button.ahk
#Include ..\Components\InfoPopup.ahk


GetUpdDialog(currentVer, updatedVer) {
    handoffStarted := false

    mg := Gui("AlwaysOnTop +Border")
    mg.BackColor := 0x171717
    mg.Title := "Update Available"

    mg.AddText("x0 y280 w400 h1 +Background0x646464", "")
    Border(mg, 10, 40, 380, 1, 646464)
    mg.AddText("x5 y282 w200 h20 c646464", "Client Version: " currentVer).SetFont("s10 italic")
    mg.AddText("x345 y282 w50 h20 c646464", "XTernal").SetFont("s10 italic")

    mg.AddText("x40 y10 w300 h30 cWhite", "Update Available (" updatedVer ")").SetFont("s15")
    mg.AddPic("x10 y10 w26 h26 icon176", "imageres.dll")
    mg.AddText("x10 y55 w380 h200 cWhite", "A newer version of XTernal is available on GitHub.`n`nThe updater installs the exact files published for the matching version tag, then restarts the macro once the update is staged successfully.").SetFont("s10")

    LearnMore := mg.AddText("x90 y119 w90 h20 c646464", "Learn More")
    LearnMore.SetFont("s10 italic underline")
    LearnMore.OnEvent("Click", (*) =>
        InfoPopup.Show(
            "How Updates Work",
            "XTernal checks the repository version file on startup.`n`n"
            . "When an update is available, it downloads the exact GitHub tag ZIP for that version, stages it in a temporary folder, then replaces the shipped app files after the current script exits."
        )
    )

    DownloadBtn := button(mg, "Download", 10, 240, {
        w: 100,
        h: 30
    })

    LaterBtn := button(mg, "Later", 120, 240, {
        w: 100,
        h: 30,
        bg: 171717
    })

    DownloadBtn.OnEvent("Click", DownloadClicked)
    LaterBtn.OnEvent("Click", CloseDialog)
    mg.OnEvent("Close", CloseDialog)
    mg.OnEvent("Escape", CloseDialog)

    mg.Show("w400 h300")
    WinWaitClose(mg.Hwnd)
    return handoffStarted

    DownloadClicked(*) {
        if !BeginUpdateInstall(updatedVer, true)
            return

        handoffStarted := true
        mg.Destroy()
    }

    CloseDialog(*) {
        handoffStarted := false
        mg.Destroy()
    }
}