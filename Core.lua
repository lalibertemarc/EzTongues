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
ns.Print = Print

local function Trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end
ns.Trim = Trim

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
ns.ResolveTongue = Resolve

local function Label(key)
    return byKey[key] and byKey[key].label or key
end
ns.Label = Label

local function Knows(key)
    return EzTonguesCharDB and EzTonguesCharDB.known[key] == true
end
ns.Knows = Knows

local function Default()
    local key = EzTonguesCharDB and EzTonguesCharDB.default
    return byKey[key] and key or ns.TONGUES[1].key
end
ns.Default = Default

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

-- A line past 255 bytes goes out in pieces, but Forever lets a key press say only one message in a public channel
-- (ns.ONE_PER_PRESS): a second SendChatMessage in the same press is blocked. So the first piece goes now and the
-- rest wait here, one per press: Enter in the box (it opens for them) or /tongue more. Escape in the box, or a new
-- line, drops them.
local waiting  -- { chatType, target, pieces = { ... } }, nil when nothing waits

local function Waiting()
    return waiting and #waiting.pieces or 0
end
ns.Waiting = Waiting

local function DropWaiting(quiet)
    if waiting and not quiet then Print(("Dropped the rest of your line (%d more)."):format(#waiting.pieces)) end
    waiting = nil
end
ns.DropWaiting = DropWaiting

local function WaitingNote()
    local n = Waiting()
    if n == 0 then return end
    Print(("%d more to say: press Enter in the box (or /tongue more) for each, Escape drops %s."):format(n,
        n == 1 and "it" or "them"))
end

local function SendPieces(pieces, chatType, target)
    DropWaiting()
    if not ns.ONE_PER_PRESS[chatType] then
        for _, msg in ipairs(pieces) do Send(msg, chatType, target) end
        return
    end
    Send(pieces[1], chatType, target)
    if #pieces < 2 then return end
    waiting = { chatType = chatType, target = target, pieces = { select(2, unpack(pieces)) } }
    WaitingNote()
    ns.OpenBox()
end

-- The next waiting piece (a key press or slash only). False when nothing waits.
local function SendNext()
    if not waiting then return false end
    if ChatLocked() then
        Print("The game blocks addon chat right now.")
        return true
    end
    Send(table.remove(waiting.pieces, 1), waiting.chatType, waiting.target)
    if #waiting.pieces == 0 then waiting = nil end
    return true
end
ns.SendNext = SendNext

-- Whispers. Forever names have surnames and whispers need "First Surname", so a typed first name is looked up
-- among the people you'd likely whisper: your target, those you whispered with lately (EzTonguesCharDB.whispers,
-- newest first) and your group.
local function UnitFullName(unit)
    local exists, isPlayer = UnitExists(unit), UnitIsPlayer(unit)
    if issecret(exists) or issecret(isPlayer) or not (exists and isPlayer) then return end
    local first, surname = UnitName(unit)
    if not first or issecret(first) then return end
    if surname and not issecret(surname) and surname ~= "" then
        return first .. (ns.ERA and "-" or " ") .. surname
    end
    return first
end

local function NameKey(name)
    return (name:match("^[^%s%-]+") or name):lower()
end

local function GroupUnits()
    local units, n = {}, GetNumGroupMembers() or 0
    if IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    else
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    end
    return units
end

-- { { name, why }, ... }: each person once, never you.
local function WhisperNames()
    local list, seen = {}, {}
    local me = UnitName("player")
    if me and not issecret(me) then seen[NameKey(me)] = true end
    local function add(name, why)
        if name and not seen[NameKey(name)] then
            seen[NameKey(name)] = true
            list[#list + 1] = { name = name, why = why }
        end
    end
    add(UnitFullName("target"), "target")
    for _, name in ipairs(EzTonguesCharDB and EzTonguesCharDB.whispers or {}) do add(name, "whispered") end
    for _, unit in ipairs(GroupUnits()) do add(UnitFullName(unit), "group") end
    return list
end
ns.WhisperNames = WhisperNames

-- The name to whisper for one typed: %t is your target, a lone first name someone above has gets their surname,
-- anything else goes out as typed. nil: nobody (%t without a target).
local function ResolveName(name)
    name = Trim(name)
    if name == "%t" then return UnitFullName("target") end
    if name == "" then return end
    if name:find("%s") then return name end
    for _, p in ipairs(WhisperNames()) do
        if NameKey(p.name) == NameKey(name) then return p.name end
    end
    return name
end
ns.ResolveName = ResolveName

-- A whisper's author as the game gives it: "First-Surname" in Forever, made "First Surname" (what whispers take);
-- "Name-Realm" in Era, kept (it whispers fine).
local function Remember(author)
    if not EzTonguesCharDB or type(author) ~= "string" or issecret(author) or author == "" then return end
    local name = ns.ERA and author or author:gsub("%-", " ")
    local list = EzTonguesCharDB.whispers
    for i = #list, 1, -1 do
        if NameKey(list[i]) == NameKey(name) then table.remove(list, i) end
    end
    table.insert(list, 1, name)
    for i = #list, ns.RECENT_MAX + 1, -1 do list[i] = nil end
end

-- A whisper's name and the text after it: "First Surname" in quotes, or a name as ResolveName takes it (a surname
-- typed after a first name it filled in is skipped).
local function WhisperTarget(rest)
    local quoted, text = rest:match('^"([^"]+)"%s+(.+)$')
    if quoted then return quoted, text end
    local name
    name, text = rest:match("^(%S+)%s+(.+)$")
    if not name then return end
    local full = ResolveName(name)
    if not full then return end
    local surname = full ~= name and full:match("^[^%s%-]+[%s%-](.+)$")
    local typed, after = text:match("^(%S+)%s+(.+)$")
    if surname and typed and typed:lower() == surname:lower() then text = after end
    return full, text
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
    SendPieces(ns.Lines(key, text, chatType), chatType, target)
end
ns.Say = Say

-- The messages to send for text in tongue key (tagged, in your dialect of it if you speak one), none past 255
-- bytes. EzTonguesAPI.Lines.
function ns.Lines(key, text, chatType)
    text = ExpandTarget(text)
    -- "[Orcish] " first, as NPCs' lines in a language: everyone sees what's spoken, and it's on every piece. A
    -- dialect's lines are always tagged "[Orcish dialect] ": that's how they're told from plain ones.
    local dialect = ns.SpokenDialect(key)
    local drift = dialect and dialect.drift
    local tag = (dialect or EzTonguesDB.tag) and ns.Tag(key, dialect ~= nil) or ""
    local said, prefix
    if chatType == "EMOTE" and text:find('"[^"]+"') then
        -- /e smiles. [Orcish] "Well met!": only the quoted speech is in the tongue.
        said = text:gsub('"([^"]+)"', function(q) return tag .. '"' .. ns.Encode(key, q, true, drift) .. '"' end)
        prefix = ""
    else
        said, prefix = ns.Encode(key, text, true, drift), tag
    end
    local pieces = ns.Split(said, MAX - #prefix)
    for i, msg in ipairs(pieces) do pieces[i] = prefix .. msg end
    return pieces
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
ns.SayTo = SayTo

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

-- { { key, english, tagged }, ... } for a line, or false. Emotes: only "quoted" speech (its tag right before the
-- quote), unless there are no quotes. Dialect lines read only in the dialects this character knows.
local function Understand(msg, emote)
    local parts = {}
    if emote and msg:find('"[^"]+"') then
        for before, q in msg:gmatch('([^"]*)"([^"]+)"') do
            local key, english, tagged = ns.Detect((before:match("%[[^%]]+%] $") or "") .. q, ns.Dialects)
            if key then parts[#parts + 1] = { key, '"' .. english .. '"', tagged } end
        end
    else
        local key, english, tagged = ns.Detect(msg, ns.Dialects)
        if key then parts[1] = { key, english, tagged } end
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

-- Dialects learned or forgotten read lines differently.
function ns.ForgetHeard()
    cache, cached = {}, 0
end

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
        elseif EzTonguesDB.showName and not p[3] and not named[p[1]] then  -- a tag already names it
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
    local dialect = ns.SpokenDialect(key)
    local drift = dialect and dialect.drift
    local said = ns.Encode(key, text, nil, drift)
    local back = ns.Decode(key, said, drift)
    Print(Label(key) .. (dialect and ", " .. dialect.name .. " dialect:" or ":"))
    DEFAULT_CHAT_FRAME:AddMessage("  " .. ((dialect or EzTonguesDB.tag) and ns.Tag(key, dialect ~= nil) or "") .. said)
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
-- Slash command
---------------------------------------------------------------------------
local function OpenSettings()
    if InCombatLockdown() then return Print("Options can't open in combat.") end
    if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
end

local HELP = {
    "/tongue <lang> <text> - say <text> in a language (/lang works too)",
    "/tongue <lang> y|p|g|o|r|e <text> - yell, party, guild, officer, raid or emote it (emotes: only the \"quotes\")",
    "/tongue <lang> w <name> <text> - whisper it (\"First Surname\", %t, or the first name of your target, someone you whispered with or in your group)",
    "/tongue <text> - your default language; /tongue default <lang> sets it",
    "/tongue more - say the next piece of a line too long for one message (the box's Enter does too)",
    "/tongue test [lang] <text> - show it in the language and back, sends nothing",
    "/tongue list - every language, and which you know",
    "/tongue learn|forget <lang|all> - honor system: learn what your character speaks",
    "/tongue dialect - your guild's own way of speaking a tongue: a name and a passphrase you share (add, use, plain, forget)",
    "/tongue box - the edit box: language and channel on its left, or start a line with /y, /p, /w name... (also a key binding: Options > Keybindings > EzTongues)",
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
    more = function()
        if not SendNext() then return Print("Nothing waits to be said.") end
        WaitingNote()
    end,
    dialect = function(arg) ns.DialectCommand(arg) end,
    dialects = function(arg) ns.DialectCommand(arg) end,
    box = function() ns.FocusBox() end,
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
ev:RegisterEvent("CHAT_MSG_WHISPER")
ev:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
ev:SetScript("OnEvent", function(_, event, ...)
    if event ~= "PLAYER_LOGIN" then return Remember((select(2, ...))) end  -- text, author
    EzTonguesDB = EzTonguesDB or {}
    EzTonguesDB.keyLog, EzTonguesDB.keyLogOn = nil, nil  -- left by a debug build's key log (2026-11-08)
    for k, v in pairs(ns.DEFAULTS) do
        if EzTonguesDB[k] == nil then EzTonguesDB[k] = v end
    end
    EzTonguesCharDB = EzTonguesCharDB or {}
    local start = StartingTongues()
    if type(EzTonguesCharDB.known) ~= "table" then
        EzTonguesCharDB.known = {}
        for _, key in ipairs(start) do EzTonguesCharDB.known[key] = true end
    end
    if type(EzTonguesCharDB.whispers) ~= "table" then EzTonguesCharDB.whispers = {} end
    if type(EzTonguesCharDB.dialects) ~= "table" then EzTonguesCharDB.dialects = {} end
    if type(EzTonguesCharDB.speak) ~= "table" then EzTonguesCharDB.speak = {} end
    if not byKey[EzTonguesCharDB.default] then EzTonguesCharDB.default = start[1] or ns.TONGUES[1].key end
    ns.BuildSettings(start)
end)
