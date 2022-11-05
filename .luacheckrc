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
read_globals = {
    -- WoW
    "LARGE_NUMBER_SEPERATOR",
}
globals = {
    -- BuffOverlay
    "LifebloomGlowDB",

    -- Other Addons
    "GetAddOnMetadata",

    -- Lua
    "_G",

    -- WoW
    "CreateFrame",
    "C_UnitAuras",
    "C_Timer",
    "C_Traits",
    "C_ClassTalents",
    "Spell",
    "CopyTable",
    "GetTime",
    "GetMasteryEffect",
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
    "WorldFrame",
    "wipe",
    "AuraUtil",
}
