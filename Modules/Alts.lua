-- Scrollkeeper: Modules/Alts.lua
-- Your own mages, remembered across your account, so your other
-- characters can help them.
--
-- Every time you play a mage, it saves its skill, level and Study timer
-- in SK.db.mages. On any other character (a rogue alt, another mage)
-- Scrollkeeper can then say "your mage Naage can read this scroll" and
-- show when each mage's Study is ready.

local _, SK = ...

-- "Naage-Forever": this character's key in SK.db.mages.
function SK.CharKey()
    local name, realm = UnitName("player"), GetRealmName and GetRealmName() or ""
    return (name or "?") .. "-" .. (realm or "")
end

-- This character's saved entry, if it's a mage.
function SK.MyMage()
    if not SK.isMage then return nil end
    SK.db.mages = SK.db.mages or {}
    local key = SK.CharKey()
    local entry = SK.db.mages[key]
    if not entry then
        entry = { name = UnitName("player") }
        -- The Study timer used to be shared by the whole account. The
        -- first mage to log in after the update keeps it.
        if (SK.db.studyReadyAt or 0) > 0 then
            entry.studyReadyAt = SK.db.studyReadyAt
            SK.db.studyReadyAt = 0
        end
        SK.db.mages[key] = entry
    end
    return entry
end

-- Save this mage's current state.
local function Save()
    local entry = SK.MyMage()
    if not entry then return end
    local skill = SK.GetComprehension()
    entry.name = UnitName("player")
    entry.level = UnitLevel("player")
    entry.skill = skill.rank
    entry.max = skill.max
    entry.knowsStudy = SK.KnowsStudy() and true or false
    entry.seen = time()
end

SK.Listen("READY", Save)
SK.Listen("SKILL_CHANGED", Save)
SK.Listen("STUDY_CHANGED", Save)
SK.On("PLAYER_LEVEL_UP", function() C_Timer.After(1, Save) end)

-- Your other mages: list of { key, name, level, skill, max, studyLeft },
-- most skilled first. Leaves out the character you're playing.
function SK.MyOtherMages()
    local list, me = {}, SK.CharKey()
    for key, entry in pairs(SK.db.mages or {}) do
        if key ~= me and entry.skill then
            local left = (entry.studyReadyAt or 0) - time()
            list[#list + 1] = {
                key = key, name = entry.name or key, level = entry.level or 0,
                skill = entry.skill, max = entry.max or 0, knowsStudy = entry.knowsStudy,
                studyLeft = left > 0 and left or 0,
            }
        end
    end
    table.sort(list, function(a, b) return a.skill > b.skill end)
    return list
end

-- Which of your other mages can read a scroll that needs `needs`, and
-- whether it's a skill-up for them: list of { name, skill, chance }.
function SK.MyMagesFor(needs)
    local list = {}
    for _, mage in ipairs(SK.MyOtherMages()) do
        if mage.skill >= needs then
            list[#list + 1] = { name = mage.name, skill = mage.skill, chance = SK.SkillUpChance(needs, mage.skill) }
        end
    end
    -- Skill-ups first.
    table.sort(list, function(a, b)
        local ga, gb = a.chance and a.chance.gives or false, b.chance and b.chance.gives or false
        if ga ~= gb then return ga end
        return a.skill < b.skill
    end)
    return list
end
