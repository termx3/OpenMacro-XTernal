#Requires AutoHotkey v2.0
#Include ..\Components\Border.ahk
#Include ..\Components\Button.ahk
#Include ..\Components\InfoPopup.ahk

GetUpdDialog(currentVer, UpdatedVer) {
    mg := Gui("AlwaysOnTop +Border")
    mg.BackColor := 0x171717

    mg.AddText("x0 y280 w400 h1 +Background0x646464","")
    Border(mg, 10, 40, 380, 1, 646464)
    mg.AddText("x5 y282 w200 h20 c646464", "Client Version: " currentVer).SetFont("s10 italic")
    mg.AddText("x345 y282 w50 h20 c646464", "XTernal").SetFont("s10 italic")

    mg.AddText("x40 y10 w300 h30 cWhite", "Update Available (" UpdatedVer ")").SetFont("s15")
    mg.AddPic("x10 y10 w26 h26 icon176", "imageres.dll")
    mg.AddText("x10 y55 w380 h200 cWhite", "Updated versions ensure compatibility and avoid detection entirely.`n`nWe strongly discourage using outdated software. We are not liable for platform actions on your account caused by outdated software.`n`nRoblox frequently changes how data is stored in memory with each update. The macro cannot read this data correctly without an update.").SetFont("s10")

    LearnMore := mg.AddText("x80 y200 w90 h20 c646464", "Learn More")
    LearnMore.SetFont("s10 italic underline")
    LearnMore.OnEvent("Click", (*) => 
        InfoPopup.Show("Why Outdated Versions Are Dangerous", 
            "Roblox stores game data (player position, camera, health, etc.) at specific memory locations. These locations change with every Roblox update.`n`n"
            "When XTernal uses outdated information:`n"
            "• The macro reads incorrect memory, also called garbage`n"
            "• Data becomes corrupted or nonsensical`n"
            "• Unusual patterns can trigger Roblox' anti cheat detection`n`n"
            "Updated versions include fresh memory locations that match the current Roblox build, ensuring the macro reads correct data and operates safely."
        )
    )

    button(mg, "Download", 10, 240, {
        W: 100,
        h: 30,
    })
    button(mg, "Later", 120, 240, {
        w: 100,
        h: 30,
        bg: 171717
    }).OnEvent("Click", (*) => ExitApp())

    mg.Show("w400 h300")
}