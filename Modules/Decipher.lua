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
            -- Lower rank = deciphered sooner.
            local rank = (gives and 0 or 100000) + scroll.needs
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

local WAIT_SECONDS = 4
local pending   -- { at, tier, result, skillBefore } while a decipher is being recorded

local function Finish()
    local entry = pending
    pending = nil
    if not entry or not entry.tier then return end

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
        SK.Print(L["deciphered: "] .. SK.ScrollLink(entry.resultID, result) .. skillText)
    end
    SK.Send("DECIPHERED", entry.tier, entry.resultID)
    SK.Send("LOG_CHANGED")
    SK.Send("MY_DATA_CHANGED")
end

local function IsDecipherSpell(spellID)
    return spellID == SK.SPELL_COMPREHEND_CAST or spellID == SK.SPELL_COMPREHEND_SCROLL
end

-- The cast finished: start recording. The instant spellbook spell also
-- fires this event; starting twice is harmless.
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or not IsDecipherSpell(spellID) then return end
    if pending then return end
    pending = { at = GetTime(), skillBefore = SK.GetComprehension().rank }
    C_Timer.After(WAIT_SECONDS, function() if pending then Finish() end end)
end)

-- Which tier was read: the untranslated scroll that left the bags.
SK.Listen("BAGS_CHANGED", function(now, before)
    if not pending or pending.tier then return end
    local stillThere = {}
    for _, scroll in ipairs(now.untranslated) do
        stillThere[scroll.bag .. ":" .. scroll.slot] = true
    end
    for _, scroll in ipairs(before.untranslated) do
        if not stillThere[scroll.bag .. ":" .. scroll.slot] then
            pending.tier = scroll.needs
            break
        end
    end
    if pending.tier and pending.result then Finish() end
end)

-- What it became: the item in the "You receive item" chat message.
SK.On("CHAT_MSG_LOOT", function(message)
    if not pending or pending.result or type(message) ~= "string" then return end
    local name = message:match("|h%[(.-)%]|h")
    if name then
        pending.result = name
        pending.resultID = tonumber(message:match("item:(%d+)"))
    end
    if pending.tier and pending.result then Finish() end
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
