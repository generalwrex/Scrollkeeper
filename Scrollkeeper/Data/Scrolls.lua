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
    { scroll = "Scroll of the Saber", weapon = "Blade of Silverlaine", from = "Shadowfang Keep", makes = "Coldflame Saber" },
    { scroll = "Scroll of the Blade", weapon = "Hypnotic Blade", from = "Scarlet Monastery", makes = "Narpas Sword" },
    { scroll = "Scroll of Wit", weapon = "Witchblade", from = "Scholomance", makes = "Wit's Edge" },
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
