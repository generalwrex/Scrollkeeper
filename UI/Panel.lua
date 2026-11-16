-- Scrollkeeper: UI/Panel.lua
-- The window mages see, built like the game's own character window:
--
--   portrait + title        drag to move; shrink, settings and close buttons
--   skill bar               Comprehension, with ticks where the tiers are
--   [Decipher]              ready / skill-ups / too hard / next tier, and the button
--   [Your Scrolls]          a button for each kind of usable scroll in your bags
--   [Familiar] [Imbue]      use your best familiar / imbue scroll, one click
--   [Study]                 cooldown, Light Feathers, library, warnings
--
-- The Advanced view adds a right-hand column: the Scrollkeeper network
-- (other users, community odds) and Your Stats.
--
-- Secure buttons (decipher, scroll buttons) can only be moved, shown or
-- re-pointed out of combat, so layout changes wait until combat ends.

local _, SK = ...
local L = SK.L

local WIDTH = 250
local LEFT, RIGHT = 16, 18             -- inner padding, clear of the gold border
local INNER = WIDTH - LEFT - RIGHT
local TOP = 62                          -- where the content starts, below the portrait
local ROW_HEIGHT = 16
local ICON_SIZE, ICON_GAP, ICONS_PER_ROW = 26, 4, 5
local CATEGORY_LABEL_WIDTH = 64   -- "Familiars" etc. to the left of each icon row
local SCROLLS_MAX_ROWS = 4        -- icon rows shown before Your Scrolls gets a scrollbar
local COMPACT_ICONS_PER_ROW = 7   -- compact view: icons per row, no labels
local MAX_SCROLL_BUTTONS = 40
local QUICK_ICON = 30             -- Familiar / Imbue icon buttons
local ICON_PAD = 3                -- room inside the scroll box for the gold outline and counts
local COLLAPSED_HEIGHT = 92        -- title bar, portrait, the skill bar, and the bottom border
local SIDE_WIDTH = 250            -- Advanced view: the extra right-hand column
local SIDE_INNER = SIDE_WIDTH - RIGHT - 4
local PORTRAIT = "Interface\\Icons\\INV_Scroll_03"
local SIZE_SMALLER = "Interface\\Buttons\\UI-Panel-SmallerButton-Up"
local SIZE_SMALLER_DOWN = "Interface\\Buttons\\UI-Panel-SmallerButton-Down"
local SIZE_BIGGER = "Interface\\Buttons\\UI-Panel-BiggerButton-Up"
local SIZE_BIGGER_DOWN = "Interface\\Buttons\\UI-Panel-BiggerButton-Down"

local panel
local parts = {}            -- named pieces of the window
local sections = {}         -- section header plates
local rows = {}             -- label/value rows, by name
local scrollButtons = {}
local side = {}             -- Advanced view's right-hand column: network and stats
local layoutWaiting         -- a layout change is waiting for combat to end
local usingGameFrame        -- true when the game's own window template was available

------------------------------------------------------------------------
-- Views: "full" (Advanced) shows everything, "compact" (Simple) only the
-- buttons and bars, "mini" just the title bar.
------------------------------------------------------------------------

local VIEW_ORDER = { full = "compact", compact = "mini", mini = "full" }

function SK.ViewMode()
    local mode = SK.db.viewMode
    if not VIEW_ORDER[mode] then
        -- Settings saved before views existed: keep what they had.
        -- Brand-new installs start Simple.
        if SK.db.collapsed ~= nil then
            mode = SK.db.collapsed and "mini" or "full"
        else
            mode = "compact"
        end
        SK.db.viewMode = mode
    end
    return mode
end

function SK.NextViewMode()
    return VIEW_ORDER[SK.ViewMode()]
end

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
        frame:SetTitle(L["Scrollkeeper"])
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
    title:SetText(L["Scrollkeeper"])
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

-- When the window grows (Advanced is tall), don't let it run down
-- behind the action bars: slide it up instead.
local BOTTOM_MARGIN = 150   -- room for the action bars, in screen units
local function KeepAboveActionBars()
    local left, top = panel:GetLeft(), panel:GetTop()
    if not left or not top then return end
    local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local bottomOnScreen = (top - panel:GetHeight()) * scale
    if bottomOnScreen < BOTTOM_MARGIN then
        local newTop = math.min(top + (BOTTOM_MARGIN - bottomOnScreen) / scale,
            UIParent:GetTop() / scale)
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, newTop)
        SK.db.panelPoint = { "TOPLEFT", "BOTTOMLEFT", left, newTop }
    end
end

-- After a size change, slide the window so the size button is back where
-- it was (under the mouse), and remember the new spot.
-- The game's window frame has tall bottom corner pieces (about 100 high).
-- In the short title-only view they'd poke out above the top of the
-- window, so crop them to their bottom part there, and restore them
-- in the other views.
local CORNER_KEEP = 30
local function FitBorder(short)
    local border = panel.NineSlice
    if type(border) ~= "table" then return end
    for _, key in ipairs({ "BottomLeftCorner", "BottomRightCorner" }) do
        local piece = border[key]
        if type(piece) == "table" and piece.GetTexCoord and piece:GetHeight() > 0 then
            piece.skOriginal = piece.skOriginal or { height = piece:GetHeight(), coords = { piece:GetTexCoord() } }
            local original = piece.skOriginal
            local c = original.coords   -- ULx, ULy, LLx, LLy, URx, URy, LRx, LRy
            if short and original.height > CORNER_KEEP then
                local keep = CORNER_KEEP / original.height
                piece:SetHeight(CORNER_KEEP)
                piece:SetTexCoord(c[1], c[4] - (c[4] - c[2]) * keep, c[3], c[4],
                    c[5], c[8] - (c[8] - c[6]) * keep, c[7], c[8])
            else
                piece:SetHeight(original.height)
                piece:SetTexCoord(unpack(c))
            end
        end
    end
