-- Scrollkeeper: Modules/Alts.lua
-- Your own mages, remembered across your account, so your other
-- characters can help them.
--
-- Every time you play a mage, it saves its skill, level and Study timer
-- in SK.db.mages. On any other character (a rogue alt, another mage)
-- Scrollkeeper can then say "your mage Naage can read this scroll" and
-- show when each mage's Study is ready.

local _, SK = ...

-- This character's full name. Forever characters have a first name and a
-- surname, and UnitName("player") gives them as two values ("Test", "Sheep").
-- Elsewhere the second value is empty, so this is just the name.
function SK.PlayerFullName()
    local first, last = UnitName("player")
    if type(last) == "string" and last ~= "" and last ~= (GetRealmName and GetRealmName()) then
        return first .. " " .. last
    end
    return first
end

-- This character's realm. The game sometimes gives an empty realm name
-- for a whole session, so the last one we saw for this character is
-- remembered (or taken from its saved mage entry).
function SK.RealmName()
    local realm = GetRealmName and SK.Try(GetRealmName)
    local name = SK.PlayerFullName and SK.PlayerFullName()
    local db = SK.db
    if type(realm) == "string" and realm ~= "" then
        if db and name then
            db.realmOf = type(db.realmOf) == "table" and db.realmOf or {}
            db.realmOf[name] = realm
        end
        return realm
    end
    if not (db and name) then return "" end
    if type(db.realmOf) == "table" and db.realmOf[name] then return db.realmOf[name] end
    for _, entry in pairs(db.mages or {}) do
        if entry.name == name and type(entry.realm) == "string" and entry.realm ~= "" then return entry.realm end
    end
    return ""
end

-- "Archmage Naage-Realm": this character's key in SK.db.mages.
function SK.CharKey()
    local realm = SK.RealmName()
    return (SK.PlayerFullName() or "?") .. "-" .. (realm or "")
end

-- This character's saved entry, if it's a mage.
function SK.MyMage()
    if not SK.isMage then return nil end
    SK.db.mages = SK.db.mages or {}
    local key = SK.CharKey()
    local entry = SK.db.mages[key]
    if not entry then
        -- Saved before surnames were read? Pick up that entry ("Test-Realm").
        local first = (SK.PlayerFullName() or ""):match("^(%S+) ")
        local oldKey = first and (first .. "-" .. SK.RealmName())
        entry = (oldKey and SK.db.mages[oldKey]) or { }
        if oldKey then SK.db.mages[oldKey] = nil end
        entry.name = SK.PlayerFullName()
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
    entry.name = SK.PlayerFullName()
    entry.level = UnitLevel("player")
    entry.skill = skill.rank
    entry.max = skill.max
    entry.knowsStudy = SK.KnowsStudy() and true or false
    entry.faction = UnitFactionGroup and UnitFactionGroup("player") or entry.faction
    entry.realm = SK.RealmName() ~= "" and SK.RealmName() or entry.realm
    entry.seen = time()

    -- Forever names have a first name and a surname ("Test Sheep"). Older
    -- saves only had the first name; drop that leftover entry for this
    -- character so it isn't listed twice (or mailed at the wrong name).
    local full = entry.name or ""
    local first = full:match("^(%S+) ")
    if first then
        local realm = SK.RealmName()
        local oldKey = first .. "-" .. realm
        if oldKey ~= SK.CharKey() and SK.db.mages[oldKey] then SK.db.mages[oldKey] = nil end
    end
    -- Saved while the game gave no realm name ("Archmage Naage-"): drop it.
    local noRealm = full .. "-"
    if noRealm ~= SK.CharKey() and SK.db.mages[noRealm] then SK.db.mages[noRealm] = nil end
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

-- Your other mages you can mail right now: same realm and faction as
-- the character you're on.
function SK.MailableMages()
    local list = {}
    local realm = SK.RealmName()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, mage in ipairs(SK.MyOtherMages()) do
        local entry = SK.db.mages[mage.key] or {}
        local entryRealm = entry.realm or mage.key:match("%-(.+)$")
        -- Same realm, or any realm of the same ruleset (Forever's realm
        -- numbers are layers: Realm 1 PvE and Realm 3 PvE can mail each other).
        local sameRuleset = entryRealm and SK.SameServerRealm and SK.SameServerRealm(entryRealm)
        if (not realm or not entryRealm or entryRealm == realm or sameRuleset)
            and (not faction or not entry.faction or entry.faction == faction) then
            list[#list + 1] = mage
        end
    end
    return list
end
