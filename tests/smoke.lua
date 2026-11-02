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
        if k == "CreateFontString" then return function() return Stub("font") end end
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
ChatFontNormal = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }
ChatFrameUtil = { AddMessageEventFilter = function(event, fn) filters[event] = fn end }
C_ChatInfo = {
    SendChatMessage = function(msg, chatType, _, to) sent[#sent + 1] = { msg = msg, chatType = chatType, to = to } end,
    InChatMessagingLockdown = function() return false end,
}
function issecretvalue() return false end
function UnitName(unit)
    if unit == "player" then return player.name, player.surname end
    if unit == "target" and target then return target.name, target.surname end
end
function UnitRace() return player.race, player.race end
function UnitClass() return player.class, player.class end
function UnitFactionGroup() return player.faction end
function UnitExists(unit) return unit == "target" and target ~= nil end
function UnitIsPlayer() return true end
function InCombatLockdown() return false end
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
for _, f in ipairs(frames) do
    if f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
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
check(emote:find("^smiles%. \"") ~= nil, "emote narration stays English: " .. emote)

target = { name = "Jaina", surname = "Proudmoore" }
sent = {}
slash("orc w jaina Proudmoore I see you")
check(sent[1] and sent[1].chatType == "WHISPER" and sent[1].to == "Jaina Proudmoore", "whisper to target's full name")
check(sent[1] and ns.Decode("orcish", sent[1].msg) == "I see you", "whisper text: " .. (sent[1] and sent[1].msg or ""))
sent = {}
slash("orc Look at %t over there")
check(sent[1] and ns.Decode("orcish", sent[1].msg) == "Look at Jaina over there", "%t filled in before encoding")

-- Long lines go out in pieces of 255 bytes or less.
sent = {}
slash("orcish " .. string.rep("Victory or death, my friends, we march to the gates of the city tonight! ", 8))
check(#sent >= 3, "long line split")
for _, m in ipairs(sent) do check(#m.msg <= 255 and ns.Detect(m.msg) == "orcish", "piece ok: " .. m.msg) end

-- Hearing it: someone else's line, as someone who knows Orcish and Thalassian.
local filter = filters.CHAT_MSG_SAY
local stop, out = filter(nil, "CHAT_MSG_SAY", said, "Bob-Realm", "x")
check(stop == false and out == said .. " |cffa0a0a0(Victory or death, Thrall!)|r", "translation added: " .. tostring(out))
local _, out2 = filters.CHAT_MSG_EMOTE(nil, "CHAT_MSG_EMOTE", emote, "Bob")
check(out2 == emote .. " |cffa0a0a0(\"Well met, friend.\")|r", "emote quote translated: " .. tostring(out2))
slash("forget orcish")
local _, out3 = filter(nil, "CHAT_MSG_SAY", said, "Bob")
check(out3 == said .. " |cffa0a0a0(Orcish)|r", "unknown language named: " .. tostring(out3))
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

-- The box: keybind opens it, Enter says the line in its language.
EzTongues_ToggleBox("down")
EzTongues_ToggleBox("up")
local editBox
for _, f in ipairs(frames) do if f.scripts.OnEnterPressed then editBox = f end end
check(editBox ~= nil, "box made")
slash("learn orcish")
sent = {}
editBox.text = "/p Well met"
editBox.scripts.OnEnterPressed(editBox)
check(sent[1] and sent[1].chatType == "PARTY" and ns.Decode("orcish", sent[1].msg) == "Well met", "box sends to party")

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
