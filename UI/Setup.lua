-- Scrollkeeper: UI/Setup.lua
-- The first-time setup: a short walk-through the first time you log in
-- with Scrollkeeper. One question per page, big buttons with a picture and
-- a line about what each choice does, Back and Next.
--
-- Mages are asked about the panel, the minimap button and scroll icon,
-- combat, sharing and language. Other classes get tooltips, the mailbox
-- helper, sharing and language. Everything can be changed later in the
-- settings, and /sk setup opens this again.

local _, SK = ...
local L = SK.L

local WIDTH, HEIGHT = 440, 424
local OPTION_HEIGHT, OPTION_GAP = 46, 6
local MAX_OPTIONS = 5
local window
local questions, page = {}, 1
local answers = {}

------------------------------------------------------------------------
-- The questions
--   { key, question, multi, options = { { value, label, description, icon } } }
--   multi = each option is its own on/off setting (pick any)
------------------------------------------------------------------------

local ICON = "Interface\\Icons\\"

local function BuildQuestions()
    local list = {}
    if SK.isMage then
        list[#list + 1] = { key = "viewMode", question = L["How much should the panel show?"], options = {
            { "compact", L["Simple"], L["Buttons, bars and your scrolls."], ICON .. "INV_Scroll_03" },
            { "full", L["Advanced"], L["Everything: all the numbers, sections and weapon upgrades."], ICON .. "INV_Misc_Book_09" },
            { "mini", L["Title only"], L["Just the title and your skill bar."], ICON .. "INV_Scroll_05" },
        } }
        list[#list + 1] = { question = L["How do you want to open it?"], multi = true,
            hint = L["Pick any, or none. The panel's X and /sk always work."], options = {
            { "minimapButton", L["Minimap button"], L["A round button on the minimap's edge with your scroll count."], ICON .. "INV_Misc_Map_01" },
            { "scrollIcon", L["Scroll icon"], L["A small icon you can put anywhere with your scroll count."], ICON .. "INV_Scroll_03" },
        } }
        list[#list + 1] = { key = "hideInCombat", question = L["Hide the panel in combat?"], options = {
            { true, L["Yes"], L["It hides when a fight starts and comes back after."], ICON .. "Ability_Stealth" },
            { false, L["No"], L["It stays up. The X still closes it in combat."], ICON .. "Ability_Warrior_BattleShout" },
        } }
    else
        list[#list + 1] = { key = "showTooltips", question = L["Add Scrollkeeper lines to scroll tooltips?"], options = {
            { true, L["Yes"], L["See which of your mages can use a scroll, and what it sells for."], ICON .. "INV_Scroll_03" },
            { false, L["No"], L["Leave tooltips alone."], ICON .. "INV_Misc_QuestionMark" },
        } }
        list[#list + 1] = { key = "mailHelper", question = L["At the mailbox, show which mages could use your scrolls?"], options = {
            { true, L["Yes"], L["One click fills in the mail to the right mage."], ICON .. "INV_Letter_15" },
            { false, L["No"], L["Just the normal mailbox."], ICON .. "INV_Misc_QuestionMark" },
        } }
    end
    list[#list + 1] = { key = "sharing", question = L["Share scroll data with other Scrollkeeper users?"],
        hint = L["Only scroll data is shared, never names."], options = {
        { "everyone", L["Everyone"], L["Best odds and drop spots, from every Scrollkeeper user online."], ICON .. "Spell_Holy_PrayerOfHealing02" },
        { "guild", L["Guild and group"], L["Only the people you play with."], ICON .. "INV_Shirt_GuildTabard_01" },
        { "off", L["No"], L["Nothing is sent or received."], ICON .. "Ability_Rogue_Feint" },
    } }
    local languages = {}
    for _, language in ipairs(SK.LANGUAGES or {}) do
        local auto = language[1] == "auto"
        languages[#languages + 1] = { language[1], auto and L["Auto (game language)"] or language[2],
            auto and L["Use the same language as the game."] or nil, ICON .. "INV_Misc_Book_11" }
    end
    list[#list + 1] = { key = "language", question = L["Language"],
        hint = L["Spanish, French and German were translated with AI, so fixes are welcome on GitHub."], options = languages }
    return list
