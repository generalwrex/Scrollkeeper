-- Scrollkeeper: UI/Panel.lua
-- The small window mages see: skill, scrolls waiting, the decipher
-- button, and the Study timer. Drag it anywhere; the position is saved.

local _, SK = ...

local WIDTH, PADDING = 230, 10
local BASE_HEIGHT = 144   -- window height with no warning showing

local panel, button
local lines = {}          -- text rows, top to bottom
local needsButtonUpdate   -- set when the button must change after combat

------------------------------------------------------------------------
-- Building the window
------------------------------------------------------------------------

local function AddLine(name, font)
    local text = panel:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetWidth(WIDTH - PADDING * 2)
    lines[name] = text
    return text
end

local function Build()
    panel = CreateFrame("Frame", "ScrollkeeperPanel", UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, BASE_HEIGHT)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.8)
    panel:SetBackdropBorderColor(0.41, 0.8, 0.94, 1)

    -- Dragging
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        if not SK.InCombat() then self:StartMoving() end
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

    -- Rows. Everything is placed at a fixed distance from the top of the
    -- window, because the game does not allow a secure button to be
    -- attached to a piece of text.
    local function PlaceRow(name, y, font)
        local row = AddLine(name, font)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, y)
        return row
    end

    PlaceRow("title", -10, "GameFontNormal"):SetText("|cff69ccf0Scrollkeeper|r")
    PlaceRow("skill", -30)
    PlaceRow("tier", -45)
    PlaceRow("scrolls", -60)

    -- Decipher button: a secure button, so one click from you casts
    -- Comprehend Scroll on the chosen scroll. Nothing is automatic.
    button = CreateFrame("Button", "ScrollkeeperDecipherButton", panel,
        "SecureActionButtonTemplate,UIPanelButtonTemplate")
    button:SetSize(WIDTH - PADDING * 2, 22)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -78)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetText("Decipher next scroll")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local nextScroll = SK.NextDecipherable()
        if nextScroll then
            GameTooltip:SetText("Decipher " .. nextScroll.name)
            GameTooltip:AddLine(("Needs %d Comprehension."):format(nextScroll.needs), 1, 1, 1)
            if not (IsResting and IsResting()) then
                GameTooltip:AddLine("You are not in a rest area. Guides say a failed decipher can turn you into a sheep for a few seconds.", 1, 0.6, 0.2, true)
            end
        else
            GameTooltip:SetText("Nothing to decipher")
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    PlaceRow("study", -108)
    PlaceRow("log", -123)
    PlaceRow("warning", -140)   -- last, because it can wrap onto two lines

    -- Close button (top right)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        if SK.InCombat() then
            SK.Print("the panel can't be hidden in combat.")
            return
        end
        SK.db.showPanel = false
        panel:Hide()
        SK.Print("panel hidden. Type /sk to show it again.")
    end)
end

------------------------------------------------------------------------
-- Keeping it up to date
------------------------------------------------------------------------

-- Point the button at the next scroll. The game only allows this out of combat.
local function UpdateButton()
    if SK.InCombat() then
        needsButtonUpdate = true
        return
    end
    needsButtonUpdate = false

    local nextScroll, readable = SK.NextDecipherable()
    if nextScroll then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", SK.SPELL_COMPREHEND_SCROLL)
        button:SetAttribute("target-bag", nextScroll.bag)
        button:SetAttribute("target-slot", nextScroll.slot)
        button:SetText(("Decipher next scroll (%d)"):format(readable))
        button:Enable()
    else
        button:SetAttribute("type", nil)
        button:SetText("Nothing to decipher")
        button:Disable()
    end
end

local function UpdateText()
    local skill = SK.GetComprehension()
    local _, readable, tooHard = SK.NextDecipherable()

    -- Skill
    local bonus = skill.bonus > 0 and (" |cff40ff40+%d|r"):format(skill.bonus) or ""
    lines.skill:SetText(("Comprehension: |cffffffff%d%s|r / %d"):format(skill.rank, bonus, skill.max))

    -- Tier
    local nextTier = SK.NextTierAfter(skill.effective)
    if nextTier then
        lines.tier:SetText(("Next tier at %d (%d to go)"):format(nextTier, nextTier - skill.effective))
    else
        lines.tier:SetText("You can read every tier.")
    end

    -- Scrolls waiting
    if readable + tooHard == 0 then
        lines.scrolls:SetText("No untranslated scrolls in your bags.")
    elseif tooHard > 0 then
        lines.scrolls:SetText(("Scrolls: |cff40ff40%d ready|r, |cffff6666%d too hard|r"):format(readable, tooHard))
    else
        lines.scrolls:SetText(("Scrolls: |cff40ff40%d ready|r"):format(readable))
    end

    -- Study
    if SK.KnowsStudy() then
        local left = SK.StudySecondsLeft()
        local color = left == 0 and "|cff40ff40" or "|cffffffff"
        lines.study:SetText(("Study: %s%s|r   Feathers: |cffffffff%d|r"):format(
            color, SK.FormatStudyTime(left), SK.bags.feathers))
    else
        lines.study:SetText("Study: not learned yet")
    end

    -- Warnings
    if SK.bags.bundles > 0 then
        lines.warning:SetText("|cffffd100Open your Bundle of Scrolls before the next Study.|r")
    elseif SK.KnowsStudy() and SK.bags.feathers == 0 then
        lines.warning:SetText("|cffff6666No Light Feathers. Study needs one.|r")
    else
        lines.warning:SetText("")
    end

    lines.log:SetText(("Deciphered so far: %d  |cff888888(/sk log)|r"):format(SK.db.deciphered or 0))

    -- Fit the window to its content: taller when a warning is showing.
    if not SK.InCombat() then
        local warningText = lines.warning:GetText()
        local extra = (warningText and warningText ~= "") and (lines.warning:GetStringHeight() + 8) or 0
        panel:SetHeight(BASE_HEIGHT + extra)
    end
end

local function Update()
    if not panel then return end
    UpdateText()
    UpdateButton()
end

------------------------------------------------------------------------
-- Showing and hiding
------------------------------------------------------------------------

function SK.TogglePanel()
    if not panel then return end
    if SK.InCombat() then
        SK.Print("the panel can't be shown or hidden in combat.")
        return
    end
    SK.db.showPanel = not panel:IsShown()
    panel:SetShown(SK.db.showPanel)
    if SK.db.showPanel then Update() end
end

SK.Listen("READY", function()
    if not SK.isMage then return end   -- other classes only get tooltips
    Build()
    panel:SetShown(SK.db.showPanel)

    SK.Listen("BAGS_CHANGED", Update)
    SK.Listen("SKILL_CHANGED", Update)
    SK.Listen("STUDY_CHANGED", Update)
    SK.Listen("LOG_CHANGED", Update)
    SK.On("PLAYER_REGEN_ENABLED", function()
        if needsButtonUpdate then Update() end
    end)

    -- Tick the Study timer once a second while the panel is visible.
    local elapsedTotal = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < 1 then return end
        elapsedTotal = 0
        SK.Safely("panel timer", UpdateText)
    end)
end)
