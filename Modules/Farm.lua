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

-- Zones with the most scroll drops (yours and everyone's): list of { name, count }.
local function BestZones(limit)
    local byMap = {}
    local function Add(drops)
        for mapID, cells in pairs(drops or {}) do
            for _, count in pairs(cells) do byMap[mapID] = (byMap[mapID] or 0) + count end
        end
    end
    Add(SK.db.drops)
    for _, entry in pairs(SK.db.community or {}) do Add(entry.drops) end
    for _, entry in ipairs(SK.ShippedCommunity and SK.ShippedCommunity() or {}) do Add(entry.drops) end
    local list = {}
    for mapID, count in pairs(byMap) do
        local info = C_Map and C_Map.GetMapInfo and SK.Try(C_Map.GetMapInfo, tonumber(mapID))
        list[#list + 1] = { name = info and info.name or ("map " .. mapID), count = count }
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    while #list > (limit or 3) do table.remove(list) end
    return list
end

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
    local best, bestRate, real
    for _, tier in ipairs(SK.TIERS) do
        if skill.effective >= tier then
            local chance = SK.SkillUpChance(tier, skill.rank)
            if chance and chance.gives then
                local rate, isReal = RealRate(tier, chance.key)
                rate = rate or GUESS[chance.key] or 0.25
                if not bestRate or rate > bestRate then best, bestRate, real = { tier = tier, chance = chance }, rate, isReal end
            end
        end
    end
    if not best then return nil, L["none of the tiers you can read give skill-ups any more"] end

    local plan = {
        goal = goal, unlocks = goal ~= skill.max, needed = needed,
        tier = best.tier, chance = best.chance, rate = bestRate, realRate = real,
        scrolls = math.ceil(needed / math.max(bestRate, 0.05)),
        zones = BestZones(3),
    }
    local farm = SK.db.farm
    if farm and farm.seconds >= 1800 and farm.looted > 0 then
        plan.perHour = farm.looted / (farm.seconds / 3600)
        plan.hours = plan.scrolls / plan.perHour
    end
    return plan
end

-- The plan in a few lines of text (chat, tooltips).
function SK.FarmPlanLines()
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
    if #plan.zones > 0 then
        local names = {}
        for _, zone in ipairs(plan.zones) do names[#names + 1] = ("%s (%d)"):format(zone.name, zone.count) end
        lines[#lines + 1] = L["Most scrolls found in: "] .. table.concat(names, ", ") .. "."
    end
    return lines, plan
end
