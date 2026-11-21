-- Scrollkeeper: Modules/Scrolls.lua
-- Your usable scrolls, grouped by category, with the best one marked.
--
-- "Best" means the highest-level scroll in its category that you're high
-- enough level to use: a Cat Familiar over a Rat Familiar, Imbue Flame
-- over Imbue Lesser Flame. Only imbues and familiars are ranked: in the
-- other categories each scroll does a different job.
--
-- Imbues only work on one kind of weapon ("Imbue a staff", "Imbue a
-- sword"), so an imbue counts as usable only if it fits the weapon in
-- your main hand.

local _, SK = ...
local L = SK.L

-- Weapon subclass IDs (item class 2) for each word imbue tooltips use.
local WEAPON_KINDS = {
    sword  = { [7] = true, [8] = true },
    staff  = { [10] = true },
    dagger = { [15] = true },
    knife  = { [15] = true },
    mace   = { [4] = true, [5] = true },
    axe    = { [0] = true, [1] = true },
    wand   = { [19] = true },
}

-- "a staff", "a sword" ... for messages, by subclass ID.
local WEAPON_WORDS = {
    [7] = "a sword", [8] = "a sword", [10] = "a staff", [15] = "a dagger",
    [4] = "a mace", [5] = "a mace", [0] = "an axe", [1] = "an axe", [19] = "a wand",
}

-- "sword" -> "a sword", "axe" -> "an axe"
function SK.WeaponWithArticle(word)
    if not word or word == "" then return L["a different weapon"] end
    return (word:match("^[aeiouAEIOU]") and "an " or "a ") .. word
end

-- The main-hand weapon's subclass ID and a short description ("a staff"), or nil.
function SK.MainHandWeapon()
    local itemID = GetInventoryItemID and GetInventoryItemID("player", 16)
    if not itemID or not C_Item then return nil end
    local _, _, subType, _, _, classID, subClassID = SK.Try(C_Item.GetItemInfoInstant, itemID)
    if classID ~= 2 then return nil end
    local word = WEAPON_WORDS[subClassID]
    return subClassID, word and L[word] or (subType and subType:lower())
end

-- Does this imbue fit the main-hand weapon? (true if we can't tell)
function SK.ImbueFits(scroll)
    if not scroll.imbueFor then return true end
    local kinds = WEAPON_KINDS[scroll.imbueFor]
    if not kinds then return true end
    local subClassID = SK.MainHandWeapon()
    return subClassID ~= nil and kinds[subClassID] == true
end


-- A weapon in your bags that this imbue would fit: its name, or nil.
-- (Equipping it is up to you; Scrollkeeper only points it out.)
function SK.WeaponInBagsFor(scroll)
    local kinds = scroll and scroll.imbueFor and WEAPON_KINDS[scroll.imbueFor]
    if not kinds or not (C_Container and C_Item) then return nil end
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local _, _, _, _, _, classID, subClassID = SK.Try(C_Item.GetItemInfoInstant, info.itemID)
                if classID == 2 and kinds[subClassID] then
                    return (info.hyperlink and info.hyperlink:match("%[(.-)%]"))
                        or SK.Try(C_Item.GetItemNameByID, info.itemID) or "a weapon"
                end
            end
        end
    end
    return nil
end

-- When none of your imbues fit the weapon you hold: the first imbue you
-- could use by swapping to a weapon in your bags, as scroll, weaponName.
function SK.ImbueSwapHint()
    for _, scroll in ipairs(SK.bags.translated or {}) do
        if scroll.category == "imbues" and (scroll.level or 0) <= (UnitLevel("player") or 0) then
            local weapon = SK.WeaponInBagsFor(scroll)
            if weapon then return scroll, weapon end
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Imbues for your spec: a Fire mage's best imbue is a flame one, a Frost
-- mage's a frost one, an Arcane mage's an arcane one. Spec = the talent
-- tree with the most points (none below level 10).
------------------------------------------------------------------------

local SPEC_TREES = { "arcane", "fire", "frost" }   -- mage talent tabs, in order

-- "arcane", "fire", "frost", or nil (no points yet, or not a mage).
function SK.MageSpec()
    if not (SK.isMage and GetNumTalentTabs and GetTalentTabInfo) then return nil end
    local best, bestPoints = nil, 0
    for tab = 1, math.min(3, GetNumTalentTabs() or 0) do
        local info = { SK.Try(GetTalentTabInfo, tab) }
        -- Classic: name, icon, points...  Later clients: id, name, description, icon, points...
        local points = type(info[1]) == "number" and info[5] or info[3]
        points = tonumber(points) or 0
        if points > bestPoints then best, bestPoints = SPEC_TREES[tab], points end
    end
    return best
end

-- Which school an imbue is, by its (English) name.
local IMBUE_SCHOOLS = {
    { "Flame", "fire" },
    { "Frost", "frost" }, { "Chill", "frost" }, { "Ice", "frost" },
    { "Mana", "arcane" }, { "Spellbreak", "arcane" }, { "Spark", "arcane" },
}
function SK.ImbueSchool(scroll)
    local name = ((SK.EnglishScrollName and SK.EnglishScrollName(scroll.itemID)) or scroll.name or ""):lower()
    for _, pair in ipairs(IMBUE_SCHOOLS) do
        if name:find(pair[1]:lower(), 1, true) then return pair[2] end
    end
    return nil
end

------------------------------------------------------------------------
-- Your favorites: which imbue and familiar this character actually uses.
-- Counted when the scroll is used (its spell goes off), per character:
-- SK.charDB.scrollUses[itemID] = times. The most used (2+ times) beats the
-- spec guess; at 60 everyone has their own pick.
------------------------------------------------------------------------

local function Uses()
    if not SK.charDB then return {} end
    SK.charDB.scrollUses = SK.charDB.scrollUses or {}
    return SK.charDB.scrollUses
end
function SK.ScrollUses(itemID) return itemID and Uses()[itemID] or 0 end

SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    unit, spellID = SK.Known(unit), SK.Known(spellID)
    if unit ~= "player" or not spellID or not SK.bags then return end
    for _, scroll in ipairs(SK.bags.translated or {}) do
        if scroll.category == "imbues" or scroll.category == "familiars" then
            local _, itemSpell = SK.Try(C_Item and C_Item.GetItemSpell or GetItemSpell, scroll.itemID)
            if itemSpell and itemSpell == spellID then
                Uses()[scroll.itemID] = (Uses()[scroll.itemID] or 0) + 1
                return
            end
        end
    end
end)

-- Returns a list of { key, label, scrolls = { ... } } for the categories
-- you have scrolls in, in display order. Each scroll gets .usable and .best.
function SK.ScrollGroups()
    local playerLevel = UnitLevel("player") or 0
    local byKey = {}
    for _, scroll in ipairs(SK.bags.translated) do
        scroll.levelOK = (scroll.level or 0) <= playerLevel
        scroll.fits = scroll.category ~= "imbues" or SK.ImbueFits(scroll)
        scroll.usable = scroll.levelOK and scroll.fits
        scroll.best = false
        byKey[scroll.category] = byKey[scroll.category] or {}
        table.insert(byKey[scroll.category], scroll)
    end

    local spec = SK.MageSpec and SK.MageSpec()
    for _, scroll in ipairs(byKey.imbues or {}) do
        scroll.forSpec = spec ~= nil and SK.ImbueSchool(scroll) == spec
    end

    local groups = {}
    for _, category in ipairs(SK.SCROLL_CATEGORIES) do
        local scrolls = byKey[category.key]
        if scrolls then
            -- Usable first; then your favorite (used most, at least twice);
            -- then (imbues) the ones for your spec; then highest level.
            local function Favorite(scroll)
                local n = SK.ScrollUses(scroll.itemID)
                return n >= 2 and n or 0
            end
            table.sort(scrolls, function(a, b)
                if a.usable ~= b.usable then return a.usable end
                local fa, fb = Favorite(a), Favorite(b)
                if fa ~= fb then return fa > fb end
                if (a.forSpec or false) ~= (b.forSpec or false) then return a.forSpec or false end
                if a.level ~= b.level then return a.level > b.level end
                return a.name < b.name
            end)
            local ranked = category.key == "imbues" or category.key == "familiars"
            if ranked and scrolls[1].usable then
                scrolls[1].best = true
            end
            groups[#groups + 1] = { key = category.key, label = category.label, scrolls = scrolls }
        end
    end
    return groups
end

-- The best usable scroll in a category, or nil.
function SK.BestScroll(categoryKey)
    for _, group in ipairs(SK.ScrollGroups()) do
        if group.key == categoryKey then
            for _, scroll in ipairs(group.scrolls) do
                if scroll.usable then return scroll end
            end
        end
    end
    return nil
end
