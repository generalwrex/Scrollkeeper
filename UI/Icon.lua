-- Scrollkeeper: UI/Icon.lua
-- The scroll icon: a small square you can keep on screen while you play.
--
--   the number    how many scrolls you can decipher right now
--                 (green when some of them still give skill-ups)
--   a gold glow   Study is ready
--   left-click    decipher your best scroll (skill-ups first), no window needed
--   right-click   open or close the panel, in the view you picked
--   shift-drag    move it, or right-drag (unless the panel position is locked)
--
-- Turn it on in Options > AddOns > Scrollkeeper > Scroll icon. Mages only.
-- (Idea from Curnil, thanks!)

local _, SK = ...
local L = SK.L

local SIZE = 40
local icon

local function Build()
    -- A secure button, so left-click can cast Decipher on your best scroll
    -- (the same one the panel's Decipher button would read). Right-click is
    -- ours: open or close the panel. Moving it is a Shift-drag or a
    -- right-drag: a plain left-click casts as soon as the button goes down,
    -- so Shift-left-click is set to do nothing (an empty macro).
    icon = CreateFrame("Button", "ScrollkeeperIcon", UIParent, "SecureActionButtonTemplate")
    icon:SetSize(SIZE, SIZE)
    icon:SetFrameStrata("MEDIUM")
    icon:SetClampedToScreen(true)
    icon:SetMovable(true)
    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton", "RightButton")
    icon:SetAttribute("shift-type1", "macro")
    icon:SetAttribute("shift-macrotext1", "")
    icon:RegisterForClicks("AnyUp", "AnyDown")

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexture("Interface\\Icons\\INV_Scroll_03")
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetPoint("TOPLEFT", -2, 2)
    icon.border:SetPoint("BOTTOMRIGHT", 2, -2)
    icon.border:SetColorTexture(0, 0, 0, 0)
    -- The frame around the icon: the skill-up color of the scroll a click
    -- would read (orange, yellow, green; gray when it gives nothing).
    icon.edge = icon:CreateTexture(nil, "BACKGROUND")
    icon.edge:SetPoint("TOPLEFT", -3, 3)
    icon.edge:SetPoint("BOTTOMRIGHT", 3, -3)
    icon.edge:SetColorTexture(0, 0, 0, 0.8)

    icon.glow = icon:CreateTexture(nil, "OVERLAY")
    icon.glow:SetPoint("TOPLEFT", -10, 10)
    icon.glow:SetPoint("BOTTOMRIGHT", 10, -10)
    icon.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    icon.glow:SetBlendMode("ADD")
    icon.glow:SetVertexColor(1, 0.82, 0)
    icon.glow:Hide()

    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    icon.count:SetPoint("BOTTOMRIGHT", -2, 2)

    icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    icon:SetScript("OnDragStart", function(self, button)
        if SK.db.locked or InCombatLockdown() then return end
        if button == "LeftButton" and not IsShiftKeyDown() then return end
        self:StartMoving()
    end)
    icon:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        SK.db.iconPos = { point, relativePoint, x, y }
    end)
    -- The template's own click handler casts the left-click; this hook
    -- only handles the right button (once: clicks come down and up).
    icon:HookScript("OnClick", function(_, button, down)
        if button ~= "RightButton" or down then return end
        if SK.InCombat() then
            SK.Print(L["the panel can be opened after combat."])
            return
        end
        SK.TogglePanel()
    end)
    icon:SetScript("OnEnter", function(self)
        local _, readable, tooHard, skillUps = SK.NextDecipherable()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Scrollkeeper")
        GameTooltip:AddDoubleLine(L["Ready to decipher"], readable, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Skill-ups"], skillUps or 0, 1, 0.82, 0, 1, 1, 1)
        if (tooHard or 0) > 0 then GameTooltip:AddDoubleLine(L["Too hard"], tooHard, 1, 0.82, 0, 1, 1, 1) end
        if SK.StudySecondsLeft and SK.KnowsStudy and SK.KnowsStudy() then
            GameTooltip:AddDoubleLine(L["Study"], SK.FormatStudyTime(SK.StudySecondsLeft()), 1, 0.82, 0, 1, 1, 1)
        end
        local nextScroll = SK.NextDecipherable()
        if nextScroll then
            local chance = SK.SkillUpChance(nextScroll.needs, SK.GetComprehension().rank)
            GameTooltip:AddLine(L["Click: decipher %s"]:format(SK.ScrollLink(nextScroll.itemID, nextScroll.name))
                .. (chance and (" (" .. SK.ColoredChance(chance) .. "|cff40ff40)|r") or ""),
                0.25, 1, 0.25, true)
        end
        GameTooltip:AddLine(L["Right-click: open or close the panel. Shift-drag: move."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local pos = SK.db.iconPos
    if pos then
        icon:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        icon:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

-- Lost the icon off screen? Turn it on and put it in the middle.
function SK.ResetIconPosition()
    SK.db.iconPos = nil
    SK.db.scrollIcon = true
    SK.RefreshIcon()   -- builds it if it was never shown
    if icon and not InCombatLockdown() then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    SK.Print(L["scroll icon moved to the middle of the screen."])
end

function SK.RefreshIcon()
    local toggle = ScrollkeeperPanel and ScrollkeeperPanel.iconToggle
    local texture = toggle and toggle.GetNormalTexture and toggle:GetNormalTexture()
    if texture and texture.SetDesaturated then texture:SetDesaturated(not (SK.db and SK.db.scrollIcon)) end
    local wanted = SK.isMage and SK.db and SK.db.scrollIcon
    -- It's a secure button: showing, hiding, moving and changing what it
    -- casts all wait until combat ends (PLAYER_REGEN_ENABLED below).
    local locked = InCombatLockdown()
    if not wanted then
        if icon and not locked then icon:Hide() end
        return
    end
    if not icon then
        if locked then return end
        Build()
    end
    local nextScroll, readable, _, skillUps = SK.NextDecipherable()
    if not locked then
        -- Left-click: Decipher on the best scroll, like the panel's button.
        if nextScroll then
            icon:SetAttribute("type1", "spell")
            icon:SetAttribute("spell1", SK.SPELL_COMPREHEND_SCROLL)
            icon:SetAttribute("target-bag", nextScroll.bag)
            icon:SetAttribute("target-slot", nextScroll.slot)
        else
            icon:SetAttribute("type1", nil)
        end
    end
    icon.count:SetText(readable or 0)
    if (skillUps or 0) > 0 then
        icon.count:SetTextColor(0.25, 1, 0.25)
    elseif (readable or 0) > 0 then
        icon.count:SetTextColor(1, 1, 1)
    else
        icon.count:SetTextColor(0.6, 0.6, 0.6)
    end
    icon.texture:SetDesaturated((readable or 0) == 0)
    local chance = nextScroll and SK.SkillUpChance(nextScroll.needs, SK.GetComprehension().rank)
    if chance then
        local hex = chance.color
        icon.edge:SetColorTexture(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255, 1)
    else
        icon.edge:SetColorTexture(0, 0, 0, 0.8)
    end
    local studyReady = SK.KnowsStudy and SK.KnowsStudy() and SK.StudySecondsLeft and SK.StudySecondsLeft() <= 0
    icon.glow:SetShown(studyReady and true or false)
    if not locked then
        icon:SetScale(SK.db.scale or 1)
        icon:Show()
    end
end
SK.On("PLAYER_REGEN_ENABLED", function() SK.RefreshIcon() end)

SK.Listen("READY", SK.RefreshIcon)
SK.Listen("BAGS_CHANGED", SK.RefreshIcon)
SK.Listen("SKILL_CHANGED", SK.RefreshIcon)
SK.Listen("STUDY_CHANGED", SK.RefreshIcon)

------------------------------------------------------------------------
-- A small pop-up near the top of the screen when your weapon imbue or
-- familiar drops off and you have a scroll for it. Mages only.
--   Left-click: open the panel (the Imbue / Familiar buttons are there).
--   Right-click: close it.
-- Never in combat or while dead, and the same reminder waits at least
-- five minutes before it can pop up again. Setting: reminderToast.
------------------------------------------------------------------------

do
    local SHOW_SECONDS = 12
    local FADE_SECONDS = 1.5
    local REPEAT_SECONDS = 300

    local toast
    local lastShown = {}     -- kind -> GetTime() it was last shown

    local function Build()
        toast = CreateFrame("Button", "ScrollkeeperToast", UIParent, "BackdropTemplate")
        toast:SetSize(300, 58)   -- height grows to fit the text (see Fit)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
        toast:SetFrameStrata("HIGH")
        toast:SetClampedToScreen(true)
        toast:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if toast.SetBackdrop then
            toast:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            toast:SetBackdropBorderColor(1, 0.82, 0, 1)
        end

        local icon = toast:CreateTexture(nil, "ARTWORK")
        icon:SetSize(38, 38)
        icon:SetPoint("TOPLEFT", 10, -10)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        toast.icon = icon

        local TEXT_WIDTH = 300 - 10 - 38 - 10 - 12
        local title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
        title:SetWidth(TEXT_WIDTH)
        title:SetJustifyH("LEFT")
        toast.title = title

        local hint = toast:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        hint:SetWidth(TEXT_WIDTH)
        hint:SetJustifyH("LEFT")
        toast.hint = hint

        -- Long titles (German!) wrap to two lines; make room instead of overlapping.
        function toast:Fit()
            local textHeight = (self.title:GetStringHeight() or 12) + 4 + (self.hint:GetStringHeight() or 10)
            self:SetHeight(math.max(58, textHeight + 20))
        end

        toast:SetScript("OnClick", function(self, button)
            self:Hide()
            -- Shift-right-click: turn these reminders off (same as the setting).
            if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
                SK.db.reminderToast = false
                SK.Print(L["imbue and familiar pop-ups are off. Turn them back on in /sk options (Panel)."])
                return
            end
            if button == "LeftButton" and SK.TogglePanel and not SK.InCombat()
                and not (ScrollkeeperPanel and ScrollkeeperPanel:IsShown()) then
                SK.TogglePanel()
            end
        end)

        -- Fade out after a few seconds. (No pausing on mouse-over: the
        -- cursor often just sits there while you play, so it'd never go.)
        toast:SetScript("OnUpdate", function(self, elapsed)
            self.age = (self.age or 0) + elapsed
            if self.age > SHOW_SECONDS + FADE_SECONDS then
                self:Hide()
            elseif self.age > SHOW_SECONDS then
                self:SetAlpha(1 - (self.age - SHOW_SECONDS) / FADE_SECONDS)
            end
        end)
        toast:Hide()
    end

    -- Which reminders apply right now: { imbue = scroll or nil, familiar = scroll or nil }
    local function Missing()
        local state = SK.WeaponState and SK.WeaponState() or {}
        local imbue = not state.imbued and SK.BestScroll and SK.BestScroll("imbues") or nil
        local familiar = not state.familiar and SK.BestScroll and SK.BestScroll("familiars") or nil
        return imbue, familiar
    end

    local function Update()
        if not SK.isMage or not SK.db then return end
        local imbue, familiar = Missing()

        -- Fixed it? Then the pop-up goes away by itself.
        if toast and toast:IsShown() and not imbue and not familiar then toast:Hide() end

        if not SK.db.reminderToast or SK.InCombat() then return end
        if UnitIsDeadOrGhost and SK.Known(UnitIsDeadOrGhost("player")) then return end

        local now = GetTime()
        local function Due(kind, scroll)
            return scroll and (not lastShown[kind] or now - lastShown[kind] >= REPEAT_SECONDS)
        end
        if not (Due("imbue", imbue) or Due("familiar", familiar)) then return end
        if imbue then lastShown.imbue = now end
        if familiar then lastShown.familiar = now end

        if not toast then Build() end
        local title
        if imbue and familiar then
            title = L["No weapon imbue and no familiar out"]
        elseif imbue then
            title = L["No weapon imbue"]
        else
            title = L["No familiar out"]
        end
        toast.title:SetText(title)
        toast.hint:SetText(L["Click: panel  ·  Right-click: close  ·  Shift-right-click: off"])

        local scroll = familiar or imbue
        local iconTexture = scroll.itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(scroll.itemID)
        toast.icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Scroll_03")
        toast:Fit()

        toast.age = 0
        toast:SetAlpha(1)
        toast:Show()
    end

    -- Bags and auras settle a moment after a change, so wait a little.
    local pending
    local function UpdateSoon()
        if pending then return end
        pending = true
        C_Timer.After(2, function() pending = false; SK.Safely("reminder toast", Update) end)
    end

    SK.Listen("REMINDERS_CHANGED", UpdateSoon)
    SK.On("PLAYER_REGEN_ENABLED", UpdateSoon)
    SK.On("PLAYER_UNGHOST", UpdateSoon)
    SK.On("PLAYER_ALIVE", UpdateSoon)
end
