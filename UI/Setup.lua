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
local MAX_OPTIONS = 8                    -- pages with more than 5 use short rows (see Layout)
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
            { "full", L["Advanced"] .. " |cff40ff40" .. L["(recommended)"] .. "|r", L["Everything: all the numbers, sections and weapon upgrades."], ICON .. "INV_Misc_Book_09" },
            { "compact", L["Simple"], L["Buttons, bars and your scrolls."], ICON .. "INV_Scroll_03" },
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
        list[#list + 1] = { key = "reminders", question = L["Remind you about your imbue and familiar?"], multi = true,
            hint = L["Pick any, or none. Only when you have a scroll to fix it."], options = {
            { "reminderToast", L["Imbue and familiar pop-up"], L["When your weapon imbue or familiar wears off."], ICON .. "Spell_Fire_FlameTounge" },
            { "expiringReminder", L["Running-out pop-up"], L["A few minutes before it runs out (set how many in the settings)."], ICON .. "INV_Misc_PocketWatch_01" },
            { "reminderInCombat", L["Also in combat"], L["So you know if it runs out mid-fight."], ICON .. "Ability_DualWield" },
        } }
        list[#list + 1] = { key = "keys", keys = true, question = L["Set some keys?"],
            hint = L["Click one, then press the key you want. Keys you already use are left alone. Escape cancels."], options = {
            { "CLICK ScrollkeeperFamiliarKey:LeftButton", L["Summon a familiar"], nil, ICON .. "Ability_Hunter_BeastCall" },
            { "CLICK ScrollkeeperImbueKey:LeftButton", L["Imbue your weapon"], nil, ICON .. "Spell_Fire_FlameTounge" },
            { "CLICK ScrollkeeperUnlockButton:LeftButton", L["Khadgar's Unlocking (locked chests)"], nil, ICON .. "INV_Misc_Key_03" },
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
    list[#list + 1] = { key = "sharing", version = 2, account = true, question = L["How much should Scrollkeeper share?"],
        hint = L["Only scroll info is shared: your Comprehension skill, what your scrolls became and where they dropped. Never your chat, gold, bags or where you are."], options = {
        { "full", L["Full"] .. " |cff40ff40" .. L["(recommended)"] .. "|r", L["Everything works. Other Scrollkeeper mages see your name and skill, so they can send you scrolls you need."], ICON .. "Spell_Holy_PrayerOfHealing02" },
        { "anon", L["Anonymous"], L["Share with everyone, but your name isn't shown in their lists, so nobody can mail you scrolls from them."], ICON .. "Ability_Stealth" },
        { "none", L["None"] .. " |cffff6666" .. L["(not recommended)"] .. "|r", L["Nothing is sent. No Fellow Mages or swap board, but each update's odds still show."], ICON .. "Ability_Rogue_Feint" },
    } }
    -- Required: shown to everyone (old setups too), and Skip can't pass it.
    list[#list + 1] = { key = "shareUsage", version = 1, account = true, required = true,
        question = L["Help make Scrollkeeper better?"],
        hint = L["Why: knowing which features people really use tells us where to spend our time, so the ones you rely on get fixed first, keep working as the game changes, and get better. It's opt-in: nothing is sent unless you pick Yes. It's totally anonymous: just counts like \"Scroll Bag opened 12 times\" under a random ID. Never your name, realm, guild, chat, gold, bags or where you are. Change it any time in /sk options > Sharing."],
        options = {
        { true, L["Yes, share anonymous counts"] .. " |cff40ff40" .. L["(recommended)"] .. "|r", L["The features you use get fixed first and improved next."], ICON .. "INV_Misc_Note_01" },
        { false, L["No thanks"], L["Nothing about how you use Scrollkeeper is sent (the default)."], ICON .. "Ability_Rogue_Feint" },
    } }
    local languages = {}
    for _, language in ipairs(SK.LANGUAGES or {}) do
        local auto = language[1] == "auto"
        languages[#languages + 1] = { language[1], auto and L["Auto (game language)"] or language[2],
            auto and L["Use the same language as the game."] or nil, ICON .. "INV_Misc_Book_11" }
    end
    list[#list + 1] = { key = "language", account = true, question = L["Language"],
        hint = L["Spanish, French, German and Chinese were translated with AI, so fixes are welcome on GitHub."], options = languages }
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

-- Sharing and language are one setting for the whole account: answered
-- once (on any character, mage or not), never asked again elsewhere.
local function SeenAccount()
    SK.db.setupSeenAccount = SK.db.setupSeenAccount or {}
    local seen = SK.db.setupSeenAccount
    -- Answered before this was account-wide: on either kind of character.
    for _, field in ipairs({ "setupSeen", "setupSeenOther" }) do
        for key, version in pairs(SK.db[field] or {}) do
            if (key == "sharing" or key == "language") and (seen[key] or 0) < version then seen[key] = version end
        end
    end
    return seen
end

local function SeenFor(q) return q.account and SeenAccount() or Seen() end


local function MarkSeen(list)
    for _, q in ipairs(list) do SeenFor(q)[q.key] = q.version or 1 end
end

local function Unseen(list)
    local out = {}
    for _, q in ipairs(list) do
        if (SeenFor(q)[q.key] or 0) < (q.version or 1) then out[#out + 1] = q end
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

------------------------------------------------------------------------
-- Key bindings page: click a row, press a key. A key that's already bound
-- to something else is refused (with what it's used for), never replaced.
------------------------------------------------------------------------

local capturing   -- the binding command waiting for a key, or nil
local keyNote     -- a message under the rows ("F is already used for Jump")

local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true, UNKNOWN = true }

-- "CTRL-SHIFT-F" style, the way bindings are written.
local function FullKey(key)
    local prefix = ""
    if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end

-- What a binding command is called in the Key Bindings window.
local function ActionName(action)
    return _G["BINDING_NAME_" .. action] or action
end

local function StopCapture()
    capturing = nil
    if window then
        window:EnableKeyboard(false)
        window:SetScript("OnKeyDown", nil)
    end
end

local function OnKey(_, key)
    if not capturing then return end
    if window.SetPropagateKeyboardInput then window:SetPropagateKeyboardInput(false) end
    if key == "ESCAPE" then
        StopCapture()
        keyNote = nil
        SK.RefreshSetupPage()
        return
    end
    if MODIFIER_KEYS[key] then return end   -- wait for the real key
    local full = FullKey(key)
    local used = GetBindingAction and GetBindingAction(full, true) or ""
    if used ~= "" and used ~= capturing then
        keyNote = "|cffff6666" .. L["%s is already used for: %s. Pick another key."]:format(full, ActionName(used)) .. "|r"
        SK.RefreshSetupPage()
        return
    end
    if SK.InCombat() or not (SetBinding and SaveBindings) then
        keyNote = "|cffff6666" .. L["Keys can't be set in combat."] .. "|r"
    else
        -- One key per action: the old one (if any) goes.
        local old1, old2 = GetBindingKey(capturing)
        if old1 then SetBinding(old1) end
        if old2 then SetBinding(old2) end
        SetBinding(full, capturing)
        SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
        keyNote = "|cff40ff40" .. L["%s set to %s."]:format(ActionName(capturing), full) .. "|r"
    end
    StopCapture()
    SK.RefreshSetupPage()
end

local function StartCapture(command)
    capturing = command
    keyNote = nil
    window:EnableKeyboard(true)
    if window.SetPropagateKeyboardInput then window:SetPropagateKeyboardInput(false) end
    window:SetScript("OnKeyDown", OnKey)
    SK.RefreshSetupPage()
end

-- Is any of the page's keys set yet? (Existing players see the page once
-- only if none are.)
local function AnyKeySet(q)
    for _, data in ipairs(q.options) do
        if GetBindingKey and GetBindingKey(data[1]) then return true end
    end
    return false
end

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

    option.index = i
    option:SetScript("OnClick", function(self)
        local q = questions[page]
        if q.keys then
            StartCapture(self.value)
            return
        end
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
    SK.UI.Background(background)

    window.step = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.step:SetPoint("TOPLEFT", 64, -34)

    -- Little dots, one per question.
    window.dots = {}
    for i = 1, 8 do
        local dot = window:CreateTexture(nil, "OVERLAY")
        dot:SetSize(8, 8)
        dot:SetPoint("TOPRIGHT", window, "TOPRIGHT", -20 - (8 - i) * 12, -36)
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

    -- Under the key rows: "F is already used for Jump" and such.
    window.keyNote = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.keyNote:SetPoint("BOTTOMLEFT", 24, 48)
    window.keyNote:SetPoint("RIGHT", window, "RIGHT", -24, 0)
    window.keyNote:SetJustifyH("LEFT")
    window:HookScript("OnHide", function() StopCapture() keyNote = nil end)

    window.next = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    window.next:SetSize(110, 24)
    window.next:SetPoint("BOTTOMRIGHT", -16, 14)
    window.next:SetScript("OnClick", function()
        StopCapture()
        keyNote = nil
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
        StopCapture()
        keyNote = nil
        if page > 1 then page = page - 1 SK.RefreshSetupPage() end
    end)

    window.skip = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    window.skip:SetSize(90, 24)
    window.skip:SetPoint("BOTTOMLEFT", 16, 14)
    window.skip:SetText(L["Skip"])
    window.skip:SetScript("OnClick", function()
        SK.db[SK.isMage and "setupDone" or "setupDoneOther"] = true
        -- Required questions still need an answer: show just those next.
        local required, rest = {}, {}
        for _, q in ipairs(questions) do
            if q.required then required[#required + 1] = q else rest[#rest + 1] = q end
        end
        MarkSeen(rest)
        if #required > 0 then
            questions, page, answers = required, 1, {}
            SK.RefreshSetupPage()
            return
        end
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
    -- Up to 5 options get full rows; more (like the 7 languages) get short
    -- rows without the description, so they all fit.
    local short = #q.options > 5
    local height, gap = short and 34 or OPTION_HEIGHT, short and 4 or OPTION_GAP
    -- Below the question and its hint (a long hint pushes the rows down).
    local top = 66 + (window.question:GetStringHeight() or 16) + 6 + (window.hint:GetStringHeight() or 0) + 10
    top = math.max(112, top)
    for i, option in ipairs(window.options) do
        option:SetHeight(height)
        option:ClearAllPoints()
        option:SetPoint("TOPLEFT", 24, -top - (i - 1) * (height + gap))
        option:SetPoint("RIGHT", window, "RIGHT", -24, 0)
        option.icon:SetSize(height - 12, height - 12)
        option.description:SetShown(not short)
    end
    for i, option in ipairs(window.options) do
        local data = q.options[i]
        if data then
            option.value = data[1]
            option.label:SetText(data[2])
            option.description:SetText(data[3] or "")
            option.icon:SetTexture(data[4] or (ICON .. "INV_Misc_QuestionMark"))
            local on = Selected(q, data[1])
            if q.keys then
                local key = GetBindingKey and GetBindingKey(data[1])
                on = key ~= nil
                if capturing == data[1] then
                    option.description:SetText("|cffffd100" .. L["Press a key... (Escape to cancel)"] .. "|r")
                elseif key then
                    option.description:SetText(L["Key: %s  (click to change)"]:format("|cffffffff" .. key .. "|r"))
                else
                    option.description:SetText(L["No key yet: click, then press one."])
                end
            end
            option.selected:SetShown(on)
            option.bar:SetShown(on)
            option.check:SetShown(on)
            option.icon:SetDesaturated(not on)
            option:Show()
        else
            option:Hide()
        end
    end
    window.keyNote:SetText(q.keys and keyNote or "")
    window.back:SetEnabled(page > 1)
    -- Only required questions left: no Skip (and no closing without an answer).
    local onlyRequired = true
    for _, question in ipairs(questions) do
        if not question.required then onlyRequired = false end
    end
    window.skip:SetShown(not onlyRequired)
    window.next:SetText(page < #questions and L["Next"] or L["Done"])
end

-- onlyNew: just the questions this character hasn't answered yet.
-- skipAccount: leave out account-wide questions (sharing, language)
-- already answered on another character (the first-login setup).
function SK.ShowSetup(onlyNew, skipAccount)
    if SK.InCombat() then
        SK.Print(L["the setup can be opened after combat."])
        return
    end
    questions = BuildQuestions()
    if onlyNew then questions = Unseen(questions) end
    if skipAccount then
        local kept = {}
        for _, q in ipairs(questions) do
            if not (q.account and (SeenAccount()[q.key] or 0) >= (q.version or 1)) then kept[#kept + 1] = q end
        end
        questions = kept
    end
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
        for _, q in ipairs(BuildQuestions()) do
            if not q.required then seen[q.key] = 1 end
        end
    end
    -- The reminders page (1.2.2) is only for new setups: everyone else
    -- keeps both reminders on, as they were, without being asked.
    if SK.db[doneKey] and SK.isMage and Seen().reminders == nil then Seen().reminders = 1 end
    if SK.db[doneKey] and SK.isMage and Seen().keys == nil then
        for _, q in ipairs(BuildQuestions()) do
            if q.keys and AnyKeySet(q) then Seen().keys = 1 end
        end
    end
    if SK.db[doneKey] and #Unseen(BuildQuestions()) == 0 then return end
    C_Timer.After(4, function()
        if SK.InCombat() then return end
        if not SK.db[doneKey] then SK.ShowSetup(false, true)
        elseif #Unseen(BuildQuestions()) > 0 then SK.ShowSetup(true) end
    end)
end)

------------------------------------------------------------------------
-- One-time messages (Data/Messages.lua): printed in chat the first time
-- you open the panel, each once per account.
------------------------------------------------------------------------

function SK.ShowMessages()
    if not SK.db then return end
    SK.db.messagesSeen = SK.db.messagesSeen or {}
    for _, message in ipairs(SK.MESSAGES or {}) do
        local wanted = not message.version
            or (type(SK.version) == "string" and SK.version:sub(1, #message.version) == message.version)
        if message.id and wanted and not SK.db.messagesSeen[message.id] then
            SK.db.messagesSeen[message.id] = true
            for i, line in ipairs(message.lines or {}) do
                if i == 1 then SK.Print(L[line]) else print("  " .. L[line]) end
            end
        end
    end
end

-- Once the panel exists: when it opens (or if it's already open).
SK.Listen("READY", function()
    C_Timer.After(1, function()
        local panel = ScrollkeeperPanel
        if not (panel and panel.HookScript) then return end
        panel:HookScript("OnShow", function() SK.Safely("messages", SK.ShowMessages) end)
        if panel:IsShown() then SK.Safely("messages", SK.ShowMessages) end
    end)
end)
