#Requires AutoHotkey v2.0

class button {
    static DefaultW           := 150
    static DefaultH           := 145
    static DefaultBg          := "0x303030"
    static DefaultBorderColor := "0x303030"
    static DefaultBorderSize  := 2
    static DefaultTextColor   := "0xFFFFFF"
    static DefaultFontSize    := 11
    static DefaultFont        := "Segoe UI"
    static DefaultBorder      := true

    __New(gui, text, x, y, options := {}) {
        w         := options.HasProp("w")         ? options.w         : button.DefaultW
        h         := options.HasProp("h")         ? options.h         : button.DefaultH
        bg        := options.HasProp("bg")        ? options.bg        : button.DefaultBg
        textColor := options.HasProp("textColor") ? options.textColor : button.DefaultTextColor
        fontSize  := options.HasProp("fontSize")  ? options.fontSize  : button.DefaultFontSize
        font      := options.HasProp("font")      ? options.font      : button.DefaultFont
        border    := options.HasProp("border")    ? options.border    : button.DefaultBorder

        borderFlag := border ? " +Border" : " -Border"

        gui.SetFont("s" fontSize " c" textColor, font)
        this.ctrl := gui.Add("Text",
            "x" x " y" y
            " w" w " h" h
            " +Background" bg
            borderFlag
            " +0x200 Center",
            text)
        gui.SetFont()
    }

    OnEvent(eventName, callback) {
        this.ctrl.OnEvent(eventName, callback)
    }
}