-- Scrollkeeper: Data/Scrolls.lua
-- What each tier of untranslated scroll can turn into.
--
-- Source: community guides from the beta (Conquest Capped, Warcraft Tavern),
-- not the game itself. Tier 175 is datamined. The addon's own luck log
-- (/sk log) records what your deciphers really produce.

local _, SK = ...

-- Comprehension skill needed for each tier, lowest first.
SK.TIERS = { 1, 15, 50, 175 }

-- Character level needed to USE the scrolls a tier produces.
SK.TIER_USE_LEVEL = { [1] = 6, [15] = 16, [50] = 25, [175] = 46 }

SK.TIER_RESULTS = {
    [1] = {
        "Minor Evocation", "Comprehension", "Imbue Lesser Flame",
        "Imbue Chillknife", "Rat Familiar",
    },
    [15] = {
        "Imbue Frost", "Imbue Striking", "Imbue Baleflame", "Imbue Iceknife",
        "Imbue Spark", "Frog Familiar", "Cryoblast", "Polymorph: Odd Melon",
        "Confuse Beast", "Scroll of the Saber",
    },
    [50] = {
        "Imbue Flame", "Imbue Accuracy", "Imbue Balefrost", "Imbue Quickening",
        "Imbue Manablade", "Cat Familiar", "Khadgar's Unlocking",
        "Rebuke Elemental", "Scroll of the Blade",
    },
    [175] = {
        "Greater Cryoblast", "Imbue Greater Flame", "Imbue Greater Frost",
        "Imbue Precision", "Imbue Spellbreak", "Scroll of Wit",
    },
}

-- Scrolls that upgrade a dungeon weapon into a new one.
SK.WEAPON_UPGRADES = {
    { short = "Saber", scroll = "Scroll of the Saber", weapon = "Blade of Silverlaine", from = "Shadowfang Keep", makes = "Coldflame Saber" },
    { short = "Blade", scroll = "Scroll of the Blade", weapon = "Hypnotic Blade", from = "Scarlet Monastery", makes = "Narpas Sword" },
    { short = "Wit", scroll = "Scroll of Wit", weapon = "Witchblade", from = "Scholomance", makes = "Wit's Edge" },
}

-- The highest tier a given skill can read, or nil if it can read none.
function SK.HighestTierFor(skill)
    local best
    for _, tier in ipairs(SK.TIERS) do
        if skill >= tier then best = tier end
    end
    return best
end

-- The next tier above a given skill, or nil if every tier is readable.
function SK.NextTierAfter(skill)
    for _, tier in ipairs(SK.TIERS) do
        if skill < tier then return tier end
    end
    return nil
end

------------------------------------------------------------------------
-- Skill-ups
-- Like professions, a scroll gives Comprehension only while it is not
-- too easy for you. These numbers are from Forever beta skill data
-- (LeprestoRE guide). The game agrees so far: a tier 1 scroll read at
-- 57 skill gave nothing.
--
--   below yellow   always a skill-up
--   yellow         usually
--   green          sometimes  (halfway between yellow and gray)
--   gray and up    never
------------------------------------------------------------------------

SK.SKILLUP_COLORS = {
    [1]   = { yellow = 15,  gray = 30 },
    [15]  = { yellow = 50,  gray = 75 },
    [50]  = { yellow = 100, gray = 200 },
    [175] = { yellow = 250, gray = 300 },
}

local CHANCES = {
    orange = { label = "skill-up",           color = "ff8040", gives = true },
    yellow = { label = "skill-up likely",    color = "ffff00", gives = true },
    green  = { label = "skill-up unlikely",  color = "40c040", gives = true },
    gray   = { label = "no skill-up",        color = "808080", gives = false },
}

-- How likely deciphering a scroll of tier `needs` is to raise a skill of
-- `skill`. Returns a table { key, label, color, gives } (see CHANCES).
-- Uses your trained skill, not bonus points: bonuses let you read harder
-- scrolls but don't change what counts as easy.
function SK.SkillUpChance(needs, skill)
    local colors = SK.SKILLUP_COLORS[needs]
    if not colors then return nil end
    local green = math.floor((colors.yellow + colors.gray) / 2)
    local key
    if skill >= colors.gray then key = "gray"
    elseif skill >= green then key = "green"
    elseif skill >= colors.yellow then key = "yellow"
    else key = "orange" end
    local chance = CHANCES[key]
    return { key = key, label = chance.label, color = chance.color, gives = chance.gives }
end

-- "|cffff8040skill-up|r"
function SK.ColoredChance(chance)
    if not chance then return "" end
    return "|cff" .. chance.color .. chance.label .. "|r"
end
