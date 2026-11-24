-- Scrollkeeper: Modules/Auction.lua
-- Scroll prices from the auction house, gathered by Scrollkeeper itself.
--
--   While the auction house is open, any mage scroll that shows up in
--   your searches gets its lowest price saved (untranslated scrolls,
--   mage-only scrolls, and what deciphers turn into; not ordinary
--   scrolls like Scroll of Agility). The "Scan scrolls" button on
--   the auction house looks up every scroll at once.
--
-- Saved in SK.db.ahPrices[itemID] = { price = copper each, count, at = time() }.
-- Tooltips then show "Auction house: 1g 20s (2 hours ago)".
-- Works with both auction house styles (the modern one and the classic list).

local _, SK = ...
local L = SK.L

local MAX_PAGES = 10

local function IsScroll(itemID)
    if not (itemID and C_Item and C_Item.GetItemInfoInstant) then return false end
    local _, _, _, _, _, classID, subClassID = SK.Try(C_Item.GetItemInfoInstant, itemID)
    return classID == SK.ITEM_CLASS_CONSUMABLE and subClassID == SK.ITEM_SUBCLASS_SCROLL
end

-- Is this scroll one we care about? Untranslated mage scrolls, mage-only
-- scrolls, and anything a decipher can turn into (like Scroll of Strength).
-- Ordinary scrolls anyone uses (Scroll of Agility II...) are left out.
local relevant = {}
local function DecipherResult(itemID, name)
    for _, results in pairs(SK.db.resultsByID or {}) do
        if results[itemID] then return true end
    end
    for _, entry in pairs(SK.db.community or {}) do
        for _, results in pairs(entry.results or {}) do
            if results[itemID] then return true end
        end
    end
    for _, entry in ipairs(SK.ShippedCommunity and SK.ShippedCommunity() or {}) do
        for _, results in pairs(entry.results or {}) do
            if results[itemID] then return true end
        end
    end
    for _, names in pairs(SK.TIER_RESULTS or {}) do
        for _, known in ipairs(names) do
            if name and (known == name or ("Scroll of " .. known) == name) then return true end
        end
    end
    return false
end

