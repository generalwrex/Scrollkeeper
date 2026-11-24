-- Scrollkeeper: UI/Icon.lua
-- The scroll icon: a small square you can keep on screen while you play.
--
--   the number    how many scrolls you can decipher right now
--                 (green when some of them still give skill-ups)
--   a gold glow   Study is ready
--   left-click    the most useful thing right now: Study when you're in a
--                 library and it's ready, else open a Bundle of Scrolls,
--                 else decipher your best scroll (skill-ups first)
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
    -- The template's own click handler casts the left-click. Right-click
    -- opens and closes the panel, in combat too (see SK.MakePanelToggle).
    if SK.MakePanelToggle then SK.MakePanelToggle(icon, "RightButton") end
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
        if self.action == "study" then
            GameTooltip:AddLine(L["Click: Study (you're in a library). Makes a Bundle of Scrolls."], 0.25, 1, 0.25, true)
        elseif self.action == "bundle" then
            GameTooltip:AddLine(L["Click: open a Bundle of Scrolls (%d left)"]:format(SK.bags.bundles or 0), 0.25, 1, 0.25, true)
        elseif nextScroll then
            local chance = SK.SkillUpChance(nextScroll.needs, SK.GetComprehension().rank)
            GameTooltip:AddLine(L["Click: decipher %s"]:format(SK.ScrollLink(nextScroll.itemID, nextScroll.name))
                .. (chance and (" (" .. SK.ColoredChance(chance) .. "|cff40ff40)|r") or ""),
                0.25, 1, 0.25, true)
        end
        if self.action ~= "bundle" and (self.action == "study" or nextScroll) and SK.IsMoving and SK.IsMoving() then
            GameTooltip:AddLine(L["Stand still to decipher"], 1, 0.82, 0)
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

-- What the icon's left-click does, most useful first:
--   "study"     in a library, Study is learned and ready, and you have a
--               Light Feather: makes a Bundle of Scrolls
--   "bundle"    you have a Bundle of Scrolls: opens it
--   "decipher"  otherwise: deciphers your best scroll (as always)
function SK.IconAction()
    local bags = SK.bags or {}
    if SK.KnowsStudy and SK.KnowsStudy() and SK.StudySecondsLeft and SK.StudySecondsLeft() <= 0
        and (bags.feathers or 0) > 0 and SK.InLibrary and SK.InLibrary() then
        return "study"
    end
    if (bags.bundles or 0) > 0 and bags.bundleBag and bags.bundleSlot then return "bundle" end
    return "decipher"
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
    -- What a left-click does right now (see SK.IconAction). In combat the
    -- button keeps what it had: a secure button can't change mid-fight.
    local action = locked and (icon.action or "decipher") or SK.IconAction()
    if not locked then
        icon.action = action
        icon:SetAttribute("target-bag", nil)
        icon:SetAttribute("target-slot", nil)
        icon:SetAttribute("spell1", nil)
        icon:SetAttribute("item1", nil)
        if action == "study" then
            icon:SetAttribute("type1", "spell")
            icon:SetAttribute("spell1", SK.SPELL_STUDY)
        elseif action == "bundle" then
            icon:SetAttribute("type1", "item")
            icon:SetAttribute("item1", SK.bags.bundleBag .. " " .. SK.bags.bundleSlot)
        elseif nextScroll then
            -- Decipher on the best scroll, like the panel's button.
            icon:SetAttribute("type1", "spell")
            icon:SetAttribute("spell1", SK.SPELL_COMPREHEND_SCROLL)
            icon:SetAttribute("target-bag", nextScroll.bag)
            icon:SetAttribute("target-slot", nextScroll.slot)
        else
            icon:SetAttribute("type1", nil)
        end
    end
    -- The picture and number say what the click does: Study (Light
    -- Feathers left), a bundle (how many), or deciphering (scrolls ready).
    local texture, count = "Interface\\Icons\\INV_Scroll_03", readable or 0
    if action == "study" then
        texture = (C_Spell and C_Spell.GetSpellTexture and SK.Try(C_Spell.GetSpellTexture, SK.SPELL_STUDY)) or "Interface\\Icons\\INV_Misc_Book_09"
        count = SK.bags.feathers or 0
    elseif action == "bundle" then
        texture = (SK.db.bundleID and C_Item and C_Item.GetItemIconByID and SK.Try(C_Item.GetItemIconByID, SK.db.bundleID))
            or "Interface\\Icons\\INV_Misc_Bag_10"
        count = SK.bags.bundles or 0
    end
    if type(texture) ~= "string" and type(texture) ~= "number" then texture = "Interface\\Icons\\INV_Scroll_03" end
    icon.texture:SetTexture(texture)
    icon.count:SetText(count)
    if action ~= "decipher" then
        icon.count:SetTextColor(1, 0.82, 0)
    elseif (skillUps or 0) > 0 then
        icon.count:SetTextColor(0.25, 1, 0.25)
    elseif (readable or 0) > 0 then
        icon.count:SetTextColor(1, 1, 1)
    else
        icon.count:SetTextColor(0.6, 0.6, 0.6)
    end
    icon.texture:SetDesaturated(action == "decipher" and (readable or 0) == 0)
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
-- Walking into or out of a library, Study cast, and Study coming off
-- cooldown (no event for that: checked every few seconds).
SK.Listen("PLACE_CHANGED", SK.RefreshIcon)
SK.Listen("STUDY_CHANGED", SK.RefreshIcon)
SK.Listen("READY", function()
    if not C_Timer.NewTicker then return end
    C_Timer.NewTicker(5, function()
        if icon and icon:IsShown() and not InCombatLockdown() and SK.IconAction() ~= icon.action then
            SK.Safely("scroll icon", SK.RefreshIcon)
        end
    end)
end)
SK.Listen("STUDY_CHANGED", SK.RefreshIcon)

