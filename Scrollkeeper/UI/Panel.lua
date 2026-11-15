-- Scrollkeeper: UI/Panel.lua
-- The window mages see. From top to bottom:
--
--   title bar        drag to move, [-] to shrink, [x] to hide
--   skill bar        Comprehension, with marks where the scroll tiers are
--   decipher         how many scrolls are waiting, and the button
--   your scrolls     a button for each kind of usable scroll in your bags
--   study bar        the one-hour Study cooldown and your Light Feathers
--   warning          only when something needs attention
--
-- Secure buttons (decipher, scroll buttons) can only be moved, shown or
-- re-pointed out of combat, so layout changes wait until combat ends.

local _, SK = ...

local WIDTH, PADDING = 240, 10
local INNER = WIDTH - PADDING * 2
local ICON_SIZE, ICON_GAP, ICONS_PER_ROW = 30, 4, 6
local MAX_SCROLL_BUTTONS = 12
local HEADER_HEIGHT = 26

local panel
local parts = {}           -- named pieces of the window
local scrollButtons = {}
local layoutWaiting        -- a layout change is waiting for combat to end

------------------------------------------------------------------------
-- Building the window (runs once)
------------------------------------------------------------------------

local function Text(font)
    local text = panel:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetWidth(INNER)
    return text
end

local function SmallButton(label, tooltip, onClick)
    local button = CreateFrame("Button", nil, panel)
    button:SetSize(16, 16)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(label)
    button.text = text
    button:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.text:SetTextColor(1, 0.82, 0)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", onClick)
    return button
end

