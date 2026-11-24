-- Scrollkeeper: UI/Picks.lua
-- Right-click anything that suggests a scroll (the panel's Familiar and
-- Imbue buttons, the imbue/familiar pop-up) for a row of all your scrolls
-- of that kind:
--
--   [Cat] [Frog] [Rat]        click one: use it (an imbue goes on your weapon)
--    ★                         click a star: pin it, so the button, key
--                              binding and pop-up use it. Imbues get one pin
--                              per weapon kind (staff, dagger, sword).
--
-- The scroll buttons are real item buttons, so it works in combat too: the
-- panel's right-click opens it through the game's secure code. What's in
-- it is what you had when the fight started (addons can't change secure
-- buttons mid-fight). Pins changed in combat take over after it.

local _, SK = ...
local L = SK.L

local SIZE, GAP, MAX = 30, 6, 10
local rows = {}          -- categoryKey -> the row frame
local header             -- secure handler that opens rows in combat

local function Build(categoryKey)
    local row = CreateFrame("Frame", "ScrollkeeperPicks_" .. categoryKey, UIParent, "SecureHandlerBaseTemplate,BackdropTemplate")
    row:SetFrameStrata("DIALOG")
    row:SetClampedToScreen(true)
    row:SetSize(SIZE + 16, SIZE + 34)
    if row.SetBackdrop then
        row:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        row:SetBackdropBorderColor(1, 0.82, 0, 1)
        SK.UI.SkinBox(row, "accent")
    end
    row:Hide()
    row.categoryKey = categoryKey
    row.buttons, row.stars = {}, {}
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.title:SetPoint("TOPLEFT", 8, -6)
    for i = 1, MAX do
        local b = SK.UI.CreateItemButton(row, "ScrollkeeperPick_" .. categoryKey .. i, SIZE)
        b:SetPoint("TOPLEFT", 8 + (i - 1) * (SIZE + GAP), -20)
        b:Hide()
        -- Close the row after using a scroll (out of combat; in combat it
        -- stays until you right-click again).
        b:HookScript("PostClick", function(_, _, down)
            if not down and not SK.InCombat() then row:Hide() end
        end)
        local star = CreateFrame("Button", nil, row)
        star:SetSize(14, 14)
        star:SetPoint("TOP", b, "BOTTOM", 0, -2)
        star.tex = star:CreateTexture(nil, "OVERLAY")
        star.tex:SetAllPoints()
        star.tex:SetTexture("Interface\\COMMON\\FavoritesIcon")
        star:SetScript("OnClick", function(self)
            if not self.itemID then return end
            SK.TogglePin(self.itemID)
            if SK.InCombat() then SK.Print(L["pinned. The button switches to it after combat."]) end
        end)
        star:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(SK.IsPinned(self.itemID) and L["Pinned: click to unpin"] or L["Click to pin"])
            local kind = SK.ImbueWeapon(self.itemID)
            GameTooltip:AddLine(kind and L["Your imbue for a %s: the Imbue button uses it whenever you hold one."]:format(L[kind])
                or L["Your familiar: the Familiar button uses it."], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        star:SetScript("OnLeave", function() GameTooltip:Hide() end)
        star:Hide()
        row.buttons[i], row.stars[i] = b, star
    end
    -- Click outside: close (out of combat).
    row:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    row:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    row:SetScript("OnEvent", function(self)
        if SK.InCombat() or self:IsMouseOver() then return end
        C_Timer.After(0.05, function() if not SK.InCombat() and not self:IsMouseOver() then self:Hide() end end)
    end)
    rows[categoryKey] = row
    return row
end

-- Point the row's buttons at your scrolls (out of combat only).
local function Fill(row)
    if SK.InCombat() then return end
    local scrolls = {}
    for _, group in ipairs(SK.ScrollGroups and SK.ScrollGroups() or {}) do
        if group.key == row.categoryKey then scrolls = group.scrolls end
    end
    local imbue = row.categoryKey == "imbues"
    local shown = math.min(#scrolls, MAX)
    for i = 1, MAX do
        local b, star, scroll = row.buttons[i], row.stars[i], scrolls[i]
        if scroll and i <= shown then
            SK.SetScrollUse(b, scroll.usable and scroll.itemID or nil, imbue)
            b:SetDisplay(scroll.itemID, scroll.icon, scroll.count)
            b:SetUsable(scroll.usable)
            b:SetBest(scroll.best)
            b.scroll = scroll
            b.categoryLabel = row.categoryKey == "imbues" and L["Imbue"] or L["Familiar"]
            b:Show()
            star.itemID = scroll.itemID
            local pinned = SK.IsPinned(scroll.itemID)
            star.tex:SetDesaturated(not pinned)
            star.tex:SetAlpha(pinned and 1 or 0.35)
            star:SetShown(not imbue or SK.ImbueWeapon(scroll.itemID, scroll) ~= nil)
        else
            SK.SetScrollUse(b, nil)
            b:Hide()
            star:Hide()
        end
    end
    row.title:SetText(shown == 0 and (imbue and L["No imbue scrolls"] or L["No familiar scrolls"])
        or (imbue and L["Imbues"] or L["Familiars"]))
    row:SetWidth(math.max(120, 16 + math.max(shown, 1) * (SIZE + GAP) - GAP))
end

local function FillAll()
    for _, row in pairs(rows) do SK.Safely("pick row", Fill, row) end
end

-- Open the row by an anchor (out of combat).
function SK.ShowPicks(categoryKey, anchor)
    if SK.InCombat() then return end
    local row = rows[categoryKey] or Build(categoryKey)
    Fill(row)
    row:ClearAllPoints()
    row:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -8, 4)
    row:SetShown(not row:IsShown())
end

-- Give a secure button (the panel's Familiar or Imbue icon) a right-click
-- that opens the row, in combat too.
function SK.AttachPicks(button, categoryKey)
    if not (button and SecureHandlerWrapScript) or button.skPicks then return end
    local row = rows[categoryKey] or Build(categoryKey)
    Fill(row)
    header = header or CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    button:SetAttribute("type2", "none")   -- right-click never uses the scroll
    header:SetFrameRef("picks_" .. categoryKey, row)
    SecureHandlerWrapScript(button, "OnClick", header, ([[
        if button ~= "RightButton" then return end
        if down then return false end
        local row = owner:GetFrameRef("picks_%s")
        if row:IsShown() then
            row:Hide()
        else
            row:ClearAllPoints()
            row:SetPoint("BOTTOMLEFT", self, "TOPLEFT", -8, 4)
            row:Show()
        end
        return false
    ]]):format(categoryKey))
    button.skPicks = true
end

SK.Listen("READY", function()
    if not SK.isMage then return end
    SK.AttachPicks(_G.ScrollkeeperFamiliarButton, "familiars")
    SK.AttachPicks(_G.ScrollkeeperImbueButton, "imbues")
end)
SK.Listen("BAGS_CHANGED", FillAll)
SK.Listen("PINS_CHANGED", FillAll)
SK.Listen("REMINDERS_CHANGED", FillAll)
SK.On("PLAYER_REGEN_ENABLED", FillAll)
SK.On("PLAYER_EQUIPMENT_CHANGED", function() C_Timer.After(0.5, FillAll) end)
