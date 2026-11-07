-- EzTongues' dialects: a guild's or group's own way of speaking a tongue. A dialect is a name of your choosing and
-- a passphrase; the passphrase (with the tongue) picks a few letter swaps, consonant for consonant and vowel for
-- vowel, laid over the whole line once it's in the tongue: Lok'tar ogar -> Lom'tur ogur. Only those who added the
-- same passphrase to that tongue read it; everyone else sees "[Orcish dialect]" and no translation. The swaps undo
-- themselves (a <-> b), so the same drift turns a line back.
--   ns.DialectDrift(key, pass) -> the swap table for a tongue and a passphrase
--   ns.Drift(s, drift)         -> s with its letters swapped (case kept); ns.Drift(ns.Drift(s, d), d) == s
--   ns.Dialects(key)           -> the dialects this character knows for a tongue, the one it speaks first
--   ns.SpokenDialect(key)      -> the dialect this character speaks that tongue in, or nil (plain)
--
-- FROZEN: every line ever sent in a dialect must keep decoding. Never change NormalizePass, Hash, the generator,
-- the pools, how many pairs each gives or the order they're drawn in. tests/pinned.lua pins sample encodings.
local _, ns = ...

---------------------------------------------------------------------------
-- The drift (frozen)
---------------------------------------------------------------------------
-- Consonants common in every tongue that rarely sit in a th/sh/ch pair, so drifted words can still be said.
local CONSONANT_POOL, CONSONANT_PAIRS = "rnlmdktgbvz", 3
local VOWEL_POOL, VOWEL_PAIRS = "aeiou", 1

local PRIME = 2147483647  -- 2^31 - 1: every product below stays exact in Lua's doubles

-- "  Wolves of  the North " and "wolves of the north" are the same passphrase.
local function NormalizePass(pass)
    return (pass:lower():gsub("%s+", " "):match("^ ?(.-) ?$"))
end
ns.NormalizePass = NormalizePass

local function Hash(s)
    local h = 0
    for i = 1, #s do h = (h * 31 + s:byte(i)) % PRIME end
    return h == 0 and 1 or h
end

