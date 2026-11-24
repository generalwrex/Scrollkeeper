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

-- Forever's talents: one spec for every mage ("Mage"), and the three
-- classic trees are columns in the modern talent system (C_Traits). Each
-- talent there has a definition ID; these are the mage trees' IDs (from
-- WowSimsExporter's Forever talent list, which reads them the same way).
local TREE_TALENTS = {
    arcane = { 135345, 135343, 135332, 135342, 135341, 135340, 135339, 135338, 135337, 135336, 135335, 135334, 135333, 145958, 135331, 135330, 135329, 135328 },
    fire = { 135326, 135325, 135324, 135323, 135322, 135319, 135321, 135320, 135327, 135318, 135317, 135316, 135315, 135314, 135313, 135312, 135311 },
    frost = { 135310, 135309, 135308, 135307, 135304, 135305, 135306, 135302, 135301, 135297, 135300, 135299, 135298, 135295, 135296, 135294, 135293, 135292 },
}
local TREE_OF = {}
for tree, ids in pairs(TREE_TALENTS) do for _, id in ipairs(ids) do TREE_OF[id] = tree end end

-- Points spent in each tree: { arcane = 0, fire = 0, frost = 20 }, or nil
-- if the game has no talent data (or no C_Traits).
local function TraitTreePoints()
    if not (C_Traits and C_ClassTalents and C_ClassTalents.GetActiveConfigID) then return nil end
    local configID = SK.Try(C_ClassTalents.GetActiveConfigID)
    local config = configID and SK.Try(C_Traits.GetConfigInfo, configID)
    if type(config) ~= "table" or type(config.treeIDs) ~= "table" then return nil end
    local points = { arcane = 0, fire = 0, frost = 0 }
    for _, treeID in ipairs(config.treeIDs) do
        for _, nodeID in ipairs(SK.Try(C_Traits.GetTreeNodes, treeID) or {}) do
            local node = SK.Try(C_Traits.GetNodeInfo, configID, nodeID)
            local rank = type(node) == "table" and (node.currentRank or node.ranksPurchased) or 0
            if type(rank) == "number" and rank > 0 and type(node.activeEntry) == "table" then
                local entry = SK.Try(C_Traits.GetEntryInfo, configID, node.activeEntry.entryID)
                local tree = type(entry) == "table" and TREE_OF[entry.definitionID]
                if tree then points[tree] = points[tree] + rank end
            end
        end
    end
    return points
end

-- Reading the talents walks every node, so it's kept a little while
-- (and read again when the talents change).
local specCache, specCachedAt
SK.On("TRAIT_CONFIG_UPDATED", function() specCachedAt = nil end)
SK.On("PLAYER_TALENT_UPDATE", function() specCachedAt = nil end)
SK.On("CHARACTER_POINTS_CHANGED", function() specCachedAt = nil end)

-- "arcane", "fire", "frost", or nil (no points yet, or not a mage).
function SK.MageSpec()
    if not SK.isMage then return nil end
    local now = GetTime and GetTime() or 0
    if specCachedAt and now - specCachedAt < 30 then return specCache or nil end
    local points = TraitTreePoints()
    if points then
        local best, bestPoints = nil, 0
        for _, tree in ipairs(SPEC_TREES) do
            if points[tree] > bestPoints then best, bestPoints = tree, points[tree] end
        end
        specCache, specCachedAt = best or false, now
        return best
    end
    if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
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
-- SK.charDB.scrollUses[itemID] = times. For imbues your spec comes first
-- (a Frost mage gets a Frost imbue, even a lower level one); among those,
-- or with none for your spec, the most used (2+ times) wins.
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

-- Why a scroll is your pick, in words: "your usual (used 5 times)",
-- "for your Fire spec", or nil.
local SPEC_NAMES = { arcane = "Arcane", fire = "Fire", frost = "Frost" }
-- Your spec's name ("Frost"), in your language, or nil.
function SK.SpecName()
    local spec = SK.MageSpec and SK.MageSpec()
    return spec and L[SPEC_NAMES[spec]] or nil
end

-- You carry imbues, but none fit your spec (only another school's):
-- nothing is suggested, and the panel says why.
function SK.NoImbueForSpec()
    if SK.db and SK.db.imbueByUse then return false end
    local any = false
    for _, scroll in ipairs(SK.bags and SK.bags.translated or {}) do
        if scroll.category == "imbues" then any = true end
    end
    return any and SK.BestScroll("imbues") == nil and SK.SpecName() ~= nil
end
function SK.ScrollReason(scroll)
    if not scroll then return nil end
    if SK.IsPinned and SK.IsPinned(scroll.itemID) then return L["pinned"] end
    local uses = SK.ScrollUses(scroll.itemID)
    local usual = uses >= 2 and L["your usual (used %d times)"]:format(uses) or nil
    if usual and SK.db and SK.db.imbueByUse then return usual end
    if scroll.category == "imbues" and scroll.forSpec then
        local spec = SK.MageSpec and SK.MageSpec()
        if spec then return L["for your %s spec"]:format(L[SPEC_NAMES[spec]]) end
    end
    return usual
end

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
        local school = SK.ImbueSchool(scroll)
        scroll.forSpec = spec ~= nil and school == spec
        -- Another school's imbue (fire or arcane for a Frost mage) is never
        -- suggested; neutral ones (Accuracy, Striking...) still can be.
        -- Unless you asked for the one you use most.
        scroll.offSpec = spec ~= nil and school ~= nil and school ~= spec and not (SK.db and SK.db.imbueByUse) or nil
    end

    local groups = {}
    for _, category in ipairs(SK.SCROLL_CATEGORIES) do
        local scrolls = byKey[category.key]
        if scrolls then
            -- Usable first; then (imbues) the ones for your spec, even a
            -- lower level one; then your favorite (used most, at least
            -- twice); then highest level. The imbueByUse option swaps the
            -- first two: your favorite, then your spec.
            local byUse = SK.db and SK.db.imbueByUse
            local function Favorite(scroll)
                local n = SK.ScrollUses(scroll.itemID)
                return n >= 2 and n or 0
            end
            -- A pinned scroll (Scroll Bag, or right-click the Familiar or
            -- Imbue button) beats every other pick while you can use it.
            local function Pinned(scroll)
                return SK.PinOf and SK.PinOf(category.key, SK.ImbueWeapon and SK.ImbueWeapon(scroll.itemID, scroll)) == scroll.itemID
            end
            table.sort(scrolls, function(a, b)
                if a.usable ~= b.usable then return a.usable end
                local pa, pb = Pinned(a), Pinned(b)
                if pa ~= pb then return pa end
                local fa, fb = Favorite(a), Favorite(b)
                if byUse and fa ~= fb then return fa > fb end
                if (a.forSpec or false) ~= (b.forSpec or false) then return a.forSpec or false end
                if (a.offSpec or false) ~= (b.offSpec or false) then return not a.offSpec end
                if fa ~= fb then return fa > fb end
                if a.level ~= b.level then return a.level > b.level end
                return a.name < b.name
            end)
            local ranked = category.key == "imbues" or category.key == "familiars"
            if ranked and scrolls[1].usable and (not scrolls[1].offSpec or Pinned(scrolls[1])) then
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
            for i, scroll in ipairs(group.scrolls) do
                -- (A pinned one sorts first, even another school's imbue.)
                if scroll.usable and (not scroll.offSpec or (i == 1 and scroll.best)) then return scroll end
            end
        end
    end
    return nil
end
