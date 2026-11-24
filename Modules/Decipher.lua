-- Scrollkeeper: Modules/Decipher.lua
-- Picks the next scroll to decipher and keeps the luck log.
--
-- The addon never casts anything by itself. The button in UI/Panel.lua
-- is a normal "secure" button: one click from you, one cast.

local _, SK = ...
local L = SK.L

------------------------------------------------------------------------
-- Which scroll is next
------------------------------------------------------------------------

-- Returns: next scroll to decipher (or nil), how many you can read,
-- how many are too hard, and how many of the readable ones can still
-- raise your skill.
--
-- Order: scrolls that can still give a skill-up come first, easiest tier
-- first, because easy scrolls are the next to stop giving points. Scrolls
-- that can't raise your skill come last; they are still worth reading for
-- what they turn into.
local CHANCE_ORDER = { orange = 0, yellow = 1, green = 2, gray = 100 }

function SK.NextDecipherable()
    local skill = SK.GetComprehension()
    local best, bestRank
    local readable, tooHard, skillUps = 0, 0, 0
    for _, scroll in ipairs(SK.bags.untranslated) do
        if scroll.needs <= skill.effective then
            readable = readable + 1
            local chance = SK.SkillUpChance(scroll.needs, skill.rank)
            local gives = not chance or chance.gives
            if gives then skillUps = skillUps + 1 end
            -- Lower rank = deciphered sooner: the best skill-up chance first
            -- (orange, then yellow, green, gray), and the lower tier between
            -- two of the same color. So at 74 skill a tier 50 (orange) goes
            -- before a tier 15 (green).
            local rank = (CHANCE_ORDER[chance and chance.key or "orange"] or 3) * 1000 + scroll.needs
            if not bestRank or rank < bestRank then best, bestRank = scroll, rank end
        else
            tooHard = tooHard + 1
        end
    end
    return best, readable, tooHard, skillUps
end

------------------------------------------------------------------------
-- Luck log
-- What the game does when you decipher (seen with /sk eventlog):
--   1. the spellbook spell starts a 4 second cast
--   2. the cast finishes and chat says "You receive item: [Scroll of ...]"
--   3. one bag update removes the untranslated scroll
--   4. a second bag update adds the new scroll
-- So the tier comes from the bag update (which untranslated scroll went
-- away) and the result comes from the loot message.
------------------------------------------------------------------------

-- How long after the cast finishes to wait for the bag update and the loot
-- message before saving anyway.
local WAIT_SECONDS = 6
local pending   -- { at, tier, guessTier, result, skillBefore } while a decipher is being recorded

local function Finish()
    local entry = pending
    pending = nil
    if not entry then return end
    -- The bag update didn't say which scroll went away in time: go by the
    -- scroll the Decipher button was pointed at when the cast started.
    entry.tier = entry.tier or entry.guessTier
    if not entry.tier then return end

    local db = SK.db
    local result = entry.result or "unknown"
    db.deciphered = (db.deciphered or 0) + 1
    db.results[entry.tier] = db.results[entry.tier] or {}
    db.results[entry.tier][result] = (db.results[entry.tier][result] or 0) + 1

    -- The same count by item ID, which is the same in every language.
    -- This is what gets shared with other players.
    if entry.resultID then
        db.resultsByID = db.resultsByID or {}
        db.resultsByID[entry.tier] = db.resultsByID[entry.tier] or {}
        local byID = db.resultsByID[entry.tier]
        byID[entry.resultID] = (byID[entry.resultID] or 0) + 1
        db.itemNames = db.itemNames or {}
        db.itemNames[entry.resultID] = result
    end

    -- Remember whether it raised the skill, by tier and color, so the
    -- skill-up guesses can be checked against what really happens.
    local skillNow = SK.GetComprehension().rank
    local rose = skillNow > entry.skillBefore
    local chance = SK.SkillUpChance(entry.tier, entry.skillBefore)
    if chance then
        db.skillups = db.skillups or {}
        local key = entry.tier .. " " .. chance.key
        local seen = db.skillups[key] or { tries = 0, ups = 0 }
        seen.tries = seen.tries + 1
        if rose then seen.ups = seen.ups + 1 end
        seen.lastSkill = entry.skillBefore
        db.skillups[key] = seen
    end

    if db.announce then
        local skillText
        if rose then
            skillText = L[" |cff40ff40(skill %d > %d)|r"]:format(entry.skillBefore, skillNow)
        else
            skillText = L[" |cff808080(no skill-up)|r"]
        end
        local line = L["deciphered: "] .. SK.ScrollLink(entry.resultID, result) .. skillText
        -- What the Scroll Bag makes of it: "extra, keeping 1", "set aside,
        -- no sword". A moment later, once the new scroll is in your bags.
        if db.bagChatStatus ~= false and SK.ModuleOn("Bag") and entry.resultID and SK.StashNote and SK.IsMageScroll(entry.resultID) then
            local id = entry.resultID
            C_Timer.After(0.6, function()
                local note = SK.StashNote(id)
                SK.Print(line .. (note and ("  ·  " .. note) or ""))
            end)
        else
            SK.Print(line)
        end
    end
    SK.Send("DECIPHERED", entry.tier, entry.resultID)
    SK.Send("LOG_CHANGED")
    SK.Send("MY_DATA_CHANGED")
end

-- Clicking Decipher: the instant spellbook spell. Remember which scroll it
-- was pointed at (the next one to decipher), in case the bag update is late.
local aimedTier, skillAtClick
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or spellID ~= SK.SPELL_COMPREHEND_SCROLL then return end
    local scroll = SK.NextDecipherable()
    aimedTier = scroll and scroll.needs or nil
    skillAtClick = SK.GetComprehension().rank   -- before any skill-up from this one
end)

