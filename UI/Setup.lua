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

local WIDTH, HEIGHT = 440, 464
local OPTION_HEIGHT, OPTION_GAP = 54, 6
local MAX_OPTIONS = 5
local window
local questions, page = {}, 1
local answers = {}

------------------------------------------------------------------------
-- The questions
--   { key, version, question, multi, options = { { value, label, description, icon } } }
-- When a question is added (or changed enough to ask again, by raising its
-- version), people who already did setup get just that page next login.
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
        list[#list + 1] = { key = "open", question = L["How do you want to open it?"], multi = true,
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
    list[#list + 1] = { key = "sharing", version = 2, question = L["How much should Scrollkeeper share?"],
        hint = L["Sharing is what powers community odds, drop spots, the swap board and the mailbox list. Only scroll data is sent."], options = {
        { "full", L["Full"], L["Share with every Scrollkeeper user online, with your name."], ICON .. "Spell_Holy_PrayerOfHealing02" },
        { "anon", L["Anonymous"], L["Share with everyone, but your name isn't shown in their lists, so nobody can mail you scrolls from them."], ICON .. "Ability_Stealth" },
        { "simple", L["Simple"], L["Only your guild, group and friends."], ICON .. "INV_Shirt_GuildTabard_01" },
        { "none", L["None"], L["Turns off the whole network: no shared odds, swap board, or guildies at the mailbox."], ICON .. "Ability_Rogue_Feint" },
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
        return SK.db.sharing or "full"
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

-- Which questions this character type has answered: { key = version }.
local function Seen()
    local field = SK.isMage and "setupSeen" or "setupSeenOther"
    SK.db[field] = SK.db[field] or {}
    return SK.db[field]
end

local function MarkSeen(list)
    local seen = Seen()
    for _, q in ipairs(list) do seen[q.key] = q.version or 1 end
end

local function Unseen(list)
    local seen, out = Seen(), {}
    for _, q in ipairs(list) do
        if (seen[q.key] or 0) < (q.version or 1) then out[#out + 1] = q end
    end
    return out
end

local function Apply()
    local oldLanguage = SK.db.language
    for key, value in pairs(answers) do
        if key == "sharing" then
            SK.SetSharing(value)
        else
            SK.db[key] = value
        end
    end
    SK.db[SK.isMage and "setupDone" or "setupDoneOther"] = true
    MarkSeen(questions)
    -- Mages: open the panel in the view they just picked.
    -- (Only when this run asked about the view, not for a single new question.)
    if SK.isMage and questions[1] and questions[1].key == "viewMode" then
        SK.db.showPanel = true
    end
    if SK.ApplyPanelSettings then SK.ApplyPanelSettings() end
    if SK.UpdateCombatHiding then SK.UpdateCombatHiding() end
    if SK.RefreshIcon then SK.RefreshIcon() end
    if SK.RefreshMinimapButton then SK.RefreshMinimapButton() end
    if SK.Net and SK.Net.UpdateChannel then SK.Net.UpdateChannel() end
    if SK.db.share and SK.SendHello then SK.SendHello() end
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
    option.description:SetWordWrap(true)   -- up to two lines
    if option.description.SetMaxLines then option.description:SetMaxLines(2) end

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
        MarkSeen(questions)
        window:Hide()
        -- Skipping the full setup still opens the panel (with the defaults).
        if SK.isMage and questions[1] and questions[1].key == "viewMode" and not SK.InCombat() then
            SK.db.showPanel = true
            if SK.ApplyPanelSettings then SK.ApplyPanelSettings() end
        end
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

-- onlyNew: just the questions this character hasn't answered yet.
function SK.ShowSetup(onlyNew)
    if SK.InCombat() then
        SK.Print(L["the setup can be opened after combat."])
        return
    end
    questions = BuildQuestions()
    if onlyNew then questions = Unseen(questions) end
    if #questions == 0 then return end
    page, answers = 1, {}
    if not window then Build() end
    SK.RefreshSetupPage()
    window:Show()
end

-- The first time you log in with Scrollkeeper (any class): open it a few
-- seconds after logging in. Mages and other classes are asked separately,
-- since they get different questions. After that, only new questions are
-- shown, once.
SK.Listen("READY", function()
    local doneKey = SK.isMage and "setupDone" or "setupDoneOther"
    -- Did setup before questions were tracked (1.1.2/1.1.3): everything
    -- that existed then counts as answered.
    if SK.db[doneKey] and not SK.db[SK.isMage and "setupSeen" or "setupSeenOther"] then
        local seen = Seen()
        for _, q in ipairs(BuildQuestions()) do seen[q.key] = 1 end
    end
    if SK.db[doneKey] and #Unseen(BuildQuestions()) == 0 then return end
    C_Timer.After(4, function()
        if SK.InCombat() then return end
        if not SK.db[doneKey] then SK.ShowSetup()
        elseif #Unseen(BuildQuestions()) > 0 then SK.ShowSetup(true) end
    end)
end)

------------------------------------------------------------------------
-- A one-time thank-you in 1.1.5, once per account, after the setup window
-- (if that shows). Only this release says it.
------------------------------------------------------------------------

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_THANKS"] = {
        text = "",   -- filled in when shown, in your language
        button1 = OKAY or "Okay",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

SK.Listen("READY", function()
    if not (type(SK.version) == "string" and SK.version:match("^1%.1%.5")) then return end
    if SK.db.thanked115 then return end
    C_Timer.After(10, function()
        if SK.db.thanked115 or SK.InCombat() or not StaticPopup_Show then return end
        if ScrollkeeperSetupFrame and ScrollkeeperSetupFrame:IsShown() then return end   -- next login then
        SK.db.thanked115 = true
        StaticPopupDialogs["SCROLLKEEPER_THANKS"].text =
            L["|cffffd100Hey, thanks for using Scrollkeeper!|r\n\nAll of you downloading it and sharing your scroll data is what fills in the odds, the drop spots and everything else. Couldn't do it without you.\n\n- Natop (Archmage Naage)"]
            .. "\n\n|cff9d9d9d" .. L["New: you can back up all your Scrollkeeper data now, in Options > Scrollkeeper > Backup."] .. "|r"
        StaticPopup_Show("SCROLLKEEPER_THANKS")
    end)
end)
