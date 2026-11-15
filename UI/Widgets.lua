-- Scrollkeeper: UI/Widgets.lua
-- Small building blocks the panel is made from: a progress bar and an
-- item button. Keeping them here keeps UI/Panel.lua about layout only.

local _, SK = ...

SK.UI = {}

local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- Colours used across the panel, as { red, green, blue }.
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
    background:SetColorTexture(0, 0, 0, 0.5)

    -- The classic skill-bar frame from the character sheet's Skills tab.
    local border = bar:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    border:SetPoint("TOPLEFT", -5, 6)
    border:SetPoint("BOTTOMRIGHT", 5, -6)

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
    bar.leftLabel = MakeLabel("LEFT", 4, "LEFT")
    bar.rightLabel = MakeLabel("RIGHT", -4, "RIGHT")

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

    button:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Only the picture and number; safe to call in combat.
    function button:SetDisplay(itemID, iconTexture, amount)
        self.itemID = itemID
        self.icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.count:SetText(amount and amount > 1 and amount or "")
    end

    return button
end