end

-- The current answer for a question, from your settings.
local function Current(key)
    if key == "sharing" then
        if not SK.db.share then return "off" end
        return SK.db.shareChannel and "everyone" or "guild"
    elseif key == "viewMode" then
        return SK.ViewMode and SK.ViewMode() or "compact"
    end
    return SK.db[key]
end

local function Selected(question, value)
    if question.multi then
        if answers[value] ~= nil then return answers[value] end
        return SK.db[value] and true or false
    end
    if answers[question.key] ~= nil then return answers[question.key] == value end
    return Current(question.key) == value
end

local function Apply()
    local oldLanguage = SK.db.language
    for key, value in pairs(answers) do
        if key == "sharing" then
            SK.db.share = value ~= "off"
            SK.db.shareChannel = value == "everyone"
        else
            SK.db[key] = value
        end
    end
    SK.db[SK.isMage and "setupDone" or "setupDoneOther"] = true
    -- Mages: open the panel in the view they just picked.
    if SK.isMage then SK.db.showPanel = true end
    if SK.ApplyPanelSettings then SK.ApplyPanelSettings() end
    if SK.UpdateCombatHiding then SK.UpdateCombatHiding() end
    if SK.RefreshIcon then SK.RefreshIcon() end
    if SK.RefreshMinimapButton then SK.RefreshMinimapButton() end
    if SK.Net and SK.Net.UpdateChannel then SK.Net.UpdateChannel() end
    return SK.db.language ~= oldLanguage
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local function MakeOption(i)
    local option = CreateFrame("Button", nil, window)
    option:SetSize(WIDTH - 48, OPTION_HEIGHT)

    option.background = option:CreateTexture(nil, "BACKGROUND")
    option.background:SetAllPoints()
    option.background:SetColorTexture(1, 1, 1, 0.05)

    option.selected = option:CreateTexture(nil, "BORDER")
    option.selected:SetAllPoints()
    option.selected:SetColorTexture(1, 0.82, 0, 0.16)
    option.bar = option:CreateTexture(nil, "ARTWORK")
    option.bar:SetPoint("TOPLEFT")
    option.bar:SetPoint("BOTTOMLEFT")
    option.bar:SetWidth(3)
    option.bar:SetColorTexture(1, 0.82, 0, 1)

    local highlight = option:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    option.icon = option:CreateTexture(nil, "ARTWORK")
    option.icon:SetSize(OPTION_HEIGHT - 12, OPTION_HEIGHT - 12)
    option.icon:SetPoint("LEFT", 10, 0)
    option.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    option.label = option:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    option.label:SetPoint("TOPLEFT", option.icon, "TOPRIGHT", 10, -2)
    option.label:SetJustifyH("LEFT")
    option.description = option:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    option.description:SetPoint("TOPLEFT", option.label, "BOTTOMLEFT", 0, -3)
    option.description:SetPoint("RIGHT", option, "RIGHT", -34, 0)
    option.description:SetJustifyH("LEFT")
    option.description:SetWordWrap(false)

    option.check = option:CreateTexture(nil, "OVERLAY")
    option.check:SetSize(22, 22)
    option.check:SetPoint("RIGHT", -8, 0)
    option.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

    option:SetPoint("TOPLEFT", 24, -112 - (i - 1) * (OPTION_HEIGHT + OPTION_GAP))
    option:SetScript("OnClick", function(self)
        local q = questions[page]
        if q.multi then
            answers[self.value] = not Selected(q, self.value)
        else
            answers[q.key] = self.value
        end
        SK.RefreshSetupPage()
    end)
    return option
