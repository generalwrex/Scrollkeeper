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
-- When Comprehend Scroll succeeds, compare the bags before and after to
-- see which untranslated scroll went away and what appeared instead.
------------------------------------------------------------------------

local pending   -- { tier = number, skillBefore = number } while waiting for the bags to update

SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or spellID ~= SK.SPELL_COMPREHEND_SCROLL then return end
    pending = { skillBefore = SK.GetComprehension().rank, at = GetTime() }
end)

SK.Listen("BAGS_CHANGED", function(now, before)
    if not pending then return end
    if GetTime() - pending.at > 5 then pending = nil return end

    -- Which untranslated scroll was used up?
    local usedTier
    local stillThere = {}
    for _, scroll in ipairs(now.untranslated) do
        stillThere[scroll.bag .. ":" .. scroll.slot] = true
    end
    for _, scroll in ipairs(before.untranslated) do
        if not stillThere[scroll.bag .. ":" .. scroll.slot] then
            usedTier = scroll.needs
            break
        end
    end
    if not usedTier then return end   -- bags changed for another reason; keep waiting

    -- What appeared?
    local gained = {}
    for itemID, count in pairs(now.counts) do
        local extra = count - (before.counts[itemID] or 0)
        if extra > 0 then table.insert(gained, now.names[itemID] or ("item " .. itemID)) end
    end
    table.sort(gained)

    local db = SK.db
    db.deciphered = (db.deciphered or 0) + 1
    db.results[usedTier] = db.results[usedTier] or {}
    for _, name in ipairs(gained) do
        db.results[usedTier][name] = (db.results[usedTier][name] or 0) + 1
    end

    if db.announce then
        local skillNow = SK.GetComprehension().rank
        local skillText = ""
        if skillNow > pending.skillBefore then
            skillText = (" |cff40ff40(skill %d > %d)|r"):format(pending.skillBefore, skillNow)
        end
        local what = #gained > 0 and table.concat(gained, ", ") or "nothing new in your bags"
        SK.Print("deciphered: " .. what .. skillText)
    end

    pending = nil
    SK.Send("LOG_CHANGED")
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
