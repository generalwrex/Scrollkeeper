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
        if key == "anonymous" and SK.SendHello then SK.SendHello() end
        if key == "scrollIcon" and SK.RefreshIcon then SK.RefreshIcon() end
        if key == "minimapButton" and SK.RefreshMinimapButton then SK.RefreshMinimapButton() end
        SK.Send("DROPS_CHANGED")
    end)
    return Settings.CreateCheckbox(category, setting, tooltip)
end

local layout

-- A section title, like the game's own settings pages have.
local function AddHeader(text)
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

-- Grey out a setting unless another one is on.
local function DependsOn(child, parent, key)
    if child and parent and child.SetParentInitializer then
        child:SetParentInitializer(parent, function() return SK.db[key] and true or false end)
    end
end

------------------------------------------------------------------------
-- About page (Options > AddOns > Scrollkeeper > About)
------------------------------------------------------------------------

SK.AUTHOR_CHARACTER = "Archmage Naage"

-- People who helped: { name, what they did }. Shown on the About page.
SK.CREDITS = {
    { "Curnil", "the scroll icon idea" },
}

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

local function AddBackupPage()
    if not Settings.RegisterCanvasLayoutSubcategory then return end
    local page = CreateFrame("Frame")

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["Backup"])

    local text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetWidth(560)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    text:SetText(L["Everything Scrollkeeper has saved (settings, your luck log, drops, books, your mages, prices and what you heard from other players) lives in your WTF folder. If you ever have to wipe WTF, it's gone."]
        .. "\n\n" .. L["Make a backup, copy the text and keep it somewhere safe (a text file, a note, Discord). Restore pastes it back in and reloads."])

    local backup = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    backup:SetSize(180, 26)
    backup:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
    backup:SetText(L["Back up my data"])
    backup:SetScript("OnClick", function() SK.ShowBackup() end)

    local restore = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    restore:SetSize(180, 26)
    restore:SetPoint("LEFT", backup, "RIGHT", 12, 0)
    restore:SetText(L["Restore a backup"])
    restore:SetScript("OnClick", function() SK.ShowRestore() end)

    local commands = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    commands:SetPoint("TOPLEFT", backup, "BOTTOMLEFT", 0, -10)
    commands:SetText(L["Same as /sk backup and /sk restore."])

    Settings.RegisterCanvasLayoutSubcategory(category, page, L["Backup"])
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
    version:SetText(L["Version %s  ·  by Natop (generalwrex)"]:format(SK.version))

    local ingame = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ingame:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -3)
    ingame:SetText(L["In game: %s (PvE). Say hi!"]:format(SK.AUTHOR_CHARACTER))

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
        label:SetText(L[link[1]])
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

    local thanks = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    thanks:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", -8, -18)
    thanks:SetText(L["Thanks"])
    local thanksText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    thanksText:SetPoint("TOPLEFT", thanks, "BOTTOMLEFT", 8, -8)
    thanksText:SetWidth(560)
    thanksText:SetJustifyH("LEFT")
    thanksText:SetSpacing(3)
    local lines = {}
    for _, credit in ipairs(SK.CREDITS) do
        lines[#lines + 1] = ("|cffffd100%s|r  %s"):format(credit[1], L[credit[2]])
    end
    lines[#lines + 1] = L["Everyone who shares their scroll data or reports a bug."]
    thanksText:SetText(table.concat(lines, "\n"))

    Settings.RegisterCanvasLayoutSubcategory(category, page, L["About"])
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
        category, layout = Settings.RegisterVerticalLayoutCategory("Scrollkeeper")

        -- Panel ------------------------------------------------------------
        AddHeader(L["Panel"])
        local showPanel = AddCheckbox("showPanel", L["Show the panel"],
            L["The window with your Comprehension, scrolls and Study timer. Mages only."], true)
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
        AddCheckbox("minimapButton", L["Minimap button"],
            L["The round Scrollkeeper button on the edge of the minimap, with how many scrolls you can decipher. Left-click: panel. Right-click: settings. Drag to move it around."], true)
        AddCheckbox("scrollIcon", L["Scroll icon"],
            L["A small icon you can keep on screen with how many scrolls you can decipher. Click it to open or close the panel in the view you picked above."], false)
        AddCheckbox("hideInCombat", L["Hide the panel in combat"],
            L["The panel hides when combat starts and comes back when it ends. (The X always closes it, even in combat.)"], true)
        AddCheckbox("reminderToast", L["Imbue and familiar pop-up"],
            L["A small pop-up when your weapon imbue or familiar wears off and you have a scroll for it. Click it to open the panel. Not in combat, and at most once every five minutes."], true)
        AddCheckbox("locked", L["Lock position"],
            L["Stops the panel (and the scroll icon) from being dragged."], false)
        local buttons = AddCheckbox("showScrollBar", L["Scroll buttons"],
            L["Adds a button to the panel for each kind of translated scroll in your bags. Click one to use it."], true)
        DependsOn(buttons, showPanel, "showPanel")
        if CreateSettingsButtonInitializer and layout then
            layout:AddInitializer(CreateSettingsButtonInitializer(L["Panel position"], L["Move to middle"],
                function() if SlashCmdList.SCROLLKEEPER then SlashCmdList.SCROLLKEEPER("reset") end end,
                L["Lost the panel off screen? This puts it back in the middle at normal size."], true))
        end

        -- Tooltips and chat -------------------------------------------------
        AddHeader(L["Tooltips and chat"])
        AddCheckbox("showTooltips", L["Tooltip lines"],
            L["Mages see whether they can decipher a scroll. Other classes see that it is a mage scroll."], true)
        AddCheckbox("announce", L["Decipher messages"],
            L["Prints a chat line such as \"deciphered: Scroll of Frog Familiar\"."], true)
        AddCheckbox("chatHelper", L["Chat notes"],
            L["When someone links a scroll in chat and asks who needs it, add a note only you see: is it a skill-up for you or your mages."], true)

        -- Sharing ------------------------------------------------------------
        AddHeader(L["Sharing"])
        SK.Safely("settings sharing", function()
            local setting = Settings.RegisterAddOnSetting(category, "Scrollkeeper_sharing", "sharing", SK.db,
                "string", L["Sharing"], "full")
            setting:SetValueChangedCallback(function()
                SK.SetSharing(SK.db.sharing)
                if SK.Net and SK.Net.UpdateChannel then SK.Net.UpdateChannel() end
                if SK.db.share and SK.SendHello then SK.SendHello() end
            end)
            local function Options()
                local container = Settings.CreateControlTextContainer()
                container:Add("full", L["Full"], L["Share with every Scrollkeeper user online, with your name."])
                container:Add("anon", L["Anonymous"], L["Share with everyone, but your name isn't shown in their lists, so nobody can mail you scrolls from them."])
                container:Add("simple", L["Simple"], L["Only your guild, group and friends."])
                container:Add("none", L["None"], L["Turns off the whole network: no shared odds, swap board, or guildies at the mailbox."])
                return container:GetData()
            end
            Settings.CreateDropdown(category, setting, Options,
                L["What Scrollkeeper shares with other players: what scrolls became, where they drop, which libraries work and who needs which scrolls. Only scroll data is sent, never chat or gold."])
        end)

        -- Helpers ------------------------------------------------------------
        AddHeader(L["Mailbox, guild bank and auction house"])
        AddCheckbox("mailHelper", L["Mailbox helper"],
            L["At the mailbox, list your mages, guildies and friends who could use your spare scrolls. Click one to fill in the mail."], true)
        AddCheckbox("mailIncludeMine", L["Mailbox: offer scrolls I'd use too"],
            L["Also list mages who could use the scrolls you'd still level from yourself, marked so you know. Off: only scrolls you can't use."], false)
        AddCheckbox("guildBankMarks", L["Guild bank marks"],
            L["Put a colored dot on guild bank scrolls that you, your mages or a guildie would get a skill-up from."], true)
        AddCheckbox("ahScanButton", L["Auction house scan button"],
            L["Show a Scan scrolls button on the auction house. Prices you see are saved for tooltips either way."], true)

        -- Language -------------------------------------------------------------
        AddHeader(L["Language"])
        SK.Safely("settings language", function()
            local setting = Settings.RegisterAddOnSetting(category, "Scrollkeeper_language", "language", SK.db,
                "string", L["Language"], "auto")
            setting:SetValueChangedCallback(function()
                SK.Print(L["language changed. Type /reload to switch."])
            end)
            local function Options()
                local container = Settings.CreateControlTextContainer()
                for _, language in ipairs(SK.LANGUAGES or {}) do
                    container:Add(language[1], language[1] == "auto" and L["Auto (game language)"] or language[2])
                end
                return container:GetData()
            end
            Settings.CreateDropdown(category, setting, Options,
                L["Scrollkeeper's language. Spanish, French, German and Chinese were translated with AI, so fixes are welcome on GitHub. Takes effect after /reload."])
        end)

        -- Map ------------------------------------------------------------------
        AddHeader(L["Map"])
        AddCheckbox("mapPins", L["Map pins"],
            L["Show libraries and the spots where untranslated scrolls dropped on the world map."], true)

        SK.Safely("settings backup", AddBackupPage)
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
