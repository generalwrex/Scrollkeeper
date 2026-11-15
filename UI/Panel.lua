-- Scrollkeeper: UI/Panel.lua
-- The window mages see, built like the game's own character window:
--
--   portrait + title        drag to move; shrink, settings and close buttons
--   skill bar               Comprehension, with ticks where the tiers are
--   [Decipher]              ready / skill-ups / too hard / next tier, and the button
--   [Your Scrolls]          a button for each kind of usable scroll in your bags
--   [Study]                 cooldown, Light Feathers, library, warnings
--
-- Secure buttons (decipher, scroll buttons) can only be moved, shown or
-- re-pointed out of combat, so layout changes wait until combat ends.

local _, SK = ...

local WIDTH = 250
local LEFT, RIGHT = 12, 12             -- inner padding of the window
local INNER = WIDTH - LEFT - RIGHT
local TOP = 62                          -- where the content starts, below the portrait
local ROW_HEIGHT = 16
local ICON_SIZE, ICON_GAP, ICONS_PER_ROW = 30, 6, 6
local MAX_SCROLL_BUTTONS = 12
local COLLAPSED_HEIGHT = 58
local PORTRAIT = "Interface\\Icons\\INV_Scroll_03"

local panel
local parts = {}            -- named pieces of the window
local sections = {}         -- section header plates
local rows = {}             -- label/value rows, by name
local scrollButtons = {}
local layoutWaiting         -- a layout change is waiting for combat to end
local usingGameFrame        -- true when the game's own window template was available

------------------------------------------------------------------------
-- Small builders
------------------------------------------------------------------------

-- A small square button drawn with one of the game's button icons.
local function IconButton(texture, size, tooltip, onClick)
    local button = CreateFrame("Button", nil, panel)
    button:SetSize(size, size)
    button:SetNormalTexture(texture)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(type(tooltip) == "function" and tooltip() or tooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self, ...)
        onClick(self, ...)
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)
    return button
end

-- A bronze section plate like "General" on the character window.
-- Uses the character window's own template when the game has it.
local function SectionHeader(text)
    local ok, header = pcall(CreateFrame, "Frame", nil, panel, "CharacterStatFrameCategoryTemplate")
    if ok and header and type(header.Title) == "table" then
        header.Title:SetText(text)
    else
        header = CreateFrame("Frame", nil, panel)
        local background = header:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.35, 0.22, 0.08, 0.85)
        local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("CENTER", 0, 0)
        title:SetText(text)
        header.Title = title
    end
    header:SetSize(INNER, 22)
    table.insert(sections, header)
    return header
end

-- A "Label ........ value" row with a faint stripe, like the stat rows.
local function Row(name, label, striped)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(INNER, ROW_HEIGHT)
    if striped then
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        stripe:SetColorTexture(0.45, 0.32, 0.12, 0.18)
    end
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetText(label)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", -6, 0)
    row.value:SetJustifyH("RIGHT")
    rows[name] = row
    return row
end

------------------------------------------------------------------------
-- Building the window (runs once)
------------------------------------------------------------------------

