#Requires AutoHotkey v2.0
#Include Button.ahk
#Include Border.ahk

class InfoPopup {
    static isOpen := false

    static Show(title, message) {
        global APPEARANCE

        if (this.isOpen)
            return

        this.isOpen := true

        Accent      := APPEARANCE["accent_color"]
        BgColor     := APPEARANCE["bg_color"]
        TextColor   := APPEARANCE["text_color"]
        BorderColor := APPEARANCE["border_color"]

        dlg := Gui("AlwaysOnTop +Border")
        dlg.Title := title
        dlg.BackColor := "0x" BgColor

        dlg.AddText("x10 y10 w380 h24 c" TextColor, title).SetFont("s11")
        Border(dlg, 10, 38, 380, 1, BorderColor)

        info := dlg.AddText("x10 y50 w380 h120 c" TextColor, message)
        info.SetFont("s10")

        understood := button(dlg, "Close", 290, 185, {
            w: 100,
            h: 30,
            fontSize: 12,
            bg: Accent
        })
        understood.OnEvent("Click", (*) => this.Close(dlg))

        dlg.OnEvent("Close", (*) => this.Close(dlg))
        dlg.OnEvent("Escape", (*) => this.Close(dlg))

        dlg.Show("w400 h230")
    }

    static Close(dlg) {
        dlg.Destroy()
        this.isOpen := false
    }
}