-- EzTongues' line codec. A line goes out word by word: a lore phrase if one matches (longest first), else the
-- dictionary's native word (Dictionary.lua), else the letter cipher (Cipher.lua). Every step can be undone, so the
-- line alone carries its meaning and decode(encode(x)) == x.
--   ns.Encode(key, line[, glue]) -> the line in that tongue (glue: phrase spaces become \1 so Split keeps them whole)
--   ns.Decode(key, line)         -> the English line, or nil unless every word is one of that tongue's
--   ns.Detect(line)              -> key, English line: the tongue a whole line is in, or nil
--   ns.Split(line, max)          -> the line cut at spaces into chat messages of at most max bytes
-- A word is letters with single apostrophes inside (don't, Kel'Thuzad); case is kept as lower, Capitalized or ALL
-- CAPS (a MiXeD word is ciphered, which keeps every letter's case). Chat links (|H...|h...|h and other | escapes),
-- {skull}-style tokens and %t are never touched: they're swapped for {1}, {2}... while the codec works.
local _, ns = ...

local concat = table.concat

---------------------------------------------------------------------------
-- Protected tokens (as in EzAccent, plus any other | escape)
---------------------------------------------------------------------------
-- The last one catches any other escape (|n, ||), so a letter after a | is never touched.
local ESCAPES = { "^|c[^|]*|H.-|h.-|h|r", "^|H.-|h.-|h", "^|T.-|t", "^|A.-|a", "^|K.-|k", "^|c%x%x%x%x%x%x%x%x",
                  "^|r", "^|." }

local function Protect(line)
    local saved, out, i = {}, {}, 1
    while i <= #line do
        local c, s, e = line:sub(i, i)
        if c == "|" then
            for _, p in ipairs(ESCAPES) do
                s, e = line:find(p, i)
                if s then break end
            end
        elseif c == "{" then
            s, e = line:find("^{[^{}]*}", i)
        elseif c == "%" then
            s, e = line:find("^%%%a", i)
        end
        if s then
            saved[#saved + 1] = line:sub(s, e)
            out[#out + 1] = "{" .. #saved .. "}"
            i = e + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return concat(out), saved
end

local function Restore(line, saved)
    return (line:gsub("{(%d+)}", function(n) return saved[tonumber(n)] end))
end

---------------------------------------------------------------------------
-- Words and case
---------------------------------------------------------------------------
-- Calls fn on every word of s and puts back what it returns; nil if fn ever returns nil.
local function MapWords(s, fn)
    local out, i, n = {}, 1, #s
    while i <= n do
        local a, b = s:find("^[A-Za-z]+", i)
        if a then
            while true do
                local _, d = s:find("^'[A-Za-z]+", b + 1)
                if not d then break end
                b = d
            end
            local r = fn(s:sub(a, b))
            if not r then return end
            out[#out + 1] = r
            i = b + 1
        else
            local nxt = s:find("[A-Za-z]", i) or n + 1
            out[#out + 1] = s:sub(i, nxt - 1)
            i = nxt
        end
    end
    return concat(out)
end

-- "lower", "cap" (first letter only; a lone capital too), "upper" (two letters or more) or "mixed".
local function Case(w)
    local up = w:find("[A-Z]")
    if not up then return "lower" end
    if not w:find("[a-z]") then
        return #w:gsub("[^A-Za-z]", "") >= 2 and "upper" or "cap"
    end
    if up == 1 and not w:find("[A-Z]", 2) then return "cap" end
    return "mixed"
end

local function ApplyCase(w, case)
    if case == "upper" then return w:upper() end
    if case == "cap" then return w:sub(1, 1):upper() .. w:sub(2) end
    return w
end

local function IsLetter(s, p)
    return p >= 1 and s:find("^[A-Za-z]", p) ~= nil
end

-- s:sub(i, j) is whole words: no letter, nor an apostrophe and a letter, right before or after it.
local function WholeWords(s, i, j)
    if IsLetter(s, i - 1) or (s:sub(i - 1, i - 1) == "'" and IsLetter(s, i - 2)) then return false end
    if IsLetter(s, j + 1) or (s:sub(j + 1, j + 1) == "'" and IsLetter(s, j + 2)) then return false end
    return true
end

-- A phrase only counts typed all lower case, Sentence case or ALL CAPS (anything else goes word by word).
local function PhraseCase(s, low)
    if s == low then return "lower" end
    if s == low:upper() then return "upper" end
    if s == low:sub(1, 1):upper() .. low:sub(2) then return "cap" end
end

---------------------------------------------------------------------------
-- Tongues
---------------------------------------------------------------------------
local byKey = {}
for _, t in ipairs(ns.TONGUES) do byKey[t.key] = t end

local function ByLength(a, b)
    if #a.from ~= #b.from then return #a.from > #b.from end
    return a.from < b.from
end

-- The tongue's tables, built on first use: natives (native -> English) and the phrase lists. Every tongue gets
-- them as soon as chat is heard; words (English -> native) only once you speak it.
local function Tongue(key)
    local t = byKey[key]
    if not t or t.natives then return t end
    ns.PrepareCipher(t)
    local natives = {}
    for en, nat in (ns.DICTIONARY[key] or ""):gmatch("(%S+) (%S+)") do natives[nat] = en end
    t.toNative, t.toEnglish = {}, {}
    for _, p in ipairs(t.phrases) do
        t.toNative[#t.toNative + 1] = { from = p[1]:lower(), to = p[2]:lower() }
        t.toEnglish[#t.toEnglish + 1] = { from = p[2]:lower(), to = p[1]:lower() }
    end
    table.sort(t.toNative, ByLength)
    table.sort(t.toEnglish, ByLength)
    t.natives = natives
    return t
end
ns.Tongue = Tongue

local function Speaking(key)
    local t = Tongue(key)
    if not t.words then
        t.words = {}
        for nat, en in pairs(t.natives) do t.words[en] = nat end
    end
    return t
end

-- Swaps every phrase of list in s for a {n} sentinel holding its other side; returns s and how many it swapped.
local function SwapPhrases(s, list, saved, glue)
    local low, count = s:lower(), 0
    for _, p in ipairs(list) do
        local start = 1
        while true do
            local i, j = low:find(p.from, start, true)
            if not i then break end
            local case = WholeWords(s, i, j) and PhraseCase(s:sub(i, j), p.from)
            if case then
                local to = case == "upper" and p.to:upper() or case == "cap" and ApplyCase(p.to, "cap") or p.to
                if glue then to = to:gsub(" ", "\1") end
                saved[#saved + 1] = to
                local tag = "{" .. #saved .. "}"
                s = s:sub(1, i - 1) .. tag .. s:sub(j + 1)
                low = low:sub(1, i - 1) .. tag .. low:sub(j + 1)
                start = i + #tag
                count = count + 1
            else
                start = i + 1
            end
        end
    end
    return s, count
end

function ns.Encode(key, line, glue)
    local t = Speaking(key)
    local s, saved = Protect(line)
    s = SwapPhrases(s, t.toNative, saved, glue)
    s = MapWords(s, function(w)
        local case = Case(w)
        local nat = case ~= "mixed" and t.words[w:lower()]
        return nat and ApplyCase(nat, case) or ns.Cipher(t, w)
    end)
    return Restore(s, saved)
end

local function DecodeProtected(t, s, saved)
    local phrases, n
    s, phrases = SwapPhrases(s, t.toEnglish, saved)
    n = 0
    s = MapWords(s, function(w)
        n = n + 1
        local case = Case(w)
        local en = case ~= "mixed" and t.natives[w:lower()]
        if en then return ApplyCase(en, case) end
        return ns.Decipher(t, w)
    end)
    if not s or n + phrases == 0 then return end
    return Restore(s, saved)
end

function ns.Decode(key, line)
    local s, saved = Protect(line)
    return DecodeProtected(Tongue(key), s, saved)
end

-- A line is in a tongue when every word in it is that tongue's (native words and markers are never shared, so at
-- most one tongue fits, but for lines made only of phrases two tongues share). Plain English never fits: native
-- words are never common English words.
function ns.Detect(line)
    local s, saved = Protect(line)
    if not s:find("[A-Za-z]") then return end
    local n = #saved
    for _, t in ipairs(ns.TONGUES) do
        for k = #saved, n + 1, -1 do saved[k] = nil end
        local english = DecodeProtected(Tongue(t.key), s, saved)
        if english then return t.key, english end
    end
end

-- Cut at spaces (never inside a link or a glued phrase) into messages of at most max bytes; a single longer word
-- goes alone.
function ns.Split(text, max)
    local text2, saved = Protect(text)
    local out, cur = {}, ""
    for word in text2:gmatch("%S+") do
        word = Restore(word, saved):gsub("\1", " ")
        if cur == "" then
            cur = word
        elseif #cur + 1 + #word <= max then
            cur = cur .. " " .. word
        else
            out[#out + 1] = cur
            cur = word
        end
    end
    if cur ~= "" then out[#out + 1] = cur end
    return out
end