local function CreateWindow()
    -- The game's own window: portrait, gold border, title bar, close button.
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperPanel", UIParent, "PortraitFrameTemplate")
    if ok and frame and type(frame.SetTitle) == "function" then
        usingGameFrame = true
        frame:SetTitle("Scrollkeeper")
        if type(frame.SetPortraitToAsset) == "function" then
            frame:SetPortraitToAsset(PORTRAIT)
        elseif type(frame.SetPortraitTextureRaw) == "function" then
            frame:SetPortraitTextureRaw(PORTRAIT)
        end
        -- Opaque background, like the character window.
        local background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetPoint("TOPLEFT", 2, -2)
        background:SetPoint("BOTTOMRIGHT", -2, 2)
        background:SetColorTexture(0.05, 0.05, 0.06, 0.95)
        return frame
    end

    -- Fallback if the template is missing: a plain dialog window.
    usingGameFrame = false
    frame = CreateFrame("Frame", "ScrollkeeperPanel", UIParent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Scrollkeeper")
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(36, 36)
    portrait:SetPoint("TOPLEFT", 10, -10)
    portrait:SetTexture(PORTRAIT)
    return frame
end

-- Keep the window's top-left corner still when its height changes, so
-- shrinking it doesn't make it jump. Positions are saved the same way.
local function AnchorTopLeft()
    local left, top = panel:GetLeft(), panel:GetTop()
    if not left or not top then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    SK.db.panelPoint = { "TOPLEFT", "BOTTOMLEFT", left, top }
end

local function Build()
    panel = CreateWindow()
    panel:SetSize(WIDTH, 300)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetToplevel(true)

    -- We save the position ourselves (top-left corner), so tell the game
    -- not to. Otherwise it restores its own copy, anchored to whichever
    -- corner is closest, and the window jumps when its height changes.
    if panel.SetDontSavePosition then panel:SetDontSavePosition(true) end
    if panel.SetUserPlaced then pcall(panel.SetUserPlaced, panel, false) end

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
        if self.SetUserPlaced then pcall(self.SetUserPlaced, self, false) end
        AnchorTopLeft()
    end)

    local saved = SK.db.panelPoint
    if saved then
        panel:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
    end
    panel:SetScale(SK.db.scale or 1)
    AnchorTopLeft()

    -- Close: the template's red X, or our own.
    local close = usingGameFrame and type(panel.CloseButton) == "table" and panel.CloseButton
        or CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    if not usingGameFrame then close:SetPoint("TOPRIGHT", 1, 1) end
    close:SetScript("OnClick", function()
        if SK.InCombat() then SK.Print("the panel can't be hidden in combat.") return end
        SK.db.showPanel = false
        panel:Hide()
        SK.Print("panel hidden. Type /sk to show it again.")
    end)

    -- Summary line beside the portrait, like "Level 20 Mage".
    parts.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    parts.summary:SetPoint("TOPLEFT", 62, -32)
    parts.summary:SetPoint("RIGHT", panel, "RIGHT", -52, 0)
    parts.summary:SetJustifyH("CENTER")
    parts.summary:SetWordWrap(false)

    -- Shrink and settings, at the right of the summary line.
    parts.gear = IconButton("Interface\\Buttons\\UI-OptionsButton", 18, "Settings", function() SK.OpenOptions() end)
    parts.gear:SetPoint("TOPRIGHT", -12, -30)
    parts.collapse = IconButton("Interface\\Buttons\\UI-MinusButton-Up", 18,
        function() return SK.db.collapsed and "Expand" or "Shrink" end,
        function()
            if SK.InCombat() then SK.Print("the panel can't change size in combat.") return end
            SK.db.collapsed = not SK.db.collapsed
            SK.RefreshPanel()
        end)
    parts.collapse:SetPoint("RIGHT", parts.gear, "LEFT", -4, 0)

    -- Comprehension bar
    parts.skillBar = SK.UI.CreateBar(panel, INNER, 16)
    parts.skillBar:SetBarColor(SK.UI.COLORS.accent)

    -- Decipher section
    parts.decipherHeader = SectionHeader("Decipher")
    Row("ready", "Ready", true)
    Row("skillups", "Skill-ups", false)
    Row("tooHard", "Too hard", true)
    Row("nextTier", "Next tier", false)

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
            local chance = SK.SkillUpChance(nextScroll.needs, SK.GetComprehension().rank)
            if chance then GameTooltip:AddLine(SK.ColoredChance(chance)) end
            GameTooltip:AddLine("One click deciphers one scroll. Scrolls that can raise your skill go first.", 0.7, 0.7, 0.7, true)
        else
            GameTooltip:SetText("Nothing to decipher")
            GameTooltip:AddLine("Untranslated scrolls drop from enemies and chests everywhere.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    parts.decipher:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Your scrolls section
    parts.scrollsHeader = SectionHeader("Your Scrolls")
    for i = 1, MAX_SCROLL_BUTTONS do
        scrollButtons[i] = SK.UI.CreateItemButton(panel, "ScrollkeeperScrollButton" .. i, ICON_SIZE)
        scrollButtons[i]:Hide()
    end

    -- Study section
    parts.studyHeader = SectionHeader("Study")
    parts.studyBar = SK.UI.CreateBar(panel, INNER, 16)
    Row("feathers", "Light Feathers", true)
    Row("library", "Library", false)

    parts.warning = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    parts.warning:SetWidth(INNER)
    parts.warning:SetJustifyH("LEFT")
end

------------------------------------------------------------------------
-- Layout: where each piece sits. Only runs out of combat.
------------------------------------------------------------------------

local function Place(region, y, height)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT, y)
    return y - height
