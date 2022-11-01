std = "lua51"
max_line_length = false
exclude_files = {
    ".luacheckrc",
    "Libs/",
}
ignore = {
    "11./SLASH_.*", -- slash handler
    "212", -- unused argument
}
globals = {
    --Addon Specific
    "LifebloomGlowDB",

    -- Lua
    "_G",
    "CopyTable",
    "GetTime",

    -- WoW
    "CreateFrame",
    "C_UnitAuras",
    "DevTools_Dump",
    "SlashCmdList",
    "InterfaceOptionsFrame_OpenToCategory",
    "InterfaceOptionsFramePanelContainer",
    "UnitClass",
    "hooksecurefunc",
    "TargetFrame",
    "FocusFrame",
    "ColorPickerFrame",
}
