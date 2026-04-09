#Requires AutoHotkey v2.0
#Include Button.ahk

class InfoPopup {
    static isOpen := false

    static Show(title, message) {
        global APPEARANCE

        if (this.isOpen)
            return

        this.isOpen := true

        Accent     := APPEARANCE["accent_color"]
        BgColor    := APPEARANCE["bg_color"]
        TextColor  := APPEARANCE["text_color"]

        dlg := Gui("AlwaysOnTop +Border")
        dlg.Title := title
        dlg.BackColor := "0x" BgColor

        info := dlg.AddText("x10 y10 w380 h400 c" TextColor, message)
        info.SetFont("s10")

        understood := button(dlg, "Close", 290, 185, {
            w: 100,
            h: 30,
            fontSize: 12
        })
        understood.OnEvent("Click", (*) => this.Close(dlg))

        dlg.OnEvent("Close", (GuiObj) => this.Close(dlg))

        dlg.Show("w400 h230")
    }

    static Close(dlg) {
        dlg.Destroy()
        this.isOpen := false
    }
}
