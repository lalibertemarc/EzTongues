-- EzTongues' box, as in EzAccent: an edit box of its own, like the chat's. The dropdown on the left picks the
-- language (it's also your default) or one of its dialects. The channel shows at the start of the line ("Say:", "Tell Bob Smith:"); start
-- a line the way chat does to switch it (/y, /p, /e ... or /w name, then a space), click it for a list of channels
-- and people to whisper, or press Tab to whisper the next person the box knows (your target, people you whispered
-- with, your group). Enter says the line, Escape closes the box, Up/Down go through this session's lines. A line
-- too long for one message leaves pieces waiting (ns.Waiting): the box stays open and each Enter on an empty line
-- says the next one; Escape drops them. A click outside it lets go of the keyboard (so you can move) and leaves it open; a click on it, or its key, takes the
-- keyboard back.
local _, ns = ...

local MAX = 255  -- chat message limit, in bytes
local ROW = 18   -- dropdown row height

local box, edit, langButton, header, hint, list
local channel, whisperTo = "SAY", nil  -- the box's channel (and whom it whispers), kept for the session
local skipWord  -- after "/w bob " filled in Bob's surname: the surname, skipped if typed next
local held      -- the line you had when you picked "Whisper..." from the list: it comes back once the name is in
local history, historyAt = {}, 0

local Trim = ns.Trim

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

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

---------------------------------------------------------------------------
-- Dropdown list: one flat frame of its own (Blizzard menus break in combat). items: { text, note, color = {r, g, b},
-- grey, checked, func }. A click anywhere else closes it; so does a click on what opened it.
---------------------------------------------------------------------------
local function MakeList()
    local l = CreateFrame("Frame", "EzTonguesBoxList", UIParent, "BackdropTemplate")
    l:SetFrameStrata("FULLSCREEN_DIALOG")
    l:SetClampedToScreen(true)
    l:EnableMouse(true)
    l:SetBackdrop(BACKDROP)
    l:SetBackdropColor(0, 0, 0, 0.95)
    l:Hide()
    l.rows = {}
    l:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    l:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    l:SetScript("OnEvent", function(self)
        if not (self:IsMouseOver() or self.owner:IsMouseOver()) then self:Hide() end
    end)
    return l
end

local function Row(i)
    local b = list.rows[i]
    if b then return b end
    b = CreateFrame("Button", nil, list)
    b:SetHeight(ROW)
    b:SetPoint("TOPLEFT", 5, -5 - (i - 1) * ROW)
    b:SetPoint("RIGHT", -5, 0)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetSize(6, 6)
    b.mark:SetPoint("LEFT", 6, 0)
    b.mark:SetColorTexture(0.71, 0.56, 0.88)
    b.note = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.note:SetPoint("RIGHT", -4, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", 18, 0)
    b.text:SetPoint("RIGHT", b.note, "LEFT", -6, 0)
    b.text:SetJustifyH("LEFT")
    b:SetScript("OnClick", function(self)
        list:Hide()
        if self.func then self.func() end
    end)
    list.rows[i] = b
    return b
end

-- Opens under owner (or over it, when the box sits too low), or closes it if owner's list is already open.
local function ToggleList(owner, items, width)
    list = list or MakeList()
    if list:IsShown() and list.owner == owner then return list:Hide() end
    list.owner = owner
    for i, item in ipairs(items) do
        local b = Row(i)
        b.text:SetText(item.text)
        b.note:SetText(item.note or "")
        local c = item.color or { 1, 1, 1 }
        if item.grey then b.text:SetTextColor(0.55, 0.55, 0.55) else b.text:SetTextColor(c[1], c[2], c[3]) end
        b.mark:SetShown(item.checked or false)
        b.func = item.func
        b:Show()
    end
    for i = #items + 1, #list.rows do list.rows[i]:Hide() end
    local height = 10 + #items * ROW
    list:SetSize(width, height)
    list:ClearAllPoints()
    if (owner:GetBottom() or 0) < height + 10 then
        list:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
    else
        list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    end
    list:Show()
end
ns.ToggleList = ToggleList  -- the options page's Dialects subpage picks its tongue with it too

---------------------------------------------------------------------------
-- Channel and whisper name
---------------------------------------------------------------------------
local function MenuEntry(chatType)
    for _, m in ipairs(ns.BOX_MENU) do
        if m.chatType == chatType then return m end
    end
end

-- Greyed in the list when you can't talk there right now (picking it anyway lets the game say why).
local function Available(m)
    if m.need == "group" then return IsInGroup() end
    if m.need == "raid" then return IsInRaid() end
    if m.need == "guild" then return IsInGuild() end
    return true
end

local function ChatColor(chatType)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if info and info.r then return { info.r, info.g, info.b } end
    return { 1, 1, 1 }
end

local function UpdateHint()
    local waiting = ns.Waiting()
    if waiting > 0 then
        hint:SetText(("Enter: say the next piece (%d)  Esc: drop"):format(waiting))
    elseif edit:HasFocus() then
        hint:SetText(channel == "WHISPER" and "Tab: next name  Esc: close" or "Tab: whisper  /y /p /w name: switch")
    else
        hint:SetText("Click here to type")
    end
end

-- The label at the start of the line, in the channel's chat color, and the line in that color too.
local function SetChannel(chatType, to)
    if chatType == "WHISPER" then
        whisperTo = to or whisperTo
        if not whisperTo then return end
    end
    channel = chatType
    local c = ChatColor(chatType)
    header.label:SetText(chatType == "WHISPER" and "Tell " .. whisperTo .. ":" or MenuEntry(chatType).label .. ":")
    header.label:SetTextColor(c[1], c[2], c[3])
    local width = (header.label:GetStringWidth() or 0) + 4
    header:SetWidth(width)
    edit:SetTextInsets(width + 4, 0, 0, 0)
    edit:SetTextColor(c[1], c[2], c[3])
    UpdateHint()
end

-- An unfinished "/w name" at the start of the line (from "Whisper..." or typed) goes when you pick another channel
-- or person; the line you had before "Whisper..." comes back.
local function DropWhisperCommand()
    local cmd = edit:GetText():match("^/(%S+)")
    if not (cmd and ns.BOX_CHANNELS[cmd:lower()] == "WHISPER") then return end
    local line = held or ""
    held = nil
    edit:SetText(line)
    edit:SetCursorPosition(#line)
end

-- Tab: whisper the next person the box knows (the first one, when you weren't whispering).
local function NextName()
    local names, at = ns.WhisperNames(), 0
    if #names == 0 then return ns.Print("Nobody to whisper yet: target someone, or start the line with /w name.") end
    DropWhisperCommand()
    for i, p in ipairs(names) do
        if channel == "WHISPER" and p.name == whisperTo then at = i end
    end
    SetChannel("WHISPER", names[at % #names + 1].name)
end

-- The list: channels, then the people you can whisper, then "Whisper..." for anyone else (it starts the line
-- with /w: type the name and a space).
local function ToggleChannels()
    local items = {}
    for _, m in ipairs(ns.BOX_MENU) do
        local chatType = m.chatType
        local color = ChatColor(chatType)
        if chatType == "WHISPER" then
            for _, p in ipairs(ns.WhisperNames()) do
                items[#items + 1] = {
                    text = p.name, note = p.why, color = color,
                    checked = channel == "WHISPER" and p.name == whisperTo,
                    func = function()
                        DropWhisperCommand()
                        SetChannel("WHISPER", p.name)
                        edit:SetFocus()
                    end,
                }
            end
            items[#items + 1] = {
                text = m.label .. "...", note = m.cmd, color = color,
                func = function()
                    -- An unfinished command ("/w Na", picked twice) is no line to give back: keep the one held.
                    local line = edit:GetText()
                    local cmd = line:match("^/(%S+)")
                    if not (cmd and ns.BOX_CHANNELS[cmd:lower()]) then
                        held = Trim(line) ~= "" and line or nil
                    end
                    edit:SetText("/w ")
                    edit:SetFocus()
                    edit:SetCursorPosition(3)
                end,
            }
        else
            items[#items + 1] = {
                text = m.label, note = m.cmd, color = color, grey = not Available(m), checked = chatType == channel,
                func = function()
                    DropWhisperCommand()
                    SetChannel(chatType)
                    edit:SetFocus()
                end,
            }
        end
    end
    ToggleList(header, items, 220)
end

-- The line without the surname skipWord waits for, once a first word (or a leading space) is there.
local function SkipSurname(text)
    local word, after = text:match("^(%S*)%s(.*)$")
    if not (skipWord and word) then return text end
    local skip = skipWord
    skipWord = nil
    return word:lower() == skip:lower() and after or text
end

-- Typing a channel command and a space switches the box to it, as in chat: "/p " is party, "/w Bob " whispers Bob
-- (with his surname, if the box knows him), "/w "First Surname" " anyone. Forever whispers need the surname, so
-- there a first name the box doesn't know waits for one: "/w Bob Smith ".
local function SwitchFromText(self)
    local text = self:GetText()
    if skipWord then
        local skipped = SkipSurname(text)
        if skipped ~= text then return self:SetText(skipped) end
    end
    local cmd, rest = text:match("^/(%S+)%s(.*)$")
    local chatType = cmd and ns.BOX_CHANNELS[cmd:lower()]
    if not chatType then return end
    local to
    if chatType == "WHISPER" then
        local after
        to, after = rest:match('^"([^"]+)"%s(.*)$')
        if not to then
            local first, more = rest:match('^([^%s"]+)%s(.*)$')
            if not first then return end
            to = ns.ResolveName(first)
            if not to then return end
            if to ~= first then
                skipWord = to:match("^[^%s%-]+[%s%-](.+)$")
                after = more
            elseif ns.ERA then
                after = more
            else
                local surname
                surname, after = more:match("^(%S+)%s(.*)$")
                if not surname then return end
                to = first .. " " .. surname
            end
        end
        rest = SkipSurname(after)
    end
    SetChannel(chatType, to)
    rest = rest .. (held or "")
    held = nil
    self:SetText(rest)
    self:SetCursorPosition(#rest)
end

-- The language: a dropdown listing every tongue, the ones you don't know greyed, each followed by the dialects you
-- know of it. Picking a dialect speaks its tongue in it; picking the tongue speaks it plain.
local function ShowLanguage()
    local key = ns.Default()
    local dialect = ns.SpokenDialect(key)
    langButton:SetText(dialect and dialect.name or ns.Label(key))
    box.title:SetText("EzTongues" .. (dialect and "  |cffa0a0a0" .. ns.Label(key) .. ", " .. dialect.name .. " dialect|r" or "") ..
        (ns.Knows(key) and "" or "  |cffff6060(you don't know it)|r"))
end

function ns.RefreshBox()
    if box and box:IsShown() then ShowLanguage() end
end

local function ToggleLanguages()
    local items = {}
    for _, t in ipairs(ns.TONGUES) do
        local key = t.key
        local known, spoken = ns.Knows(key), ns.SpokenDialect(key)
        local function Pick(name)
            return function()
                EzTonguesCharDB.default = key
                ns.SetSpokenDialect(key, name)
                ShowLanguage()
                edit:SetFocus()
            end
        end
        items[#items + 1] = {
            text = t.label, note = not known and "unknown" or nil, grey = not known,
            checked = key == ns.Default() and not spoken, func = Pick(nil),
        }
        for _, d in ipairs(ns.Dialects(key)) do
            items[#items + 1] = {
                text = "   " .. d.name, note = "dialect", grey = not known,
                checked = key == ns.Default() and spoken and spoken.name == d.name, func = Pick(d.name),
            }
        end
    end
    ToggleList(langButton, items, 170)
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function Remember(text)
    local last = history[#history]
    local to = channel == "WHISPER" and whisperTo or nil
    if not (last and last.text == text and last.channel == channel and last.to == to) then
        history[#history + 1] = { text = text, channel = channel, to = to }
    end
    if #history > 20 then table.remove(history, 1) end
end

local function Say(text)
    Remember(text)
    -- A line that still starts with a command ("/y" and Enter, "/w bob" without a line yet) goes the slash way.
    local cmd, rest = Trim(text):match("^/(%S+)%s*(.*)$")
    local chatType = cmd and ns.BOX_CHANNELS[cmd:lower()]
    if chatType then return ns.SayTo(ns.Default(), chatType, rest) end
    ns.Say(ns.Default(), text, channel, channel == "WHISPER" and whisperTo or nil)
end

-- Enter: the line, or (on an empty line) the next piece waiting. The box stays open while pieces wait.
local function Send()
    local text = edit:GetText() .. (held or "")
    skipWord, held = nil, nil
    edit:SetText("")
    if Trim(text) ~= "" then
        Say(text)
    elseif not ns.SendNext() then
        return box:Hide()
    end
    if ns.Waiting() > 0 then UpdateHint() else box:Hide() end
end

-- Escape and the ×: close, dropping the pieces still waiting.
local function Close()
    ns.DropWaiting()
    box:Hide()
end

---------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------
local function MakeBox()
    local f = CreateFrame("Frame", "EzTonguesBox", UIParent, "BackdropTemplate")
    f:SetSize(520, 56)
    PlaceBox(f)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(BACKDROP)
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
    hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPRIGHT", -24, -8)
    -- Never over the title: a hint too long for the space left is cut short.
    hint:SetPoint("LEFT", f.title, "RIGHT", 12, 0)
    hint:SetJustifyH("RIGHT")
    hint:SetWordWrap(false)

    -- Own OnClick: the template's HideUIPanel is blocked in combat.
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", 1, 1)
    close:SetScript("OnClick", Close)

    -- The language: a dropdown.
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    langButton = b
    b:SetSize(112, 22)
    b:SetPoint("BOTTOMLEFT", 8, 6)
    local label = b:GetFontString()
    label:ClearAllPoints()
    label:SetPoint("LEFT", 8, 0)
    label:SetPoint("RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(18, 18)
    arrow:SetPoint("RIGHT", -2, 0)
    b:SetScript("OnClick", ToggleLanguages)

    local e = CreateFrame("EditBox", "EzTonguesBoxEdit", f)
    edit = e
    e:SetFontObject(ChatFontNormal)
    e:SetPoint("TOPLEFT", b, "TOPRIGHT", 8, 0)
    e:SetPoint("BOTTOMRIGHT", -10, 6)
    e:SetAutoFocus(false)
    e:SetMaxLetters(MAX)
    e:SetScript("OnEnterPressed", Send)
    e:SetScript("OnEscapePressed", Close)
    e:SetScript("OnTextChanged", function(self, userInput)
        if userInput then SwitchFromText(self) end
    end)
    e:SetScript("OnTabPressed", NextName)
    e:SetScript("OnArrowPressed", function(self, key)
        if #history == 0 or (key ~= "UP" and key ~= "DOWN") then return end
        historyAt = math.max(1, math.min(#history + 1, historyAt + (key == "UP" and -1 or 1)))
        local h = history[historyAt]
        if h then SetChannel(h.channel, h.to) end
        self:SetText(h and h.text or "")
        self:SetCursorPosition(#self:GetText())
    end)
    e:SetScript("OnEditFocusGained", UpdateHint)
    e:SetScript("OnEditFocusLost", UpdateHint)

    -- The channel, at the start of the line: a click lists channels and names.
    header = CreateFrame("Button", "EzTonguesBoxHeader", e)
    header:SetPoint("TOPLEFT")
    header:SetPoint("BOTTOMLEFT")
    header.label = header:CreateFontString(nil, "OVERLAY")
    header.label:SetFontObject(ChatFontNormal)
    header.label:SetPoint("LEFT")
    header:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    header:SetScript("OnClick", ToggleChannels)

    f:SetScript("OnMouseDown", function() e:SetFocus() end)
    f:SetScript("OnShow", function()
        ShowLanguage()
        historyAt = #history + 1
        SetChannel(channel)
        e:SetFocus()
    end)
    f:SetScript("OnHide", function()
        e:ClearFocus()
        if list then list:Hide() end
    end)

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

-- Other addons (EzAcquaintances' book): the box on a whisper to name ("First Surname"), open or not. The box stays on
-- them, as if picked from the list.
function ns.OpenWhisper(name)
    whisperTo, channel = name, "WHISPER"
    if box and box:IsShown() then
        SetChannel("WHISPER", name)
        edit:SetFocus()
    else
        OpenBox()
    end
    DropWhisperCommand()
end

-- For other addons: EzTonguesAPI.Whisper("First Surname") opens the box on a whisper to them.
EzTonguesAPI = {
    Whisper = function(name) ns.OpenWhisper(name) end,
    -- EzLines: { { key, label, known }, ... } in EzTongues' order.
    Tongues = function()
        local out = {}
        for _, t in ipairs(ns.TONGUES) do out[#out + 1] = { key = t.key, label = t.label, known = ns.Knows(t.key) } end
        return out
    end,
    -- EzLines: the messages for text in tongue key (tagged, %t filled in, only the "quoted" parts of an emote), none
    -- past 255 bytes; nil and why when this character doesn't speak it. Sends nothing.
    Lines = function(key, text, chatType)
        key = ns.ResolveTongue(key)
        if not key then return nil, "unknown tongue" end
        if not ns.Knows(key) then return nil, "you don't speak " .. ns.Label(key) end
        return ns.Lines(key, text, chatType)
    end,
}

function ns.ResetBox()
    EzTonguesDB.box = nil
    if box then PlaceBox(box) end
    ns.Print("Box moved back to its first spot.")
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