-- Comprehension an untranslated scroll needs, read while the auction house
-- has it loaded, and saved with its price (the plan can't always read
-- tooltips after a /reload, the game hasn't loaded those items yet).
local function ReadNeeds(itemID)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local data = SK.Try(C_TooltipInfo.GetItemByID, itemID)
    return type(data) == "table" and SK.RequirementFromLines(data.lines) or nil
end
local function SaveNeeds(entry, itemID, old)
    entry.needs = ReadNeeds(itemID) or (old and old.needs) or nil
    return entry
end

local function Relevant(itemID)
    if relevant[itemID] ~= nil then return relevant[itemID] end
    local name = C_Item and C_Item.GetItemNameByID and SK.Try(C_Item.GetItemNameByID, itemID)
    if type(name) ~= "string" then return false end      -- not loaded yet: skip this time
    local yes = false
    -- Untranslated scrolls: "Scroll: ZIMBO" (with any language's colon).
    if name:find("^[^%s]+%s?[:：]") then yes = true end
    -- The game's own tooltip, where the client has it.
    if not yes and C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local data = SK.Try(C_TooltipInfo.GetItemByID, itemID)
        if type(data) == "table" and type(data.lines) == "table" then
            yes = SK.RequirementFromLines(data.lines) ~= nil
            local mage = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.MAGE) or "Mage"
            local allowed = (ITEM_CLASSES_ALLOWED or "Classes: %s"):match("^(.-)%%s") or "Classes: "
            for _, line in ipairs(data.lines) do
                local text = line.leftText
                if type(text) == "string" and text:sub(1, #allowed) == allowed and text:find(mage, 1, true) then yes = true end
            end
        end
    end
    -- Anything a decipher turns into (mage scrolls, and the odd Scroll of Strength).
    yes = yes or DecipherResult(itemID, name)
    relevant[itemID] = yes
    return yes
end

-- Remember a price from the browse list: the lowest buyout for a scroll
-- (the browse list never shows bids). A new scan replaces old prices.
local scanStarted = 0
local scanning = false
local function Record(itemID, price)
    if not (itemID and price and price > 0 and IsScroll(itemID) and Relevant(itemID)) then return end
    SK.db.ahPrices = SK.db.ahPrices or {}
    local known = SK.db.ahPrices[itemID]
    if known and known.at >= scanStarted and known.price < price then price = known.price end
    SK.db.ahPrices[itemID] = SaveNeeds({ price = math.floor(price), at = time() }, itemID, known)
end

-- Our own price for an item: copper each and when we saw it, or nil.
function SK.AuctionPrice(itemID)
    local known = SK.db and SK.db.ahPrices and SK.db.ahPrices[itemID]
    if known then return known.price, known.at end
end

-- "2 hours ago"
function SK.TimeAgo(at)
    local seconds = math.max(0, time() - (at or 0))
    if seconds < 3600 then return L["%d min ago"]:format(math.max(1, math.floor(seconds / 60))) end
    if seconds < 86400 then return L["%d |4hour:hours; ago"]:format(math.floor(seconds / 3600)) end
    return L["%d |4day:days; ago"]:format(math.floor(seconds / 86400))
end

------------------------------------------------------------------------
-- The modern auction house (C_AuctionHouse)
------------------------------------------------------------------------

local pages = 0

-- The auction house drops requests sent while it's still busy with the
-- last one (its "throttle"). Wait until it's ready, then send. Gives up
-- after about 10 seconds and calls giveUp instead, if there is one.
local function WhenReady(send, giveUp, tries)
    tries = tries or 40
    local ready = not (C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady)
        or C_AuctionHouse.IsThrottledMessageSystemReady()
    if ready then send() return end
    if tries <= 0 then
        if giveUp then giveUp() end
        return
    end
    C_Timer.After(0.25, function() WhenReady(send, giveUp, tries - 1) end)
end

local function ReadBrowseResults()
    local results = C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults() or {}
    for _, result in ipairs(results) do
        local key = result.itemKey
        Record(key and key.itemID, result.minPrice)
    end
end

local function FinishScan()
    if not scanning then return end
    scanning = false
    local count = 0
    for _, known in pairs(SK.db.ahPrices or {}) do
        if known.at >= scanStarted then count = count + 1 end
    end
    SK.Print(L["auction house: saved prices for %d |4scroll:scrolls;."]:format(count))
    SK.db.ahLastScan = scanStarted   -- the plan only goes by prices from this scan on
    SK.Send("PRICES_CHANGED")
end

local function MoreOrDone()
    if not scanning then return end
    local full = C_AuctionHouse.HasFullBrowseResults and C_AuctionHouse.HasFullBrowseResults()
    if full or pages >= MAX_PAGES then
        FinishScan()
    else
        pages = pages + 1
        WhenReady(function() C_AuctionHouse.RequestMoreBrowseResults() end, FinishScan)
    end
end

SK.On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function() ReadBrowseResults() MoreOrDone() end)
SK.On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function() ReadBrowseResults() MoreOrDone() end)

local function ScanModern()
    if not (C_AuctionHouse and C_AuctionHouse.SendBrowseQuery) then return false end
    scanStarted, pages, scanning = time(), 0, true
    local query = {
        searchString = "",
        sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } },
        filters = {},
        itemClassFilters = { { classID = SK.ITEM_CLASS_CONSUMABLE, subClassID = SK.ITEM_SUBCLASS_SCROLL } },
    }
    WhenReady(function() C_AuctionHouse.SendBrowseQuery(query) end, FinishScan)
    C_Timer.After(30, FinishScan)   -- in case the results never finish
    return true
end

------------------------------------------------------------------------
-- The classic auction house (QueryAuctionItems)
------------------------------------------------------------------------

SK.On("AUCTION_ITEM_LIST_UPDATE", function()
    if not (GetNumAuctionItems and GetAuctionItemInfo) then return end
    local shown = GetNumAuctionItems("list")
    for i = 1, shown do
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
        if buyout and buyout > 0 and count and count > 0 then Record(itemID, buyout / count) end
    end
    if scanning then
        scanning = false
        SK.Print(L["auction house: saved prices from %d listings on this page."]:format(shown))
        SK.Send("PRICES_CHANGED")
    end
end)

