#Requires AutoHotkey v2.0
#Include ..\Components\Border.ahk
#Include ..\Components\Button.ahk
#Include ..\Components\InfoPopup.ahk


GetUpdDialog(currentVer, updatedVer) {
    global APPEARANCE

    handoffStarted := false
    isDownloading := false
    dialogShowOpts := "w400 h300"
    Accent := APPEARANCE["accent_color"]
    BgColor := APPEARANCE["bg_color"]
    TextColor := APPEARANCE["text_color"]
    BorderColor := APPEARANCE["border_color"]

    mg := Gui("AlwaysOnTop +Border")
    mg.BackColor := "0x" BgColor
    mg.Title := "Update Available"
    mg.SetFont(, "Segoe UI")

    mg.AddText("x0 y280 w400 h1 +Background" BorderColor, "")
    Border(mg, 10, 40, 380, 1, BorderColor)
    mg.AddText("x5 y282 w200 h20 c" BorderColor, "Client Version: " currentVer).SetFont("s10 italic")
    mg.AddText("x345 y282 w50 h20 c" BorderColor, "XTernal").SetFont("s10 italic")

    mg.AddText("x40 y10 w300 h30 c" TextColor, "Update Available (" updatedVer ")").SetFont("s15")
    mg.AddPic("x10 y10 w26 h26 icon176", "imageres.dll")
    mg.AddText("x10 y55 w380 h200 c" TextColor, "A newer version of XTernal is available on GitHub.`n`nThe updater installs the exact files published for the matching version tag, then restarts the macro once the update is staged successfully.").SetFont("s10")

    LearnMore := mg.AddText("x90 y122 w90 h20 c" Accent, "Learn More")
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
        h: 30,
        bg: Accent,
        textColor: TextColor
    })

    LaterBtn := button(mg, "Later", 120, 240, {
        w: 100,
        h: 30,
        bg: BgColor,
        textColor: TextColor
    })

    DownloadBtn.OnEvent("Click", DownloadClicked)
    LaterBtn.OnEvent("Click", CloseDialog)
    mg.OnEvent("Close", CloseDialog)
    mg.OnEvent("Escape", CloseDialog)

    mg.Show(dialogShowOpts)
    WinWaitClose(mg.Hwnd)
    return handoffStarted

    DownloadClicked(*) {
        if isDownloading
            return

        isDownloading := true
        mg.Hide()
        SetTimer(StartDownloadAfterHide, -10)
    }

    StartDownloadAfterHide() {
        if BeginUpdateInstall(updatedVer, true) {
            handoffStarted := true
            mg.Destroy()
            return
        }

        isDownloading := false
        mg.Show(dialogShowOpts)
    }

    CloseDialog(*) {
        handoffStarted := false
        mg.Destroy()
    }
}