------------------------------------------------------------------------
-- A small pop-up near the top of the screen when your weapon imbue or
-- familiar drops off and you have a scroll for it. Mages only.
--   Left-click: use the scroll (imbue or familiar), right there.
--   Right-click: close it.  Shift-right-click: turn these off.
-- In combat only with the "in combat too" setting, and then it can't use
-- the scroll (the game blocks addons from showing a clickable "use"
-- button mid-fight): it names your key binding instead (UI/Renew.lua).
-- The same reminder waits at least five minutes before popping up again.
------------------------------------------------------------------------

do
    local SHOW_SECONDS = 12
    local FADE_SECONDS = 1.5
    local REPEAT_SECONDS = 300

    local toast              -- the one showing now (secureToast or plainToast)
    local secureToast, plainToast
    local lastShown = {}     -- kind -> GetTime() it was last shown

    -- Hide it, unless that's not allowed right now (a secure one in combat:
    -- then it just goes invisible and really hides after the fight).
    local function HideToast(frame)
        if not frame then return end
        if frame.secure and InCombatLockdown and InCombatLockdown() then
            frame:SetAlpha(0)
            frame.hideAfterCombat = true
            return
        end
        frame:Hide()
    end

    local function Build(secure)
        local toast = CreateFrame("Button", secure and "ScrollkeeperToast" or "ScrollkeeperToastPlain", UIParent,
            secure and "SecureActionButtonTemplate,BackdropTemplate" or "BackdropTemplate")
        toast.secure = secure
        toast:SetSize(300, 58)   -- height grows to fit the text (see Fit)
        -- Where you put it last (Alt-drag), else near the top of the screen.
        local point = SK.db.toastPoint
        if type(point) == "table" and point[1] then
            toast:SetPoint(point[1], UIParent, point[2] or point[1], point[3] or 0, point[4] or 0)
        else
            toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
        end
        -- Alt-drag moves it (a plain click uses the scroll, so Alt-click mustn't).
        toast:SetMovable(true)
        toast:RegisterForDrag("LeftButton")
        if secure then toast:SetAttribute("alt-type1", "none") end
        toast:SetScript("OnDragStart", function(self)
            if not (IsAltKeyDown and IsAltKeyDown()) or SK.db.locked then return end
            if self.secure and InCombatLockdown and InCombatLockdown() then return end
            self.age = 0
            self:StartMoving()
        end)
        toast:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local from, _, to, x, y = self:GetPoint()
            SK.db.toastPoint = { from, to, x, y }
            -- Keep the other pop-up (plain/secure) in the same spot.
            for _, other in ipairs({ secureToast, plainToast }) do
                if other and other ~= self and not (other.secure and InCombatLockdown and InCombatLockdown()) then
                    other:ClearAllPoints()
                    other:SetPoint(from, UIParent, to, x, y)
                end
            end
        end)
        toast:SetFrameStrata("HIGH")
        toast:SetClampedToScreen(true)
        -- The secure one hears press and release: the game uses items on
        -- whichever its "cast on key down" setting says (like the panel's buttons).
        if secure then toast:RegisterForClicks("AnyUp", "AnyDown") else toast:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        -- Right-click never uses the scroll.
        if secure then toast:SetAttribute("type2", "none") end
        if toast.SetBackdrop then
            toast:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            toast:SetBackdropBorderColor(1, 0.82, 0, 1)
            SK.UI.SkinBox(toast, "accent")
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

        -- (HookScript: the secure template's own click uses the scroll first.)
        toast:HookScript("OnClick", function(self, button, down)
            if down then return end   -- act once, on release
            SK.Track(button == "RightButton" and "toast.right" or "toast.use")
            HideToast(self)
            -- Shift-right-click: turn these reminders off (same as the setting).
            if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() and self.expiring then
                SK.db.expiringReminder = false
                SK.Print(L["running-out pop-ups are off. Turn them back on in /sk options (Pop-ups)."])
                return
            end
            if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
                SK.db.reminderToast = false
                SK.Print(L["imbue and familiar pop-ups are off. Turn them back on in /sk options (Pop-ups)."])
                return
            end
            -- Right-click: pick another scroll of that kind (out of combat).
            if button == "RightButton" and self.pickKind and SK.ShowPicks and not SK.InCombat() then
                SK.ShowPicks(self.pickKind, self)
                return
            end
            -- The plain (in-combat) one can't use anything: open the panel after.
            if button == "LeftButton" and not self.secure and SK.TogglePanel and not SK.InCombat()
                and not (ScrollkeeperPanel and ScrollkeeperPanel:IsShown()) then
                SK.TogglePanel()
            end
        end)

        -- Fade out after a few seconds. (No pausing on mouse-over: the
        -- cursor often just sits there while you play, so it'd never go.)
        toast:SetScript("OnUpdate", function(self, elapsed)
            if self.IsDragging and self:IsDragging() then self.age = 0 return end
            self.age = (self.age or 0) + elapsed
            if self.age > SHOW_SECONDS + FADE_SECONDS then
                HideToast(self)
            elseif self.age > SHOW_SECONDS then
                self:SetAlpha(1 - (self.age - SHOW_SECONDS) / FADE_SECONDS)
            end
        end)
        toast:Hide()
        return toast
    end

    -- The toast to use now: the clickable one, or in combat the plain one.
    -- scroll + imbue: what a left-click on the clickable one uses.
    local function Take(scroll, imbue)
        local inCombat = InCombatLockdown and InCombatLockdown()
        if toast and toast:IsShown() then HideToast(toast) end
        if inCombat then
            plainToast = plainToast or Build(false)
            toast = plainToast
        else
            secureToast = secureToast or Build(true)
            toast = secureToast
            if SK.SetScrollUse then SK.SetScrollUse(toast, scroll and scroll.itemID, imbue) end
            toast.pickKind = scroll and (imbue and "imbues" or "familiars") or nil
            toast:SetAttribute("type2", "none")
            toast.hideAfterCombat = nil
        end
        return toast
    end

    -- The hint line: which scroll and why, then what clicking does (or, in
    -- combat, your key).
    local function Hint(kind, scroll)
        local which = ""
        if scroll then
            local why = SK.ScrollReason and SK.ScrollReason(scroll)
            which = "|cffffffff" .. (scroll.name or "") .. "|r" .. (why and (" |cff66bbff(" .. why .. ")|r") or "") .. "\n"
        end
        if toast.secure then return which .. L["Click: use it  ·  Right-click: pick another  ·  Shift-right-click: off"] .. "  ·  " .. L["Alt-drag: move"] end
        local key = SK.RenewKey and SK.RenewKey(kind)
        if key then return which .. L["In combat: press %s to use it."]:format(key) end
        return which .. L["In combat: set a key in Key Bindings > Scrollkeeper to use it mid-fight."]
    end

    -- Flying a flight path: nothing can be used, and the familiar drops off
    -- anyway. The landing (PLAYER_CONTROL_GAINED) checks again.
    local function OnTaxi()
        return type(UnitOnTaxi) == "function" and SK.Known(UnitOnTaxi("player")) == true
    end

    -- Familiars are only worth a scroll in a dungeon or raid (they also drop
    -- off on every flight path), so the familiar pop-ups stay there unless
    -- the familiarAnywhere option is on.
    function SK.WantFamiliar()
        if SK.db and SK.db.familiarAnywhere then return true end
        if type(IsInInstance) ~= "function" then return false end
        local inside, kind = IsInInstance()
        return SK.Known(inside) == true and (kind == "party" or kind == "raid")
    end

    -- Which reminders apply right now: { imbue = scroll or nil, familiar = scroll or nil }
    local function Missing()
        local state = SK.WeaponState and SK.WeaponState() or {}
        local imbue = not state.imbued and SK.BestScroll and SK.BestScroll("imbues") or nil
        local familiar = not state.familiar and SK.WantFamiliar() and SK.BestScroll and SK.BestScroll("familiars") or nil
        return imbue, familiar
    end

    local function Update()
        if not SK.isMage or not SK.db then return end
        local imbue, familiar = Missing()

        -- Fixed it? Then the pop-up goes away by itself.
        if toast and toast:IsShown() and not imbue and not familiar then HideToast(toast) end

        -- In combat only if you asked for it (it can run out mid-fight).
        if not SK.db.reminderToast or (SK.InCombat() and not SK.db.reminderInCombat) then return end
        if UnitIsDeadOrGhost and SK.Known(UnitIsDeadOrGhost("player")) then return end
        if OnTaxi() then return end

        local now = GetTime()
        local function Due(kind, scroll)
            return scroll and (not lastShown[kind] or now - lastShown[kind] >= REPEAT_SECONDS)
        end
        if not (Due("imbue", imbue) or Due("familiar", familiar)) then return end
        if imbue then lastShown.imbue = now end
        if familiar then lastShown.familiar = now end

        -- A click summons the familiar first (then the imbue pop-up comes next).
        Take(familiar or imbue, not familiar)
        local title
        if imbue and familiar then
            title = L["No weapon imbue and no familiar out"]
        elseif imbue then
            title = L["No weapon imbue"]
        else
            title = L["No familiar out"]
        end
        toast.title:SetText(title)
        toast.hint:SetText(Hint(familiar and "familiar" or "imbue", familiar or imbue))
        toast.expiring = nil

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

    -- Running out soon: a pop-up when the imbue or familiar has this many
    -- minutes left (setting, 5 by default) and you carry a scroll to renew
    -- it. Once per buff: renewing it resets that.
    local warned = {}
    local function CheckExpiring()
        if not (SK.isMage and SK.db and SK.db.expiringReminder ~= false) then return end
        if SK.InCombat() and not SK.db.reminderInCombat then return end
        if not SK.BuffTimeLeft then return end
        if UnitIsDeadOrGhost and SK.Known(UnitIsDeadOrGhost("player")) then return end
        if OnTaxi() then return end
        local limit = (tonumber(SK.db.expiringMinutes) or 5) * 60
        local left = SK.BuffTimeLeft()
        local due = {}
        for _, kind in ipairs({ "imbue", "familiar" }) do
            local seconds = left[kind]
            if kind == "familiar" and not SK.WantFamiliar() then seconds = nil end
            if not seconds or seconds > limit then
                warned[kind] = nil            -- renewed (or gone): warn again next time
            elseif not warned[kind] then
                local scroll = SK.BestScroll and SK.BestScroll(kind == "imbue" and "imbues" or "familiars")
                if scroll then due[#due + 1] = { kind = kind, seconds = seconds, scroll = scroll } end
            end
        end
        if #due == 0 then return end
        for _, entry in ipairs(due) do warned[entry.kind] = true end

        local pick = due[#due]
        Take(pick.scroll, pick.kind == "imbue")
        local function Minutes(seconds) return math.max(1, math.ceil(seconds / 60)) end
        local title
        if #due == 2 then
            title = L["Imbue and familiar run out in %d min"]:format(Minutes(math.min(due[1].seconds, due[2].seconds)))
        elseif due[1].kind == "imbue" then
            title = L["Weapon imbue runs out in %d min"]:format(Minutes(due[1].seconds))
        else
            title = L["Familiar runs out in %d min"]:format(Minutes(due[1].seconds))
        end
        toast.title:SetText(title)
        toast.hint:SetText(Hint(pick.kind, pick.scroll))
        toast.expiring = true
        local scroll = due[#due].scroll
        local iconTexture = scroll.itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(scroll.itemID)
        toast.icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Scroll_03")
        toast:Fit()
        toast.age = 0
        toast:SetAlpha(1)
        toast:Show()
    end
    SK.CheckExpiring = CheckExpiring
    SK.Listen("READY", function()
        if C_Timer.NewTicker then C_Timer.NewTicker(15, function() SK.Safely("expiring reminder", CheckExpiring) end) end
    end)

    SK.Listen("REMINDERS_CHANGED", UpdateSoon)
    SK.On("PLAYER_REGEN_ENABLED", function()
        if secureToast and secureToast.hideAfterCombat then
            secureToast.hideAfterCombat = nil
            secureToast:Hide()
        end
        UpdateSoon()
    end)
    -- Landed, or walked into a dungeon/raid: check right away (a fresh
    -- dungeon gets its familiar pop-up even if one showed a moment ago).
    SK.On("PLAYER_CONTROL_GAINED", UpdateSoon)
    SK.On("PLAYER_ENTERING_WORLD", function()
        if SK.WantFamiliar() then lastShown.familiar = nil end
        UpdateSoon()
    end)
    SK.On("PLAYER_UNGHOST", UpdateSoon)
    SK.On("PLAYER_ALIVE", UpdateSoon)
end
