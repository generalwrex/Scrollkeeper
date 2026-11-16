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
        if key == "hideInCombat" and SK.UpdateCombatHiding then SK.UpdateCombatHiding() end
        if SK.Net and (key == "share" or key == "shareChannel") then SK.Net.UpdateChannel() end
        SK.Send("DROPS_CHANGED")
    end)
    Settings.CreateCheckbox(category, setting, tooltip)
end

------------------------------------------------------------------------
-- About page (Options > AddOns > Scrollkeeper > About)
------------------------------------------------------------------------

SK.LINKS = {
    { "CurseForge", "https://www.curseforge.com/wow/addons/scrollkeeper" },
    { "GitHub", "https://github.com/generalwrex/scrollkeeper" },
    { "Report a bug", "https://github.com/generalwrex/scrollkeeper/issues/new/choose" },
}

-- A box holding a web address, ready to copy (the game can't open links).
local function CopyBox(parent, url)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(380, 20)
    box:SetAutoFocus(false)
    box:SetText(url)
    box:SetCursorPosition(0)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnMouseUp", function(self) self:SetFocus() self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Read-only: put the address back if it's typed over.
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(url) self:HighlightText() end
    end)
    return box
end

local function AddAboutPage()
    if not Settings.RegisterCanvasLayoutSubcategory then return end
    local page = CreateFrame("Frame")

    local icon = page:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\INV_Scroll_03")

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
    title:SetText("Scrollkeeper")

    local version = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText(("Version %s  ·  by generalwrex"):format(SK.version))

    local blurb = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    blurb:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)
    blurb:SetWidth(560)
    blurb:SetJustifyH("LEFT")
    blurb:SetSpacing(3)
    blurb:SetText("Everything for the mage's Comprehension skill in one place: decipher, "
        .. "study, imbue and summon from one panel, see what each scroll tier turns into, "
        .. "find libraries and scroll drops on the map, and share what you learn with "
        .. "other Scrollkeeper players. Made for WoW Forever.")

    local y = -150
    local header = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText("Links")
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", header, "RIGHT", 10, -1)
    hint:SetText("Click one, press Ctrl+C, and paste it in your browser.")
    y = y - 28
    for _, link in ipairs(SK.LINKS) do
        local label = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 24, y - 3)
        label:SetText(link[1])
        local box = CopyBox(page, link[2])
        box:SetPoint("TOPLEFT", 150, y)
        y = y - 28
    end

    y = y - 12
    local help = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    help:SetPoint("TOPLEFT", 16, y)
    help:SetText("Help improve it")
    local helpText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    helpText:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 8, -8)
    helpText:SetWidth(560)
    helpText:SetJustifyH("LEFT")
    helpText:SetSpacing(3)
    helpText:SetText("|cffffd100/sk export|r  copy your scroll data to share. Everyone's shared data "
        .. "ships with the next version.\n"
        .. "|cffffd100/sk bug|r  copy a bug report if something goes wrong.\n"
        .. "Paste either one on the GitHub page above (Report a bug).")

    Settings.RegisterCanvasLayoutSubcategory(category, page, "About")
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
        AddCheckbox("hideInCombat", "Hide the panel in combat",
            "The panel hides when combat starts and comes back when it ends. (The X always closes it, even in combat.)", true)
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

        SK.Safely("settings about", AddAboutPage)

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
