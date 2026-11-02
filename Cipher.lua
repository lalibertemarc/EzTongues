-- EzTongues' letter cipher, for words the dictionary doesn't have (names, rare words, typos). Each language swaps
-- consonants for consonants and vowels for vowels (Data.lua), keeps every letter's case, adds its flavor (a doubled
-- first vowel, a doubled last k...) and puts a marker in front: Thrall -> Dag'Grumm. Dictionary words never start
-- with a marker and an apostrophe, so the marker tells the decoder to come here. Fully reversible.
--   ns.Cipher(tongue, word)    -> the ciphered word
--   ns.Decipher(tongue, word)  -> the English word, or nil if word isn't one of this tongue's ciphered words
local _, ns = ...

-- Fills in a tongue's swap tables, markers and flavor sets (once).
function ns.PrepareCipher(t)
    if t.enc then return end
    t.enc, t.dec = {}, {}
    local function Map(from, to)
        assert(#from == #to, t.key)
        for i = 1, #from do
            local a, b = from:sub(i, i), to:sub(i, i)
            assert(not t.enc[a] and not t.dec[b], t.key .. ": letters must swap one to one")
            t.enc[a], t.dec[b] = b, a
        end
    end
    Map(ns.CONSONANTS, t.consonants)
    Map(ns.VOWELS, t.vowels)
    t.isMarker = {}
    for _, m in ipairs(t.markers) do t.isMarker[m] = true end
    t.last = {}
    for c in (t.doubleLast or ""):gmatch(".") do t.last[c] = true end
end

local function Swap(s, map)
    return (s:gsub("[A-Za-z]", function(c)
        local l = c:lower()
        return c == l and map[l] or map[l]:upper()
    end))
end

-- Shouting stays shouting: flavor letters are capitals when the whole word is (two letters or more).
local function Shouted(s)
    return not s:find("[a-z]") and #s:gsub("[^A-Za-z]", "") >= 2
end

local function Like(c, shouted)
    return shouted and c:upper() or c:lower()
end

function ns.Cipher(t, word)
    local body = Swap(word, t.enc)
    local shouted = Shouted(body)
    if t.doubleVowel then
        local k = body:find("[AEIOUaeiou]")
        if k then body = body:sub(1, k) .. Like(body:sub(k, k), shouted) .. body:sub(k + 1) end
    end
    local last = body:sub(-1)
    if t.last[last:lower()] then body = body .. Like(last, shouted) end
    -- Which marker is only for variety (any of them decodes); the same word always gets the same one.
    local sum, low = 0, word:lower()
    for i = 1, #low do sum = sum + low:byte(i) end
    local m = t.markers[sum % #t.markers + 1]
    if shouted then
        m = m:upper()
    elseif word:find("^[A-Z]") then
        m = m:sub(1, 1):upper() .. m:sub(2)
    end
    return m .. "'" .. body
end

function ns.Decipher(t, word)
    local m, body = word:match("^([A-Za-z]+)'(.+)$")
    if not m or not t.isMarker[m:lower()] then return end
    local last = body:sub(-1):lower()
    if t.last[last] then
        if body:sub(-2, -2):lower() ~= last then return end
        body = body:sub(1, -2)
    end
    if t.doubleVowel then
        local k = body:find("[AEIOUaeiou]")
        if k then
            if body:sub(k + 1, k + 1):lower() ~= body:sub(k, k):lower() then return end
            body = body:sub(1, k) .. body:sub(k + 2)
        end
    end
    return Swap(body, t.dec)
end
