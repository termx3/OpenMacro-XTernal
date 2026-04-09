#Requires AutoHotkey v2.0

#Include ..\Components\Border.ahk
#Include ..\Components\Button.ahk

GetPostUpdateDialog(updatedVersion := "") {
    g := Gui("AlwaysOnTop +Border")
    g.BackColor := 0x171717
    g.Title := "Update Complete"

    BgColor := APPEARANCE["bg_color"]

    heading := (updatedVersion != "") ? "Successfully Updated to " updatedVersion : "Successfully Updated"

    g.AddText("x40 y10 w340 h40 cWhite", heading).SetFont("s15")
    g.AddPicture("x10 y12 w23 h23 Icon234", "imageres.dll")
    Border(g, 10, 45, 380, 1, 646464)

    g.AddText("x10 y60 w380 h20 cWhite", "XTernal has been updated and is ready to use.").SetFont("s10")
    g.AddText("x10 y80 w380 h40 cWhite", "The macro restarted successfully after installing the new version.").SetFont("s10")

    CloseBtn := button(g, "Close", 10, 135, {
        w: 100,
        h: 30,
        bg: BgColor
    })

    CloseBtn.OnEvent("Click", CloseDialog)
    g.OnEvent("Close", CloseDialog)
    g.OnEvent("Escape", CloseDialog)

    g.Show("h180 w400")

    CloseDialog(*) {
        g.Destroy()
    }
}