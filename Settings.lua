-- Options page: Esc > Options > AddOns > EzTongues. Built at login, once the saved variables exist.
local _, ns = ...

local HONOR = "Honor system: anyone with EzTongues could read every language, so what your character knows is up to you and your roleplay."

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
    Button("Your dialects", "List", function() ns.DialectCommand("") end,
        "A dialect is a guild's or group's own way of speaking a tongue: /tongue dialect add orcish Bloodfang <passphrase>. Everyone who adds the same passphrase to that tongue reads it; everyone else sees [Orcish dialect] and no translation. Lists the ones you know and the commands in your chat.")

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