local function Build()
    local accent = SK.UI.COLORS.accent

    panel = CreateFrame("Frame", "ScrollkeeperPanel", UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, 150)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.04, 0.05, 0.08, 0.88)
    panel:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.9)

    -- Dragging
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        if SK.db.locked or SK.InCombat() then return end
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        SK.db.panelPoint = { point, relativePoint, x, y }
    end)

    local saved = SK.db.panelPoint
    if saved then
        panel:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 320, -40)
    end
    panel:SetScale(SK.db.scale or 1)

    -- Title bar
    local headerBackground = panel:CreateTexture(nil, "BORDER")
    headerBackground:SetPoint("TOPLEFT", 3, -3)
    headerBackground:SetPoint("TOPRIGHT", -3, -3)
    headerBackground:SetHeight(HEADER_HEIGHT - 4)
    headerBackground:SetColorTexture(accent[1], accent[2], accent[3], 0.18)

    local headerIcon = panel:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(16, 16)
    headerIcon:SetPoint("TOPLEFT", PADDING - 2, -6)
    headerIcon:SetTexture("Interface\\Icons\\INV_Scroll_03")
    headerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    parts.title = Text("GameFontNormal")
    parts.title:SetPoint("TOPLEFT", PADDING + 18, -7)
    parts.title:SetWidth(INNER - 60)

    parts.close = SmallButton("x", "Hide (type /sk to show it again)", function()
        if SK.InCombat() then SK.Print("the panel can't be hidden in combat.") return end
        SK.db.showPanel = false
        panel:Hide()
        SK.Print("panel hidden. Type /sk to show it again.")
    end)
    parts.close:SetPoint("TOPRIGHT", -6, -5)

    parts.collapse = SmallButton("-", "Shrink or expand", function()
        if SK.InCombat() then SK.Print("the panel can't change size in combat.") return end
        SK.db.collapsed = not SK.db.collapsed
        SK.RefreshPanel()
    end)
    parts.collapse:SetPoint("RIGHT", parts.close, "LEFT", -2, 0)

    parts.gear = SmallButton("*", "Settings", function() SK.OpenOptions() end)
    parts.gear:SetPoint("RIGHT", parts.collapse, "LEFT", -2, 0)

    -- Skill
    parts.skillBar = SK.UI.CreateBar(panel, INNER, 14)
    parts.skillBar:SetBarColor(accent)
    parts.tier = Text()

    -- Decipher
    parts.waiting = Text()
    parts.decipher = CreateFrame("Button", "ScrollkeeperDecipherButton", panel,
        "SecureActionButtonTemplate,UIPanelButtonTemplate")
    parts.decipher:SetSize(INNER, 24)
    parts.decipher:RegisterForClicks("AnyUp", "AnyDown")
    parts.decipher:SetText("Decipher next scroll")
    parts.decipher:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local nextScroll = SK.NextDecipherable()
        if nextScroll then
            GameTooltip:SetText("Decipher " .. nextScroll.name)
            GameTooltip:AddLine(("Needs %d Comprehension."):format(nextScroll.needs), 1, 1, 1)
            GameTooltip:AddLine("One click deciphers one scroll, easiest first.", 0.7, 0.7, 0.7, true)
        else
            GameTooltip:SetText("Nothing to decipher")
            GameTooltip:AddLine("Untranslated scrolls drop from enemies and chests everywhere.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    parts.decipher:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Your scrolls
    parts.scrollsLabel = Text("GameFontDisableSmall")
    parts.scrollsLabel:SetText("YOUR SCROLLS")
    for i = 1, MAX_SCROLL_BUTTONS do
        scrollButtons[i] = SK.UI.CreateItemButton(panel, "ScrollkeeperScrollButton" .. i, ICON_SIZE)
        scrollButtons[i]:Hide()
    end

    -- Study
    parts.studyBar = SK.UI.CreateBar(panel, INNER, 14)
    parts.warning = Text()
end

------------------------------------------------------------------------
-- Layout: where each piece sits. Only runs out of combat.
------------------------------------------------------------------------

local function Place(region, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, y)
end

local function Layout()
    if SK.InCombat() then
        layoutWaiting = true
        return
    end
    layoutWaiting = false

    local collapsed = SK.db.collapsed
    parts.collapse.text:SetText(collapsed and "+" or "-")

    local body = { parts.skillBar, parts.tier, parts.waiting, parts.decipher, parts.scrollsLabel, parts.studyBar, parts.warning }
    for _, region in ipairs(body) do region:SetShown(not collapsed) end

    if collapsed then
        for _, button in ipairs(scrollButtons) do button:Hide() end
        panel:SetHeight(HEADER_HEIGHT + 2)
        return
    end

    local y = -(HEADER_HEIGHT + 6)

    Place(parts.skillBar, y);  y = y - 18
    Place(parts.tier, y);      y = y - 18

    Place(parts.waiting, y);   y = y - 16
    Place(parts.decipher, y);  y = y - 30

    -- Scroll buttons: one per kind of usable scroll, six to a row.
    local scrolls = SK.db.showScrollBar and SK.bags.translated or {}
    local shown = math.min(#scrolls, MAX_SCROLL_BUTTONS)
    parts.scrollsLabel:SetShown(shown > 0)
    if shown > 0 then
        Place(parts.scrollsLabel, y); y = y - 14
    end
    for i, button in ipairs(scrollButtons) do
        local scroll = scrolls[i]
        if scroll and i <= shown then
            local column, row = (i - 1) % ICONS_PER_ROW, math.floor((i - 1) / ICONS_PER_ROW)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", panel, "TOPLEFT",
                PADDING + column * (ICON_SIZE + ICON_GAP), y - row * (ICON_SIZE + ICON_GAP))
            button:SetAttribute("type", "item")
            button:SetAttribute("item", "item:" .. scroll.itemID)
            button:SetDisplay(scroll.itemID, scroll.icon, scroll.count)
            button:Show()
        else
            button:SetAttribute("type", nil)
            button:Hide()
        end
    end
    if shown > 0 then
        local rows = math.ceil(shown / ICONS_PER_ROW)
        y = y - rows * (ICON_SIZE + ICON_GAP) - 4
    end

    Place(parts.studyBar, y);  y = y - 18

    local warning = parts.warning:GetText()
    if warning and warning ~= "" then
        Place(parts.warning, y - 2)
        y = y - parts.warning:GetStringHeight() - 6
    end

    panel:SetHeight(-y + PADDING - 2)

    -- Point the decipher button at the next readable scroll.
    local nextScroll, readable = SK.NextDecipherable()
    if nextScroll then
        parts.decipher:SetAttribute("type", "spell")
        parts.decipher:SetAttribute("spell", SK.SPELL_COMPREHEND_SCROLL)
        parts.decipher:SetAttribute("target-bag", nextScroll.bag)
        parts.decipher:SetAttribute("target-slot", nextScroll.slot)
        parts.decipher:SetText(("Decipher next scroll (%d)"):format(readable))
        parts.decipher:Enable()
    else
        parts.decipher:SetAttribute("type", nil)
        parts.decipher:SetText("Nothing to decipher")
        parts.decipher:Disable()
    end
end

------------------------------------------------------------------------
-- Text and bars: what each piece says. Safe to run in combat.
------------------------------------------------------------------------

local function UpdateText()
    local colors = SK.UI.COLORS
    local skill = SK.GetComprehension()
    local _, readable, tooHard = SK.NextDecipherable()
    local studyLeft = SK.StudySecondsLeft()
    local knowsStudy = SK.KnowsStudy()

    -- Title: when shrunk, the title carries the important numbers.
    if SK.db.collapsed then
        local study = knowsStudy and ("  Study " .. SK.FormatStudyTime(studyLeft)) or ""
        parts.title:SetText(("|cff69ccf0Scrollkeeper|r  |cffffffff%d ready|r%s"):format(readable, study))
    else
        parts.title:SetText("|cff69ccf0Scrollkeeper|r")
    end

    -- Skill bar
    local bonus = skill.bonus > 0 and (" |cff40ff40+%d|r"):format(skill.bonus) or ""
    parts.skillBar:SetProgress(skill.rank, skill.max)
    parts.skillBar:SetMarks(SK.TIERS, skill.max)
    parts.skillBar:SetLabel(("Comprehension %d%s / %d"):format(skill.rank, bonus, skill.max))

    local nextTier = SK.NextTierAfter(skill.effective)
    if not nextTier then
        parts.tier:SetText("|cff40ff40You can read every scroll tier.|r")
    elseif nextTier > skill.max then
        -- The cap rises with character level, so say when it becomes reachable.
        local levelNeeded = math.ceil(nextTier / SK.SKILL_CAP_PER_LEVEL)
        parts.tier:SetText(("Next tier at |cffffffff%d|r (reachable at level %d)"):format(nextTier, levelNeeded))
    else
        parts.tier:SetText(("Next tier at |cffffffff%d|r (%d to go)"):format(nextTier, nextTier - skill.effective))
    end

    -- Scrolls waiting
    if readable + tooHard == 0 then
        parts.waiting:SetText("|cff8c8c8cNo untranslated scrolls in your bags.|r")
    elseif tooHard > 0 then
        parts.waiting:SetText(("|cff40ff40%d ready|r to decipher, |cffff6666%d too hard|r"):format(readable, tooHard))
    else
        parts.waiting:SetText(("|cff40ff40%d ready|r to decipher"):format(readable))
    end

    -- Scroll counts (the icons themselves only change out of combat)
    for i, button in ipairs(scrollButtons) do
        local scroll = SK.db.showScrollBar and SK.bags.translated[i]
        if scroll and button.itemID == scroll.itemID then
            button:SetDisplay(scroll.itemID, scroll.icon, scroll.count)
        end
    end

    -- Study bar: fills up as the cooldown runs down.
    local feathers = ("Feathers %d"):format(SK.bags.feathers)
    if not knowsStudy then
        parts.studyBar:SetProgress(0, 1)
        parts.studyBar:SetLabel("|cff8c8c8cStudy not learned yet|r")
    elseif studyLeft == 0 then
        parts.studyBar:SetProgress(1, 1)
        parts.studyBar:SetBarColor(colors.good)
        parts.studyBar:SetLabel("Study ready   |cffffffff" .. feathers .. "|r")
    else
        parts.studyBar:SetProgress(SK.STUDY_COOLDOWN_SECONDS - studyLeft, SK.STUDY_COOLDOWN_SECONDS)
        parts.studyBar:SetBarColor(colors.wait)
        parts.studyBar:SetLabel(("Study in %s   |cffffffff%s|r"):format(SK.FormatStudyTime(studyLeft), feathers))
    end

    -- Warning
    if SK.bags.bundles > 0 then
        parts.warning:SetText("|cffffd100Open your Bundle of Scrolls before the next Study.|r")
    elseif knowsStudy and SK.bags.feathers == 0 then
        parts.warning:SetText("|cffff6666No Light Feathers. Study needs one.|r")
    else
        parts.warning:SetText("")
    end
end

-- Redraw everything. Other files call this after a setting changes.
function SK.RefreshPanel()
    if not panel then return end
    UpdateText()
    Layout()
end

------------------------------------------------------------------------
-- Showing, hiding and settings
------------------------------------------------------------------------

function SK.TogglePanel()
    if not panel then return end
    if SK.InCombat() then
        SK.Print("the panel can't be shown or hidden in combat.")
        return
    end
    SK.db.showPanel = not panel:IsShown()
    panel:SetShown(SK.db.showPanel)
    if SK.db.showPanel then SK.RefreshPanel() end
end

-- Apply the saved settings to the window (called from the settings page).
function SK.ApplyPanelSettings()
    if not panel or SK.InCombat() then return end
    panel:SetScale(SK.db.scale or 1)
    panel:SetShown(SK.db.showPanel)
    SK.RefreshPanel()
end

SK.Listen("READY", function()
    if not SK.isMage then return end   -- other classes only get tooltips
    Build()
    panel:SetShown(SK.db.showPanel)

    SK.Listen("BAGS_CHANGED", SK.RefreshPanel)
    SK.Listen("SKILL_CHANGED", SK.RefreshPanel)
    SK.Listen("STUDY_CHANGED", SK.RefreshPanel)
    SK.On("PLAYER_REGEN_ENABLED", function()
        if layoutWaiting then SK.RefreshPanel() end
    end)

    -- Tick the Study timer once a second while the panel is visible.
    local sinceLast = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        sinceLast = sinceLast + elapsed
        if sinceLast < 1 then return end
        sinceLast = 0
        SK.Safely("panel timer", UpdateText)
    end)
end)
