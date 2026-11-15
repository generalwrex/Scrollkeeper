-- Scrollkeeper: Modules/Study.lua
-- Tracks the one-hour Study cooldown.
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
