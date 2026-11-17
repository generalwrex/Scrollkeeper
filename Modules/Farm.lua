-- Scrollkeeper: Modules/Farm.lua
-- The farming planner: how far to your next goal, and how long it'll take.
--
--   goal       the next scroll tier you unlock (15, 50, 175), or your cap
--   skill-ups  how many points that is
--   scrolls    about how many scrolls that takes at your skill-up colors
--              (from real skill-up rates when there are enough, yours and
--              everyone's, otherwise a rough guess)
--   time       from how many untranslated scrolls you find per hour
--   where      the zones with the most scroll drops reported
--
-- Time is counted while you're logged in on a mage, in SK.db.farm.

local _, SK = ...
local L = SK.L

-- Rough skill-up chance per scroll by color, until there's real data.
local GUESS = { orange = 1, yellow = 0.75, green = 0.25, gray = 0 }
local MIN_TRIES = 10

-- Count play time and scrolls found.
SK.Listen("READY", function()
    if not SK.isMage then return end
    SK.db.farm = SK.db.farm or { seconds = 0, looted = 0 }
    if C_Timer.NewTicker then
        C_Timer.NewTicker(60, function()
            if not (UnitIsAFK and UnitIsAFK("player")) then SK.db.farm.seconds = SK.db.farm.seconds + 60 end
        end)
    end
end)
SK.Listen("SCROLL_LOOTED", function(count)
    if not SK.db.farm then return end
    SK.db.farm.looted = SK.db.farm.looted + (count or 1)
end)

-- Real skill-up rate for a tier and color: ups / tries from you and everyone.
local function RealRate(tier, color)
    local ups, tries = 0, 0
    local mine = SK.db.skillups and SK.db.skillups[tier .. " " .. color]
    if mine then ups, tries = ups + mine.ups, tries + mine.tries end
    local function Add(list)
        local seen = list and list[tier] and list[tier][color]
        if seen then ups, tries = ups + (seen[1] or seen.ups or 0), tries + (seen[2] or seen.tries or 0) end
    end
    for _, entry in pairs(SK.db.community or {}) do Add(entry.skillups) end
    for _, entry in ipairs(SK.ShippedCommunity and SK.ShippedCommunity() or {}) do
        local seen = entry.skillups and entry.skillups[tier .. " " .. color]
        if seen then ups, tries = ups + (seen.ups or 0), tries + (seen.tries or 0) end
    end
    if tries >= MIN_TRIES then return ups / tries, true end
    return nil
end

-- Zones with the most scroll drops: list of { mapID, name, count }.
-- No tier: every untranslated scroll, yours and everyone's.
-- A tier: only scrolls of that tier (your own drops, logged since 1.1.4).
local function BestZones(limit, tier)
    local byMap = {}
    if tier then
        for mapID, tiers in pairs(SK.db.dropTiers or {}) do
            if tiers[tier] then byMap[mapID] = tiers[tier] end
        end
    else
        local function Add(drops)
            for mapID, cells in pairs(drops or {}) do
                for _, count in pairs(cells) do byMap[mapID] = (byMap[mapID] or 0) + count end
            end
        end
        Add(SK.db.drops)
        for _, entry in pairs(SK.db.community or {}) do Add(entry.drops) end
        for _, entry in ipairs(SK.ShippedCommunity and SK.ShippedCommunity() or {}) do Add(entry.drops) end
    end
    local list = {}
    for mapID, count in pairs(byMap) do
        local info = C_Map and C_Map.GetMapInfo and SK.Try(C_Map.GetMapInfo, tonumber(mapID))
        list[#list + 1] = { mapID = tonumber(mapID), name = info and info.name or ("map " .. mapID), count = count }
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    while #list > (limit or 3) do table.remove(list) end
    return list
end

-- "1g 20s" with coin icons.
function SK.Money(copper)
    if GetMoneyString then return GetMoneyString(copper) end
    return ("%dg"):format(math.floor(copper / 10000))
end

-- "2s 46c" as short colored text, for tight rows. Copper is left off
-- once there's gold (it hardly matters then).
function SK.ShortMoney(copper)
    copper = math.floor(copper + 0.5)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = "|cffffd700" .. gold .. "g|r" end
    if silver > 0 then parts[#parts + 1] = "|cffc7c7cf" .. silver .. "s|r" end
    if gold == 0 and (rest > 0 or silver == 0) then parts[#parts + 1] = "|cffeda55f" .. rest .. "c|r" end
    return table.concat(parts, " ")
end

-- Chance a scroll of `tier` gives a skill-up at skill `skill`, or nil if
-- it can't (gray). Real rates when there's enough data, else a guess.
local function RateAt(tier, skill)
    local chance = SK.SkillUpChance(tier, skill)
    if not (chance and chance.gives) then return nil end
    return RealRate(tier, chance.key) or GUESS[chance.key] or 0.25
end
SK.SkillUpRateAt = RateAt

-- Comprehension an item needs, from its tooltip (cached), or nil.
-- Only a found requirement is cached: until the game has loaded an item,
-- its tooltip is missing lines, so "nothing found" may just mean "not yet".
local needsCache = {}
local function NeedsOf(itemID)
    if needsCache[itemID] then return needsCache[itemID] end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local data = SK.Try(C_TooltipInfo.GetItemByID, itemID)
    local needs = type(data) == "table" and type(data.lines) == "table" and SK.RequirementFromLines(data.lines) or nil
    if needs then
        needsCache[itemID] = needs
    elseif C_Item and C_Item.RequestLoadItemDataByID then
        SK.Try(C_Item.RequestLoadItemDataByID, itemID)   -- try again on the next refresh
    end
    return needs
end

-- Every untranslated scroll we know of: { [itemID] = needs or false }.
-- From the auction house (only what you browse, or our own scan) and your bags.
local function KnownScrolls()
    local known = {}
    for itemID, entry in pairs(SK.db.ahPrices or {}) do known[itemID] = entry.needs or false end
    for _, scroll in ipairs(SK.bags and SK.bags.untranslated or {}) do
        if scroll.itemID then known[scroll.itemID] = scroll.needs or known[scroll.itemID] or false end
    end
    return known
end

-- The price to show for a scroll. With Auctionator or TSM: theirs (or nil
-- if they don't have one). Without: our own scan's, if it's from the last scan.
local function PriceOf(itemID)
    if SK.HasAuctionAddon and SK.HasAuctionAddon() then
        return SK.AddonAuctionPrice(itemID), nil
    end
    local entry = SK.db.ahPrices and SK.db.ahPrices[itemID]
    if entry and entry.price and (entry.at or 0) >= (SK.db.ahLastScan or 0) then return entry.price, entry.at end
end

-- How many untranslated scrolls (any tier) have a price right now.
function SK.PricedUntranslated()
    local count = 0
    for itemID, needs in pairs(KnownScrolls()) do
        if (needs or NeedsOf(itemID)) and PriceOf(itemID) then count = count + 1 end
    end
    return count
end

-- Untranslated scrolls with a price that you can read and that still give
-- you skill-ups, cheapest first: list of { itemID, price, at, needs, chance }.
function SK.CheapestScrolls(limit)
    local skill = SK.GetComprehension()
    local list = {}
    for itemID, savedNeeds in pairs(KnownScrolls()) do
        local needs = savedNeeds or NeedsOf(itemID)
        local entry = SK.db.ahPrices and SK.db.ahPrices[itemID]
        if needs and entry and not entry.needs then entry.needs = needs end   -- remember it
        if needs and needs <= skill.effective then
            local chance = SK.SkillUpChance(needs, skill.rank)
            local price, at = PriceOf(itemID)
            if chance and chance.gives and price then
                list[#list + 1] = { itemID = itemID, price = price, at = at, needs = needs, chance = chance }
            end
        end
    end
    table.sort(list, function(a, b) return a.price < b.price end)
    while #list > (limit or 3) do table.remove(list) end
    return list
end
SK.BestZones = BestZones

-- The plan: a table, or nil and a reason.
function SK.FarmPlan()
    if not SK.isMage then return nil, L["only mages have a Comprehension skill"] end
    local skill = SK.GetComprehension()
    local goal
    for _, tier in ipairs(SK.TIERS) do
        if tier > skill.rank then goal = tier break end
    end
    if not goal or goal > skill.max then goal = skill.max end
    local needed = goal - skill.rank
    if needed <= 0 then
        return nil, L["you're at your cap (%d). Train Comprehension to go higher."]:format(skill.max)
    end

    -- The best tier you can read right now that still gives skill-ups.
    -- (rates keeps every readable tier's rate, for working out what buying costs.)
    local best, bestRate, real
    local rates = {}
    for _, tier in ipairs(SK.TIERS) do
        if skill.effective >= tier then
            local chance = SK.SkillUpChance(tier, skill.rank)
            if chance and chance.gives then
                local rate, isReal = RealRate(tier, chance.key)
                rate = rate or GUESS[chance.key] or 0.25
                rates[tier] = rate
                if not bestRate or rate > bestRate then best, bestRate, real = { tier = tier, chance = chance }, rate, isReal end
            end
        end
    end
    if not best then return nil, L["none of the tiers you can read give skill-ups any more"] end

    -- How many scrolls to the goal, one skill point at a time (the chance
    -- drops as you level): at each point, the best tier you can read then.
    local expected = 0
    for level = skill.rank, goal - 1 do
        local rate
        for _, tier in ipairs(SK.TIERS) do
            local r = level + skill.bonus >= tier and RateAt(tier, level)
            if r and (not rate or r > rate) then rate = r end
        end
        expected = expected + 1 / math.max(rate or 0.05, 0.05)
    end

    local plan = {
        goal = goal, unlocks = goal ~= skill.max, needed = needed,
        rank = skill.rank, bonus = skill.bonus,
        tier = best.tier, chance = best.chance, rate = bestRate, realRate = real,
        scrolls = math.ceil(expected),
        rates = rates,
        zones = BestZones(3, best.tier),
        zonesTier = best.tier,
    }
    -- No drops of that tier logged yet: fall back to every tier.
    if #plan.zones == 0 then plan.zones, plan.zonesTier = BestZones(3), nil end
    local farm = SK.db.farm
    if farm and farm.seconds >= 1800 and farm.looted > 0 then
        plan.perHour = farm.looted / (farm.seconds / 3600)
        plan.hours = plan.scrolls / plan.perHour
    end
    return plan
end

-- The plan in a few lines of text (the panel's tooltip, the Plan window).
-- noZones = true leaves out the "most scrolls found in" line (the Plan
-- window lists the zones itself).
function SK.FarmPlanLines(noZones)
    local plan, reason = SK.FarmPlan()
    if not plan then return { L["Farming plan: "] .. reason } end
    local lines = {}
    lines[#lines + 1] = plan.unlocks
        and L["Next goal: %d Comprehension (unlocks tier %d scrolls), %d |4skill-up:skill-ups; to go."]:format(plan.goal, plan.goal, plan.needed)
        or L["Next goal: your cap of %d, %d |4skill-up:skill-ups; to go."]:format(plan.goal, plan.needed)
    lines[#lines + 1] = L["Read tier %d scrolls (%s): about %d |4scroll:scrolls;%s."]:format(plan.tier,
        SK.ColoredChance(plan.chance), plan.scrolls, plan.realRate and "" or L[", a rough guess until there's more data"])
    if plan.hours then
        lines[#lines + 1] = L["You find about %.0f scrolls an hour, so roughly %s of farming."]:format(plan.perHour,
            plan.hours < 1 and L["%d minutes"]:format(math.max(1, math.floor(plan.hours * 60))) or L["%.1f hours"]:format(plan.hours))
    else
        lines[#lines + 1] = L["Play a bit more and it'll tell you how long that takes."]
    end
    if not noZones and #plan.zones > 0 then
        local names = {}
        for _, zone in ipairs(plan.zones) do names[#names + 1] = ("%s (%d)"):format(zone.name, zone.count) end
        lines[#lines + 1] = (plan.zonesTier and L["Tier %d scrolls found most in: "]:format(plan.zonesTier)
            or L["Most scrolls found in: "]) .. table.concat(names, ", ") .. "."
    end
    return lines, plan
end
