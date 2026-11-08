std = "lua51"
max_line_length = false
self = false
exclude_files = { "tests/", "tools/" }

globals = {
    "EzTonguesAPI",
    "EzTonguesDB",
    "EzTonguesCharDB",
    "EzTongues_ToggleBox",
    "SLASH_EZTONGUES1",
    "SLASH_EZTONGUES2",
    "SLASH_EZTONGUES3",
    "SlashCmdList",
    "BINDING_HEADER_EZTONGUES",
    "BINDING_NAME_EZTONGUES_BOX",
}

read_globals = {
    -- Frames & UI
    "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME", "ChatFontNormal", "GameTooltip",
    -- Settings panel
    "Settings", "CreateSettingsListSectionHeaderInitializer", "CreateSettingsButtonInitializer",
    -- Chat filters (ChatFrameUtil on newer clients)
    "ChatFrameUtil", "ChatFrame_AddMessageEventFilter",
    -- Namespaced APIs
    "C_ChatInfo", "issecretvalue",
    -- Global APIs
    "GetBuildInfo", "UnitRace", "UnitClass", "UnitFactionGroup", "UnitName", "UnitExists", "UnitIsPlayer",
    "SendChatMessage", "InCombatLockdown", "IsInGroup", "IsInRaid", "IsInGuild", "GetNumGroupMembers", "ChatTypeInfo",
    -- Lua helpers WoW adds
    "tContains", "wipe",
}
