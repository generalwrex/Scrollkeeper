-- Scrollkeeper: UI/Options.lua
-- The settings page in the game's own Options > AddOns list.
-- Open it with /sk options or the * button on the panel.

local _, SK = ...
local L = SK.L

local category

-- One checkbox. `key` is the name of the setting in the saved table.
local function AddCheckbox(key, label, tooltip, default)
    local setting = Settings.RegisterAddOnSetting(category, "Scrollkeeper_" .. key, key, SK.db,
        "boolean", label, default)
    setting:SetValueChangedCallback(function()
        if SK.ApplyPanelSettings then SK.ApplyPanelSettings() end
        if key == "hideInCombat" and SK.UpdateCombatHiding then SK.UpdateCombatHiding() end
        if SK.Net and (key == "share" or key == "shareChannel") then SK.Net.UpdateChannel() end
        if key == "scrollIcon" and SK.RefreshIcon then SK.RefreshIcon() end
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
    title:SetText(L["Scrollkeeper"])

    local version = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText(L["Version %s  ·  by generalwrex"]:format(SK.version))

    local blurb = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    blurb:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)
    blurb:SetWidth(560)
    blurb:SetJustifyH("LEFT")
    blurb:SetSpacing(3)
    blurb:SetText(L["Everything for the mage's Comprehension skill in one place: decipher, "]
        .. L["study, imbue and summon from one panel, see what each scroll tier turns into, "]
        .. L["find libraries and scroll drops on the map, and share what you learn with "]
        .. L["other Scrollkeeper players. Made for WoW Forever."])

    local y = -150
    local header = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(L["Links"])
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", header, "RIGHT", 10, -1)
    hint:SetText(L["Click one, press Ctrl+C, and paste it in your browser."])
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
    help:SetText(L["Help improve it"])
    local helpText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    helpText:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 8, -8)
    helpText:SetWidth(560)
    helpText:SetJustifyH("LEFT")
    helpText:SetSpacing(3)
    helpText:SetText(L["|cffffd100/sk export|r  copy your scroll data to share. Everyone's shared data "]
        .. L["ships with the next version.\n"]
        .. L["|cffffd100/sk bug|r  copy a bug report if something goes wrong.\n"]
        .. L["Paste either one on the GitHub page above (Report a bug)."])

    Settings.RegisterCanvasLayoutSubcategory(category, page, "About")
end

local function AddScaleSlider()
    local setting = Settings.RegisterAddOnSetting(category, "Scrollkeeper_scale", "scale", SK.db,
        "number", L["Panel size"], 1)
    setting:SetValueChangedCallback(function() SK.ApplyPanelSettings() end)
    local options = Settings.CreateSliderOptions(0.7, 1.5, 0.05)
    if MinimalSliderWithSteppersMixin and options.SetLabelFormatter then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return ("%d%%"):format(value * 100 + 0.5)
        end)
    end
    Settings.CreateSlider(category, setting, options, L["How big the panel is."])
end

SK.Listen("READY", function()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end

    SK.Safely("settings page", function()
        category = Settings.RegisterVerticalLayoutCategory("Scrollkeeper")

        AddCheckbox("showPanel", L["Show the panel"],
            L["The window with your Comprehension, scrolls and Study timer. Mages only."], true)
        AddCheckbox("scrollIcon", L["Scroll icon"],
            L["A small icon you can keep on screen with how many scrolls you can decipher. Click it to open or close the panel in the view you picked below."], false)
        AddCheckbox("hideInCombat", L["Hide the panel in combat"],
            L["The panel hides when combat starts and comes back when it ends. (The X always closes it, even in combat.)"], true)
        AddCheckbox("locked", L["Lock position"],
            L["Stops the panel from being dragged."], false)
        AddCheckbox("showScrollBar", L["Scroll buttons"],
            L["Adds a button to the panel for each kind of translated scroll in your bags. Click one to use it."], true)
        AddCheckbox("showTooltips", L["Tooltip lines"],
            L["Mages see whether they can decipher a scroll. Other classes see that it is a mage scroll."], true)
        AddCheckbox("announce", L["Decipher messages"],
            L["Prints a chat line such as \"deciphered: Scroll of Frog Familiar\"."], true)

        AddCheckbox("share", L["Share with other players"],
            L["Talk to other Scrollkeeper users in your guild and group: what scrolls became, where they drop, which libraries work, and which mages need which scrolls. Only scroll data is sent."], true)
        AddCheckbox("shareChannel", L["Share with everyone"],
            L["Also share through a hidden Scrollkeeper channel, so odds, drop spots and libraries come from every Scrollkeeper user online, not just your guild and group."], true)
        AddCheckbox("mailHelper", L["Mailbox helper"],
            L["At the mailbox, list your mages, guildies and friends who could use your spare scrolls. Click one to fill in the mail."], true)
        AddCheckbox("guildBankMarks", L["Guild bank marks"],
            L["Put a colored dot on guild bank scrolls that you, your mages or a guildie would get a skill-up from."], true)
        AddCheckbox("ahScanButton", L["Auction house scan button"],
            L["Show a Scan scrolls button on the auction house. Prices you see are saved for tooltips either way."], true)
        AddCheckbox("chatHelper", L["Chat notes"],
            L["When someone links a scroll in chat and asks who needs it, add a note only you see: is it a skill-up for you or your mages."], true)
        AddCheckbox("mapPins", L["Map pins"],
            L["Show libraries and the spots where untranslated scrolls dropped on the world map."], true)

        SK.Safely("settings view", function()
            local setting = Settings.RegisterAddOnSetting(category, "Scrollkeeper_viewMode", "viewMode", SK.db,
                "string", L["Panel view"], "compact")
            setting:SetValueChangedCallback(function() SK.ApplyPanelSettings() end)
            local function Options()
                local container = Settings.CreateControlTextContainer()
                container:Add("compact", L["Simple"], L["Buttons, bars and your scrolls."])
                container:Add("full", L["Advanced"], L["Everything: all the numbers, sections and weapon upgrades."])
                container:Add("mini", L["Title only"], L["Just the title and your skill bar."])
                return container:GetData()
            end
            Settings.CreateDropdown(category, setting, Options, L["How much the panel shows. The size button on the panel switches between these too."])
        end)

        SK.Safely("settings slider", AddScaleSlider)

        SK.Safely("settings about", AddAboutPage)

        Settings.RegisterAddOnCategory(category)
    end)
end)

function SK.OpenOptions()
    if SK.InCombat() then
        SK.Print(L["settings can't be opened in combat."])
        return
    end
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        SK.Print(L["settings page unavailable. Commands: /sk tooltips, /sk announce, /sk reset"])
    end
end
