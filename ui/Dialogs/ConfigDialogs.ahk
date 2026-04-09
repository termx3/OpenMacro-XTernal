#Requires AutoHotkey v2.0

#Include ..\Components\Border.ahk
#Include ..\Components\Button.ahk

ShowConfigSavedDialog(configName) {
    global APPEARANCE

    Accent    := APPEARANCE["accent_color"]
    BgColor   := APPEARANCE["bg_color"]
    TextColor := APPEARANCE["text_color"]

    dlg := Gui("AlwaysOnTop +Border")
    dlg.Title := "Config Saved"
    dlg.BackColor := "0x" BgColor
    dlg.SetFont(, "Segoe UI")

    dlg.AddText("x40 y12 w300 h25 c" TextColor, "Config Saved").SetFont("s14 bold")
    dlg.AddPicture("x12 y14 w22 h22 Icon78", "imageres.dll")
    Border(dlg, 10, 42, 330, 1)

    dlg.AddText("x12 y55 w328 h30 c" TextColor, "Config '" configName "' has been saved successfully.").SetFont("s10")

    okBtn := button(dlg, "OK", 250, 100, {
        w: 90,
        h: 28,
        fontSize: 11
    })
    okBtn.OnEvent("Click", (*) => dlg.Destroy())

    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())

    dlg.Show("w350 h140")
}

ShowConfigNameInput() {
    global APPEARANCE

    Accent    := APPEARANCE["accent_color"]
    BgColor   := APPEARANCE["bg_color"]
    TextColor := APPEARANCE["text_color"]

    result := ""

    dlg := Gui("AlwaysOnTop +Border")
    dlg.Title := "New Config"
    dlg.BackColor := "0x" BgColor
    dlg.SetFont(, "Segoe UI")

    dlg.AddText("x40 y12 w300 h25 c" TextColor, "New Config").SetFont("s14 bold")
    dlg.AddPicture("x12 y14 w22 h22 Icon77", "imageres.dll")
    Border(dlg, 10, 42, 380, 1)

    dlg.AddText("x12 y58 w150 h20 c" TextColor, "Config Name").SetFont("s11")
    nameInput := dlg.AddEdit("x170 y55 w220 h26 Limit32 -VScroll vConfigName")
    nameInput.SetFont("s11")

    saveBtn := button(dlg, "Save", 190, 100, {
        h: 28,
        w: 95,
        fontSize: 11
    })

    cancelBtn := button(dlg, "Cancel", 295, 100, {
        h: 28,
        w: 95,
        bg: BgColor,
        fontSize: 11
    })

    saveBtn.OnEvent("Click", SaveClicked)
    cancelBtn.OnEvent("Click", CancelClicked)
    dlg.OnEvent("Close", CancelClicked)
    dlg.OnEvent("Escape", CancelClicked)

    dlg.Show("h140 w400")
    nameInput.Focus()

    WinWaitClose(dlg.Hwnd)
    return result

    SaveClicked(*) {
        form := dlg.Submit()
        result := form.ConfigName
        dlg.Destroy()
    }

    CancelClicked(*) {
        result := ""
        dlg.Destroy()
    }
}

ShowConfigAlert(title, message) {
    global APPEARANCE

    Accent    := APPEARANCE["accent_color"]
    BgColor   := APPEARANCE["bg_color"]
    TextColor := APPEARANCE["text_color"]

    dlg := Gui("AlwaysOnTop +Border")
    dlg.Title := title
    dlg.BackColor := "0x" BgColor
    dlg.SetFont(, "Segoe UI")

    dlg.AddText("x40 y12 w300 h25 c" TextColor, title).SetFont("s14 bold")
    dlg.AddPicture("x12 y14 w22 h22 Icon84", "imageres.dll")
    Border(dlg, 10, 42, 330, 1)

    dlg.AddText("x12 y55 w328 h30 c" TextColor, message).SetFont("s10")

    okBtn := button(dlg, "OK", 250, 100, {
        w: 90,
        h: 28,
        fontSize: 11
    })
    okBtn.OnEvent("Click", (*) => dlg.Destroy())

    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())

    dlg.Show("w350 h140")
}

ShowConfigConfirmDialog(configName) {
    global APPEARANCE

    Accent    := APPEARANCE["accent_color"]
    BgColor   := APPEARANCE["bg_color"]
    TextColor := APPEARANCE["text_color"]

    confirmed := false

    dlg := Gui("AlwaysOnTop +Border")
    dlg.Title := "Confirm Delete"
    dlg.BackColor := "0x" BgColor
    dlg.SetFont(, "Segoe UI")

    dlg.AddText("x40 y12 w310 h25 c" TextColor, "Delete Config").SetFont("s14 bold")
    dlg.AddPicture("x12 y14 w22 h22 Icon84", "imageres.dll")
    Border(dlg, 10, 42, 340, 1)

    dlg.AddText("x12 y55 w338 h30 c" TextColor, "Are you sure you want to delete '" configName "'?").SetFont("s10")

    deleteBtn := button(dlg, "Delete", 165, 100, {
        h: 28,
        w: 90,
        bg: "CC3333",
        fontSize: 11
    })

    cancelBtn := button(dlg, "Cancel", 265, 100, {
        h: 28,
        w: 90,
        bg: BgColor,
        fontSize: 11
    })

    deleteBtn.OnEvent("Click", ConfirmClicked)
    cancelBtn.OnEvent("Click", CancelClicked)
    dlg.OnEvent("Close", CancelClicked)
    dlg.OnEvent("Escape", CancelClicked)

    dlg.Show("w360 h140")

    WinWaitClose(dlg.Hwnd)
    return confirmed

    ConfirmClicked(*) {
        confirmed := true
        dlg.Destroy()
    }

    CancelClicked(*) {
        confirmed := false
        dlg.Destroy()
    }
}
