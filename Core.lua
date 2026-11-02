-- EzTongues: speak a racial language. Your line goes out as that tongue (/tongue thalassian Well met!); anyone with
-- EzTongues whose character knows it sees the translation after it. No addon messages: the line itself carries
-- its meaning (Codec.lua), and knowing a language is the honor system.
local _, ns = ...

BINDING_HEADER_EZTONGUES = "EzTongues"
BINDING_NAME_EZTONGUES_BOX = "Open the tongue box"

local MAX = 255  -- chat message limit, in bytes

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb48ee0EzTongues|r: " .. msg)
end

local function Trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function issecret(v)
    return issecretvalue and issecretvalue(v)
end

---------------------------------------------------------------------------
-- Languages (EzTonguesCharDB: known[key], default)
---------------------------------------------------------------------------
local byKey = {}
for _, t in ipairs(ns.TONGUES) do byKey[t.key] = t end

-- A key or alias as typed (lowercase only, so a line starting "Orc" is said, not taken as a language).
local function Resolve(word)
    word = word or ""
    if byKey[word] then return word end
    return ns.ALIASES[word]
end

local function Label(key)
    return byKey[key] and byKey[key].label or key
end

local function Knows(key)
    return EzTonguesCharDB and EzTonguesCharDB.known[key] == true
end

local function Default()
    local key = EzTonguesCharDB and EzTonguesCharDB.default
    return byKey[key] and key or ns.TONGUES[1].key
end