local function ScanClassic()
    if not QueryAuctionItems then return false end
    if CanSendAuctionQuery and not CanSendAuctionQuery() then
        SK.Print(L["the auction house needs a moment, try again in a few seconds."])
        return true
    end
    scanStarted, scanning = time(), true
    QueryAuctionItems("Scroll", nil, nil, 0)
    return true
end

------------------------------------------------------------------------
-- Looking a scroll up, and the "Scan scrolls" / "Plan" buttons
------------------------------------------------------------------------

-- Type the scroll's name in the auction house search box and search,
-- same as you would. Never buys anything.
function SK.ShowOnAuctionHouse(itemID)
    local name = C_Item and C_Item.GetItemNameByID and SK.Try(C_Item.GetItemNameByID, itemID)
    if not name then return end
    local modern = _G.AuctionHouseFrame
    if modern and modern:IsShown() then
        local bar = modern.SearchBar
        if not (bar and bar.SearchBox and type(bar.StartSearch) == "function") then return end
        bar.SearchBox:SetText(name)
        WhenReady(function() SK.Try(bar.StartSearch, bar) end)
        return
    end
    if _G.AuctionFrame and _G.AuctionFrame:IsShown() and _G.BrowseName then
        _G.BrowseName:SetText(name)
        if _G.AuctionFrameBrowse_Search then SK.Try(_G.AuctionFrameBrowse_Search) end
        return
    end
    SK.Print(L["open the auction house first."])
end

function SK.ScanAuctionScrolls()
    if not (ScanModern() or ScanClassic()) then
        SK.Print(L["open the auction house first."])
    end
end

local button
local function ShowButton()
    local parent = _G.AuctionHouseFrame or _G.AuctionFrame
    if not parent then return end
    if not button then
        -- On the modern auction house the buttons belong to the category list
        -- on the Buy tab, so they only show there (not on Sell, Auctions or
        -- other addons' tabs like Auctionator's) and sit inside that list.
        local categories = parent.CategoriesList
        local host = (categories and categories.GetWidth) and categories or parent
        button = CreateFrame("Button", "ScrollkeeperScanButton", host, "UIPanelButtonTemplate")
        button:SetSize(110, 22)
        button:SetText(L["Scan scrolls"])
        if host == categories then
            -- Bottom of the category list, same width as its buttons
            -- (its scrollbar is on the right).
            button:SetHeight(20)
            button:SetPoint("BOTTOMLEFT", categories, "BOTTOMLEFT", 6, 12)
            button:SetPoint("BOTTOMRIGHT", categories, "BOTTOMRIGHT", -26, 12)
        else
            button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -60, -40)
        end
        button:SetFrameLevel((host:GetFrameLevel() or 0) + 10)
        button:SetScript("OnClick", SK.ScanAuctionScrolls)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(L["Scrollkeeper"])
            GameTooltip:AddLine(L["Look up every scroll on the auction house and save the prices for your tooltips."], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Plan, just above it: the Plan window docked beside the auction house.
        local plan = CreateFrame("Button", "ScrollkeeperAHPlanButton", host, "UIPanelButtonTemplate")
        plan:SetHeight(button:GetHeight())
        plan:SetFrameLevel(button:GetFrameLevel())
        button.planHost = host
        plan:SetText(L["Plan"])
        plan:SetScript("OnClick", function() if SK.TogglePlan then SK.TogglePlan(parent) end end)
        plan:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(L["Scrollkeeper"])
            GameTooltip:AddLine(L["The scrolls here you'd still level from, and what they cost."], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        plan:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button.plan = plan
    end
    -- With Auctionator or TSM their prices are used, so no scan button.
    local otherAddon = SK.HasAuctionAddon and SK.HasAuctionAddon()
    local showScan = SK.db.ahScanButton ~= false and not otherAddon
    local showPlan = SK.db.ahScanButton ~= false and SK.isMage and SK.ModuleOn("Plan") and true or false
    button:SetShown(showScan)
    button.plan:SetShown(showPlan)
    -- Plan sits on top of Scan scrolls, or in its place when that's hidden.
    button.plan:ClearAllPoints()
    if showScan then
        button.plan:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
        button.plan:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 2)
    else
        for i = 1, button:GetNumPoints() do button.plan:SetPoint(button:GetPoint(i)) end
    end
end

SK.On("AUCTION_HOUSE_SHOW", function() C_Timer.After(0.2, ShowButton) end)
