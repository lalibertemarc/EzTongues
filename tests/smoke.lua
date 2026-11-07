-- EzTongues smoke test, plain Lua 5.1 with the WoW API stubbed. From the EzTongues folder: lua tests/smoke.lua
-- Checks decode(encode(x)) == x over a few hundred lines in every language, that plain English isn't taken for a
-- language, the dictionary's rules, pinned sample encodings (they must never change), and the slash command and
-- chat filter end to end.
local failures, checks = 0, 0
local function check(ok, msg)
    checks = checks + 1
    if not ok then
        failures = failures + 1
        if failures <= 40 then print("FAIL: " .. msg) end
    end
end

---------------------------------------------------------------------------
-- WoW stubs
---------------------------------------------------------------------------
local printed, sent, filters, frames = {}, {}, {}, {}
local player = { name = "Grukk", surname = "Stonefist", race = "Orc", class = "WARRIOR", faction = "Horde" }
local target
local group = {}  -- party1, party2 ...: { name, surname }

local function Stub(name)
    local f = { scripts = {}, name = name, shown = false, text = "" }
    return setmetatable(f, { __index = function(_, k)
        if k == "SetScript" then return function(self, s, fn) self.scripts[s] = fn end end
        if k == "GetScript" then return function(self, s) return self.scripts[s] end end
        if k == "Show" then return function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
        if k == "Hide" then return function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "SetText" then return function(self, t) self.text = t end end
        if k == "GetText" then return function(self) return self.text end end
        if k == "CreateFontString" or k == "GetFontString" or k == "CreateTexture" then
            return function() return Stub("region") end
        end
        if k == "HasFocus" then return function(self) return self.focus end end
        if k == "SetFocus" then return function(self) self.focus = true end end
        if k == "ClearFocus" then return function(self) self.focus = false end end
        if k == "GetPoint" then return function() return "BOTTOM", nil, "BOTTOM", 0, 300 end end
        return function() end
    end })
end