-- What a new character knows: race, faction (Horde: Orcish) and class (warlocks: Demonic).
local function StartingTongues()
    local list = {}
    local function add(key)
        if key and not tContains(list, key) then list[#list + 1] = key end
    end
    for _, key in ipairs(ns.RACE_TONGUES[select(2, UnitRace("player"))] or {}) do add(key) end
    add(ns.FACTION_TONGUE[UnitFactionGroup("player")])
    add(ns.CLASS_TONGUE[select(2, UnitClass("player"))])
    return list
end

local function TongueKeys()
    local keys = {}
    for _, t in ipairs(ns.TONGUES) do keys[#keys + 1] = t.key end
    return table.concat(keys, ", ")
end

---------------------------------------------------------------------------
-- Chat. Only ever called from a slash command or a key press in the box, which give the send its hardware event;
-- never from a timer or an event (Forever blocks those).
---------------------------------------------------------------------------
local function Send(msg, chatType, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, chatType, nil, target)
    else
        SendChatMessage(msg, chatType, nil, target)
    end
end

-- Encounters and similar lock addon chat (C_ChatInfo.InChatMessagingLockdown). A real game block:
-- SendChatMessage then raises ADDON_ACTION_BLOCKED.
local function ChatLocked()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

-- A whisper's name and the text after it. Forever names have surnames and whispers need "First Surname": when
-- the name is your target's first name, the full name comes from the target (and a typed surname is skipped).
-- "First Surname" in quotes works too, and so does %t for your target.
local function TargetFullName()
    if not (UnitExists("target") and UnitIsPlayer("target")) then return end
    local first, surname = UnitName("target")
    if not first or issecret(first) then return end
    if surname and not issecret(surname) and surname ~= "" then
        return first .. (ns.ERA and "-" or " ") .. surname, first, surname
    end
    return first, first
end

local function WhisperTarget(rest)
    local quoted, text = rest:match('^"([^"]+)"%s+(.+)$')
    if quoted then return quoted, text end
    local name
    name, text = rest:match("^(%S+)%s+(.+)$")
    if not name then return end
    local full, first, surname = TargetFullName()
    if name == "%t" then return full, text end
    if full and first:lower() == name:lower() then
        local typed, after = text:match("^(%S+)%s+(.+)$")
        if surname and typed and typed:lower() == surname:lower() then text = after end
        return full, text
    end
    return name, text
end

-- %t in the line itself: the game would put your target's name in plain (and the line would stop decoding), so
-- it goes in first and gets ciphered with the rest.
local function ExpandTarget(text)
    if not text:find("%%t") or not UnitExists("target") then return text end
    local name = UnitName("target")
    if not name or issecret(name) then return text end
    return (text:gsub("%%t", function() return name end))
end

local function Say(key, text, chatType, target)
    text = Trim(text)
    if text == "" then return Print("Nothing to say.") end
    if not Knows(key) then
        return Print(("You don't speak %s. If your character does: /tongue learn %s"):format(Label(key), key))
    end
    if chatType == "WHISPER" and not target then return Print("Whisper whom? /tongue <lang> w <name> <text>") end
    if ChatLocked() then return Print("The game blocks addon chat right now.") end
    text = ExpandTarget(text)
    local said
    if chatType == "EMOTE" and text:find('"[^"]+"') then
        -- /e smiles. "Well met!": only the quoted speech is in the tongue.
        said = text:gsub('"([^"]+)"', function(q) return '"' .. ns.Encode(key, q, true) .. '"' end)
    else
        said = ns.Encode(key, text, true)
    end
    for _, msg in ipairs(ns.Split(said, MAX)) do
        Send(msg, chatType, target)
    end
end

-- rest of a /tongue <lang> <letter> line
local function SayTo(key, chatType, rest)
    if chatType == "WHISPER" then
        local target, text = WhisperTarget(Trim(rest))
        if not target then return Print("Whisper whom? /tongue <lang> w <name> <text> (or %t for your target)") end
        return Say(key, text, chatType, target)
    end
    Say(key, rest, chatType)
end

-- "y Hello" -> yell; anything else is said.
local function Speak(key, rest)
    local letter, text = rest:match("^(%S+)%s+(.+)$")
    local chatType = letter and ns.SHORT_CHANNELS[letter]
    if chatType then return SayTo(key, chatType, text) end
    Say(key, rest, "SAY")
end

---------------------------------------------------------------------------
-- Hearing: a chat filter adds the translation (or just the language's name) to lines in a tongue.
---------------------------------------------------------------------------
local cache, cached = {}, 0

-- { { key, english }, ... } for a line, or false. Emotes: only "quoted" speech, unless there are no quotes.
local function Understand(msg, emote)
    local parts = {}
    if emote and msg:find('"[^"]+"') then
        for q in msg:gmatch('"([^"]+)"') do
            local key, english = ns.Detect(q)
            if key then parts[#parts + 1] = { key, '"' .. english .. '"' } end
        end
    else
        local key, english = ns.Detect(msg)
        if key then parts[1] = { key, english } end
    end
    return #parts > 0 and parts
end

-- The filter runs once per chat frame showing the line, so results are kept for a while.
local function Heard(msg, emote)
    local id = (emote and "e" or "s") .. msg
    local parts = cache[id]
    if parts == nil then
        local ok, result = pcall(Understand, msg, emote)
        parts = ok and result or false
        if cached >= 200 then cache, cached = {}, 0 end
        cache[id] = parts
        cached = cached + 1
    end
    return parts
end
ns.Understand = Understand

local function IsMe(author)
    if type(author) ~= "string" or issecret(author) then return false end
    local me = UnitName("player")
    return me and not issecret(me) and author:match("^[^%s%-]+") == me
end

local function ColorCode()
    for _, c in ipairs(ns.COLORS) do
        if c.key == EzTonguesDB.color then return "|cff" .. c.hex end
    end
    return "|cff" .. ns.COLORS[1].hex
end

local function Filter(_, event, msg, author, ...)
    if not EzTonguesDB or type(msg) ~= "string" or issecret(msg) then return false end
    local parts = Heard(msg, event == "CHAT_MSG_EMOTE")
    if not parts then return false end
    local mine = event == "CHAT_MSG_WHISPER_INFORM" or IsMe(author)
    local shown, named = {}, {}
    for _, p in ipairs(parts) do
        if mine or Knows(p[1]) then
            shown[#shown + 1] = p[2]
        elseif EzTonguesDB.showName and not named[p[1]] then
            named[p[1]] = true
            shown[#shown + 1] = Label(p[1])
        end
    end
    if #shown == 0 then return false end
    local color = ColorCode()
    -- A link in the translation ends the color with |r: start it again after each one.
    local added = (table.concat(shown, " "):gsub("|r", "|r" .. color))
    return false, msg .. " " .. color .. "(" .. added .. ")|r", author, ...
end

local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
for _, event in ipairs(ns.CHAT_EVENTS) do
    AddFilter(event, Filter)
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------
local function Test(arg)
    arg = Trim(arg)
    local first, rest = arg:match("^(%S+)%s+(.+)$")
    local key = Resolve(first)
    local text = key and rest or arg
    key = key or Default()
    if text == "" then return Print("/tongue test [lang] <text> shows your line in a tongue and back, sends nothing.") end
    local said = ns.Encode(key, text)
    local back = ns.Decode(key, said)
    Print(Label(key) .. ":")
    DEFAULT_CHAT_FRAME:AddMessage("  " .. said)
    DEFAULT_CHAT_FRAME:AddMessage("  |cffa0a0a0" .. (back or "(doesn't decode!)") ..
        (back == text and "" or "  |cffff6060(differs from what you typed)") .. "|r")
end
ns.Test = Test

local function List()
    Print("Languages (" .. "|cff40ff40known|r, the rest you'd only recognize):")
    for _, t in ipairs(ns.TONGUES) do
        local mark = Knows(t.key) and "|cff40ff40" or "|cff909090"
        DEFAULT_CHAT_FRAME:AddMessage(("  %s%s|r (%s)%s"):format(mark, t.label, t.key,
            t.key == Default() and "  - default" or ""))
    end
    DEFAULT_CHAT_FRAME:AddMessage("  /tongue learn <lang>, /tongue forget <lang>, /tongue default <lang>")
end

local function SetKnown(arg, on)
    arg = Trim(arg):lower()
    local keys = {}
    if arg == "all" then
        for _, t in ipairs(ns.TONGUES) do keys[#keys + 1] = t.key end
    elseif Resolve(arg) then
        keys[1] = Resolve(arg)
    else
        return Print(("/tongue %s <lang|all>, lang being one of: %s"):format(on and "learn" or "forget", TongueKeys()))
    end
    local names = {}
    for _, key in ipairs(keys) do
        EzTonguesCharDB.known[key] = on
        names[#names + 1] = Label(key)
    end
    Print((on and "You know %s now." or "You've forgotten %s."):format(table.concat(names, ", ")))
end

local function SetDefault(arg)
    arg = Trim(arg):lower()
    if arg == "" then return Print("Default language: " .. Label(Default()) .. ". /tongue default <lang> changes it.") end
    local key = Resolve(arg)
    if not key then return Print(("Unknown language \"%s\". Choose from: %s."):format(arg, TongueKeys())) end
    EzTonguesCharDB.default = key
    Print("Default language: " .. Label(key) .. (Knows(key) and "." or " (you don't know it yet: /tongue learn " .. key .. ")."))
end
ns.SetDefault = SetDefault

---------------------------------------------------------------------------
-- The box: an edit box of its own, as in EzAccent. Enter says the line in the box's language (in /say, or the
-- channel of a leading /y, /p, /w name ...), Escape closes it, Up/Down go through this session's lines, the button
-- on the left picks the language (it's also your default). A click outside lets go of the keyboard and leaves it open.
---------------------------------------------------------------------------
local box, edit, langButton
local history, historyAt = {}, 0

local function PlaceBox(f)
    local p = EzTonguesDB.box
    f:ClearAllPoints()
    if p then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
    end
end

local function SaveBoxPoint(f)
    local point, _, relPoint, x, y = f:GetPoint()
    EzTonguesDB.box = { point, relPoint, x, y }
end

local function BoxLine(text)
    text = Trim(text)
    local key = Default()
    local cmd, rest = text:match("^/(%S+)%s*(.*)$")
    local chatType = cmd and ns.BOX_CHANNELS[cmd:lower()]
    if chatType then return SayTo(key, chatType, rest) end
    Say(key, text, "SAY")
end

local function ShowLanguage()
    if not box then return end
    langButton:SetText(Label(Default()))
    box.title:SetText("EzTongues" .. (Knows(Default()) and "" or "  |cffff6060(you don't know it)|r"))
end

local function CycleLanguage(step)
    local at = 1
    for i, t in ipairs(ns.TONGUES) do
        if t.key == Default() then at = i end
    end
    EzTonguesCharDB.default = ns.TONGUES[(at - 1 + step) % #ns.TONGUES + 1].key
    ShowLanguage()
end

local function MakeBox()
    local f = CreateFrame("Frame", "EzTonguesBox", UIParent, "BackdropTemplate")
    f:SetSize(500, 56)
    PlaceBox(f)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveBoxPoint(self)
    end)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", 10, -8)
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPRIGHT", -24, -8)

    -- Own OnClick: the template's HideUIPanel is blocked in combat.
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", 1, 1)
    close:SetScript("OnClick", function() f:Hide() end)

    -- The language: left-click for the next one, right-click for the one before.
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    langButton = b
    b:SetSize(96, 22)
    b:SetPoint("BOTTOMLEFT", 8, 6)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button) CycleLanguage(button == "RightButton" and -1 or 1) end)

    local e = CreateFrame("EditBox", nil, f)
    edit = e
    e:SetFontObject(ChatFontNormal)
    e:SetPoint("TOPLEFT", b, "TOPRIGHT", 8, 0)
    e:SetPoint("BOTTOMRIGHT", -10, 6)
    e:SetAutoFocus(false)
    e:SetMaxLetters(MAX)
    e:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        self:SetText("")
        f:Hide()
        if Trim(text) ~= "" then
            if history[#history] ~= text then history[#history + 1] = text end
            if #history > 20 then table.remove(history, 1) end
            BoxLine(text)
        end
    end)
    e:SetScript("OnEscapePressed", function() f:Hide() end)
    e:SetScript("OnArrowPressed", function(self, key)
        if #history == 0 or (key ~= "UP" and key ~= "DOWN") then return end
        historyAt = math.max(1, math.min(#history + 1, historyAt + (key == "UP" and -1 or 1)))
        self:SetText(history[historyAt] or "")
        self:SetCursorPosition(#self:GetText())
    end)
    e:SetScript("OnEditFocusGained", function()
        hint:SetText("Enter: say  /y /p /g /r /e /w name  Esc: close")
    end)
    e:SetScript("OnEditFocusLost", function()
        hint:SetText("Click here to type")
    end)
    f:SetScript("OnMouseDown", function() e:SetFocus() end)

    f:SetScript("OnShow", function()
        ShowLanguage()
        historyAt = #history + 1
        e:SetFocus()
    end)
    f:SetScript("OnHide", function() e:ClearFocus() end)

    -- Any click outside the box (the world, another window) gives the keyboard back to the game.
    f:RegisterEvent("GLOBAL_MOUSE_DOWN")
    f:SetScript("OnEvent", function(self)
        if self:IsShown() and e:HasFocus() and not self:IsMouseOver() then e:ClearFocus() end
    end)
    return f
end

local function OpenBox()
    box = box or MakeBox()
    box:Show()
end
ns.OpenBox = OpenBox

function ns.ResetBox()
    EzTonguesDB.box = nil
    if box then PlaceBox(box) end
    Print("Box moved back to its first spot.")
end

-- Bindings.xml (runOnUp): opens on key release, so the key's own letter never lands in the box. While the box is
-- open but let go of, the key takes the keyboard back instead of closing it.
function EzTongues_ToggleBox(keystate)
    if keystate ~= "up" then return end
    if box and box:IsShown() then
        if edit:HasFocus() then box:Hide() else edit:SetFocus() end
    else
        OpenBox()
    end
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function OpenSettings()
    if InCombatLockdown() then return Print("Options can't open in combat.") end
    if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
end

local HELP = {
    "/tongue <lang> <text> - say <text> in a language (/lang works too)",
    "/tongue <lang> y|p|g|o|r|e <text> - yell, party, guild, officer, raid or emote it (emotes: only the \"quotes\")",
    "/tongue <lang> w <name> <text> - whisper it (your target's first name, \"First Surname\", or %t)",
    "/tongue <text> - your default language; /tongue default <lang> sets it",
    "/tongue test [lang] <text> - show it in the language and back, sends nothing",
    "/tongue list - every language, and which you know",
    "/tongue learn|forget <lang|all> - honor system: learn what your character speaks",
    "/tongue box - the edit box (also a key binding: Options > Keybindings > EzTongues)",
    "/tongue config - the options page (Options > AddOns > EzTongues)",
}

local function Help()
    Print("Default language: " .. Label(Default()))
    for _, line in ipairs(HELP) do DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
end

-- Command words are lowercase only, so a sentence starting "Test" or "List" is said.
local COMMANDS = {
    help = Help,
    list = List,
    learn = function(arg) SetKnown(arg, true) end,
    forget = function(arg) SetKnown(arg, false) end,
    default = SetDefault,
    test = Test,
    box = OpenBox,
    config = OpenSettings,
}

SLASH_EZTONGUES1 = "/tongue"
SLASH_EZTONGUES2 = "/lang"
SLASH_EZTONGUES3 = "/eztongues"
SlashCmdList.EZTONGUES = function(msg)
    msg = Trim(msg)
    if msg == "" then return Help() end
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    if COMMANDS[cmd] then return COMMANDS[cmd](rest) end
    local key = Resolve(cmd)
    if key then
        if rest == "" then return Print("Say what? /tongue " .. key .. " <text>") end
        return Speak(key, rest)
    end
    Speak(Default(), msg)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    EzTonguesDB = EzTonguesDB or {}
    for k, v in pairs(ns.DEFAULTS) do
        if EzTonguesDB[k] == nil then EzTonguesDB[k] = v end
    end
    EzTonguesCharDB = EzTonguesCharDB or {}
    local start = StartingTongues()
    if type(EzTonguesCharDB.known) ~= "table" then
        EzTonguesCharDB.known = {}
        for _, key in ipairs(start) do EzTonguesCharDB.known[key] = true end
    end
    if not byKey[EzTonguesCharDB.default] then EzTonguesCharDB.default = start[1] or ns.TONGUES[1].key end
    ns.BuildSettings(start)
end)
