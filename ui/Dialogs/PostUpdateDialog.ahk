#Requires AutoHotkey v2.0

#Include ..\Components\Border.ahk
#Include ..\Components\Button.ahk

GetPostUpdateDialog(updatedVersion := "") {
    global APPEARANCE

    Accent := APPEARANCE["accent_color"]
    BgColor := APPEARANCE["bg_color"]
    TextColor := APPEARANCE["text_color"]
    BorderColor := APPEARANCE["border_color"]

    g := Gui("AlwaysOnTop +Border")
    g.BackColor := "0x" BgColor
    g.Title := "Update Complete"
    g.SetFont(, "Segoe UI")

    heading := (updatedVersion != "") ? "Successfully Updated to " updatedVersion : "Successfully Updated"

    g.AddText("x40 y10 w340 h40 c" TextColor, heading).SetFont("s15")
    g.AddPicture("x10 y12 w23 h23 Icon234", "imageres.dll")
    Border(g, 10, 45, 380, 1, BorderColor)

    g.AddText("x10 y60 w380 h20 c" TextColor, "XTernal has been updated and is ready to use.").SetFont("s10")
    g.AddText("x10 y80 w380 h40 c" TextColor, "The macro restarted successfully after installing the new version.").SetFont("s10")

    CloseBtn := button(g, "Close", 10, 135, {
        w: 100,
        h: 30,
        bg: Accent,
        textColor: TextColor
    })

    CloseBtn.OnEvent("Click", CloseDialog)
    g.OnEvent("Close", CloseDialog)
    g.OnEvent("Escape", CloseDialog)

    g.Show("h180 w400")
    WinWaitClose("ahk_id " g.Hwnd)

    CloseDialog(*) {
        g.Destroy()
    }
}
