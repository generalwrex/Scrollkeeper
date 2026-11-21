-- Scrollkeeper: UI/Guide.lua
-- The Codex (/sk codex, also /sk guide): everything in one place.
--   Scrolls  every mage scroll, tier by tier: what it does (the game's own
--            tooltip text, so it's in your language), how many you have,
--            and why it's your pick (your usual, your spec, a skill-up).
--   Books    the 40 books for the librarians: where each one is (click for
--            a waypoint), which you've handed in, and your next reward.

local _, SK = ...
local L = SK.L

local WIDTH, ROWS = 470, 12
local INNER = WIDTH - 30
local window
local tab = "scrolls"

------------------------------------------------------------------------
-- What a scroll does: the "Use:" line of its tooltip (in your language).
------------------------------------------------------------------------

local useCache, waiting = {}, {}
local function WhatItDoes(itemID)
    if useCache[itemID] then return useCache[itemID] end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local data = SK.Try(C_TooltipInfo.GetItemByID, itemID)
    local lines = type(data) == "table" and data.lines or nil
    if not lines or #lines < 2 then
        waiting[itemID] = true
        if C_Item and C_Item.RequestLoadItemDataByID then SK.Try(C_Item.RequestLoadItemDataByID, itemID) end
        return nil
    end
    local use = type(ITEM_SPELL_TRIGGER_ONUSE) == "string" and ITEM_SPELL_TRIGGER_ONUSE or "Use:"
    for _, line in ipairs(lines) do
        local text = SK.Known(line.leftText)
        if type(text) == "string" and text:find(use, 1, true) == 1 then
            useCache[itemID] = (text:sub(#use + 1):gsub("^%s+", ""))
            return useCache[itemID]
        end
    end
    return nil
end

SK.On("GET_ITEM_INFO_RECEIVED", function(itemID)
    if itemID and waiting[itemID] then
        waiting[itemID] = nil
        if window and window:IsShown() then SK.RefreshGuide() end
    end
end)

------------------------------------------------------------------------
-- The scroll rows: a header per tier, then each scroll it can become.
------------------------------------------------------------------------

local function IDByName(name)
    for id, english in pairs(SK.MAGE_SCROLL_IDS or {}) do
        if english == "Scroll of " .. name or english == name then return id end
    end
end

local function ScrollRows()
    local counts, uses = {}, {}
    for _, scroll in ipairs(SK.bags and SK.bags.translated or {}) do counts[scroll.itemID] = scroll.count end
    local best = {}
    for _, key in ipairs({ "imbues", "familiars" }) do
        local scroll = SK.BestScroll and SK.BestScroll(key)
        if scroll then best[scroll.itemID] = SK.ScrollReason and SK.ScrollReason(scroll) or L["your best one"] end
    end
    local skill = SK.GetComprehension and SK.GetComprehension() or { rank = 0, effective = 0 }
    local rows = {}
    for _, tier in ipairs(SK.TIERS) do
        local chance = SK.SkillUpChance(tier, skill.rank)
        local readable = (skill.effective or 0) >= tier
        local status = not readable and ("|cffff6666" .. L["you need %d skill to read these"]:format(tier) .. "|r")
            or (chance and chance.gives and ("|cff40ff40" .. L["skill-ups for you"] .. "|r"))
            or ("|cff808080" .. L["no skill-ups for you anymore"] .. "|r")
        rows[#rows + 1] = { header = true, tier = tier, status = status }
        for _, name in ipairs(SK.TIER_RESULTS[tier] or {}) do
            local id = IDByName(name)
            if id then
                rows[#rows + 1] = { itemID = id, name = name, count = counts[id] or 0, uses = SK.ScrollUses and SK.ScrollUses(id) or 0,
                    pick = best[id] }
            end
        end
    end
    return rows
end

------------------------------------------------------------------------
-- The book rows: your progress, then every book by zone.
------------------------------------------------------------------------

local function ZoneName(mapID)
    local info = C_Map and C_Map.GetMapInfo and SK.Try(C_Map.GetMapInfo, mapID)
    return type(info) == "table" and info.name or ("map " .. mapID)
end

local function BookRows()
    local rows = {}
    local list = {}
    for _, spot in ipairs(SK.BOOK_SPOTS or {}) do list[#list + 1] = spot end
    table.sort(list, function(a, b)
        local za, zb = ZoneName(a.map), ZoneName(b.map)
        if za ~= zb then return za < zb end
        return a.name < b.name
    end)
    local ids = SK.BookIDsByName()
    for _, spot in ipairs(list) do
        rows[#rows + 1] = { book = spot, itemID = ids[spot.name:lower()], handed = SK.BookHanded and SK.BookHanded(spot.name) or false,
            by = SK.BookHandedBy and SK.BookHandedBy(spot.name) or {} }
    end
    return rows
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperGuideFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperGuideFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, 470)
    window:SetPoint("CENTER", -150, 0)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Scrollkeeper: Codex"])
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09") end
    tinsert(UISpecialFrames, "ScrollkeeperGuideFrame")   -- Escape closes it

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    -- Side tabs: square icons down the right edge, like the game's own
    -- windows on Forever (Professions, Spellbook). Hover for the name.
    local TAB_KEYS = { "scrolls", "books" }
    local function MakeTab(i, icon, text)
        local button = CreateFrame("CheckButton", "ScrollkeeperGuideFrameTab" .. i, window)
        button:SetSize(32, 32)
        button:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -48 - (i - 1) * 48)
        local frame = button:CreateTexture(nil, "BACKGROUND")
        frame:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        frame:SetSize(64, 64)
        frame:SetPoint("TOPLEFT", -3, 11)
        button:SetNormalTexture(icon)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        -- (The usual "checked" glow isn't on Forever: the hover glow is.)
        button:SetCheckedTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:SetID(i)
        button:SetScript("OnClick", function(self)
            tab = TAB_KEYS[self:GetID()]
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then SK.Try(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
            SK.RefreshGuide()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return button
    end
    window.tabs = {
        MakeTab(1, "Interface\\Icons\\INV_Scroll_03", L["Scrolls"]),
        MakeTab(2, "Interface\\Icons\\INV_Misc_Book_09", L["Books"]),
    }
    window.scrollsTab, window.booksTab = window.tabs[1], window.tabs[2]

    window.top = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.top:SetPoint("TOPLEFT", 64, -38)
    window.top:SetWidth(INNER - 12)
    window.top:SetJustifyH("LEFT")

    window.list = SK.UI.CreateScrollList(window, INNER, ROWS, true)
    window.list:SetPoint("TOPLEFT", 15, -70)

    window.note = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.note:SetPoint("BOTTOMLEFT", 16, 14)
    window.note:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    window.note:SetJustifyH("LEFT")

    window:SetScript("OnShow", function() SK.RefreshGuide() end)
    window:Hide()
end

local function ScrollRow(row, entry)
    row.itemID, row.tipTitle, row.tipLines, row.tipFunc, row.onClick, row.tipCount = nil, nil, nil, nil, nil, nil
    if entry.header then
        row.label:SetText("|cffffd100" .. L["Tier %d scrolls"]:format(entry.tier) .. "|r")
        row.sub:SetText(entry.status)
        return
    end
    row.itemID = entry.itemID
    local name = C_Item and SK.Try(C_Item.GetItemNameByID, entry.itemID) or ("Scroll of " .. entry.name)
    local tags = {}
    if entry.count > 0 then tags[#tags + 1] = "|cffffffff" .. L["you have %d"]:format(entry.count) .. "|r" end
    if entry.pick then tags[#tags + 1] = "|cff66bbff" .. entry.pick .. "|r" end
    if entry.uses > 0 and not entry.pick then tags[#tags + 1] = "|cff808080" .. L["used %d times"]:format(entry.uses) .. "|r" end
    -- The scroll as an item link, like in chat ([Scroll of ...]).
    local link = SK.ScrollLink and SK.ScrollLink(entry.itemID, name) or name
    row.label:SetText(link .. (#tags > 0 and ("  " .. table.concat(tags, "  ")) or ""))
    row.sub:SetText("|cffbbbbbb" .. (WhatItDoes(entry.itemID) or L["(loading...)"]) .. "|r")
    row.tipCount = #tags > 0 and table.concat(tags, "  ") or nil
end

-- Book item IDs by name (lowercase), from books handed in or shared, so a
-- book can show as an item link. (Wowhead's list only has names.)
function SK.BookIDsByName()
    local ids = {}
    local function Add(id, name)
        id = tonumber(id)
        if not id then return end
        name = type(name) == "string" and name or (C_Item and SK.Try(C_Item.GetItemNameByID, id))
        if type(name) == "string" then ids[name:lower()] = id end
    end
    for id, name in pairs(SK.db.bookIDs or {}) do Add(id, name) end
    for _, entry in pairs(SK.COMMUNITY_DATA or {}) do
        for _, id in ipairs(entry.bookIDs or {}) do Add(id) end
    end
    return ids
end

local function BookRow(row, entry)
    row.itemID, row.tipTitle, row.tipLines, row.tipFunc, row.onClick, row.tipCount = nil, nil, nil, nil, nil, nil
    local spot = entry.book
    local mark = entry.handed and "|cff40ff40✓|r " or ""
    local id = entry.itemID
    local name = (entry.handed and "|cff808080" or "|cffffffff") .. spot.name .. "|r"
    if id and SK.ScrollLink then name = SK.ScrollLink(id, spot.name) end
    row.label:SetText(mark .. name)
    local where = ("%s  %.1f, %.1f"):format(ZoneName(spot.map), spot.x, spot.y)
    if spot.note then where = where .. "  (" .. L[spot.note] .. ")" end
    row.sub:SetText("|cffbbbbbb" .. where .. "|r")
    row.tipFunc = function(tooltip)
        tooltip:AddLine(spot.name)
        tooltip:AddLine(where, 1, 1, 1)
        if #entry.by > 0 then tooltip:AddLine(L["Handed in by: %s"]:format(table.concat(entry.by, ", ")), 0.6, 0.85, 0.6, true) end
        tooltip:AddLine(L["Click for a waypoint."], 0.6, 0.6, 0.6)
    end
    row.onClick = function()
        if SK.SetWaypoint and SK.SetWaypoint(spot.map, spot.x / 100, spot.y / 100, spot.name) then
            SK.Print(L["waypoint set: "] .. spot.name)
        end
    end
end

function SK.RefreshGuide()
    if not (window and window:IsShown()) then return end
    -- The picked tab glows.
    window.scrollsTab:SetChecked(tab ~= "books")
    window.booksTab:SetChecked(tab == "books")
    if tab == "books" then
        local handed, reward = 0, nil
        if SK.BookProgress then handed, reward = SK.BookProgress() end
        local top = L["Books handed in: %d of %d."]:format(handed or 0, SK.BOOKS_TOTAL or 40)
        if reward and SK.BookRewardText then
            top = top .. "  " .. L["Next reward at %d: %s."]:format(reward.books, SK.BookRewardText(reward))
        end
        window.top:SetText(top)
        window.list:SetRows(BookRows(), BookRow, "")
        window.note:SetText(L["Book spots from Wowhead's list. Any class can hand books in."])
    else
        local skill = SK.GetComprehension and SK.GetComprehension()
        window.top:SetText(skill and skill.known and L["Your Comprehension: |cffffffff%d|r / %d"]:format(skill.rank, skill.max)
            or L["Comprehend Scroll is learned from a mage trainer at level 6."])
        window.list:SetRows(ScrollRows(), ScrollRow, "")
        window.note:SetText(L["Hover a scroll for its tooltip, Shift-click to link it."])
    end
end

function SK.ToggleGuide()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

SK.Listen("BAGS_CHANGED", function() SK.RefreshGuide() end)
SK.Listen("SKILL_CHANGED", function() SK.RefreshGuide() end)
