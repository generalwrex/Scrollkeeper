-- Scrollkeeper by generalwrex. Created 2026-11-18.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: UI/Log.lua
-- The Luck Log window (/sk log, or the dice on the panel): what your
-- deciphers turned into, tier by tier, next to everyone's odds, and how
-- often each skill-up color really raised your skill.

local _, SK = ...
local L = SK.L

local WIDTH = 300
local RESULT_ROWS = 9
local SKILLUP_ROWS = 5

-- The skill-up colors, as in Data/Scrolls.lua.
local CHANCE_ORDER = { "orange", "yellow", "green", "gray" }
local CHANCES = {
    orange = { label = "skill-up",          color = "ff8040" },
    yellow = { label = "skill-up likely",   color = "ffff00" },
    green  = { label = "skill-up unlikely", color = "40c040" },
    gray   = { label = "no skill-up",       color = "808080" },
}

local window

------------------------------------------------------------------------
-- The numbers
------------------------------------------------------------------------

-- Your results for one tier, biggest first: { itemID, name, count, share,
-- everyone }, where everyone is the community's share for the same scroll.
local function TierResults(tier)
    local db = SK.db
    local byID = db.resultsByID and db.resultsByID[tier] or {}
    local rows, total = {}, 0
    for id, count in pairs(byID) do
        if SK.IsDecipherResult(id) then
            rows[#rows + 1] = { itemID = id, count = count,
                name = (db.itemNames and db.itemNames[id]) or SK.EnglishScrollName(id) or ("item " .. id) }
            total = total + count
        end
    end
    -- Deciphers logged before item IDs were kept, or where the result
    -- wasn't seen, only have a name.
    local named = 0
    for _, count in pairs(db.results and db.results[tier] or {}) do named = named + count end
    if named > total and next(rows) == nil then
        for name, count in pairs(db.results[tier]) do
            rows[#rows + 1] = { name = name, count = count }
            total = total + count
        end
    end

    local everyone = {}
    for _, entry in ipairs((SK.CommunityOdds(tier))) do everyone[entry.itemID] = entry.share end
    for _, row in ipairs(rows) do
        row.share = total > 0 and row.count / total or 0
        row.everyone = row.itemID and everyone[row.itemID]
    end
    table.sort(rows, function(a, b) return a.count > b.count end)
    return rows, total
end

-- Skill-up rows in tier order, then color order.
local function SkillUpRows()
    local rows, ups, tries = {}, 0, 0
    for _, tier in ipairs(SK.TIERS) do
        for _, color in ipairs(CHANCE_ORDER) do
            local seen = SK.db.skillups and SK.db.skillups[tier .. " " .. color]
            if seen and seen.tries > 0 then
                rows[#rows + 1] = { tier = tier, color = color, ups = seen.ups, tries = seen.tries }
                ups, tries = ups + seen.ups, tries + seen.tries
            end
        end
    end
    return rows, ups, tries
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperLogFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperLogFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(330, 500)
    window:SetPoint("CENTER", -200, 0)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Scrollkeeper: Luck Log"])
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Dice_01") end
    tinsert(UISpecialFrames, "ScrollkeeperLogFrame")
    window.tier = SK.TIERS[1]

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)
    SK.UI.AddHelp(window, "log")

    -- Totals at the top: "57 scrolls deciphered" and the skill-up rate.
    window.total = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.total:SetPoint("TOPLEFT", 70, -32)
    window.total:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    window.total:SetJustifyH("LEFT")
    window.rate = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.rate:SetPoint("TOPLEFT", window.total, "BOTTOMLEFT", 0, -3)
    window.rate:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    window.rate:SetJustifyH("LEFT")

    -- What they turned into, one tier at a time.
    local results = SK.UI.CreateHeader(window, L["What they turned into"], WIDTH)
    results:SetPoint("TOPLEFT", 15, -72)

    window.tierButtons = {}
    local slot = WIDTH / #SK.TIERS
    for i, tier in ipairs(SK.TIERS) do
        local button = CreateFrame("Button", nil, window)
        button:SetSize(22, 22)
        button:SetPoint("TOPLEFT", results, "BOTTOMLEFT", (i - 1) * slot + (slot - 22) / 2, -6)
        button:SetNormalTexture(SK.UI.TIER_ICONS and SK.UI.TIER_ICONS[i] or "Interface\\Icons\\INV_Scroll_03")
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button.glow = button:CreateTexture(nil, "OVERLAY")
        button.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        button.glow:SetBlendMode("ADD")
        button.glow:SetAllPoints()
        button.number = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.number:SetPoint("BOTTOMRIGHT", 3, -2)
        button.number:SetText(tier)
        button:SetScript("OnClick", function()
            SK.Track("log.tier")
            window.tier = tier
            window.results.scroll:SetVerticalScroll(0)   -- a new tier starts at the top
            SK.RefreshLog()
        end)
        button:SetScript("OnEnter", function(self)
            local _, total = TierResults(tier)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["Tier "] .. tier)
            GameTooltip:AddLine(L["You deciphered %d of these."]:format(total), 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        window.tierButtons[tier] = button
    end

    window.results = SK.UI.CreateScrollList(window, WIDTH, RESULT_ROWS)
    window.results:SetPoint("TOPLEFT", results, "BOTTOMLEFT", 0, -34)
    window.columns = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.columns:SetPoint("TOPRIGHT", results, "BOTTOMRIGHT", -28, -34 - RESULT_ROWS * 16 - 3)
    window.columns:SetText(L["count  ·  you  ·  everyone"])

    -- How often each skill-up color really raised your skill.
    local skillups = SK.UI.CreateHeader(window, L["Skill-ups seen"], WIDTH)
    skillups:SetPoint("TOPLEFT", results, "BOTTOMLEFT", 0, -34 - RESULT_ROWS * 16 - 20)
    window.skillups = SK.UI.CreateScrollList(window, WIDTH, SKILLUP_ROWS)
    window.skillups:SetPoint("TOPLEFT", skillups, "BOTTOMLEFT", 0, -4)

    local note = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 16, 14)
    note:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText(L["Every decipher is logged by itself. Your results are shared to make everyone's odds better."])

    window:SetScript("OnShow", function() SK.RefreshLog() end)
    window:Hide()   -- new frames start shown; the first toggle would hide it instead
end

-- A faint bar behind a row, as wide as its share.
local function ShareBar(row, share)
    if type(row.shareBar) ~= "table" then
        row.shareBar = row:CreateTexture(nil, "BORDER")
        row.shareBar:SetPoint("TOPLEFT", 0, -1)
        row.shareBar:SetPoint("BOTTOMLEFT", 0, 1)
        row.shareBar:SetColorTexture(0.64, 0.21, 0.93, 0.28)
    end
    if share and share > 0 then
        local width = row:GetWidth()
        if type(width) ~= "number" or width <= 0 then width = WIDTH - 22 end
        row.shareBar:SetWidth(math.max(1, width * share))
        row.shareBar:Show()
    else
        row.shareBar:Hide()
    end
end

function SK.RefreshLog()
    if not (window and window:IsShown()) then return end
    local db = SK.db
    local deciphered = db.deciphered or 0
    window.total:SetText(L["|cffffffff%d|r |4scroll:scrolls; deciphered"]:format(deciphered))
    local skillRows, ups, tries = SkillUpRows()
    if tries > 0 then
        window.rate:SetText(L["Skill went up on |cffffffff%d|r of |cffffffff%d|r (%d%%)"]:format(ups, tries,
            math.floor(ups / tries * 100 + 0.5)))
    else
        window.rate:SetText("")
    end

    for tier, button in pairs(window.tierButtons) do
        local active = tier == window.tier
        button.glow:SetShown(active)
        SK.UI.Desaturate(button, not active)
        button.number:SetTextColor(active and 1 or 0.6, active and 0.82 or 0.6, active and 0 or 0.6)
    end

    local rows = TierResults(window.tier)
    window.results:SetRows(rows, function(row, entry)
        row.itemID = entry.itemID
        row.tipTitle, row.tipLines, row.tipFunc, row.onClick = nil, nil, nil, nil
        row.tipCount = nil
        local short = (entry.name or ""):gsub("^Scroll of ", "")
        row.label:SetText(entry.itemID and SK.UI.ItemLabel(entry.itemID, short) or short)
        local everyone = entry.everyone and ("%d%%"):format(math.floor(entry.everyone * 100 + 0.5)) or "-"
        row.value:SetText(("%d  ·  |cffffffff%d%%|r  ·  |cff808080%s|r"):format(entry.count,
            math.floor(entry.share * 100 + 0.5), everyone))
        ShareBar(row, entry.share)
    end, L["No tier %d scrolls deciphered yet."]:format(window.tier))

    window.skillups:SetRows(skillRows, function(row, entry)
        row.itemID = nil
        local chance = CHANCES[entry.color]
        row.label:SetText(L["Tier "] .. entry.tier .. "  |cff" .. chance.color .. L[chance.label] .. "|r")
        row.value:SetText(("%d / %d  |cffffffff%d%%|r"):format(entry.ups, entry.tries,
            math.floor(entry.ups / entry.tries * 100 + 0.5)))
        ShareBar(row, nil)
    end, L["Nothing yet. Each decipher notes whether your skill went up."])
end

function SK.ToggleLog()
    if not SK.ModuleOn("Log") then
        SK.Print(L["%s is turned off. Turn it on in /sk options (Modules)."]:format(L["Luck Log"]))
        return
    end
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

SK.Listen("LOG_CHANGED", function() SK.RefreshLog() end)
