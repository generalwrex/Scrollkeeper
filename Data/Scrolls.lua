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
    return "|cff" .. chance.color .. SK.L[chance.label] .. "|r"
end

------------------------------------------------------------------------
-- Categories for usable (translated) scrolls on the panel.
-- A scroll goes in the first category whose words appear in its name.
------------------------------------------------------------------------

SK.SCROLL_CATEGORIES = {
    { key = "upgrades",  label = "Upgrades",  words = { "of the Saber", "of the Blade", "of Wit" } },
    { key = "imbues",    label = "Imbues",    words = { "Imbue" } },
    { key = "familiars", label = "Familiars", words = { "Familiar" } },
    { key = "combat",    label = "Combat",    words = { "Cryoblast", "Polymorph", "Confuse Beast", "Rebuke" } },
    { key = "utility",   label = "Utility",   words = { "" } },   -- everything else
}

-- The English name of a scroll, from the shared community data (players
-- on English clients), so categories work in every language. nil if unknown.
-- Is this one of the mage scrolls (from TIER_RESULTS), or a standard
-- scroll like Scroll of Strength that deciphering can also give?
-- Mage scrolls are all new items with high IDs; the name is a backup.
local mageNames
function SK.IsMageScroll(itemID, name)
    if itemID and itemID >= 200000 then return true end
    if not mageNames then
        mageNames = {}
        for _, results in pairs(SK.TIER_RESULTS) do
            for _, result in ipairs(results) do mageNames[result] = true end
        end
    end
    local english = SK.EnglishScrollName(itemID) or name
    return english ~= nil and mageNames[(english:gsub("^Scroll of ", ""))] == true
end

-- The standard stat scrolls (Strength, Agility, Stamina, Spirit, Intellect,
-- Protection, ranks I-IV) a decipher can also give.
SK.STANDARD_SCROLLS = {
    [954] = true, [2289] = true, [4426] = true, [10310] = true,    -- Strength
    [3012] = true, [1477] = true, [4425] = true, [10309] = true,   -- Agility
    [1180] = true, [1711] = true, [4422] = true, [10307] = true,   -- Stamina
    [1181] = true, [1712] = true, [4424] = true, [10306] = true,   -- Spirit
    [955] = true, [2290] = true, [4419] = true, [10308] = true,    -- Intellect
    [3013] = true, [1478] = true, [4421] = true, [10305] = true,   -- Protection
}

-- Could a decipher have given this item? Anything else (a recipe, water,
-- mob loot) was picked up at the same moment and isn't a result.
function SK.IsDecipherResult(itemID, name)
    if not itemID then return false end
    if SK.STANDARD_SCROLLS[itemID] or SK.IsMageScroll(itemID, name) then return true end
    local english = SK.EnglishScrollName(itemID)
    return english ~= nil and english:find("^Scroll of ") ~= nil
end

function SK.EnglishScrollName(itemID)
    if not itemID then return nil end
    for _, entry in pairs(SK.COMMUNITY_DATA or {}) do
        local name = entry.names and entry.names[itemID]
        if name then return name end
    end
    for _, entry in pairs(SK.db and SK.db.community or {}) do
        local name = entry.names and entry.names[itemID]
        if name then return name end
    end
    if GetLocale and GetLocale():sub(1, 2) == "en" then
        return SK.db and SK.db.itemNames and SK.db.itemNames[itemID]
    end
end

-- Which category a scroll goes in. By its English name when that's known
-- (any language), otherwise by the words in your language's name.
function SK.CategoryFor(name, itemID)
    local english = SK.EnglishScrollName(itemID)
    local lowered = (name or ""):lower()
    for _, category in ipairs(SK.SCROLL_CATEGORIES) do
        for _, word in ipairs(category.words) do
            if word == "" then return category.key end
            if english and english:find(word, 1, true) then return category.key end
            if name and name:find(word, 1, true) then return category.key end
            local translated = SK.L[word]
            if not english and translated ~= word and lowered:find(translated:lower(), 1, true) then return category.key end
        end
    end
    return "utility"
end

------------------------------------------------------------------------
-- Item links for scroll names
------------------------------------------------------------------------

-- The item ID for a scroll name we've seen (bags, deciphers, shared data).
function SK.ItemIDByName(name)
    if not name then return nil end
    for id, known in pairs(SK.db and SK.db.itemNames or {}) do
        if known == name then return id end
    end
    for _, scroll in ipairs(SK.bags and SK.bags.translated or {}) do
        if scroll.name == name then return scroll.itemID end
    end
    for _, entry in pairs(SK.COMMUNITY_DATA or {}) do
        for id, known in pairs(entry.names or {}) do
            if known == name then return id end
        end
    end
    return nil
end

-- A scroll as a real item link (clickable in chat, hoverable in
-- Scrollkeeper's windows). Give an item ID, a name, or both.
-- short = true drops "Scroll of " and the brackets, for tight spaces.
-- Works before the game has the item's info: the link is built from the
-- item ID, and the quality color is filled in once it's known.
-- Keeps "[Scroll of Frog Familiar]" from being split across lines when
-- text wraps, by using non-breaking spaces inside the brackets.
-- Only for text people can't click (tooltips): a link shift-clicked
-- into chat has to keep its real text or the server won't send it.
local NBSP = "\194\160"
function SK.KeepLinksWhole(text)
    if type(text) ~= "string" then return text end
    return (text:gsub("%[([^%]]*)%]", function(inside)
        return "[" .. inside:gsub(" ", NBSP) .. "]"
    end))
end

function SK.ScrollLink(itemID, name, short)
    itemID = itemID or SK.ItemIDByName(name)
    local link, quality
    if itemID and C_Item then
        if C_Item.GetItemInfo then
            local ok, itemName, itemLink, itemQuality = pcall(C_Item.GetItemInfo, itemID)
            if ok then
                name = name or itemName
                link, quality = itemLink, itemQuality
            end
        end
        if not link and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        name = name or (SK.db and SK.db.itemNames and SK.db.itemNames[itemID])
        if not name and C_Item.GetItemNameByID then
            local ok, byID = pcall(C_Item.GetItemNameByID, itemID)
            name = ok and byID or nil
        end
    end
    name = name or "a scroll"
    if not itemID then
        return "|cffffd100" .. (short and name:gsub("^Scroll of ", "") or ("[" .. name .. "]")) .. "|r"
    end
    if link and not short then return link end
    local color = "ffffd100"
    local qualityColor = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qualityColor and qualityColor.hex then color = qualityColor.hex:gsub("^|c", "") end
    local text = short and (name:gsub("^Scroll of ", "")) or ("[" .. name .. "]")
    return ("|c%s|Hitem:%d|h%s|h|r"):format(color, itemID, text)
end
