#Requires AutoHotkey v2.0

#SingleInstance Force
#Include ..\Components\Border.ahk
#Include ..\Components\Button.ahk

GetAddMutationDialog()
{
    global APPEARANCE

    result := ""
    Accent := APPEARANCE["accent_color"]
    BgColor := APPEARANCE["bg_color"]
    TextColor := APPEARANCE["text_color"]
    BorderColor := APPEARANCE["border_color"]

    g := Gui("AlwaysOnTop +Border")
    g.BackColor := "0x" BgColor
    g.SetFont(, "Segoe UI")

    g.AddText("x40 y10 w400 h50 c" TextColor, "Add Mutation to DDL").SetFont("s15")
    g.AddPicture("x10 y12 w23 h23 Icon77", "imageres.dll")
    Border(g, 10, 45, 380, 1, BorderColor)

    g.AddText("x10 y63 w125 h20 c" TextColor, "Mutation Name").SetFont("s12")

    Mutation := g.AddEdit("x190 y60 w200 h30 Limit24 -VScroll vMutation")
    Mutation.SetFont("s11")

    addBtn := button(g, "Add", 190, 110, {
        h: 30,
        w: 95,
        bg: Accent,
        textColor: TextColor
    })

    cancelBtn := button(g, "Cancel", 295, 110, {
        h: 30,
        w: 95,
        bg: BgColor,
        textColor: TextColor
    })

    addBtn.OnEvent("Click", AddClicked)
    cancelBtn.OnEvent("Click", CancelClicked)
    g.OnEvent("Close", CancelClicked)
    g.OnEvent("Escape", CancelClicked)

    g.Show("h150 w400")
    Mutation.Focus()

    WinWaitClose(g.Hwnd)
    return result

    AddClicked(*)
    {
        form := g.Submit()
        result := form.Mutation
        g.Destroy()
    }

    CancelClicked(*)
    {
        result := ""
        g.Destroy()
    }
}
