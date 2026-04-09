#Requires AutoHotkey v2.0

#Include ..\Components\Border.ahk
#Include ..\Components\Button.ahk

GetPostUpdateDialog() {
    g := Gui("AlwaysOnTop +Border")
    g.BackColor := 0x171717

    g.AddText("x40 y10 w400 h40 cWhite", "Successfully Installed").SetFont("s15")
    pic := g.AddPicture("x10 y12 w23 h23 Icon234", "imageres.dll")
    Border(g, 10, 45, 380, 1, 646464)

    g.AddText("x10 y60 w400 h20 cWhite", "XTernal has been updated and is ready to use.").SetFont("s10")
    g.AddText("x10 y80 w400 h20 cWhite", "Check the Changelog tab for details on what's new.").SetFont("s10")

    button(g, "Close", 10, 260, {w: 100, h: 30 }).OnEvent("Click", (*) => ExitApp())

    g.Show("h300 w400")
}

GetPostUpdateDialog()