function GetBuildInfo() return "1.60.1", "70707", "", 16001 end
function CreateFrame(_, name)
    local f = Stub(name)
    frames[#frames + 1] = f
    return f
end
UIParent = Stub("UIParent")
GameTooltip = Stub("GameTooltip")
ChatFontNormal = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }
ChatFrameUtil = { AddMessageEventFilter = function(event, fn) filters[event] = fn end }
C_ChatInfo = {
    SendChatMessage = function(msg, chatType, _, to) sent[#sent + 1] = { msg = msg, chatType = chatType, to = to } end,
    InChatMessagingLockdown = function() return false end,
}
function issecretvalue() return false end
local function UnitOf(unit)
    if unit == "player" then return player end
    if unit == "target" then return target end
    local i = unit:match("^party(%d)$")
    return i and group[tonumber(i)]
end
function UnitName(unit)
    local u = UnitOf(unit)
    if u then return u.name, u.surname end
end
function UnitRace() return player.race, player.race end
function UnitClass() return player.class, player.class end
function UnitFactionGroup() return player.faction end
function UnitExists(unit) return UnitOf(unit) ~= nil end
function GetNumGroupMembers() return #group > 0 and #group + 1 or 0 end
function IsInGroup() return #group > 0 end
function IsInRaid() return false end
function IsInGuild() return false end
function UnitIsPlayer() return true end
function InCombatLockdown() return false end
function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
function tContains(t, v)
    for _, x in ipairs(t) do if x == v then return true end end
    return false
end
SlashCmdList = {}
Settings = {
    RegisterVerticalLayoutCategory = function() return { GetID = function() return 1 end }, { AddInitializer = function() end } end,
    RegisterAddOnSetting = function(_, var, key, tbl, _, _, default)
        if tbl[key] == nil then tbl[key] = default end
        return var
    end,
    CreateCheckbox = function() end,
    CreateDropdown = function(_, _, options) options() end,
    CreateControlTextContainer = function()
        local data = {}
        return { Add = function(_, k) data[#data + 1] = k end, GetData = function() return data end }
    end,
    RegisterAddOnCategory = function() end,
    RegisterCanvasLayoutSubcategory = function() return { GetID = function() return 2 end } end,
    OpenToCategory = function() end,
    VarType = { Boolean = "boolean", String = "string" },
}
function CreateSettingsListSectionHeaderInitializer() end
function CreateSettingsButtonInitializer() end

---------------------------------------------------------------------------
-- Load the addon in TOC order
---------------------------------------------------------------------------
local ns = {}
local before = collectgarbage("count")
for line in io.lines("EzTongues.toc") do
    if line:match("%.lua$") then assert(loadfile(line))("EzTongues", ns) end
end

local KEYS = {}
for _, t in ipairs(ns.TONGUES) do KEYS[#KEYS + 1] = t.key end
check(#KEYS == 11, "11 languages")

---------------------------------------------------------------------------
-- Dictionary rules
---------------------------------------------------------------------------
local WORD = "^[a-z]+('[a-z]+)*$"
local function IsWord(w)
    if not w:find("^[a-z]+") then return false end
    return w:gsub("^[a-z]+", ""):gsub("'[a-z]+", "") == ""
end
local markerOf, phraseWords, nativeOf = {}, {}, {}
for _, t in ipairs(ns.TONGUES) do
    for _, m in ipairs(t.markers) do
        check(not markerOf[m], "marker " .. m .. " used twice")
        check(m:find("^[a-z]+$") ~= nil, "marker letters only: " .. m)
        markerOf[m] = t.key
    end
end
for _, t in ipairs(ns.TONGUES) do
    for _, p in ipairs(t.phrases) do
        check(p[1] == p[1]:lower(), t.key .. " phrase English is lower case: " .. p[1])
        check(p[2] == p[2]:sub(1, 1):upper() .. p[2]:sub(2):lower(), t.key .. " phrase native has one capital: " .. p[2])
        for w in p[2]:lower():gmatch("[a-z]+'?[a-z']*") do
            phraseWords[w] = t.key
            check(not markerOf[w:match("^([a-z]+)'")] , "phrase word starts like a cipher word: " .. w)
        end
    end
end
local pairsCount = 0
for _, t in ipairs(ns.TONGUES) do
    local seen = {}
    for en, nat in ns.DICTIONARY[t.key]:gmatch("(%S+) (%S+)") do
        pairsCount = pairsCount + 1
        check(IsWord(en), t.key .. " English is a word: " .. en)
        check(IsWord(nat) and #nat:gsub("'", "") >= 2, t.key .. " native is a word of 2+ letters: " .. nat)
        check(not seen[en], t.key .. " English paired twice: " .. en)
        check(not nativeOf[nat], "native used twice: " .. nat)
        check(not phraseWords[nat], "native is a phrase word: " .. nat)
        check(not markerOf[nat] and not markerOf[nat:match("^([a-z]+)'") or ""], "native looks ciphered: " .. nat)
        seen[en], nativeOf[nat] = true, t.key
    end
end
check(pairsCount >= 11 * 1600, "dictionary has its pairs (" .. pairsCount .. ")")
local _ = WORD

---------------------------------------------------------------------------
-- Pinned encodings: lines already sent must decode forever, so these must never change.
---------------------------------------------------------------------------
local PINNED = dofile("tests/pinned.lua")
local SAMPLES = PINNED.samples
for _, key in ipairs(KEYS) do
    for i, s in ipairs(SAMPLES) do
        local want = PINNED[key] and PINNED[key][i]
        local got = ns.Encode(key, s)
        if want then
            check(got == want, ("%s pinned #%d changed:\n  was  %s\n  now  %s"):format(key, i, want, got))
            check(ns.Decode(key, want) == s, key .. " pinned #" .. i .. " decodes")
        end
    end
end

---------------------------------------------------------------------------
-- Round trips
---------------------------------------------------------------------------
local LINES = {
    "Hello there!", "Well met, friend.", "WELL MET!", "well met", "Farewell.", "Victory or death!",
    "Lok'tar ogar!", "By the light of the sun, we stand.", "I can't believe you'd do that, Thrall.",
    "Don't touch my {skull} please", "Look at this: |cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r!",
    "%t, come here.", "Meet me at 10:30 near the Stormwind gates, ok?", "I'm the Kel'Thuzad fan club's president.",
    "o'clock rock'n'roll y'all ma'am", "'Quoted' words and \"double quotes\" stay.", "dogs' bones and James' sword",
    "McDonald iPhone LoL WoW pvP", "ALL CAPS SENTENCE HERE", "a A i I x X", "The year 2026 was 3rd best.",
    "naïve café résumé", "emoji 🙂 here", "hyphen-ated words-and-more", "trailing apostrophe' and 'leading",
    "  two  spaces   and tabs\tin it  ", "", "...", "!!!", "{rt1}{rt2}", "Elune be with you, Tyrande.",
    "Good fortune to your family and good fortune to you.", "Zug zug, okay okay OKAY Okay", "thank you THANK YOU Thank you",
    "Glory To The Sun King", "victory or DEATH", "farewell's end", "the sun the moon The sun THE MOON",
    "Greetings, traveler. Greetings,traveler", "I will eat your heart!", "May the days ahead be guided by the elders of long ago.",
    "x'y z'' ''z a'b'c'd", "Qwrtzp Xkcd zzz brr hmmmm shh", "Ael'bab shae'zug lae'x", "dag'gog rok'k grak'zz",
    "Hello|nworld", "100% sure", "50%off", "%s %d %%", "Sin'dorei and Quel'Thalas and Zul'jin and Vol'jin",
    "Mak'gora! Throm-ka! Shan'do, thero'shan.", "keep the fire burning, my child", "mother and father",
}
-- Generated lines: dictionary words, made-up words, names, in mixed case and punctuation.
local words = {}
for en in ns.DICTIONARY.orcish:gmatch("(%S+) %S+") do words[#words + 1] = en end
local junk = { "Thrall", "Jaina", "zxq", "Gnomeregan", "brrr", "Xal'atath", "Bwonsamdi", "Kael'thas", "qwop", "Uther" }
math.randomseed(1234)
local punct = { "", "", "", ",", ".", "!", "?", "...", ";", ":", " -", "'s" }
for _ = 1, 260 do
    local n, parts = math.random(1, 14), {}
    for k = 1, n do
        local w = math.random() < 0.85 and words[math.random(#words)] or junk[math.random(#junk)]
        local r = math.random()
        if r < 0.1 then w = w:upper() elseif r < 0.3 or k == 1 then w = w:sub(1, 1):upper() .. w:sub(2) end
        parts[#parts + 1] = w .. punct[math.random(#punct)]
    end
    LINES[#LINES + 1] = table.concat(parts, " ")
end

local roundTrips = 0
for _, key in ipairs(KEYS) do
    for _, s in ipairs(LINES) do
        local e = ns.Encode(key, s)
        local back = ns.Decode(key, e)
        local hasWords = s:gsub("|c.-|r", ""):gsub("{.-}", ""):gsub("%%%a", ""):find("[A-Za-z]")
        if hasWords then
            check(back == s, ("%s round trip:\n  in   %s\n  out  %s\n  back %s"):format(key, s, e, tostring(back)))
            local k2, back2 = ns.Detect(e)
            -- Lines made only of phrases two tongues share may detect as the other one; the text is still right.
            check(k2 == key or (k2 and back2 == s), ("%s detected as %s: %s -> %s"):format(key, tostring(k2), s, e))
            roundTrips = roundTrips + 1
        else
            check(e == s, key .. " line without words is left alone: " .. s)
        end
        -- Glued for sending, split into chat messages: each piece still decodes on its own.
        local glued = ns.Encode(key, s .. " " .. s .. " " .. s .. " " .. s, true)
        for _, piece in ipairs(ns.Split(glued, 255)) do
            check(#piece <= 255 or not piece:find(" "), key .. " piece fits: " .. piece)
            if piece:find("[A-Za-z]") and hasWords then
                check(ns.Detect(piece) == key or select(2, ns.Detect(piece)) ~= nil, key .. " piece decodes: " .. piece)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Dialects: a passphrase's drift round-trips, is its own inverse, and only its own dialect reads it
---------------------------------------------------------------------------
local PASSES = { "wolves of the north", "the silver hand" }
local dialectTrips, drifted, misread = 0, 0, 0
for _, key in ipairs(KEYS) do
    for _, pass in ipairs(PASSES) do
        local d = ns.DialectDrift(key, pass)
        local other = ns.DialectDrift(key, pass .. "!")
        local function mine() return { { drift = d } } end
        local function theirs() return { { drift = other } } end
        for _, s in ipairs(LINES) do
            local e = ns.Encode(key, s, nil, d)
            check(ns.Drift(ns.Drift(e, d), d) == e, key .. " drift undoes itself: " .. e)
            if s:gsub("|c.-|r", ""):gsub("{.-}", ""):gsub("%%%a", ""):find("[A-Za-z]") then
                check(ns.Decode(key, e, d) == s, ("%s dialect round trip:\n  in   %s\n  out  %s"):format(key, s, e))
                local tagged = ns.Tag(key, true) .. e
                local k2, back, isTagged, which = ns.Detect(tagged, mine)
                check(k2 == key and back == s and isTagged and which, key .. " dialect line detected: " .. tagged)
                check(ns.Detect(tagged) == nil, key .. " dialect line unread without its dialect: " .. tagged)
                -- A short line can read as something else in another dialect of the same tongue (each of its
                -- words drifts onto a real word there): rare, but nothing in the line tells them apart.
                local k3, back3 = ns.Detect(tagged, theirs)
                if k3 and back3 ~= s then misread = misread + 1 end
                if e ~= ns.Encode(key, s) then drifted = drifted + 1 end
                dialectTrips = dialectTrips + 1
            end
        end
    end
end
check(misread <= dialectTrips / 500, ("another dialect rarely misreads a line (%d of %d)"):format(misread, dialectTrips))
check(drifted > dialectTrips * 0.9, ("dialect lines differ from plain ones (%d of %d)"):format(drifted, dialectTrips))
local function Serialize(d)
    local l = {}
    for a, b in pairs(d) do l[#l + 1] = a .. b end
    table.sort(l)
    return table.concat(l)
end
check(Serialize(ns.DialectDrift("orcish", "  Wolves of  the NORTH ")) == Serialize(ns.DialectDrift("orcish", "wolves of the north")),
    "passphrase case and spaces don't matter")
check(Serialize(ns.DialectDrift("orcish", "bloodfang")) ~= Serialize(ns.DialectDrift("thalassian", "bloodfang")),
    "same passphrase, other tongue: another drift")
local maps, distinct = {}, 0
for i = 1, 300 do
    local id = Serialize(ns.DialectDrift("orcish", "guild number " .. i))
    if not maps[id] then distinct, maps[id] = distinct + 1, true end
end
check(distinct >= 295, "passphrases give their own drifts (" .. distinct .. " of 300)")
for _, p in ipairs(PINNED.dialects) do
    local key, pass, s, want = p[1], p[2], p[3], p[4]
    local d = ns.DialectDrift(key, pass)
    local got = ns.Encode(key, s, nil, d)
    check(got == want, ("%s dialect \"%s\" pinned changed:\n  was  %s\n  now  %s"):format(key, pass, want, got))
    check(ns.Decode(key, want, d) == s, key .. " dialect pinned decodes")
end

---------------------------------------------------------------------------
-- Plain English stays plain
---------------------------------------------------------------------------
local PLAIN = {
    "Hello there!", "Anyone up for Deadmines?", "lol", "ok", "brb", "Thanks for the buff!", "No.", "Yes", "Kel'Thuzad",
    "Zul'jin", "Vol'jin", "Sin'dorei", "Quel'Thalas", "Kil'jaeden", "Mal'Ganis", "Ner'zhul", "Gul'dan", "Al'ar",
    "Kael'thas", "Zul'Gurub", "Kor'kron", "Grom'gol", "Ahn'Qiraj", "Uldum", "Ulduar", "Draenor", "Azeroth",
    "Thrall", "Jaina", "Ishnu", "Elune", "Bwonsamdi", "o'clock", "rock'n'roll", "y'all",
}
for en in ns.DICTIONARY.orcish:gmatch("(%S+) %S+") do PLAIN[#PLAIN + 1] = en end
local falsePositives = 0
for _, s in ipairs(PLAIN) do
    local k, back = ns.Detect(s)
    if k then
        falsePositives = falsePositives + 1
        check(false, ("plain English taken for %s: %s -> %s"):format(k, s, back))
    end
end

-- Intended: a line made only of a lore phrase is that language even when typed by hand.
check(ns.Detect("Lok'tar ogar!") == "orcish", "Lok'tar ogar! is Orcish")
check(select(2, ns.Detect("Lok'tar ogar!")) == "Victory or death!", "Lok'tar ogar! = Victory or death!")
check(ns.Detect("Shorel'aran.") == "thalassian", "Shorel'aran is Thalassian")

---------------------------------------------------------------------------
-- Speed and memory
---------------------------------------------------------------------------
local t0 = os.clock()
local encoded = {}
for i = 1, 300 do encoded[i] = ns.Encode(KEYS[i % #KEYS + 1], LINES[(i % #LINES) + 1]) end
for i = 1, 300 do ns.Detect(encoded[i]); ns.Detect(LINES[(i % #LINES) + 1]) end
local ms = (os.clock() - t0) * 1000
collectgarbage("collect")
local kb = collectgarbage("count") - before

---------------------------------------------------------------------------
-- Core: login, slash command, chat filter
---------------------------------------------------------------------------
local coreEvents
for _, f in ipairs(frames) do
    if f.scripts.OnEvent then
        coreEvents = coreEvents or f
        f.scripts.OnEvent(f, "PLAYER_LOGIN")
    end
end
check(EzTonguesCharDB.known.orcish == true, "orc knows Orcish")
check(EzTonguesCharDB.known.thalassian == false, "orc doesn't know Thalassian")
check(EzTonguesCharDB.default == "orcish", "orc speaks Orcish by default")

local slash = SlashCmdList.EZTONGUES
check(SLASH_EZTONGUES2 == "/lang", "/lang alias")

sent = {}
slash("orcish Victory or death, Thrall!")
check(#sent == 1 and sent[1].chatType == "SAY", "/tongue orcish says it")
local said = sent[1] and sent[1].msg or ""
check(said:find("^%[Orcish%] ") ~= nil, "line starts with its language: " .. said)

-- What a sent line says in Orcish, read through its tag.
local function Said(msg)
    local key, english, tagged = ns.Detect(msg)
    return key == "orcish" and tagged and english
end
check(ns.Detect("[Orcish] Hello there") == nil, "a tag on plain English isn't a tongue")
check(ns.Detect("[Thalassian] " .. ns.Encode("orcish", "Hello there")) == nil, "a tag picks the only tongue tried")
check(said:find("Lok'tar ogar", 1, true) ~= nil, "phrase in the line: " .. said)

sent = {}
slash("y We ride at dawn")
check(#sent == 1 and sent[1].chatType == "YELL", "/tongue y yells in the default language")
check(sent[1] and ns.Detect(sent[1].msg) == "orcish", "default language is Orcish")

sent = {}
slash("thalassian Hello")
check(#sent == 0, "can't speak a language you don't know")
slash("learn tha")
slash("thalassian e smiles. \"Well met, friend.\"")
check(#sent == 1 and sent[1].chatType == "EMOTE", "emote sent")
local emote = sent[1] and sent[1].msg or ""
check(emote:find("^smiles%. %[Thalassian%] \"") ~= nil, "emote narration stays English, tag before the quote: " .. emote)

target = { name = "Jaina", surname = "Proudmoore" }
sent = {}
slash("orc w jaina Proudmoore I see you")
check(sent[1] and sent[1].chatType == "WHISPER" and sent[1].to == "Jaina Proudmoore", "whisper to target's full name")
check(sent[1] and Said(sent[1].msg) == "I see you", "whisper text: " .. (sent[1] and sent[1].msg or ""))
sent = {}
slash("orc Look at %t over there")
check(sent[1] and Said(sent[1].msg) == "Look at Jaina over there", "%t filled in before encoding")

-- Long lines go out in pieces of 255 bytes or less. In /say only one per press (Forever blocks a second send in the
-- same press): the rest wait for /tongue more, or Enter on an empty line in the box (it opens for them).
local long = string.rep("Victory or death, my friends, we march to the gates of the city tonight! ", 8)
sent = {}
slash("orcish " .. long)
local waits = ns.Waiting()
check(#sent == 1 and waits >= 2, "a long /say line sends one piece, the rest wait: " .. waits)
local pieces = { sent[1] }
sent = {}
slash("more")
check(#sent == 1 and ns.Waiting() == waits - 1, "/tongue more says the next piece")
pieces[#pieces + 1] = sent[1]
local boxEdit
for _, f in ipairs(frames) do if f.name == "EzTonguesBoxEdit" then boxEdit = f end end
check(boxEdit ~= nil, "pieces waiting open the box")
while boxEdit and ns.Waiting() > 0 do
    sent = {}
    boxEdit.scripts.OnEnterPressed(boxEdit)
    check(#sent == 1, "Enter on an empty box line says the next piece")
    pieces[#pieces + 1] = sent[1]
end
check(#pieces == waits + 1, "every piece said")
for _, m in ipairs(pieces) do check(m and #m.msg <= 255 and Said(m.msg), "piece ok, with its tag: " .. m.msg) end
sent = {}
slash("more")
check(#sent == 0, "nothing more waits")
-- Party isn't held to one per press: every piece at once.
sent = {}
slash("orcish p " .. long)
check(#sent == waits + 1 and ns.Waiting() == 0, "party sends every piece at once: " .. #sent)
-- A new line, or Escape in the box, drops what waits.
slash("orcish " .. long)
slash("orcish Hello")
check(ns.Waiting() == 0, "a new line drops the waiting pieces")
slash("orcish " .. long)
if boxEdit then boxEdit.scripts.OnEscapePressed(boxEdit) end
check(ns.Waiting() == 0, "Escape drops the waiting pieces")

-- Tags off: the line goes out bare and still decodes.
EzTonguesDB.tag = false
sent = {}
slash("orcish Victory or death, Thrall!")
local bare = sent[1] and sent[1].msg or ""
check(bare ~= "" and not bare:find("[", 1, true) and select(2, ns.Detect(bare)) == "Victory or death, Thrall!",
    "no tag when off: " .. bare)
EzTonguesDB.tag = true

-- Hearing it: someone else's line, as someone who knows Orcish and Thalassian.
local filter = filters.CHAT_MSG_SAY
local stop, out = filter(nil, "CHAT_MSG_SAY", said, "Bob-Realm", "x")
check(stop == false and out == said .. " |cffa0a0a0(Victory or death, Thrall!)|r", "translation added: " .. tostring(out))
local _, out2 = filters.CHAT_MSG_EMOTE(nil, "CHAT_MSG_EMOTE", emote, "Bob")
check(out2 == emote .. " |cffa0a0a0(\"Well met, friend.\")|r", "emote quote translated: " .. tostring(out2))
slash("forget orcish")
local _, out3 = filter(nil, "CHAT_MSG_SAY", said, "Bob")
check(out3 == nil, "unknown tagged language left alone, the tag names it: " .. tostring(out3))
local _, out4 = filter(nil, "CHAT_MSG_SAY", bare, "Bob")
check(out4 == bare .. " |cffa0a0a0(Orcish)|r", "unknown untagged language named: " .. tostring(out4))
local _, own = filter(nil, "CHAT_MSG_SAY", said, "Grukk")
check(own == said .. " |cffa0a0a0(Victory or death, Thrall!)|r", "own line always translated: " .. tostring(own))
EzTonguesDB.showName = false
local unchanged = select(2, filter(nil, "CHAT_MSG_SAY", said, "Bob"))
check(unchanged == nil, "unknown language left alone when names are off")
EzTonguesDB.color = "gold"
local _, gold = filter(nil, "CHAT_MSG_SAY", said, "Grukk")
check(gold and gold:find("|cffe6c35c(", 1, true) ~= nil, "translation color")
check(select(2, filter(nil, "CHAT_MSG_SAY", "Just plain English here.", "Bob")) == nil, "plain line untouched")
local link = ns.Encode("orcish", "Take |cffa335ee|Hitem:1|h[Sword]|h|r now")
local _, linked = filter(nil, "CHAT_MSG_SAY", link, "Grukk")
check(linked and linked:find("|r|cffe6c35c now)|r", 1, true) ~= nil, "color picked up again after a link: " .. tostring(linked))

-- Whispers remembered, either way: a first name gets their surname.
slash("learn orcish")
coreEvents.scripts.OnEvent(coreEvents, "CHAT_MSG_WHISPER", "hi", "Bob-Smith")
check(EzTonguesCharDB.whispers[1] == "Bob Smith", "whisper author remembered as First Surname")
sent = {}
slash("orc w bob Smith Hello")
check(sent[1] and sent[1].to == "Bob Smith" and Said(sent[1].msg) == "Hello", "whisper to a remembered name")
group = { { name = "Thrall", surname = "Hellscream" } }
sent = {}
slash("orc w thrall For the Horde")
check(sent[1] and sent[1].to == "Thrall Hellscream", "whisper to a group member's full name")
group = {}

-- The box: keybind opens it, Enter says the line in its language.
EzTongues_ToggleBox("down")
EzTongues_ToggleBox("up")
local editBox, header
for _, f in ipairs(frames) do
    if f.name == "EzTonguesBoxEdit" then editBox = f elseif f.name == "EzTonguesBoxHeader" then header = f end
end
check(editBox ~= nil and header ~= nil, "box made")
local function Open()
    EzTongues_ToggleBox("up")
end
local function Type(text)
    editBox.text = text
    editBox.scripts.OnTextChanged(editBox, true)
end
local function Enter()
    sent = {}
    editBox.scripts.OnEnterPressed(editBox)
    return sent[1] or {}
end
local function Channel() return header.label.text end
check(Channel() == "Say:", "box starts on Say")
editBox.text = "/p Well met"
local m = Enter()
check(m.chatType == "PARTY" and Said(m.msg) == "Well met", "box sends a /p line to party")

-- A channel command and a space switch the box, and it stays there.
Open()
Type("/p ")
check(editBox.text == "" and Channel() == "Party:", "/p and a space switch to party: " .. Channel())
Type("Well met")
check(Enter().chatType == "PARTY", "box sends to party")
Open()
Type("Again")
check(Enter().chatType == "PARTY", "box stays on party")

-- Whisper: "/w jaina " fills in the target's surname, and skips it when typed anyway.
Open()
Type("/w jaina ")
check(Channel() == "Tell Jaina Proudmoore:" and editBox.text == "", "/w first name -> full name: " .. Channel())
Type("Proudmoore ")
check(editBox.text == "", "typed surname skipped: " .. editBox.text)
Type("I see you")
m = Enter()
check(m.chatType == "WHISPER" and m.to == "Jaina Proudmoore" and Said(m.msg) == "I see you",
    "box whispers the target")
Open()
Type("/w jaina Proudmoore right away")
check(Channel() == "Tell Jaina Proudmoore:" and editBox.text == "right away", "pasted whisper line: " .. editBox.text)
-- Forever needs the surname: a first name the box doesn't know waits for one.
Type("/w varian ")
check(editBox.text == "/w varian ", "unknown first name waits for its surname")
Type("/w varian Wrynn ")
check(Channel() == "Tell varian Wrynn:" and editBox.text == "", "unknown name with surname: " .. Channel())
Type("/w \"Anduin Wrynn\" ")
check(Channel() == "Tell Anduin Wrynn:", "quoted name")

-- Tab: whispers the next person the box knows, wrapping around.
editBox.scripts.OnTabPressed(editBox)
check(Channel() == "Tell Jaina Proudmoore:", "Tab: target first: " .. Channel())
editBox.scripts.OnTabPressed(editBox)
check(Channel() == "Tell Bob Smith:", "Tab: then a remembered name: " .. Channel())
editBox.scripts.OnTabPressed(editBox)
check(Channel() == "Tell Jaina Proudmoore:", "Tab wraps around: " .. Channel())
Type("/s ")
editBox.scripts.OnTabPressed(editBox)
check(Channel() == "Tell Jaina Proudmoore:", "Tab from Say whispers the first name")
Type("Hello?")
check(Enter().to == "Jaina Proudmoore", "whisper sent after Tab")

-- Up brings back a line with its channel.
Open()
Type("/s ")
editBox.scripts.OnArrowPressed(editBox, "UP")
check(editBox.text == "Hello?" and Channel() == "Tell Jaina Proudmoore:", "history line back with its channel")
check(Enter().chatType == "WHISPER", "history line keeps its channel")

-- The dropdowns: language, then the channel list (a click on the channel).
local buttons = {}  -- the box's close button, then the language button (the options page's come before the box)
local inBox = false
for _, f in ipairs(frames) do
    inBox = inBox or rawget(f, "name") == "EzTonguesBox"
    if inBox and f.scripts.OnClick and not rawget(f, "name") then buttons[#buttons + 1] = f end
end
Open()
buttons[2].scripts.OnClick(buttons[2])
local list
for _, f in ipairs(frames) do if f.name == "EzTonguesBoxList" then list = f end end
check(list and list.shown and #list.rows == #ns.TONGUES, "dropdown lists every tongue")
list.rows[1].scripts.OnClick(list.rows[1])
check(EzTonguesCharDB.default == ns.TONGUES[1].key and not list.shown, "dropdown row sets the default and closes")
EzTonguesCharDB.default = "orcish"
header.scripts.OnClick(header)
-- 7 channels, Jaina (target), Bob (whispered), "Whisper..."
local rows = 0
for _, r in ipairs(list.rows) do if r.shown then rows = rows + 1 end end
check(list.shown and rows == #ns.BOX_MENU + 2, "channel list: channels, names, Whisper...: " .. rows)
list.rows[2].scripts.OnClick(list.rows[2])
check(Channel() == "Yell:", "channel list picks yell")
Type("Hear me")
check(Enter().chatType == "YELL", "box yells")
-- "Whisper..." starts the line with /w and gives the line back once the name is in.
Open()
Type("hold this")
header.scripts.OnClick(header)
list.rows[rows].scripts.OnClick(list.rows[rows])
check(editBox.text == "/w ", "Whisper... starts /w")
Type("/w bob ")
check(Channel() == "Tell Bob Smith:" and editBox.text == "hold this", "line back after the name: " .. editBox.text)
-- Picking it again over an unfinished /w keeps the held line, not the /w.
Type("/s ")
Type("hold this")
header.scripts.OnClick(header)
list.rows[rows].scripts.OnClick(list.rows[rows])
Type("/w bo")
header.scripts.OnClick(header)
list.rows[rows].scripts.OnClick(list.rows[rows])
Type("/w bob ")
check(Channel() == "Tell Bob Smith:" and editBox.text == "hold this", "Whisper... twice, /w not held: " .. editBox.text)
-- Picking another channel instead drops the unused /w and gives the line back too.
Type("/s ")
Type("hold that")
header.scripts.OnClick(header)
list.rows[rows].scripts.OnClick(list.rows[rows])
Type("/w bo")
header.scripts.OnClick(header)
list.rows[1].scripts.OnClick(list.rows[1])
check(Channel() == "Say:" and editBox.text == "hold that", "unused /w dropped on Say: " .. editBox.text)
Type("/w ")
editBox.scripts.OnTabPressed(editBox)
check(Channel() == "Tell Jaina Proudmoore:" and editBox.text == "", "unused /w dropped on Tab: " .. editBox.text)
-- Another addon (EzAcquaintances' book) switches the box to a whisper.
Type("/s ")
EzTonguesAPI.Whisper("Fay Moss")
check(Channel() == "Tell Fay Moss:", "EzTonguesAPI.Whisper: " .. Channel())

-- Dialects end to end: add one, speak it, hear it; speak plain, still hear it; forget it.
local GOLD = "|cffe6c35c"
slash("dialect add orcish Bloodfang wolves of the north")
check(#EzTonguesCharDB.dialects == 1 and EzTonguesCharDB.speak.orcish == "bloodfang", "dialect added and spoken")
sent = {}
slash("orcish Victory or death, Thrall!")
local dsaid = sent[1] and sent[1].msg or ""
check(dsaid:find("^%[Orcish dialect%] ") ~= nil and dsaid ~= said, "dialect line tagged as one: " .. dsaid)
local _, heard = filter(nil, "CHAT_MSG_SAY", dsaid, "Bob")
check(heard == dsaid .. " " .. GOLD .. "(Victory or death, Thrall!)|r", "dialect line read by who knows it: " .. tostring(heard))
check(select(2, filter(nil, "CHAT_MSG_SAY", said, "Bob")) == said .. " " .. GOLD .. "(Victory or death, Thrall!)|r",
    "plain lines still read")
EzTonguesDB.tag = false
sent = {}
slash("orcish Hello")
check(sent[1] and sent[1].msg:find("^%[Orcish dialect%] ") ~= nil, "dialect lines keep their tag with tags off")
EzTonguesDB.tag = true
sent = {}
slash('orcish e grins. "Well met"')
local dem = sent[1] and sent[1].msg or ""
check(dem:find('^grins%. %[Orcish dialect%] "') ~= nil, "dialect emote: " .. dem)
check(select(2, filters.CHAT_MSG_EMOTE(nil, "CHAT_MSG_EMOTE", dem, "Bob")) == dem .. " " .. GOLD .. '("Well met")|r',
    "dialect emote read")
printed = {}
slash("test orcish Hello")
check(#printed == 3 and printed[1]:find("Bloodfang dialect", 1, true) and printed[2]:find("[Orcish dialect]", 1, true)
    and printed[3]:find("Hello", 1, true), "/tongue test speaks the dialect")
slash("dialect add orcish Wolfpack  Wolves of the NORTH ")
check(#EzTonguesCharDB.dialects == 1, "same passphrase isn't added twice")
slash("dialect add orcish Ironjaw abc")
check(#EzTonguesCharDB.dialects == 1, "short passphrase refused")
slash("dialect add orcish Ironjaw iron and blood")
check(#EzTonguesCharDB.dialects == 2 and EzTonguesCharDB.speak.orcish == "ironjaw", "second dialect added and spoken")
check(select(2, filter(nil, "CHAT_MSG_SAY", dsaid, "Bob")) == heard, "still reads the first one")
slash("dialect use bloodfang")
check(EzTonguesCharDB.speak.orcish == "bloodfang", "/tongue dialect use")
slash("dialect plain orc")
check(EzTonguesCharDB.speak.orcish == nil, "/tongue dialect plain")
sent = {}
slash("orcish Victory or death, Thrall!")
check(sent[1] and sent[1].msg == said, "plain line again: " .. (sent[1] and sent[1].msg or ""))
check(select(2, filter(nil, "CHAT_MSG_SAY", dsaid, "Bob")) == heard, "speaking plain, still reads the dialect")

-- The box's dropdown lists dialects under their tongue; picking one speaks it.
Open()
buttons[2].scripts.OnClick(buttons[2])
local orcAt, shownRows = 0, 0
for i, t in ipairs(ns.TONGUES) do if t.key == "orcish" then orcAt = i end end
for _, r in ipairs(list.rows) do if r.shown then shownRows = shownRows + 1 end end
check(shownRows == #ns.TONGUES + 2, "dropdown: every tongue and the two dialects: " .. shownRows)
list.rows[orcAt + 1].scripts.OnClick(list.rows[orcAt + 1])
check(EzTonguesCharDB.default == "orcish" and EzTonguesCharDB.speak.orcish == "bloodfang", "box picks the dialect")
Type("/s ")
Type("Victory or death, Thrall!")
check(Enter().msg == dsaid, "box speaks the dialect")
Open()
buttons[2].scripts.OnClick(buttons[2])
list.rows[orcAt].scripts.OnClick(list.rows[orcAt])
check(EzTonguesCharDB.speak.orcish == nil, "box picks the plain tongue again")

slash("dialect forget Bloodfang")
check(#EzTonguesCharDB.dialects == 1 and select(2, filter(nil, "CHAT_MSG_SAY", dsaid, "Bob")) == nil,
    "forgotten dialect no longer read")
slash("dialect use bloodfang")
slash("dialect")

-- The options page's Dialects subpage: add (refusals shown in its status line), speak, plain, two-click forget.
local page = ns.dialectsPanel
local ui = page.ui
local function Click(b) b.scripts.OnClick(b) end
page:Show()
check(ui.rows[1] and ui.rows[1].shown and ui.rows[1].dialect.name == "Ironjaw", "page lists the dialect left")
check(ui.tongue.text == "Orcish", "page's tongue starts on the default: " .. ui.tongue.text)
ui.name.text, ui.pass.text = "Wolfpack", "abc"
Click(ui.add)
check(#EzTonguesCharDB.dialects == 1 and ui.status.text:find("too short", 1, true), "page refuses a short passphrase")
Click(ui.tongue)
local dwarfAt
for i, t in ipairs(ns.TONGUES) do if t.key == "dwarvish" then dwarfAt = i end end
Click(list.rows[dwarfAt])
check(ui.tongue.text == "Dwarvish", "page picks a tongue: " .. ui.tongue.text)
ui.name.text, ui.pass.text = "Deepforge", "  Stone and  Ale "
ui.pass.scripts.OnEnterPressed(ui.pass)
local added = EzTonguesCharDB.dialects[2]
check(added and added.lang == "dwarvish" and added.name == "Deepforge" and EzTonguesCharDB.speak.dwarvish == "deepforge",
    "page adds a dialect and speaks it")
check(ui.name.text == "" and ui.pass.text == "" and ui.status.text:find("Added Deepforge", 1, true), "page clears its form")
check(ui.status.text:find("don't know Dwarvish", 1, true) ~= nil, "page warns about an unknown tongue")
-- Rows follow ns.TONGUES order: Dwarvish before Orcish.
local dwarfRow, orcRow = ui.rows[1], ui.rows[2]
check(dwarfRow.dialect.name == "Deepforge" and orcRow.dialect.name == "Ironjaw", "page rows in tongue order")
check(dwarfRow.speak.text == "Speak plain" and orcRow.speak.text == "Speak it", "page shows who's spoken")
Click(orcRow.speak)
check(EzTonguesCharDB.speak.orcish == "ironjaw" and orcRow.speak.text == "Speak plain", "page's Speak it")
Click(orcRow.speak)
check(EzTonguesCharDB.speak.orcish == nil and orcRow.speak.text == "Speak it", "page's Speak plain")
orcRow.scripts.OnEnter(orcRow)
Click(orcRow.forget)
check(#EzTonguesCharDB.dialects == 2, "Forget needs a second click")
orcRow.forget.scripts.OnLeave(orcRow.forget)
Click(orcRow.forget)
check(#EzTonguesCharDB.dialects == 2, "leaving Forget disarms it")
Click(orcRow.forget)
check(#EzTonguesCharDB.dialects == 1 and EzTonguesCharDB.dialects[1].name == "Deepforge", "page forgets a dialect")
check(not ui.rows[2].shown, "page drops the forgotten row")
slash("dialect add orcish Ironjaw iron and blood")
check(ui.rows[2].shown and ui.rows[2].dialect.name == "Ironjaw", "a slash add shows on the open page")
page:Hide()

printed = {}
slash("test darnassian Elune be with you, Tyrande.")
check(#printed == 3 and printed[3]:find("Elune be with you, Tyrande.", 1, true), "/tongue test prints both ways")
slash("list")
slash("default dwarf")
check(EzTonguesCharDB.default == "dwarvish", "/tongue default dwarf")

---------------------------------------------------------------------------
print(("%d checks, %d failed. %d round trips over %d lines x %d languages; %d plain lines checked, %d taken for a language."):format(
    checks, failures, roundTrips, #LINES, #KEYS, #PLAIN, falsePositives))
print(("600 detections + 300 encodes: %.0f ms. Memory with every language loaded: %.0f KB."):format(ms, kb))
if os.getenv("EZTONGUES_SAMPLES") then
    for _, key in ipairs(KEYS) do
        for _, s in ipairs(SAMPLES) do print(("%-12s %s"):format(key, ns.Encode(key, s))) end
    end
end
os.exit(failures == 0 and 0 or 1)
