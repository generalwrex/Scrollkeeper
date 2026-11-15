-- Scrollkeeper: Modules/Study.lua
-- Tracks the one-hour Study cooldown, and whether you are standing
-- somewhere Study works.
--
-- The ready time is saved as a clock time, so it stays right through
-- reloads and logouts.

local _, SK = ...

-- Seconds until Study is ready. 0 means ready now.
function SK.StudySecondsLeft()
    local readyAt = SK.db and SK.db.studyReadyAt or 0
    local left = readyAt - time()
    return left > 0 and left or 0
end

function SK.KnowsStudy()
    return C_SpellBook and SK.Try(C_SpellBook.IsSpellKnown, SK.SPELL_STUDY) or
        (IsPlayerSpell and SK.Try(IsPlayerSpell, SK.SPELL_STUDY)) or false
end

-- "42m", "3m 10s", "Ready"
function SK.FormatStudyTime(seconds)
    if seconds <= 0 then return "Ready" end
    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        if minutes >= 5 then return minutes .. "m" end
        return ("%dm %02ds"):format(minutes, seconds % 60)
    end
    return seconds .. "s"
end

SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or spellID ~= SK.SPELL_STUDY then return end
    SK.db.studyReadyAt = time() + SK.STUDY_COOLDOWN_SECONDS
    SK.Send("STUDY_CHANGED")
end)

------------------------------------------------------------------------
-- Libraries
-- Study only works in a library. The game doesn't say which places
-- count, so the addon starts from places guides list, and learns: every
-- time Study succeeds, the spot you stood in is remembered as a library.
------------------------------------------------------------------------

-- Subzone names from guides (English client). Learned places are added
-- to SK.db.libraries and work in any language.
local KNOWN_LIBRARIES = {
    ["The Magic Quarter"] = true,   -- Undercity
    ["Magic Quarter"] = true,
    ["Wizard's Sanctum"] = true,    -- Stormwind Mage Quarter
    ["The Mage Tower"] = true,
    ["Royal Library"] = true,       -- Stormwind Keep
    ["Great Library"] = true,       -- Dalaran
}

local function CurrentPlace()
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local zone = GetRealZoneText and GetRealZoneText() or ""
    return zone, sub
end

-- true if you are in a known or learned library, plus the place name.
function SK.InLibrary()
    local zone, sub = CurrentPlace()
    local learned = SK.db and SK.db.libraries or {}
    if sub ~= "" and (KNOWN_LIBRARIES[sub] or learned[zone .. " / " .. sub]) then
        return true, sub
    end
    return false, sub ~= "" and sub or zone
end

SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or spellID ~= SK.SPELL_STUDY then return end
    local zone, sub = CurrentPlace()
    if sub == "" then return end
    SK.db.libraries = SK.db.libraries or {}
    local key = zone .. " / " .. sub
    if not SK.db.libraries[key] then
        SK.db.libraries[key] = true
        SK.Print("learned a new library: " .. sub)
    end
end)

-- Tell the panel when you move between areas.
local function Moved() SK.Send("PLACE_CHANGED") end
SK.On("ZONE_CHANGED", Moved)
SK.On("ZONE_CHANGED_INDOORS", Moved)
SK.On("ZONE_CHANGED_NEW_AREA", Moved)
