-- Scrollkeeper by generalwrex. Created 2026-11-21.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: UI/Guide.lua
-- The Codex (/sk codex, also /sk guide): everything in one place.
--   Scrolls  every mage scroll, tier by tier: what it does (the game's own
--            tooltip text, so it's in your language), how many you have,
--            and why it's your pick (your usual, your spec, a skill-up).
--   Books    the 40 books for the librarians: where each one is (click for
--            a waypoint), which you've handed in, and your next reward.
--   Rewards  every librarian reward, as item links: which you've reached
--            and how many books until the next.

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
    -- Found it yourself (any of your characters looted it at its spot)?
    local function FoundByYou(spot)
        for cell, counts in pairs(SK.db.bookDrops and SK.db.bookDrops[spot.map] or {}) do
            local x, y = SK.CellCenter(cell)
            if x and math.abs(x - spot.x / 100) <= 0.03 and math.abs(y - spot.y / 100) <= 0.03 and (counts or 0) > 0 then return true end
        end
        for key, name in pairs(SK.db.bookNames or {}) do
            if type(name) == "string" and name:lower() == spot.name:lower() then return true end
        end
        return false
    end
    for _, spot in ipairs(list) do
        rows[#rows + 1] = { book = spot, itemID = ids[spot.name:lower()], handed = SK.BookHanded and SK.BookHanded(spot.name) or false,
            by = SK.BookHandedBy and SK.BookHandedBy(spot.name) or {}, found = FoundByYou(spot) }
    end
    return rows
end

------------------------------------------------------------------------
-- The reward rows: a header per step (how many books), then its items.
------------------------------------------------------------------------

local function RewardRows()
    local handed, nextReward = 0, nil
    if SK.BookProgress then handed, nextReward = SK.BookProgress() end
    handed = handed or 0
    local rows = {}
    for _, reward in ipairs(SK.BOOK_REWARDS or {}) do
        local status
        local reached = handed >= SK.RewardBooks(reward)
        if reached then
            status = "|cff40ff40" .. L["reached"] .. "|r"
        elseif reward.unknown then
            status = "|cffff9933" .. L["data missing: how many books these take isn't known yet"] .. "|r"
        elseif reward == nextReward then
            status = "|cffffd100" .. L["next: %d more |4book:books;"]:format(reward.books - handed) .. "|r"
        else
            status = "|cff808080" .. L["%d more |4book:books;"]:format(reward.books - handed) .. "|r"
        end
        rows[#rows + 1] = { header = true, reward = reward, status = status, reached = reached }
        for i, item in ipairs(reward.items) do
            local id = reward.ids and reward.ids[i]
            if id and C_Item and C_Item.GetItemInfo and not SK.Try(C_Item.GetItemInfo, id) then waiting[id] = true end
            rows[#rows + 1] = { itemID = id, name = item, reached = reached }
        end
    end
    return rows
end

-- The item's slot and type ("Neck", "Finger", "Bow"...), in your language.
local function ItemKind(itemID)
    if not (itemID and C_Item and C_Item.GetItemInfoInstant) then return "" end
    local ok, _, _, subType, equipLoc = pcall(C_Item.GetItemInfoInstant, itemID)
    if not ok then return "" end
    local slot = type(equipLoc) == "string" and equipLoc ~= "" and _G[equipLoc]
    local parts = {}
    if type(slot) == "string" then parts[#parts + 1] = slot end
    if type(subType) == "string" and subType ~= "" and subType ~= slot and subType ~= "Miscellaneous" then parts[#parts + 1] = subType end
    return table.concat(parts, ", ")
end

local function RewardRow(row, entry)
    row.itemID, row.tipTitle, row.tipLines, row.tipFunc, row.onClick, row.tipCount = nil, nil, nil, nil, nil, nil
    if entry.header then
        local reward = entry.reward
        local text = reward.unknown and L["? books"] or L["%d books"]:format(reward.books)
        if reward.title then text = text .. ": " .. L[reward.title] end
        if reward.level then
            local level = UnitLevel and SK.Known(UnitLevel("player"))
            local color = (type(level) == "number" and level >= reward.level) and "|cffbbbbbb" or "|cffff6666"
            text = text .. "  " .. color .. L["needs level %d"]:format(reward.level) .. "|r"
        end
        row.label:SetText((entry.reached and "|cff40ff40ng|r " or "") .. "|cffffd100" .. text .. "|r")
        row.sub:SetText(entry.status .. "  |cff808080" .. L["(pick one)"] .. "|r")
        return
    end
    row.itemID = entry.itemID
    local link = entry.itemID and SK.ScrollLink and SK.ScrollLink(entry.itemID, L[entry.name]) or L[entry.name]
    row.label:SetText("    " .. link)
    row.sub:SetText("    |cffbbbbbb" .. ItemKind(entry.itemID) .. "|r")
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
    SK.UI.Background(background)
    SK.UI.AddHelp(window, "codex")

    -- Side tabs: square icons down the right edge, like the game's own
    -- windows on Forever (Professions, Spellbook). Hover for the name.
    local TAB_KEYS = { "scrolls", "books", "rewards" }
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
        -- SetCheckedTexture has no blend mode: without ADD this glow art
        -- (black around a blue glow) covers the icon in black.
        button:SetCheckedTexture("Interface\\Buttons\\ButtonHilight-Square")
        local checked = button:GetCheckedTexture()
        if checked and checked.SetBlendMode then checked:SetBlendMode("ADD") end
        button:SetID(i)
        button:SetScript("OnClick", function(self)
            tab = TAB_KEYS[self:GetID()]
            SK.Track("codex.tab." .. tostring(tab))
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
        MakeTab(3, "Interface\\Icons\\INV_Jewelry_Necklace_07", L["Book rewards"]),
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
    local found = (entry.found and not entry.handed) and ("  |cff66bbff" .. L["you found it"] .. "|r") or ""
    row.label:SetText(mark .. name .. found)
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
        SK.Track("codex.waypoint")
        if SK.SetWaypoint and SK.SetWaypoint(spot.map, spot.x / 100, spot.y / 100, spot.name) then
            SK.Print(L["waypoint set: "] .. spot.name)
        end
    end
end

function SK.RefreshGuide()
    if not (window and window:IsShown()) then return end
    -- The picked tab glows.
    window.scrollsTab:SetChecked(tab == "scrolls")
    window.booksTab:SetChecked(tab == "books")
    window.tabs[3]:SetChecked(tab == "rewards")
    if tab == "rewards" then
        local handed = SK.BookProgress and SK.BookProgress() or 0
        window.top:SetText(L["Books handed in: %d of %d."]:format(handed or 0, SK.BOOKS_TOTAL or 40))
        window.list:SetRows(RewardRows(), RewardRow, "")
        window.note:SetText(L["The librarians' rewards. Hover an item to see it, Shift-click to link it."])
    elseif tab == "books" then
        local handed, reward = 0, nil
        if SK.BookProgress then handed, reward = SK.BookProgress() end
        local top = L["Books handed in: %d of %d."]:format(handed or 0, SK.BOOKS_TOTAL or 40)
        if reward and SK.BookRewardText then
            top = top .. "  " .. SK.NextRewardText(reward)
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
    if not SK.ModuleOn("Codex") then
        SK.Print(L["%s is turned off. Turn it on in /sk options (Modules)."]:format(L["Codex"]))
        return
    end
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

SK.Listen("BAGS_CHANGED", function() SK.RefreshGuide() end)
SK.Listen("SKILL_CHANGED", function() SK.RefreshGuide() end)