end

local function Layout()
    if SK.InCombat() then
        layoutWaiting = true
        return
    end
    layoutWaiting = false

    local collapsed = SK.db.collapsed
    parts.collapse:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up"
        or "Interface\\Buttons\\UI-MinusButton-Up")

    local body = {
        parts.skillBar, parts.decipherHeader, parts.decipher, parts.scrollsHeader,
        parts.studyHeader, parts.studyBar, parts.warning,
    }
    for _, region in ipairs(body) do region:SetShown(not collapsed) end
    for _, row in pairs(rows) do row:SetShown(not collapsed) end

    AnchorTopLeft()   -- pin the top edge before the height changes

    if collapsed then
        for _, button in ipairs(scrollButtons) do button:Hide() end
        panel:SetHeight(COLLAPSED_HEIGHT)
        return
    end

    local y = -TOP
    y = Place(parts.skillBar, y, 16) - 10

    -- Decipher
    y = Place(parts.decipherHeader, y, 22) - 2
    for _, name in ipairs({ "ready", "skillups", "tooHard", "nextTier" }) do
        y = Place(rows[name], y, ROW_HEIGHT)
    end
    y = Place(parts.decipher, y - 6, 24) - 10

    -- Your scrolls (only when there are some)
    local scrolls = SK.db.showScrollBar and SK.bags.translated or {}
    local shown = math.min(#scrolls, MAX_SCROLL_BUTTONS)
    parts.scrollsHeader:SetShown(shown > 0)
    if shown > 0 then
        y = Place(parts.scrollsHeader, y, 22) - 8
    end
    for i, button in ipairs(scrollButtons) do
        local scroll = scrolls[i]
        if scroll and i <= shown then
            local column, line = (i - 1) % ICONS_PER_ROW, math.floor((i - 1) / ICONS_PER_ROW)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", panel, "TOPLEFT",
                LEFT + 6 + column * (ICON_SIZE + ICON_GAP), y - line * (ICON_SIZE + ICON_GAP))
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
        y = y - math.ceil(shown / ICONS_PER_ROW) * (ICON_SIZE + ICON_GAP) - 4
    end

    -- Study
    y = Place(parts.studyHeader, y, 22) - 6
    y = Place(parts.studyBar, y, 16) - 6
    y = Place(rows.feathers, y, ROW_HEIGHT)
    y = Place(rows.library, y, ROW_HEIGHT)

    local warning = parts.warning:GetText()
    if warning and warning ~= "" then
        y = Place(parts.warning, y - 6, parts.warning:GetStringHeight())
    end

    panel:SetHeight(-y + 12)

    -- Point the decipher button at the next scroll.
    local nextScroll, readable = SK.NextDecipherable()
    if nextScroll then
        parts.decipher:SetAttribute("type", "spell")
        parts.decipher:SetAttribute("spell", SK.SPELL_COMPREHEND_SCROLL)
        parts.decipher:SetAttribute("target-bag", nextScroll.bag)
        parts.decipher:SetAttribute("target-slot", nextScroll.slot)
        local chance = SK.SkillUpChance(nextScroll.needs, SK.GetComprehension().rank)
        local mark = (chance and chance.gives) and " |cffff8040+|r" or ""
        parts.decipher:SetText(("Decipher next scroll (%d)%s"):format(readable, mark))
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

local GREEN, RED, GRAY, ORANGE = "|cff40ff40", "|cffff6666", "|cff8c8c8c", "|cffff8040"

