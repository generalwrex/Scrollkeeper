-- Scrollkeeper: Modules/Backfire.lua
-- Counts how often Comprehend Scroll backfires and turns you into a sheep.
--
-- A backfire: the 4 second cast finishes, you're polymorphed for 8
-- seconds, and the scroll stays in your bags. Scrollkeeper notices the
-- polymorph right after a finished cast and counts it for the tier you
-- were reading (the next scroll the Decipher button would pick).
--
-- Saved in SK.db.backfires[tier] = { b = backfires, t = tries },
-- shared with other Scrollkeeper users and in /sk export.

local _, SK = ...
local L = SK.L

local POLYMORPH_ICON = 136071        -- Spell_Nature_Polymorph
local WINDOW = 3                     -- seconds after the cast to look for it

local watchUntil, watchTier, counted = 0, nil, false

local function Bump(tier, backfired)
    if not tier then return end
    SK.db.backfires = SK.db.backfires or {}
    local seen = SK.db.backfires[tier] or { b = 0, t = 0 }
    seen.t = seen.t + 1
    if backfired then seen.b = seen.b + 1 end
    SK.db.backfires[tier] = seen
    SK.Send("MY_DATA_CHANGED")
    SK.Send("LOG_CHANGED")
end

local polymorphName
local function IsSheep(aura)
    if type(aura) ~= "table" then return false end
    local icon, name = aura.icon, aura.name
    if issecretvalue and (issecretvalue(icon) or issecretvalue(name)) then return false end
    if icon == POLYMORPH_ICON then return true end
    polymorphName = polymorphName or (C_Spell and C_Spell.GetSpellName and SK.Try(C_Spell.GetSpellName, 118)) or "Polymorph"
    return type(name) == "string" and name:find(polymorphName, 1, true) ~= nil
end

local function Polymorphed()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
    for i = 1, 40 do
        local aura = SK.Try(C_UnitAuras.GetAuraDataByIndex, "player", i, "HARMFUL")
        if not aura then return false end
        if IsSheep(aura) then return true end
    end
    return false
end

-- The cast finished: watch for the sheep for a moment.
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or spellID ~= SK.SPELL_COMPREHEND_CAST then return end
    local nextScroll = SK.NextDecipherable and SK.NextDecipherable()
    watchTier = nextScroll and nextScroll.needs
    watchUntil, counted = GetTime() + WINDOW, false
    if Polymorphed() then counted = true Bump(watchTier, true) end
end)

SK.On("UNIT_AURA", function(unit)
    if unit ~= "player" or counted or GetTime() > watchUntil then return end
    if Polymorphed() then
        counted = true
        Bump(watchTier, true)
        SK.Print(L["baa! That one backfired. The scroll is still in your bags."])
    end
end)

-- A read that worked is a try without a backfire.
SK.Listen("DECIPHERED", function(tier)
    if counted then return end
    counted = true
    Bump(tier, false)
end)

-- Your rate and everyone's: backfires, tries (all tiers, or one tier).
function SK.BackfireStats(tier)
    local mine, all = { b = 0, t = 0 }, { b = 0, t = 0 }
    local function Add(into, list)
        for t, seen in pairs(list or {}) do
            if not tier or tonumber(t) == tier then
                into.b = into.b + (seen.b or seen[1] or 0)
                into.t = into.t + (seen.t or seen[2] or 0)
            end
        end
    end
    Add(mine, SK.db.backfires)
    Add(all, SK.db.backfires)
    for _, entry in pairs(SK.db.community or {}) do Add(all, entry.backfires) end
    for _, entry in ipairs(SK.ShippedCommunity and SK.ShippedCommunity() or {}) do Add(all, entry.backfires) end
    return mine, all
end
