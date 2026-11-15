-- Scrollkeeper: Modules/Decipher.lua
-- Picks the next scroll to decipher and keeps the luck log.
--
-- The addon never casts anything by itself. The button in UI/Panel.lua
-- is a normal "secure" button: one click from you, one cast.

local _, SK = ...

------------------------------------------------------------------------
-- Which scroll is next
------------------------------------------------------------------------

-- Returns: next scroll you can read (or nil), how many you can read,
-- how many are too hard for your current skill.
function SK.NextDecipherable()
    local skill = SK.GetComprehension().effective
    local nextScroll, readable, tooHard = nil, 0, 0
    for _, scroll in ipairs(SK.bags.untranslated) do
        if scroll.needs <= skill then
            readable = readable + 1
            nextScroll = nextScroll or scroll
        else
            tooHard = tooHard + 1
        end
    end
    return nextScroll, readable, tooHard
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

    if db.announce then
        local skillNow = SK.GetComprehension().rank
        local skillText = ""
        if skillNow > entry.skillBefore then
            skillText = (" |cff40ff40(skill %d > %d)|r"):format(entry.skillBefore, skillNow)
        end
        SK.Print("deciphered: " .. result .. skillText)
    end
    SK.Send("LOG_CHANGED")
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
    if name then pending.result = name end
    if pending.tier and pending.result then Finish() end
end)

-- Print the luck log to chat.
function SK.PrintLog()
    local db = SK.db
    if (db.deciphered or 0) == 0 then
        SK.Print("no scrolls deciphered yet.")
        return
    end
    SK.Print(("%d scrolls deciphered so far:"):format(db.deciphered))
    for _, tier in ipairs(SK.TIERS) do
        local results = db.results[tier]
        if results then
            local total, rows = 0, {}
            for name, count in pairs(results) do
                total = total + count
                table.insert(rows, { name = name, count = count })
            end
            table.sort(rows, function(a, b) return a.count > b.count end)
            print(("  |cffffd100Comprehension %d scrolls|r"):format(tier))
            for _, row in ipairs(rows) do
                print(("    %s: %d (%d%%)"):format(row.name, row.count, math.floor(row.count / total * 100 + 0.5)))
            end
        end
    end
end
