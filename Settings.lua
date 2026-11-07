-- Options page: Esc > Options > AddOns > EzTongues. Built at login, once the saved variables exist. The main page is
-- Blizzard's settings list; dialects get a subpage of their own widgets (a list can't live in the settings list). No
-- inline binding rows or search tags: they taint the options search in Forever.
local _, ns = ...

local HONOR = "Honor system: anyone with EzTongues could read every language, so what your character knows is up to you and your roleplay."

local WIDTH, ROW_HEIGHT, VISIBLE_ROWS = 580, 26, 9
local GREEN, GREY, RED = "|cff40ff40", "|cffa0a0a0", "|cffff6060"

---------------------------------------------------------------------------
-- Dialects subpage: an add form (tongue, name, passphrase) and the dialects this character knows, each with
-- Speak/Plain and a two-click Forget. /tongue dialect changes show here too (ns.RefreshDialectsPage).
---------------------------------------------------------------------------
local function BuildDialectsPage(parent)
    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutSubcategory(parent, panel, "Dialects")
    ns.dialectsPanel = panel

    local function Text(owner, font, text, width)
        local fs = owner:CreateFontString(nil, "ARTWORK", font)
        fs:SetJustifyH("LEFT")
        if width then fs:SetWidth(width) end
        fs:SetText(text)
        return fs
    end

    local function Button(owner, text, width, onClick)
        local b = CreateFrame("Button", nil, owner, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end

    local function Input(width, letters, hint)
        local e = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        e:SetSize(width, 22)
        e:SetAutoFocus(false)
        e:SetMaxLetters(letters)
        local placeholder = e:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        placeholder:SetPoint("LEFT", 2, 0)
        placeholder:SetText(hint)
        -- Only toggles the hint, so it's fine that this also runs on the first show without typing.
        e:SetScript("OnTextChanged", function(self) placeholder:SetShown(self:GetText() == "") end)
        e:SetScript("OnEscapePressed", e.ClearFocus)
        return e
    end

    local title = Text(panel, "GameFontNormalHuge", "Dialects")
    title:SetPoint("TOPLEFT", 16, -16)
    local help = Text(panel, "GameFontHighlightSmall",
        "A dialect is your guild's or group's own way of speaking a tongue. Agree on a passphrase together: everyone who "
        .. "adds the same tongue and passphrase speaks and reads the same dialect (the name is yours to choose; capitals "
        .. "and spaces in the passphrase don't matter). Everyone else sees " .. GREY .. "[Orcish dialect]|r and no translation.",
        WIDTH)
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    -- Add form ------------------------------------------------------------
    local addTitle = Text(panel, "GameFontNormal", "Add a dialect")
    addTitle:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -16)

    local tongueLabel = Text(panel, "GameFontHighlightSmall", "Tongue")
    tongueLabel:SetPoint("TOPLEFT", addTitle, "BOTTOMLEFT", 0, -8)
    local nameLabel = Text(panel, "GameFontHighlightSmall", "Name")
    nameLabel:SetPoint("LEFT", tongueLabel, "LEFT", 146, 0)
    local passLabel = Text(panel, "GameFontHighlightSmall", "Passphrase (the same as your group's)")
    passLabel:SetPoint("LEFT", nameLabel, "LEFT", 146, 0)

    local pickedKey
    local tongue = Button(panel, "", 130)
    tongue:SetPoint("TOPLEFT", tongueLabel, "BOTTOMLEFT", 0, -4)
    local function ShowTongue()
        tongue:SetText(ns.Label(pickedKey))
    end
    tongue:SetScript("OnClick", function(self)
        local items = {}
        for _, t in ipairs(ns.TONGUES) do
            local key = t.key
            items[#items + 1] = {
                text = t.label, note = not ns.Knows(key) and "unknown" or nil, grey = not ns.Knows(key),
                checked = key == pickedKey, func = function() pickedKey = key; ShowTongue() end,
            }
        end
        ns.ToggleList(self, items, 170)
    end)

    local name = Input(124, 24, "e.g. Bloodfang")
    name:SetPoint("LEFT", tongue, "RIGHT", 22, 0)
    local pass = Input(250, 100, "e.g. wolves of the north")
    pass:SetPoint("LEFT", name, "RIGHT", 22, 0)

    local status = Text(panel, "GameFontHighlightSmall", "", WIDTH)
    status:SetPoint("TOPLEFT", tongue, "BOTTOMLEFT", 0, -8)

    local function Add()
        local d, why = ns.AddDialect(pickedKey, name:GetText(), pass:GetText())
        if not d then return status:SetText(RED .. why .. "|r") end
        name:SetText("")
        pass:SetText("")
        name:ClearFocus()
        pass:ClearFocus()
        local warn = ns.Knows(d.lang) and ""
            or ("  " .. RED .. "You don't know %s yet: tick it on the EzTongues page.|r"):format(ns.Label(d.lang))
        status:SetText(("%sAdded %s: you speak %s in it now.|r%s"):format(GREEN, d.name, ns.Label(d.lang), warn))
    end
    local add = Button(panel, "Add", 70, Add)
    add:SetPoint("LEFT", pass, "RIGHT", 10, 0)
    name:SetScript("OnTabPressed", function() pass:SetFocus() end)
    name:SetScript("OnEnterPressed", function() pass:SetFocus() end)
    pass:SetScript("OnTabPressed", function() name:SetFocus() end)
    pass:SetScript("OnEnterPressed", Add)

    -- The list ------------------------------------------------------------
    local listTitle = Text(panel, "GameFontNormal", "Dialects you know")
    listTitle:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -14)
    local legend = Text(panel, "GameFontDisableSmall",
        "You read every dialect you know, and speak each tongue in one of them or plain. Hover a row for a sample line.", WIDTH)
    legend:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -4)

    local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    box:SetSize(WIDTH, ROW_HEIGHT * VISIBLE_ROWS + 10)
    box:SetPoint("TOPLEFT", legend, "BOTTOMLEFT", 0, -6)
    box:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 0.5)
    box:SetBackdropBorderColor(0.6, 0.6, 0.6)

    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", -27, 5)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 32, 1)
    scroll:SetScrollChild(content)

    local empty = box:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    empty:SetPoint("CENTER")
    empty:SetText("No dialects yet. Agree on a passphrase with your group and add it above.")

    local rows, armed = {}, nil  -- armed: the row whose Forget was clicked once
    local function Row(i)
        if rows[i] then return rows[i] end
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(WIDTH - 32, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:EnableMouse(true)
        row.name = Text(row, "GameFontHighlight", "", 120)
        row.name:SetPoint("LEFT", 6, 0)
        row.name:SetWordWrap(false)
        row.tongue = Text(row, "GameFontHighlightSmall", "", 110)
        row.tongue:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.tongue:SetWordWrap(false)
        -- Two clicks: the first arms it, leaving the button disarms it.
        row.forget = Button(row, "Forget", 66, function(self)
            if armed ~= row then
                armed = row
                return self:SetText(RED .. "Sure?|r")
            end
            armed = nil
            local d = ns.ForgetDialect(row.dialect.name)
            if d then status:SetText(("Forgot %s: you no longer speak or read it."):format(d.name)) end
        end)
        row.forget:SetHeight(20)
        row.forget:SetPoint("RIGHT", -2, 0)
        row.forget:SetScript("OnLeave", function(self)
            if armed == row then armed = nil end
            self:SetText("Forget")
        end)
        row.speak = Button(row, "", 90, function()
            local d = row.dialect
            if ns.SpeaksDialect(d) then ns.PlainDialect(d.lang) else ns.UseDialect(d.name) end
        end)
        row.speak:SetHeight(20)
        row.speak:SetPoint("RIGHT", row.forget, "LEFT", -4, 0)
        row.pass = Text(row, "GameFontDisableSmall", "")
        row.pass:SetPoint("LEFT", row.tongue, "RIGHT", 6, 0)
        row.pass:SetPoint("RIGHT", row.speak, "LEFT", -8, 0)
        row.pass:SetWordWrap(false)
        row:SetScript("OnEnter", function(self)
            local d = self.dialect
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(d.name .. ", a dialect of " .. ns.Label(d.lang), 1, 1, 1)
            GameTooltip:AddLine("Passphrase: \"" .. d.pass .. "\"", 0.75, 0.75, 0.75, true)
            GameTooltip:AddLine(ns.SpeaksDialect(d) and "You speak it." or "You read it; you speak " .. ns.Label(d.lang)
                .. " " .. (ns.SpokenDialect(d.lang) and "in " .. ns.SpokenDialect(d.lang).name or "plain") .. ".",
                0.75, 0.75, 0.75, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns.DialectSample(d), 0.71, 0.56, 0.88, true)
            GameTooltip:AddLine("\"" .. ns.SAMPLE .. "\"", 0.75, 0.75, 0.75, true)
            if not ns.Knows(d.lang) then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(("You don't know %s: tick it on the EzTongues page to speak and read it.")
                    :format(ns.Label(d.lang)), 1, 0.38, 0.38, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = row
        return row
    end

    local function Refresh()
        local n = 0
        armed = nil
        for _, t in ipairs(ns.TONGUES) do
            for _, d in ipairs(EzTonguesCharDB.dialects) do
                if d.lang == t.key then
                    n = n + 1
                    local row = Row(n)
                    local spoken = ns.SpeaksDialect(d)
                    row.dialect = d
                    row.name:SetText(spoken and GREEN .. d.name .. "|r" or d.name)
                    row.tongue:SetText(ns.Knows(d.lang) and t.label or RED .. t.label .. " (unknown)|r")
                    row.pass:SetText("\"" .. d.pass .. "\"")
                    row.speak:SetText(spoken and "Speak plain" or "Speak it")
                    row.forget:SetText("Forget")
                    row:Show()
                end
            end
        end
        for i = n + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(1, n * ROW_HEIGHT))
        empty:SetShown(n == 0)
    end
    function ns.RefreshDialectsPage()
        if panel:IsShown() then Refresh() end
    end

    -- Run on show, so /tongue dialect changes and newly ticked tongues are picked up.
    panel:SetScript("OnShow", function()
        pickedKey = pickedKey or ns.Default()
        ShowTongue()
        status:SetText("")
        Refresh()
    end)
    -- For tests/smoke.lua.
    panel.ui = { tongue = tongue, name = name, pass = pass, add = add, status = status, rows = rows }
    return category
end

function ns.BuildSettings(start)
    local category, layout = Settings.RegisterVerticalLayoutCategory("EzTongues")
    ns.settingsCategory = category

    local function Header(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function Button(name, text, onClick, tooltip)
        layout:AddInitializer(CreateSettingsButtonInitializer(name, text, onClick, tooltip, false))
    end

    local starts = {}
    for _, key in ipairs(start) do starts[key] = true end

    Header("Languages you know (honor system)")
    -- Per character. A line in a language you know gets its translation; one you don't, at most its name.
    for _, t in ipairs(ns.TONGUES) do
        local setting = Settings.RegisterAddOnSetting(category, "EZTONGUES_KNOW_" .. t.key, t.key,
            EzTonguesCharDB.known, Settings.VarType.Boolean, t.label, starts[t.key] == true)
        Settings.CreateCheckbox(category, setting, t.desc .. "\n\nWhen someone speaks it, you see what they said. " .. HONOR)
    end

    Header("Speaking")
    local default = Settings.RegisterAddOnSetting(category, "EZTONGUES_DEFAULT", "default", EzTonguesCharDB,
        Settings.VarType.String, "Default language", start[1] or ns.TONGUES[1].key)
    Settings.CreateDropdown(category, default, function()
        local container = Settings.CreateControlTextContainer()
        for _, t in ipairs(ns.TONGUES) do container:Add(t.key, t.label, t.desc) end
        return container:GetData()
    end, "What /tongue <text> and the box speak in. /tongue <language> <text> speaks any other one you know.")
    local tag = Settings.RegisterAddOnSetting(category, "EZTONGUES_TAG", "tag", EzTonguesDB,
        Settings.VarType.Boolean, "Name the language in your lines", ns.DEFAULTS.tag)
    Settings.CreateCheckbox(category, tag,
        "Starts your lines with the language, as NPCs' lines do: [Orcish] Lok'tar ogar! Everyone sees it, with EzTongues or not.")
    Button("Sample line", "Preview", function() ns.Test(ns.SAMPLE) end,
        "Prints a sample line in your default language, and its translation, to your chat. Only you see it.")
    Button("Tongue box", "Open", function() ns.OpenBox() end,
        "A small edit box of its own: Enter says the line, a leading /y, /p, /w name... picks the channel, the dropdown picks the language, Escape closes it. Drag it to move it.")
    Button("Box position", "Reset", function() ns.ResetBox() end, "Puts the box back above your action bars.")
    -- No inline binding rows or search tags: they taint the options search in Forever.
    Button("Key binding", "Key Bindings",
        function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, "EzTongues") end,
        "Bind a key to open the box in the EzTongues section of the Key Bindings page.")

    Header("Dialects")
    local dialects = BuildDialectsPage(category)
    Button("Your dialects", "Manage", function() Settings.OpenToCategory(dialects:GetID()) end,
        "A dialect is your guild's or group's own way of speaking a tongue: a passphrase you share. Everyone who adds the same passphrase to that tongue reads it; everyone else sees [Orcish dialect] and no translation. Opens the Dialects page (under EzTongues in the list on the left) to add, speak and forget them.")

    Header("Hearing")
    local showName = Settings.RegisterAddOnSetting(category, "EZTONGUES_SHOW_NAME", "showName", EzTonguesDB,
        Settings.VarType.Boolean, "Name languages you don't know", ns.DEFAULTS.showName)
    Settings.CreateCheckbox(category, showName,
        "Adds (Thalassian) after a line in a language your character doesn't know, so you know what you're not understanding. Lines that start with [Thalassian] already say it.")
    local color = Settings.RegisterAddOnSetting(category, "EZTONGUES_COLOR", "color", EzTonguesDB,
        Settings.VarType.String, "Translation color", ns.DEFAULTS.color)
    Settings.CreateDropdown(category, color, function()
        local container = Settings.CreateControlTextContainer()
        for _, c in ipairs(ns.COLORS) do container:Add(c.key, "|cff" .. c.hex .. c.label .. "|r") end
        return container:GetData()
    end, "The color of the translation added after the line.")

    Settings.RegisterAddOnCategory(category)
end
