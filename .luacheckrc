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

    -- WoW
    "CreateFrame",
    "C_UnitAuras",
    "C_Timer",
    "CopyTable",
    "GetTime",
    "DevTools_Dump",
    "SlashCmdList",
    "InterfaceOptionsFrame_OpenToCategory",
    "InterfaceOptionsFramePanelContainer",
    "InterfaceOptions_AddCategory",
    "UnitClass",
    "hooksecurefunc",
    "TargetFrame",
    "FocusFrame",
    "ColorPickerFrame",
    "GameTooltip",
    "ShowUIPanel",
    "UnitGUID",
    "UnitIsFriend",
    "CombatLogGetCurrentEventInfo",
}
