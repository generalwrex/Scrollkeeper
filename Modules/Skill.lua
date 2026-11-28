-- Scrollkeeper by generalwrex. Created 2026-11-15.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: Modules/Skill.lua
-- Reads the player's Comprehension skill.

local _, SK = ...

-- Returns a table: { known, name, rank, max, bonus, effective }
--   rank       your trained skill
--   bonus      temporary points (for example from a Scroll of Comprehension)
--   effective  rank + bonus, which is what scrolls are checked against
function SK.GetComprehension()
    local result = { known = false, name = "Comprehension", rank = 0, max = 0, bonus = 0, effective = 0 }

    local info = C_SkillInfo and SK.Try(C_SkillInfo.GetSkillLineInfoByID, SK.SKILL_LINE_COMPREHENSION)
    if type(info) ~= "table" then return result end

    if type(info.name) == "string" and info.name ~= "" then result.name = info.name end
    result.rank = tonumber(info.rank) or 0
    result.max = tonumber(info.maxRank) or 0
    result.bonus = (tonumber(info.tempPoints) or 0) + (tonumber(info.modifier) or 0)
    result.effective = result.rank + result.bonus
    -- Non-mages get the skill's name back but no rank.
    result.known = result.max > 0
    return result
end

-- Tell the rest of the addon when the skill changes.
SK.On("SKILL_LINES_CHANGED", function() SK.Send("SKILL_CHANGED") end)
SK.On("PLAYER_LEVEL_UP", function() SK.Send("SKILL_CHANGED") end)