local function UpdateText()
    local colors = SK.UI.COLORS
    local skill = SK.GetComprehension()
    local _, readable, tooHard, skillUps = SK.NextDecipherable()
    local studyLeft = SK.StudySecondsLeft()
    local knowsStudy = SK.KnowsStudy()
    local inLibrary, place = SK.InLibrary()

    -- Summary line beside the portrait.
    if SK.db.collapsed then
        parts.summary:SetText(("|cffffffff%d|r ready"):format(readable))
    else
        parts.summary:SetText(("Comprehension |cffffffff%d|r"):format(skill.rank))
    end

    -- Skill bar
    local bonus = skill.bonus > 0 and (" " .. GREEN .. "+%d|r"):format(skill.bonus) or ""
    parts.skillBar:SetProgress(skill.rank, skill.max)
    parts.skillBar:SetMarks(SK.TIERS, skill.max)
    parts.skillBar:SetLabel("Skill", ("%d%s / %d"):format(skill.rank, bonus, skill.max))

    -- Decipher rows
    rows.ready.value:SetText(readable > 0 and (GREEN .. readable .. "|r") or (GRAY .. "0|r"))
    rows.skillups.value:SetText(skillUps > 0 and (ORANGE .. skillUps .. "|r") or (GRAY .. "none|r"))
    rows.tooHard.value:SetText(tooHard > 0 and (RED .. tooHard .. "|r") or (GRAY .. "0|r"))

    local nextTier = SK.NextTierAfter(skill.effective)
    if not nextTier then
        rows.nextTier.value:SetText(GREEN .. "all unlocked|r")
    elseif nextTier > skill.max then
        rows.nextTier.value:SetText(("%d %s(level %d)|r"):format(nextTier, GRAY,
            math.ceil(nextTier / SK.SKILL_CAP_PER_LEVEL)))
    else
        rows.nextTier.value:SetText(("%d %s(%d to go)|r"):format(nextTier, GRAY, nextTier - skill.effective))
    end

    -- Scroll counts (the icons themselves only change out of combat)
    for i, button in ipairs(scrollButtons) do
        local scroll = SK.db.showScrollBar and SK.bags.translated[i]
        if scroll and button.itemID == scroll.itemID then
            button:SetDisplay(scroll.itemID, scroll.icon, scroll.count)
        end
    end

    -- Study bar: fills up as the cooldown runs down.
    if not knowsStudy then
        parts.studyBar:SetProgress(0, 1)
        parts.studyBar:SetLabel(GRAY .. "Not learned yet|r")
    elseif studyLeft == 0 then
        parts.studyBar:SetProgress(1, 1)
        parts.studyBar:SetBarColor(colors.good)
        parts.studyBar:SetLabel("Ready")
    else
        parts.studyBar:SetProgress(SK.STUDY_COOLDOWN_SECONDS - studyLeft, SK.STUDY_COOLDOWN_SECONDS)
        parts.studyBar:SetBarColor(colors.wait)
        parts.studyBar:SetLabel("Cooldown", SK.FormatStudyTime(studyLeft))
    end
    rows.feathers.value:SetText(SK.bags.feathers > 0 and SK.bags.feathers or (RED .. "0|r"))
    rows.library.value:SetText(inLibrary and (GREEN .. "you're in one|r") or (GRAY .. "not here|r"))

    -- Warning (most important first)
    if SK.bags.bundles > 0 then
        parts.warning:SetText("|cffffd100Open your Bundle of Scrolls before the next Study.|r")
    elseif knowsStudy and SK.bags.feathers == 0 then
        parts.warning:SetText(RED .. "No Light Feathers. Study needs one.|r")
    elseif knowsStudy and studyLeft == 0 and inLibrary then
        parts.warning:SetText(GREEN .. "Study is ready and you're in a library.|r")
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
    -- Changing the scale also scales the saved position, so convert the
    -- corner to screen pixels first and back again afterwards.
    local newScale = SK.db.scale or 1
    local oldScale = panel:GetScale()
    local left, top = panel:GetLeft(), panel:GetTop()
    panel:SetScale(newScale)
    if left and top and oldScale ~= newScale then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * oldScale / newScale, top * oldScale / newScale)
    end
    AnchorTopLeft()
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
    SK.Listen("PLACE_CHANGED", SK.RefreshPanel)
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