-- Park-Miller: the same seed gives the same draws on every client (math.random wouldn't). n -> 1..n.
local function Generator(seed)
    local x = seed
    for _ = 1, 8 do x = x * 16807 % PRIME end
    return function(n)
        x = x * 16807 % PRIME
        return x % n + 1
    end
end

-- Shuffles pool and pairs its first letters: a <-> b, c <-> d ...
local function Swaps(pool, count, draw, drift)
    local letters = {}
    for c in pool:gmatch(".") do letters[#letters + 1] = c end
    for i = #letters, 2, -1 do
        local j = draw(i)
        letters[i], letters[j] = letters[j], letters[i]
    end
    for i = 1, count do
        local a, b = letters[2 * i - 1], letters[2 * i]
        drift[a], drift[b] = b, a
    end
end

function ns.DialectDrift(key, pass)
    local draw = Generator(Hash(key .. ":" .. NormalizePass(pass)))
    local drift = {}
    Swaps(CONSONANT_POOL, CONSONANT_PAIRS, draw, drift)
    Swaps(VOWEL_POOL, VOWEL_PAIRS, draw, drift)
    return drift
end

function ns.Drift(s, drift)
    return (s:gsub("[A-Za-z]", function(c)
        local l = c:lower()
        local to = drift[l]
        if not to then return c end
        return c == l and to or to:upper()
    end))
end

---------------------------------------------------------------------------
-- What this character knows (EzTonguesCharDB.dialects: { name, lang, pass } list; .speak[lang] = lowercase name)
---------------------------------------------------------------------------
local drifts = {}  -- lang .. ":" .. pass -> drift, made once (not saved)

local function DriftOf(d)
    local id = d.lang .. ":" .. NormalizePass(d.pass)
    drifts[id] = drifts[id] or ns.DialectDrift(d.lang, d.pass)
    return drifts[id]
end

local function Find(name)
    name = (name or ""):lower()
    for i, d in ipairs(EzTonguesCharDB and EzTonguesCharDB.dialects or {}) do
        if d.name:lower() == name then return d, i end
    end
end

-- { { name, lang, pass, drift }, ... }: copies, so the drift never lands in the saved variables.
function ns.Dialects(key)
    local list, spoken = {}, EzTonguesCharDB and EzTonguesCharDB.speak[key]
    for _, d in ipairs(EzTonguesCharDB and EzTonguesCharDB.dialects or {}) do
        if d.lang == key then
            local entry = { name = d.name, lang = d.lang, pass = d.pass, drift = DriftOf(d) }
            if d.name:lower() == spoken then table.insert(list, 1, entry) else list[#list + 1] = entry end
        end
    end
    return list
end

function ns.SpokenDialect(key)
    local d = Find(EzTonguesCharDB and EzTonguesCharDB.speak[key])
    if d and d.lang == key then return { name = d.name, lang = d.lang, pass = d.pass, drift = DriftOf(d) } end
end

-- Speaks key in the named dialect, or plain with name nil.
function ns.SetSpokenDialect(key, name)
    EzTonguesCharDB.speak[key] = name and name:lower() or nil
end

---------------------------------------------------------------------------
-- Changing them: shared by /tongue dialect and the options page's Dialects subpage. Each returns what it did, or
-- nil and why not, and prints nothing.
---------------------------------------------------------------------------
local function Changed()
    ns.ForgetHeard()
    if ns.RefreshBox then ns.RefreshBox() end
    if ns.RefreshDialectsPage then ns.RefreshDialectsPage() end
end

-- ns.SAMPLE as it sounds in a dialect, tag first: "[Orcish dialect] ...".
function ns.DialectSample(d)
    return ns.Tag(d.lang, true) .. ns.Encode(d.lang, ns.SAMPLE, nil, DriftOf(d))
end

-- Adds a dialect of tongue key and speaks it from then on -> the dialect, or nil and why not.
function ns.AddDialect(key, name, pass)
    name, pass = ns.Trim(name or ""), ns.Trim(pass or "")
    key = ns.ResolveTongue(key)
    if not key then return nil, "Pick a tongue first." end
    if not name:find("^[%a][%a'%-]*$") or #name > 24 then
        return nil, "A dialect's name is one word of letters (an ' or - inside is fine), 24 at most."
    end
    if #NormalizePass(pass) < 4 then return nil, "That passphrase is too short: 4 letters at least, a few words is better." end
    local known = Find(name)
    if known then return nil, ("You already know a dialect called %s."):format(known.name) end
    for _, d in ipairs(EzTonguesCharDB.dialects) do
        if d.lang == key and NormalizePass(d.pass) == NormalizePass(pass) then
            return nil, ("That's %s, which you already know."):format(d.name)
        end
    end
    local d = { name = name, lang = key, pass = pass }
    table.insert(EzTonguesCharDB.dialects, d)
    ns.SetSpokenDialect(key, name)
    Changed()
    return d
end

-- Neither speaks nor reads it any more -> the dialect forgotten, or nil.
function ns.ForgetDialect(name)
    local d, i = Find(name)
    if not d then return end
    table.remove(EzTonguesCharDB.dialects, i)
    if EzTonguesCharDB.speak[d.lang] == d.name:lower() then ns.SetSpokenDialect(d.lang, nil) end
    Changed()
    return d
end

-- Speaks its tongue in the named dialect -> the dialect, or nil.
function ns.UseDialect(name)
    local d = Find(name)
    if not d then return end
    ns.SetSpokenDialect(d.lang, d.name)
    Changed()
    return d
end

-- Speaks tongue key plain again (nil: every tongue). Its dialects are still read.
function ns.PlainDialect(key)
    if key then ns.SetSpokenDialect(key, nil) else wipe(EzTonguesCharDB.speak) end
    Changed()
end

-- Whether this character speaks d's tongue in d.
function ns.SpeaksDialect(d)
    return EzTonguesCharDB.speak[d.lang] == d.name:lower()
end

---------------------------------------------------------------------------
-- /tongue dialect
---------------------------------------------------------------------------
local Print = function(msg) ns.Print(msg) end

local function List()
    local all = EzTonguesCharDB.dialects
    if #all == 0 then
        Print("You know no dialects. /tongue dialect add <lang> <Name> <passphrase> adds one: the same passphrase as your guild's, and you speak and read their dialect.")
        return
    end
    Print("Dialects you know (|cff40ff40spoken|r, the rest you read only):")
    for _, t in ipairs(ns.TONGUES) do
        for _, d in ipairs(all) do
            if d.lang == t.key then
                DEFAULT_CHAT_FRAME:AddMessage(("  %s%s|r - %s, passphrase |cffa0a0a0\"%s\"|r"):format(
                    ns.SpeaksDialect(d) and "|cff40ff40" or "|cffd8d8d8", d.name, t.label, d.pass))
            end
        end
    end
end

local function Add(arg)
    local lang, name, pass = arg:match("^(%S+)%s+(%S+)%s+(.+)$")
    local key = lang and ns.ResolveTongue(lang:lower())
    if not key then
        return Print("/tongue dialect add <lang> <Name> <passphrase>, e.g. /tongue dialect add orcish Bloodfang wolves of the north")
    end
    local d, why = ns.AddDialect(key, name, pass)
    if not d then return Print(why) end
    Print(("You speak %s as %s now (/tongue dialect plain %s to speak it plain again):"):format(ns.Label(key), name, key))
    DEFAULT_CHAT_FRAME:AddMessage("  |cffa0a0a0" .. ns.DialectSample(d) .. "|r")
    if not ns.Knows(key) then Print(("You don't speak %s yet: /tongue learn %s"):format(ns.Label(key), key)) end
end

local function Forget(arg)
    local d = ns.ForgetDialect(ns.Trim(arg))
    if not d then return Print("/tongue dialect forget <name>: the name of a dialect you know (/tongue dialect lists them).") end
    Print(("You've forgotten %s: you no longer speak or read it."):format(d.name))
end

local function Use(arg)
    local d = ns.UseDialect(ns.Trim(arg))
    if not d then return Print("/tongue dialect use <name>: the name of a dialect you know (/tongue dialect lists them).") end
    Print(("You speak %s as %s now."):format(ns.Label(d.lang), d.name))
end

local function Plain(arg)
    arg = ns.Trim(arg):lower()
    local key = ns.ResolveTongue(arg)
    if arg ~= "all" and not key then
        return Print("/tongue dialect plain <lang|all>: speak a tongue plain again (you still read its dialects).")
    end
    ns.PlainDialect(key)
    Print(key and ("You speak %s plain now."):format(ns.Label(key)) or "You speak every tongue plain now.")
end

local HELP = {
    "/tongue dialect add <lang> <Name> <passphrase> - your guild's dialect: same passphrase, same dialect (you speak it from then on)",
    "/tongue dialect use <name> - speak its tongue in that dialect",
    "/tongue dialect plain <lang|all> - speak plain again; you still read your dialects",
    "/tongue dialect forget <name> - neither speak nor read it any more",
}

local SUB = { add = Add, forget = Forget, use = Use, plain = Plain }

function ns.DialectCommand(arg)
    local cmd, rest = ns.Trim(arg):match("^(%S*)%s*(.*)$")
    if SUB[cmd] then return SUB[cmd](rest) end
    List()
    for _, line in ipairs(HELP) do DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
end