end

local function KeepUnderMouse(button, oldX, oldY)
    local newX, newY = button:GetCenter()
    local left, top = panel:GetLeft(), panel:GetTop()
    if not (oldX and newX and left and top) then return end
    left, top = left + (oldX - newX), top + (oldY - newY)
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
        if SK.db.locked then return end
        if SK.InCombat() then
            SK.Print(L["the panel can be moved after combat."])
            return
        end
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
    -- The panel holds protected buttons (Decipher, Study, scrolls), so the
    -- game won't let addon code hide it in combat. A secure button laid over
    -- the X can: its click runs in the game's own restricted environment.
    do
        local secureClose = CreateFrame("Button", "ScrollkeeperSecureClose", panel, "SecureHandlerClickTemplate")
        secureClose:SetAllPoints(close)
        secureClose:SetFrameLevel(close:GetFrameLevel() + 2)
        secureClose:SetFrameRef("panel", panel)
        secureClose:SetAttribute("_onclick", [[ self:GetFrameRef("panel"):Hide() ]])
        secureClose:HookScript("OnClick", function()
            SK.db.showPanel = false
            SK.Print(L["panel hidden. Type /sk to show it again"] .. (SK.InCombat() and L[" (after combat)."] or "."))
        end)
        secureClose:SetScript("OnEnter", function() close:LockHighlight() end)
        secureClose:SetScript("OnLeave", function() close:UnlockHighlight() end)
    end
    close:SetScript("OnClick", function()
        if SK.InCombat() then SK.Print(L["the panel can't be hidden in combat."]) return end
        SK.db.showPanel = false
        panel:Hide()
        SK.Print(L["panel hidden. Type /sk to show it again."])
    end)

    -- Summary line beside the portrait, like "Level 20 Mage".
    parts.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    parts.summary:SetPoint("TOPLEFT", 62, -32)
    parts.summary:SetPoint("RIGHT", panel, "RIGHT", -80, 0)
    parts.summary:SetJustifyH("CENTER")
    parts.summary:SetWordWrap(false)

    -- Shrink and settings, at the right of the summary line.
    parts.gear = IconButton("Interface\\Buttons\\UI-OptionsButton", 18, L["Settings"], function() SK.OpenOptions() end)
    parts.gear:SetPoint("TOPRIGHT", -12, -30)
    -- Size button, the world map's resize arrows.
    --   left-click:  smaller (Advanced -> Simple -> Title only, then back to Advanced)
    --   right-click: bigger
    -- The window moves so the button stays under your mouse.
    local VIEW_NAMES = { full = L["Advanced"], compact = L["Simple"], mini = L["Title only"] }
    local SMALLER = { full = "compact", compact = "mini", mini = "full" }
    local BIGGER = { mini = "compact", compact = "full", full = "full" }
    parts.collapse = IconButton(SIZE_SMALLER, 24,
        function()
            local mode = SK.ViewMode()
            local text = L["Size: |cffffffff%s|r\nLeft-click: %s"]:format(VIEW_NAMES[mode], VIEW_NAMES[SMALLER[mode]])
            if BIGGER[mode] ~= mode then
                text = text .. L["\nRight-click: %s"]:format(VIEW_NAMES[BIGGER[mode]])
            end
            return text
        end,
        function(self, mouseButton)
            if SK.InCombat() then SK.Print(L["the panel can't change size in combat."]) return end
            local mode = SK.ViewMode()
            local new = mouseButton == "RightButton" and BIGGER[mode] or SMALLER[mode]
            if new == mode then return end
            local oldX, oldY = self:GetCenter()
            SK.db.viewMode = new
            SK.RefreshPanel()
            KeepUnderMouse(self, oldX, oldY)
        end)
    parts.collapse:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    parts.collapse:SetPoint("RIGHT", parts.gear, "LEFT", -1, 0)

    parts.network = IconButton("Interface\\Icons\\INV_Misc_Book_09", 18,
        function()
            local count = #SK.PeerList()
            return L["Network: %d Scrollkeeper |4user:users; heard from"]:format(count)
        end,
        function() SK.ToggleNetwork() end)
    parts.network:SetPoint("RIGHT", parts.collapse, "LEFT", -4, 0)

    -- Turn the scroll icon (UI/Icon.lua) on and off. Greyed out while it's off.
    parts.iconToggle = IconButton("Interface\\Icons\\INV_Scroll_03", 18,
        function()
            return (SK.db.scrollIcon and L["Scroll icon: |cff40ff40on|r"] or L["Scroll icon: |cff808080off|r"])
                .. "\n" .. L["|cffffffffClick to turn it on or off.|r"]
        end,
        function(self)
            SK.db.scrollIcon = not SK.db.scrollIcon
            if SK.RefreshIcon then SK.RefreshIcon() end
        end)
    parts.iconToggle:SetPoint("RIGHT", parts.network, "LEFT", -4, 0)
    panel.iconToggle = parts.iconToggle
    if SK.RefreshIcon then SK.RefreshIcon() end

    -- Comprehension bar
    parts.skillBar = SK.UI.CreateBar(panel, INNER, 16)
    parts.skillBar:SetBarColor(SK.UI.COLORS.accent)

    -- Decipher section
    parts.decipherHeader = SectionHeader(L["Decipher"])
    Row("ready", L["Ready"], true)
    Row("skillups", L["Skill-ups"], false)
    Row("tooHard", L["Too hard"], true)
    Row("nextTier", L["Next tier"], false)

    parts.decipher = CreateFrame("Button", "ScrollkeeperDecipherButton", panel,
        "SecureActionButtonTemplate,UIPanelButtonTemplate")
    parts.decipher:SetSize(INNER, 24)
    parts.decipher:RegisterForClicks("AnyUp", "AnyDown")
    parts.decipher:SetText(L["Decipher next scroll"])
    parts.decipher:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local nextScroll = SK.NextDecipherable()
        if nextScroll then
            GameTooltip:SetText(L["Decipher "] .. SK.ScrollLink(nextScroll.itemID, nextScroll.name))
            GameTooltip:AddLine(L["Needs %d Comprehension."]:format(nextScroll.needs), 1, 1, 1)
            local chance = SK.SkillUpChance(nextScroll.needs, SK.GetComprehension().rank)
            if chance then GameTooltip:AddLine(SK.ColoredChance(chance)) end
            GameTooltip:AddLine(L["One click deciphers one scroll. Scrolls that can raise your skill go first."], 0.7, 0.7, 0.7, true)
        else
            GameTooltip:SetText(L["Nothing to decipher"])
            GameTooltip:AddLine(L["Untranslated scrolls drop from enemies and chests everywhere."], 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    parts.decipher:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Familiar and Imbue: the best scroll of each kind as a clickable
    -- icon, like a spell button, with its name beside it. Clicking it is
    -- the same as clicking the scroll in your bags.
    local function QuickButton(name, categoryKey, title, emptyIcon)
        local button = SK.UI.CreateItemButton(panel, name, QUICK_ICON)
        button.categoryKey = categoryKey
        button.title = title
        button.emptyIcon = emptyIcon

        button.label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label:SetPoint("TOPLEFT", button, "TOPRIGHT", 8, -2)
        button.label:SetWidth((INNER - 12) / 2 - QUICK_ICON - 12)
        button.label:SetJustifyH("LEFT")
        button.label:SetText(title)
        button.detail = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.detail:SetPoint("TOPLEFT", button.label, "BOTTOMLEFT", 0, -2)
        button.detail:SetWidth((INNER - 12) / 2 - QUICK_ICON - 12)
        button.detail:SetJustifyH("LEFT")
        button.detail:SetWordWrap(false)

        -- A green tick on the icon when it's already up.
        button.tick = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        button.tick:SetSize(14, 14)
        button.tick:SetPoint("TOPRIGHT", 4, 4)
        button.tick:Hide()

        local showItem = button:GetScript("OnEnter")
        button:SetScript("OnEnter", function(self)
            if self.itemID then
                showItem(self)
                GameTooltip:AddLine(L["|cff40ff40Click to use.|r"])
                GameTooltip:Show()
            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(title)
                local hint, weapon
                if categoryKey == "imbues" then hint, weapon = SK.ImbueSwapHint() end
                if hint then
                    local _, holding = SK.MainHandWeapon()
                    GameTooltip:AddLine(L["None of your imbues fit %s."]:format(holding or "what you're holding"), 1, 1, 1, true)
                    GameTooltip:AddLine(L["%s can be put on your %s (in your bags). Equip it, then click here."]:format(
                        SK.ScrollLink(hint.itemID, hint.name), weapon), 0.25, 1, 0.25, true)
                else
                    -- List what you do have, and what each one needs.
                    local have = {}
                    for _, group in ipairs(SK.ScrollGroups()) do
                        if group.key == categoryKey then have = group.scrolls end
                    end
                    if #have == 0 then
                        GameTooltip:AddLine(L["You don't have any %s scrolls yet."]:format(title:lower()), 1, 1, 1, true)
                    else
                        if categoryKey == "imbues" then
                            local _, holding = SK.MainHandWeapon()
                            GameTooltip:AddLine(L["You're holding %s. Your imbues:"]:format(holding or "no weapon"), 1, 1, 1, true)
                        else
                            GameTooltip:AddLine(L["Your scrolls:"], 1, 1, 1)
                        end
                        for _, scroll in ipairs(have) do
                            local needs = {}
                            if scroll.imbueFor then needs[#needs + 1] = L["for "] .. SK.WeaponWithArticle(scroll.imbueFor) end
                            if scroll.levelOK == false then needs[#needs + 1] = L["level "] .. (scroll.level or "?") end
                            GameTooltip:AddDoubleLine("  " .. SK.ScrollLink(scroll.itemID, scroll.name),
                                table.concat(needs, ", "), 1, 0.82, 0, 1, 0.4, 0.4)
                        end
                    end
                end
                GameTooltip:Show()
            end
        end)
        return button
    end
    parts.familiar = QuickButton("ScrollkeeperFamiliarButton", "familiars", L["Familiar"],
        "Interface\\Icons\\INV_Box_PetCarrier_01")
    parts.imbue = QuickButton("ScrollkeeperImbueButton", "imbues", L["Imbue"],
        "Interface\\Icons\\Spell_Fire_FlameTounge")

    -- Your scrolls section
    parts.scrollsHeader = SectionHeader(L["Your Scrolls"])

    -- The icons sit in a scrolling box, so any number of scrolls fits.
    -- The scrollbar appears only when there are more rows than fit.
    parts.scrollsBox = CreateFrame("ScrollFrame", "ScrollkeeperScrollsBox", panel, "UIPanelScrollFrameTemplate")
    parts.scrollsBox:SetSize(INNER - 18, ICON_SIZE)
    parts.scrollsArea = CreateFrame("Frame", nil, parts.scrollsBox)
    parts.scrollsArea:SetSize(INNER - 18, ICON_SIZE)
    parts.scrollsBox:SetScrollChild(parts.scrollsArea)
    -- Scrolling moves the scroll buttons, which the game doesn't allow in combat.
    parts.scrollsBox:SetScript("OnMouseWheel", function(self, delta)
        if SK.InCombat() then return end
        local new = self:GetVerticalScroll() - delta * (ICON_SIZE + ICON_GAP)
        self:SetVerticalScroll(math.max(0, math.min(new, self:GetVerticalScrollRange())))
    end)
    local scrollBar = parts.scrollsBox.ScrollBar
    if type(scrollBar) ~= "table" then scrollBar = _G["ScrollkeeperScrollsBoxScrollBar"] end
    parts.scrollsBar = type(scrollBar) == "table" and scrollBar or nil
    -- The game's template shows its scrollbar again every time the content
    -- changes. Only show it when Layout says the icons don't fit.
    parts.scrollsBox:SetScript("OnScrollRangeChanged", function(self)
        if parts.scrollsBar then parts.scrollsBar:SetShown(self.needsBar and true or false) end
    end)

    for i = 1, MAX_SCROLL_BUTTONS do
        scrollButtons[i] = SK.UI.CreateItemButton(parts.scrollsArea, "ScrollkeeperScrollButton" .. i, ICON_SIZE)
        scrollButtons[i]:Hide()
    end
    -- One small label per category ("Imbues", "Familiars", ...).
    parts.categoryLabels = {}
    for _, category in ipairs(SK.SCROLL_CATEGORIES) do
        local label = parts.scrollsArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetWidth(CATEGORY_LABEL_WIDTH)
        label:SetJustifyH("LEFT")
        label:SetText(L[category.label])
        label:Hide()
        parts.categoryLabels[category.key] = label
    end

    -- Weapon upgrades you have part of.
    parts.upgradesHeader = SectionHeader(L["Weapon Upgrades"])
    parts.upgrades = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    parts.upgrades:SetWidth(INNER - 12)
    parts.upgrades:SetJustifyH("LEFT")
    parts.upgrades:SetSpacing(3)

    -- Study section
    parts.studyHeader = SectionHeader(L["Study"])
    parts.studyBar = SK.UI.CreateBar(panel, INNER, 16)
    Row("feathers", L["Light Feathers"], true)
    Row("library", L["Library"], false)

    -- Study and Open bundle: secure buttons, one click each, no bags needed.
    local half = (INNER - 6) / 2
    parts.study = CreateFrame("Button", "ScrollkeeperStudyButton", panel,
        "SecureActionButtonTemplate,UIPanelButtonTemplate")
    parts.study:SetSize(half, 22)
    parts.study:RegisterForClicks("AnyUp", "AnyDown")
    parts.study:SetAttribute("type", "spell")
    parts.study:SetAttribute("spell", SK.SPELL_STUDY)
    parts.study:SetText(L["Study"])
    parts.study:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Study"])
        GameTooltip:AddLine(L["Makes a Bundle of Scrolls. Needs a library and a Light Feather. One hour cooldown."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    parts.study:SetScript("OnLeave", function() GameTooltip:Hide() end)

    parts.bundle = CreateFrame("Button", "ScrollkeeperBundleButton", panel,
        "SecureActionButtonTemplate,UIPanelButtonTemplate")
    parts.bundle:SetSize(half, 22)
    parts.bundle:RegisterForClicks("AnyUp", "AnyDown")
    parts.bundle:SetText(L["Open bundle"])

    parts.warning = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    parts.warning:SetWidth(INNER)
    parts.warning:SetJustifyH("LEFT")

    -- Advanced view: the right-hand column.
    local sideLeft = WIDTH - 4
    side.divider = panel:CreateTexture(nil, "ARTWORK")
    side.divider:SetColorTexture(0.6, 0.45, 0.2, 0.35)
    side.divider:SetWidth(1)
    side.divider:SetPoint("TOPLEFT", sideLeft - 6, -TOP + 4)
    side.divider:SetPoint("BOTTOMLEFT", sideLeft - 6, 14)

    local paneHeight
    side.network, paneHeight = SK.UI.CreateNetworkPane(panel, sideLeft, -TOP + 4, SIDE_INNER, 6, 7)

    local y = -TOP + 4 - paneHeight
    side.statsHeader = SK.UI.CreateHeader(panel, L["Your Stats"], SIDE_INNER)
    side.statsHeader:SetPoint("TOPLEFT", sideLeft, y)
    y = y - 26
    side.rows = {}
    local statRows = {
        { "deciphered", L["Deciphered"] },
        { "skillups", L["Skill-ups from scrolls"] },
        { "common", L["Most common"] },
        { "drops", L["Scroll drops logged"] },
        { "books", L["Books found"] },
        { "backfires", L["Sheep backfires"] },
        { "goal", L["Next goal"] },
        { "swap", L["Scroll swap"] },
        { "sharing", L["Sharing"] },
    }
    for i, entry in ipairs(statRows) do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(SIDE_INNER, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", sideLeft, y)
        if i % 2 == 1 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(0.45, 0.32, 0.12, 0.18)
        end
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetText(entry[2])
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.value:SetPoint("RIGHT", -6, 0)
        row.value:SetJustifyH("RIGHT")
        row.value:SetWidth(SIDE_INNER * 0.6)
        row.value:SetWordWrap(false)
        -- Item links in the value: tooltip on hover, Shift-click links it.
        if row.SetHyperlinksEnabled then
            row:SetHyperlinksEnabled(true)
            SK.UI.EnableItemLinks(row)
        end
        side.rows[entry[1]] = row
        if entry[1] == "goal" or entry[1] == "swap" or entry[1] == "backfires" then
            row:EnableMouse(true)
            local highlight = row:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 0.82, 0, 0.12)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if entry[1] == "goal" then
                    GameTooltip:SetText(L["Farming plan"])
                    for _, line in ipairs(SK.FarmPlanLines()) do GameTooltip:AddLine(line, 1, 1, 1, true) end
                elseif entry[1] == "swap" then
                    GameTooltip:SetText(L["Scroll swap"])
                    GameTooltip:AddLine(L["Who has spare scrolls you'd level from, and who'd want yours. Click to open it."], 1, 1, 1, true)
                else
                    local mine, all = SK.BackfireStats()
                    GameTooltip:SetText(L["Sheep backfires"])
                    GameTooltip:AddLine(L["You: %d in %d reads."]:format(mine.b, mine.t), 1, 1, 1)
                    if all.t > mine.t then
                        GameTooltip:AddLine(L["Everyone: %d in %d (%.1f%%)."]:format(all.b, all.t, all.b / all.t * 100), 1, 1, 1)
                    end
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            if entry[1] == "swap" then
                row:SetScript("OnMouseUp", function() SK.ToggleSwap() end)
            end
        end
        y = y - ROW_HEIGHT
    end
    side.height = -y + 14
end

local function SetSideShown(shown)
    side.divider:SetShown(shown)
    side.statsHeader:SetShown(shown)
    for _, row in pairs(side.rows) do row:SetShown(shown) end
    side.network:SetShown(shown)
end

-- Your Stats, from the luck log.
local function UpdateStats()
    if not side.rows then return end
    local db = SK.db
    side.rows.deciphered.value:SetText(tostring(db.deciphered or 0))

    local ups, tries = 0, 0
    for _, seen in pairs(db.skillups or {}) do
        ups, tries = ups + (seen.ups or 0), tries + (seen.tries or 0)
    end
    side.rows.skillups.value:SetText(tries > 0 and L["%d of %d"]:format(ups, tries) or "|cff808080none yet|r")

    local bestName, bestCount = nil, 0
    for _, results in pairs(db.results or {}) do
        for name, count in pairs(results) do
            if count > bestCount then bestName, bestCount = name, count end
        end
    end
    side.rows.common.value:SetText(bestName and (SK.ScrollLink(nil, bestName, true) .. " |cff808080x" .. bestCount .. "|r")
        or "|cff808080none yet|r")

    local mine = SK.BackfireStats and SK.BackfireStats() or { b = 0, t = 0 }
    side.rows.backfires.value:SetText(mine.t > 0 and L["%d of %d (%.0f%%)"]:format(mine.b, mine.t, mine.b / mine.t * 100)
        or "|cff808080none yet|r")
    local plan = SK.FarmPlan and SK.FarmPlan()
    side.rows.goal.value:SetText(plan and L["%d, ~%d scrolls"]:format(plan.goal, plan.scrolls) or "|cff808080-|r")
    local offers = (SK.ScrollsICouldGet and #SK.ScrollsICouldGet() or 0) + (SK.WhoWantsMine and #SK.WhoWantsMine() or 0)
    side.rows.swap.value:SetText(offers > 0 and ("|cff40ff40%d |4match:matches;|r"):format(offers) or "|cff808080open|r")

    local drops = 0
    for _, cells in pairs(db.drops or {}) do
        for _, count in pairs(cells) do drops = drops + count end
    end
    side.rows.drops.value:SetText(tostring(drops))

    local books = 0
    for _, cells in pairs(db.bookDrops or {}) do
        for _, count in pairs(cells) do books = books + count end
    end
    side.rows.books.value:SetText(tostring(books))

    side.rows.sharing.value:SetText(SK.db.share and L["|cff40ff40on|r"] or L["|cffff6666off|r"])
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

    local mode = SK.ViewMode()
    local collapsed = mode == "mini"
    local compact = mode == "compact"
    -- The arrows show what a left-click does: smaller, or back to big.
    parts.collapse:SetNormalTexture(mode == "mini" and SIZE_BIGGER or SIZE_SMALLER)
    parts.collapse:SetPushedTexture(mode == "mini" and SIZE_BIGGER_DOWN or SIZE_SMALLER_DOWN)

    local body = {
        parts.skillBar, parts.decipherHeader, parts.decipher, parts.scrollsHeader,
        parts.studyHeader, parts.studyBar, parts.warning, parts.study, parts.bundle,
        parts.upgradesHeader, parts.upgrades, parts.scrollsBox, parts.familiar, parts.imbue,
        parts.familiar.label, parts.familiar.detail, parts.imbue.label, parts.imbue.detail,
    }
    for _, region in ipairs(body) do region:SetShown(not collapsed) end
    parts.skillBar:Show()   -- every view shows the skill bar, Title only too
    for _, row in pairs(rows) do row:SetShown(not collapsed and not compact) end
    -- Compact view: no section plates.
    for _, header in ipairs(sections) do
        if compact then header:Hide() end
    end

    AnchorTopLeft()   -- pin the top edge before the height changes

    for _, label in pairs(parts.categoryLabels) do label:Hide() end
    local advanced = mode == "full"
    panel:SetWidth(advanced and (WIDTH + SIDE_WIDTH) or WIDTH)
    SetSideShown(advanced)

    FitBorder(collapsed)
    if collapsed then
        for _, button in ipairs(scrollButtons) do button:Hide() end
        Place(parts.skillBar, -TOP, 16)
        panel:SetHeight(COLLAPSED_HEIGHT)
        return
    end

    local y = -TOP
    y = Place(parts.skillBar, y, 16) - 10

    -- Decipher
    if not compact then
        y = Place(parts.decipherHeader, y, 22) - 2
        for _, name in ipairs({ "ready", "skillups", "tooHard", "nextTier" }) do
            y = Place(rows[name], y, ROW_HEIGHT)
        end
        y = y - 6
    end
    y = Place(parts.decipher, y, 24) - 4

    -- Familiar / Imbue icons, pointed at your best scroll of each kind.
    local half = (INNER - 12) / 2
    parts.familiar:ClearAllPoints()
    parts.familiar:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT + 6, y - 4)
    parts.imbue:ClearAllPoints()
    parts.imbue:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT + 6 + half + 12, y - 4)
    y = y - QUICK_ICON - 14
    for _, button in ipairs({ parts.familiar, parts.imbue }) do
        local best = SK.BestScroll(button.categoryKey)
        if best then
            button:SetAttribute("type", "item")
            button:SetAttribute("item", "item:" .. best.itemID)
            button:SetDisplay(best.itemID, best.icon, best.count)
            button:SetUsable(true)
            button.detail:SetText((best.name:gsub("^Scroll of ", ""):gsub("^Imbue ", ""):gsub(" Familiar$", "")))
        else
            button:SetAttribute("type", nil)
            button:SetDisplay(nil, button.emptyIcon)
            button:SetUsable(false)
            local hint = button.categoryKey == "imbues" and SK.ImbueSwapHint()
            button.detail:SetText(hint and L["|cff40ff40swap weapon|r"] or L["|cff808080none|r"])
        end
    end

    -- Your scrolls, one row of icons per category, best one outlined in gold.
    -- Everything is placed inside the scrolling area, from its top.
    local groups = SK.db.showScrollBar and SK.ScrollGroups() or {}
    parts.scrollsHeader:SetShown(#groups > 0)
    parts.scrollsBox:SetShown(#groups > 0)
    -- Full view: a labelled row per category. Compact: all icons in one
    -- flowing grid, categories still in order, no labels.
    local perRow = compact and COMPACT_ICONS_PER_ROW or ICONS_PER_ROW
    local startX = compact and 0 or CATEGORY_LABEL_WIDTH
    local used, areaY, flowIndex = 0, 0, 0
    for _, group in ipairs(groups) do
        if not compact then
            local label = parts.categoryLabels[group.key]
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", parts.scrollsArea, "TOPLEFT", 4, areaY - ICON_PAD - 8)
            label:Show()
        end
        for i, scroll in ipairs(group.scrolls) do
            if used < MAX_SCROLL_BUTTONS then
                used = used + 1
                local button = scrollButtons[used]
                local index = compact and flowIndex or (i - 1)
                flowIndex = flowIndex + 1
                local column, line = index % perRow, math.floor(index / perRow)
                local top = (compact and 0 or areaY) - ICON_PAD
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", parts.scrollsArea, "TOPLEFT",
                    ICON_PAD + startX + column * (ICON_SIZE + ICON_GAP), top - line * (ICON_SIZE + ICON_GAP))
                -- Only scrolls you can use do anything when clicked. The rest
                -- say why instead (wrong weapon, level too low).
                button:SetAttribute("type", scroll.usable and "item" or nil)
                button:SetAttribute("item", scroll.usable and ("item:" .. scroll.itemID) or nil)
                button:SetDisplay(scroll.itemID, scroll.icon, scroll.count)
                button:SetBest(scroll.best)
                button:SetUsable(scroll.usable)
                button.scroll = scroll
                button.categoryLabel = group.label
                button:Show()
            end
        end
        if not compact then
            areaY = areaY - math.ceil(#group.scrolls / ICONS_PER_ROW) * (ICON_SIZE + ICON_GAP)
        end
    end
    if compact then
        areaY = -math.ceil(flowIndex / perRow) * (ICON_SIZE + ICON_GAP)
    end
    for i = used + 1, MAX_SCROLL_BUTTONS do
        scrollButtons[i]:SetAttribute("type", nil)
        scrollButtons[i]:Hide()
    end
    if compact then parts.scrollsHeader:Hide() end
    if #groups > 0 then
        if not compact then y = Place(parts.scrollsHeader, y, 22) - 6 end
        local contentHeight = -areaY - ICON_GAP + ICON_PAD * 2
        local maxHeight = SCROLLS_MAX_ROWS * (ICON_SIZE + ICON_GAP) - ICON_GAP + ICON_PAD * 2
        local boxHeight = math.min(contentHeight, maxHeight)
        parts.scrollsArea:SetHeight(contentHeight)
        parts.scrollsBox:SetHeight(boxHeight)
        Place(parts.scrollsBox, y, boxHeight)
        local needsBar = contentHeight > maxHeight
        parts.scrollsBox.needsBar = needsBar
        if parts.scrollsBar then parts.scrollsBar:SetShown(needsBar) end
        if not needsBar then parts.scrollsBox:SetVerticalScroll(0) end
        y = y - boxHeight - 8
    end

    -- Weapon upgrades (only when you have part of one)
    local upgradesText = parts.upgrades:GetText()
    local showUpgrades = upgradesText and upgradesText ~= "" and not compact
    parts.upgradesHeader:SetShown(showUpgrades)
    parts.upgrades:SetShown(showUpgrades)
    if showUpgrades then
        y = Place(parts.upgradesHeader, y, 22) - 4
        parts.upgrades:ClearAllPoints()
        parts.upgrades:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT + 6, y)
        y = y - parts.upgrades:GetStringHeight() - 10
    end

    -- Study
    if not compact then y = Place(parts.studyHeader, y, 22) - 6 end
    y = Place(parts.studyBar, y, 16) - 6
    if not compact then
        y = Place(rows.feathers, y, ROW_HEIGHT)
        y = Place(rows.library, y, ROW_HEIGHT)
    end

    -- Study / Open bundle
    Place(parts.study, y - 6, 22)
    parts.bundle:ClearAllPoints()
    parts.bundle:SetPoint("LEFT", parts.study, "RIGHT", 6, 0)
    y = y - 34
    local knowsStudy = SK.KnowsStudy()
    if knowsStudy and SK.StudySecondsLeft() == 0 and SK.bags.feathers > 0 and SK.bags.bundles == 0 then
        parts.study:Enable()
    else
        parts.study:Disable()
    end
    if SK.bags.bundleBag then
        parts.bundle:SetAttribute("type", "item")
        parts.bundle:SetAttribute("item", SK.bags.bundleBag .. " " .. SK.bags.bundleSlot)
        parts.bundle:Enable()
    else
        parts.bundle:SetAttribute("type", nil)
        parts.bundle:Disable()
    end

    local warning = parts.warning:GetText()
    if warning and warning ~= "" then
        y = Place(parts.warning, y - 6, parts.warning:GetStringHeight())
    end

    local height = -y + 20   -- room under the last line for the window's border
    if advanced then height = math.max(height, TOP - 4 + side.height) end
    panel:SetHeight(height)
    KeepAboveActionBars()

    -- Point the decipher button at the next scroll.
    local nextScroll, readable = SK.NextDecipherable()
    if nextScroll then
        parts.decipher:SetAttribute("type", "spell")
        parts.decipher:SetAttribute("spell", SK.SPELL_COMPREHEND_SCROLL)
        parts.decipher:SetAttribute("target-bag", nextScroll.bag)
        parts.decipher:SetAttribute("target-slot", nextScroll.slot)
        local chance = SK.SkillUpChance(nextScroll.needs, SK.GetComprehension().rank)
        local mark = (chance and chance.gives) and " |cffff8040+|r" or ""
        parts.decipher:SetText(L["Decipher next scroll (%d)%s"]:format(readable, mark))
        parts.decipher:Enable()
    else
        parts.decipher:SetAttribute("type", nil)
        parts.decipher:SetText(L["Nothing to decipher"])
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
    -- Familiar / Imbue: a green tick when it's already up.
    local weapon = SK.WeaponState and SK.WeaponState() or {}
    parts.familiar.tick:SetShown(weapon.familiar and parts.familiar.itemID and true or false)
    parts.imbue.tick:SetShown(weapon.imbued and true or false)

    -- (The skill bar already shows the skill, so this says what's ready.)
    parts.summary:SetText(L["|cffffffff%d|r ready"]:format(readable))

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
        rows.nextTier.value:SetText(GREEN .. L["all unlocked|r"])
    elseif nextTier > skill.max then
        rows.nextTier.value:SetText(L["%d %s(level %d)|r"]:format(nextTier, GRAY,
            math.ceil(nextTier / SK.SKILL_CAP_PER_LEVEL)))
    else
        rows.nextTier.value:SetText(L["%d %s(%d to go)|r"]:format(nextTier, GRAY, nextTier - skill.effective))
    end

    -- Scroll counts (the icons themselves only change out of combat)
    local counts = {}
    for _, scroll in ipairs(SK.bags.translated) do counts[scroll.itemID] = scroll.count end
    for _, button in ipairs(scrollButtons) do
        if button.itemID and button:IsShown() then
            button:SetDisplay(button.itemID, button.icon:GetTexture(), counts[button.itemID] or 0)
        end
    end

    -- Weapon upgrades
    local upgradeLines = {}
    for _, entry in ipairs(SK.UpgradeStatus()) do
        local u = entry.upgrade
        if entry.ready then
            upgradeLines[#upgradeLines + 1] = L["|cff40ff40%s|r: ready, use the scroll on the weapon"]:format(u.makes)
        elseif entry.hasScroll then
            upgradeLines[#upgradeLines + 1] = L["|cffa335ee%s|r: need %s |cff808080(%s)|r"]:format(u.makes, u.weapon, u.from)
        else
            upgradeLines[#upgradeLines + 1] = L["|cffa335ee%s|r: need %s"]:format(u.makes, u.scroll)
        end
    end
    parts.upgrades:SetText(table.concat(upgradeLines, "\n"))

    -- Study bar: fills up as the cooldown runs down.
    if not knowsStudy then
        parts.studyBar:SetProgress(0, 1)
        parts.studyBar:SetLabel(GRAY .. L["Not learned yet|r"])
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
    rows.library.value:SetText(inLibrary and (GREEN .. L["you're in one|r"]) or (GRAY .. L["not here|r"]))

    -- Reminders at the bottom, most important first (at most 4).
    local notes = {}
    if SK.bags.bundles > 0 then
        notes[#notes + 1] = L["|cffffd100Open your Bundle of Scrolls before the next Study.|r"]
    elseif knowsStudy and SK.bags.feathers == 0 then
        notes[#notes + 1] = RED .. L["No Light Feathers. Study needs one.|r"]
    elseif knowsStudy and studyLeft == 0 and inLibrary then
        notes[#notes + 1] = GREEN .. L["Study is ready and you're in a library.|r"]
    end
    for _, line in ipairs(SK.Reminders()) do notes[#notes + 1] = line end
    while #notes > 4 do table.remove(notes) end
    parts.warning:SetText(table.concat(notes, "\n"))
    parts.warning:SetSpacing(3)
end

-- Redraw everything. Other files call this after a setting changes.
function SK.RefreshPanel()
    if not panel then return end
    UpdateText()
    Layout()
    if SK.ViewMode() == "full" then
        UpdateStats()
        side.network:Refresh()
    end
end

------------------------------------------------------------------------
-- Showing, hiding and settings
------------------------------------------------------------------------

function SK.TogglePanel()
    if not panel then return end
    if SK.InCombat() then
        SK.Print(panel:IsShown() and L["in combat, close the panel with its X button."]
            or L["the panel can be shown again after combat."])
        return
    end
    SK.db.showPanel = not panel:IsShown()
    panel:SetShown(SK.db.showPanel)
    if SK.db.showPanel then SK.RefreshPanel() end
end

-- Apply the saved settings to the window (called from the settings page).
function SK.ApplyPanelSettings()
    if SK.RefreshIcon then SK.RefreshIcon() end
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

------------------------------------------------------------------------
-- Hide in combat (optional)
------------------------------------------------------------------------

-- The game's own combat switch hides and shows the panel: addon code can't
-- do that in combat because the panel holds protected buttons, but a
-- secure state driver can. It only brings the panel back if combat hid it.
local combatDriver

local function BuildCombatDriver()
    combatDriver = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    combatDriver:SetFrameRef("panel", panel)
    combatDriver:SetAttribute("_onstate-combat", [[
        local panel = self:GetFrameRef("panel")
        if newstate == "1" then
            if self:GetAttribute("hideInCombat") and panel:IsShown() then
                self:SetAttribute("hidByCombat", true)
                panel:Hide()
            end
        elseif self:GetAttribute("hidByCombat") then
            self:SetAttribute("hidByCombat", nil)
            panel:Show()
        end
    ]])
    if RegisterStateDriver then RegisterStateDriver(combatDriver, "combat", "[combat] 1; 0") end
end

-- Apply the setting (it can only change out of combat; in combat it waits).
function SK.UpdateCombatHiding()
    if not combatDriver then return end
    if SK.InCombat() then
        SK.afterCombat = SK.afterCombat or {}
        SK.afterCombat.combatHiding = SK.UpdateCombatHiding
        return
    end
    combatDriver:SetAttribute("hideInCombat", SK.db.hideInCombat and true or nil)
end

SK.On("PLAYER_REGEN_ENABLED", function()
    local queued = SK.afterCombat
    SK.afterCombat = nil
    for _, run in pairs(queued or {}) do SK.Safely("after combat", run) end
end)

SK.Listen("READY", function()
    if not SK.isMage then return end   -- other classes only get tooltips
    Build()
    panel:SetShown(SK.db.showPanel)
    BuildCombatDriver()
    SK.UpdateCombatHiding()

    SK.Listen("BAGS_CHANGED", SK.RefreshPanel)
    SK.Listen("SKILL_CHANGED", SK.RefreshPanel)
    SK.Listen("STUDY_CHANGED", SK.RefreshPanel)
    SK.Listen("PLACE_CHANGED", SK.RefreshPanel)
    SK.Listen("PEERS_CHANGED", SK.RefreshPanel)
    SK.Listen("LOG_CHANGED", SK.RefreshPanel)
    SK.Listen("DROPS_CHANGED", SK.RefreshPanel)
    SK.Listen("REMINDERS_CHANGED", SK.RefreshPanel)
    SK.On("PLAYER_LEVEL_UP", function() C_Timer.After(1, SK.RefreshPanel) end)
    SK.On("PLAYER_REGEN_ENABLED", function()
        if layoutWaiting then SK.RefreshPanel() end
    end)

    -- Tick the Study timer once a second while the panel is visible. When
    -- the cooldown runs out, redraw everything so the Study button wakes up.
    local sinceLast = 0
    local wasReady = SK.StudySecondsLeft() == 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        sinceLast = sinceLast + elapsed
        if sinceLast < 1 then return end
        sinceLast = 0
        local ready = SK.StudySecondsLeft() == 0
        if ready ~= wasReady then
            wasReady = ready
            SK.Safely("panel refresh", SK.RefreshPanel)
        else
            SK.Safely("panel timer", UpdateText)
        end
    end)
end)
