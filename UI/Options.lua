-- Scrollkeeper: UI/Options.lua
-- The settings page in the game's own Options > AddOns list.
-- Open it with /sk options or the * button on the panel.

local _, SK = ...

local category

-- One checkbox. `key` is the name of the setting in the saved table.
local function AddCheckbox(key, label, tooltip, default)
    local setting = Settings.RegisterAddOnSetting(category, "Scrollkeeper_" .. key, key, SK.db,
        "boolean", label, default)
    setting:SetValueChangedCallback(function()
        if SK.ApplyPanelSettings then SK.ApplyPanelSettings() end
        if SK.Net and (key == "share" or key == "shareChannel") then SK.Net.UpdateChannel() end
        SK.Send("DROPS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddScaleSlider()
    local setting = Settings.RegisterAddOnSetting(category, "Scrollkeeper_scale", "scale", SK.db,
        "number", "Panel size", 1)
    setting:SetValueChangedCallback(function() SK.ApplyPanelSettings() end)
    local options = Settings.CreateSliderOptions(0.7, 1.5, 0.05)
    if MinimalSliderWithSteppersMixin and options.SetLabelFormatter then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return ("%d%%"):format(value * 100 + 0.5)
        end)
    end
    Settings.CreateSlider(category, setting, options, "How big the panel is.")
end

SK.Listen("READY", function()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end

    SK.Safely("settings page", function()
        category = Settings.RegisterVerticalLayoutCategory("Scrollkeeper")

        AddCheckbox("showPanel", "Show the panel",
            "The window with your Comprehension, scrolls and Study timer. Mages only.", true)
        AddCheckbox("locked", "Lock position",
            "Stops the panel from being dragged.", false)
        AddCheckbox("showScrollBar", "Scroll buttons",
            "Adds a button to the panel for each kind of translated scroll in your bags. Click one to use it.", true)
        AddCheckbox("showTooltips", "Tooltip lines",
            "Mages see whether they can decipher a scroll. Other classes see that it is a mage scroll.", true)
        AddCheckbox("announce", "Decipher messages",
            "Prints a chat line such as \"deciphered: Scroll of Frog Familiar\".", true)

        AddCheckbox("share", "Share with other players",
            "Talk to other Scrollkeeper users in your guild and group: what scrolls became, where they drop, which libraries work, and which mages need which scrolls. Only scroll data is sent.", true)
        AddCheckbox("shareChannel", "Use the public channel (experimental)",
            "Also share through a hidden Scrollkeeper channel, reaching players outside your guild and group.", false)
        AddCheckbox("mapPins", "Map pins",
            "Show libraries and the spots where untranslated scrolls dropped on the world map.", true)

        SK.Safely("settings view", function()
            local setting = Settings.RegisterAddOnSetting(category, "Scrollkeeper_viewMode", "viewMode", SK.db,
                "string", "Panel view", "compact")
            setting:SetValueChangedCallback(function() SK.ApplyPanelSettings() end)
            local function Options()
                local container = Settings.CreateControlTextContainer()
                container:Add("compact", "Simple", "Buttons, bars and your scrolls.")
                container:Add("full", "Advanced", "Everything: all the numbers, sections and weapon upgrades.")
                container:Add("mini", "Title only", "Just the title bar.")
                return container:GetData()
            end
            Settings.CreateDropdown(category, setting, Options, "How much the panel shows. The - button on the panel cycles through these too.")
        end)

        SK.Safely("settings slider", AddScaleSlider)

        Settings.RegisterAddOnCategory(category)
    end)
end)

function SK.OpenOptions()
    if SK.InCombat() then
        SK.Print("settings can't be opened in combat.")
        return
    end
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        SK.Print("settings page unavailable. Commands: /sk tooltips, /sk announce, /sk reset")
    end
end