-- The 4 second cast finished: the scroll is read, start recording.
-- (Not when the instant spell fires: then the wait ran out right as the
-- cast finished, before the bag update, and the decipher was lost.)
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or spellID ~= SK.SPELL_COMPREHEND_CAST then return end
    if pending then return end
    pending = { at = GetTime(), skillBefore = skillAtClick or SK.GetComprehension().rank, guessTier = aimedTier }
    aimedTier, skillAtClick = nil, nil
    C_Timer.After(WAIT_SECONDS, function() if pending then Finish() end end)
end)

-- Without the spell events (Forever doesn't always send them to addons),
-- a decipher still leaves two traces a moment apart:
--   an untranslated scroll leaves your bags, and
--   chat says "You receive item: [Scroll of ...]".
-- Both together = a decipher. A scroll leaving with no loot message
-- (mailed, traded, destroyed) is ignored.
local PAIR_SECONDS = 4
local recentLoot   -- { name, id, at }: a loot message with no decipher to go with yet
local lastRank     -- your skill at the bag update before this one

-- The untranslated scroll that left the bags, if one did.
local function Vanished(now, before)
    local stillThere = {}
    for _, scroll in ipairs(now.untranslated) do
        stillThere[scroll.bag .. ":" .. scroll.slot] = true
    end
    for _, scroll in ipairs(before.untranslated) do
        if not stillThere[scroll.bag .. ":" .. scroll.slot] then return scroll end
    end
end

-- "You receive item: ..." / "You receive loot: ..." (yours, not a party member's).
local function MyLootPrefixes()
    local list = {}
    -- (pairs, not ipairs: a missing one would stop ipairs early)
    for _, template in pairs({ LOOT_ITEM_PUSHED_SELF, LOOT_ITEM_SELF, LOOT_ITEM_CREATED_SELF }) do
        local prefix = type(template) == "string" and template:match("^(.-)%%s")
        if prefix and prefix ~= "" then list[#list + 1] = prefix end
    end
    return list
end

SK.Listen("BAGS_CHANGED", function(now, before)
    local rankNow = SK.GetComprehension().rank
    local gone = Vanished(now, before)
    if pending then
        -- The spell events did fire: this tells which tier was read.
        if not pending.tier and gone then pending.tier = gone.needs end
        if pending.tier and pending.result then Finish() end
    elseif gone and SK.isMage then
        local skillBefore = lastRank or rankNow
        if recentLoot and GetTime() - recentLoot.at <= PAIR_SECONDS then
            pending = { at = GetTime(), tier = gone.needs, result = recentLoot.name, resultID = recentLoot.id,
                        skillBefore = skillBefore }
            recentLoot = nil
            Finish()
        else
            -- Wait a moment for the loot message; none = it wasn't a decipher.
            local mine = { at = GetTime(), tier = gone.needs, skillBefore = skillBefore, fromBags = true }
            pending = mine
            C_Timer.After(PAIR_SECONDS, function() if pending == mine and not mine.result then pending = nil end end)
        end
    end
    lastRank = rankNow
end)

-- What it became: the item in the "You receive item" chat message.
SK.On("CHAT_MSG_LOOT", function(message)
    if type(message) ~= "string" then return end
    local name = message:match("|h%[(.-)%]|h")
    if not name then return end
    local id = tonumber(message:match("item:(%d+)"))
    -- Looting an untranslated scroll isn't a decipher result (deciphers
    -- never give one), so don't pair it with a scroll you just used.
    local link = message:match("(|c.-|h|r)")
    if link and SK.UntranslatedTier and SK.UntranslatedTier(link) then return end
    -- Only scrolls come out of a decipher; other loot (a recipe, water...)
    -- that lands at the same moment isn't the result.
    if id and SK.IsDecipherResult and not SK.IsDecipherResult(id, name) then return end
    if pending and not pending.result then
        pending.result, pending.resultID = name, id
        if pending.tier then Finish() end
        return
    end
    -- No decipher seen yet (the loot message can come before the bag
    -- update): keep it for a few seconds, if it's your own loot.
    for _, prefix in ipairs(MyLootPrefixes()) do
        if message:sub(1, #prefix) == prefix then
            recentLoot = { name = name, id = id, at = GetTime() }
            return
        end
    end
end)

local function PrintSkillUps()
    local seen = SK.db.skillups
    if not seen or not next(seen) then return end
    print(L["  |cffffd100Skill-ups seen|r (tier, color: raised / read)"])
    local keys = {}
    for key in pairs(seen) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local ta, tb = tonumber(a:match("^%d+")), tonumber(b:match("^%d+"))
        if ta ~= tb then return ta < tb end
        return a < b
    end)
    for _, key in ipairs(keys) do
        local row = seen[key]
        print(("    %s: %d / %d"):format(key, row.ups, row.tries))
    end
end

-- Print the luck log to chat.
function SK.PrintLog()
    local db = SK.db
    if (db.deciphered or 0) == 0 then
        SK.Print(L["no scrolls deciphered yet."])
        return
    end
    SK.Print(L["%d scrolls deciphered so far:"]:format(db.deciphered))
    for _, tier in ipairs(SK.TIERS) do
        local results = db.results[tier]
        if results then
            local total, rows = 0, {}
            for name, count in pairs(results) do
                total = total + count
                table.insert(rows, { name = name, count = count })
            end
            table.sort(rows, function(a, b) return a.count > b.count end)
            print(L["  |cffffd100Comprehension %d scrolls|r"]:format(tier))
            for _, row in ipairs(rows) do
                print(("    %s: %d (%d%%)"):format(SK.ScrollLink(nil, row.name), row.count,
                    math.floor(row.count / total * 100 + 0.5)))
            end
        end
    end
    PrintSkillUps()
end