end

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperSetupFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperSetupFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Welcome to Scrollkeeper"])
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Scroll_03") end
    tinsert(UISpecialFrames, "ScrollkeeperSetupFrame")

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.06, 0.05, 0.08, 0.96)

    window.step = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.step:SetPoint("TOPLEFT", 64, -34)

    -- Little dots, one per question.
    window.dots = {}
    for i = 1, 6 do
        local dot = window:CreateTexture(nil, "OVERLAY")
        dot:SetSize(8, 8)
        dot:SetPoint("TOPRIGHT", window, "TOPRIGHT", -20 - (6 - i) * 12, -36)
        dot:SetColorTexture(1, 1, 1, 0.2)
        window.dots[i] = dot
    end

    window.question = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.question:SetPoint("TOPLEFT", 24, -66)
    window.question:SetPoint("RIGHT", window, "RIGHT", -24, 0)
    window.question:SetJustifyH("LEFT")

    window.hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.hint:SetPoint("TOPLEFT", window.question, "BOTTOMLEFT", 0, -6)
    window.hint:SetPoint("RIGHT", window, "RIGHT", -24, 0)
    window.hint:SetJustifyH("LEFT")

    window.options = {}
    for i = 1, MAX_OPTIONS do window.options[i] = MakeOption(i) end

    window.next = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    window.next:SetSize(110, 24)
    window.next:SetPoint("BOTTOMRIGHT", -16, 14)
    window.next:SetScript("OnClick", function()
        if page < #questions then
            page = page + 1
            SK.RefreshSetupPage()
            return
        end
        local languageChanged = Apply()
        window:Hide()
        if languageChanged then SK.Print(L["language changed. Type /reload to switch."]) end
        SK.Print(L["all set! Change anything later with /sk options, or run this again with /sk setup."])
    end)
    window.done = window.next

    window.back = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    window.back:SetSize(90, 24)
    window.back:SetPoint("RIGHT", window.next, "LEFT", -8, 0)
    window.back:SetText(L["Back"])
    window.back:SetScript("OnClick", function()
        if page > 1 then page = page - 1 SK.RefreshSetupPage() end
    end)

    window.skip = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    window.skip:SetSize(90, 24)
    window.skip:SetPoint("BOTTOMLEFT", 16, 14)
    window.skip:SetText(L["Skip"])
    window.skip:SetScript("OnClick", function()
        SK.db[SK.isMage and "setupDone" or "setupDoneOther"] = true
    -- Mages: open the panel in the view they just picked.
    if SK.isMage then SK.db.showPanel = true end
        window:Hide()
        SK.Print(L["setup skipped. Run it any time with /sk setup."])
    end)
end

function SK.RefreshSetupPage()
    if not window then return end
    local q = questions[page]
    if not q then return end
    window.step:SetText(L["Step %d of %d"]:format(page, #questions))
    for i, dot in ipairs(window.dots) do
        dot:SetShown(i <= #questions)
        if i == page then dot:SetColorTexture(1, 0.82, 0, 1)
        elseif i < page then dot:SetColorTexture(1, 0.82, 0, 0.45)
        else dot:SetColorTexture(1, 1, 1, 0.2) end
    end
    window.question:SetText(q.question)
    window.hint:SetText(q.hint or "")
    for i, option in ipairs(window.options) do
        local data = q.options[i]
        if data then
            option.value = data[1]
            option.label:SetText(data[2])
            option.description:SetText(data[3] or "")
            option.icon:SetTexture(data[4] or (ICON .. "INV_Misc_QuestionMark"))
            local on = Selected(q, data[1])
            option.selected:SetShown(on)
            option.bar:SetShown(on)
            option.check:SetShown(on)
            option.icon:SetDesaturated(not on)
            option:Show()
        else
            option:Hide()
        end
    end
    window.back:SetEnabled(page > 1)
    window.next:SetText(page < #questions and L["Next"] or L["Done"])
end

function SK.ShowSetup()
    if SK.InCombat() then
        SK.Print(L["the setup can be opened after combat."])
        return
    end
    questions = BuildQuestions()
    page, answers = 1, {}
    if not window then Build() end
    SK.RefreshSetupPage()
    window:Show()
end

-- The first time you log in with Scrollkeeper (any class): open it a few
-- seconds after logging in. Mages and other classes are asked separately,
-- since they get different questions.
SK.Listen("READY", function()
    local doneKey = SK.isMage and "setupDone" or "setupDoneOther"
    if SK.db[doneKey] then return end
    C_Timer.After(4, function()
        if not SK.db[doneKey] and not SK.InCombat() then SK.ShowSetup() end
    end)
end)
