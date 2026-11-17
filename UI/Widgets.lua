-- Scrollkeeper: UI/Widgets.lua
-- Small building blocks the panel is made from: a progress bar and an
-- item button. Keeping them here keeps UI/Panel.lua about layout only.

local _, SK = ...
local L = SK.L

SK.UI = {}

local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- Colors used across the panel, as { red, green, blue }.
SK.UI.COLORS = {
    accent = { 0.25, 0.45, 0.95 },   -- classic skill-bar blue
    good   = { 0.25, 0.85, 0.35 },
    wait   = { 0.85, 0.65, 0.20 },
    dim    = { 0.55, 0.55, 0.55 },
}

------------------------------------------------------------------------
-- Progress bar with a label on it
--   bar:SetProgress(value, max)   bar:SetLabel("left text", "right text")   bar:SetBarColor({r,g,b})
------------------------------------------------------------------------

function SK.UI.CreateBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.12, 0.12, 0.14, 1)

    -- Thin dark edge, like the bars on the character window.
    local edge = bar:CreateTexture(nil, "BORDER")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 0.9)

    -- Two labels, one at each end, so the tier marks in the middle never
    -- cut through the words. Outlined so they stay readable on the fill.
    local function MakeLabel(point, x, justify)
        local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint(point, x, 0)
        label:SetJustifyH(justify)
        local font, size = label:GetFont()
        if font then label:SetFont(font, size, "OUTLINE") end
        return label
    end
    bar.leftLabel = MakeLabel("LEFT", 6, "LEFT")
    bar.rightLabel = MakeLabel("RIGHT", -8, "RIGHT")

    function bar:SetProgress(value, max)
        if not max or max <= 0 then max, value = 1, 0 end
        self:SetMinMaxValues(0, max)
        self:SetValue(math.max(0, math.min(value, max)))
    end
    function bar:SetLabel(left, right)
        self.leftLabel:SetText(left or "")
        self.rightLabel:SetText(right or "")
    end
    function bar:SetBarColor(color) self:SetStatusBarColor(color[1], color[2], color[3]) end

    -- Short ticks along the bottom edge, used to show where the scroll tiers are.
    bar.marks = {}
    function bar:SetMarks(positions, max)
        for _, mark in ipairs(self.marks) do mark:Hide() end
        if not max or max <= 0 then return end
        local shown = 0
        for _, position in ipairs(positions) do
            if position > 1 and position < max then
                shown = shown + 1
                local mark = self.marks[shown]
                if not mark then
                    mark = self:CreateTexture(nil, "ARTWORK")
                    mark:SetColorTexture(1, 0.82, 0, 0.9)
                    mark:SetSize(2, 5)
                    self.marks[shown] = mark
                end
                mark:ClearAllPoints()
                mark:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", width * position / max - 1, 0)
                mark:Show()
            end
        end
    end

    return bar
end

------------------------------------------------------------------------
-- Item button: shows an item's icon and how many you have. Clicking it
-- uses the item. It is a secure button, so the game only lets us change
-- which item it points at while out of combat.
------------------------------------------------------------------------

-- Why a scroll can't be used right now, or nil if it can.
function SK.UI.WhyNotUsable(scroll)
    if not scroll or scroll.usable ~= false then return nil end
    if scroll.levelOK == false then
        return L["You need level %d for %s."]:format(scroll.level or 0, SK.ScrollLink(scroll.itemID, scroll.name))
    end
    if scroll.fits == false then
        local _, weapon = SK.MainHandWeapon()
        local text = L["%s is only for %s. You're holding %s."]:format(SK.ScrollLink(scroll.itemID, scroll.name),
            SK.WeaponWithArticle and SK.WeaponWithArticle(scroll.imbueFor) or L["a different weapon"],
            weapon or L["no weapon"])
        local inBags = SK.WeaponInBagsFor and SK.WeaponInBagsFor(scroll)
        if inBags then text = text .. L[" Equip your %s to use it."]:format(inBags) end
        return text
    end
    return nil
end

function SK.UI.CreateItemButton(parent, name, size)
    local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    button:SetSize(size, size)
    button:RegisterForClicks("AnyUp", "AnyDown")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- trim the icon's built-in border
    button.icon = icon

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -1, 1)
    button.count = count

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    -- Classic item slot border around the icon.
    local frame = button:CreateTexture(nil, "OVERLAY")
    frame:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    frame:SetPoint("TOPLEFT", -size * 0.35, size * 0.35)
    frame:SetPoint("BOTTOMRIGHT", size * 0.35, -size * 0.35)

    -- A thin gold outline marks the best one in its category.
    local star = CreateFrame("Frame", nil, button, "BackdropTemplate")
    star:SetPoint("TOPLEFT", -2, 2)
    star:SetPoint("BOTTOMRIGHT", 2, -2)
    star:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    star:SetBackdropBorderColor(1, 0.82, 0, 1)
    star:SetFrameLevel(button:GetFrameLevel() + 2)
    star:Hide()
    button.star = star

    function button:SetBest(best) self.best = best; self.star:SetShown(best and true or false) end
    -- Scrolls you're not high enough level for are shown dimmed.
    function button:SetUsable(usable)
        self.usable = usable
        self.icon:SetDesaturated(not usable)
        self.icon:SetAlpha(usable and 1 or 0.5)
    end

    button:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) end
        local scroll = self.scroll
        if self.best then
            GameTooltip:AddLine(L["|cffffd100Best %s you can use.|r"]:format((self.categoryLabel or ""):lower()))
        else
            local reason = SK.UI.WhyNotUsable(scroll)
            if reason then GameTooltip:AddLine("|cffff6666" .. SK.KeepLinksWhole(reason) .. "|r", 1, 1, 1, true) end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Clicking a scroll you can't use: say why, instead of nothing happening.
    button:SetScript("PostClick", function(self, _, down)
        if down then return end
        local reason = SK.UI.WhyNotUsable(self.scroll)
        if reason then
            SK.Print(reason)
            if UIErrorsFrame then UIErrorsFrame:AddMessage(reason, 1, 0.3, 0.3) end
        end
    end)

    -- Only the picture and number; safe to call in combat.
    function button:SetDisplay(itemID, iconTexture, amount)
        self.itemID = itemID
        self.icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.count:SetText(amount and amount > 1 and amount or "")
    end

    return button
end

-- Make item links shown in a frame's text act like links elsewhere:
-- hover for the tooltip, click to open it, Shift-click to put it in chat.
-- (The frame needs SetHyperlinksEnabled(true).)
function SK.UI.EnableItemLinks(frame)
    frame:SetScript("OnHyperlinkEnter", function(self, link)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    frame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnHyperlinkClick", function(_, link, text, button)
        if SetItemRef then SetItemRef(link, text, button) end
    end)
end
