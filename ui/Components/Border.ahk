#Requires AutoHotkey v2.0

class Border {
    static DefaultColor := "0xFFFFFF"

    __New(gui, x, y, w, h, color := "") {
        color := (color != "") ? color : Border.DefaultColor

        this.ctrl := gui.Add("Text",
            "x" x " y" y
            " w" w " h" h
            " +Background" color, "")
    }
}