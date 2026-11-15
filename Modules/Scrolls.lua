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

-- The main-hand weapon's subclass ID and a short description ("a staff"), or nil.
function SK.MainHandWeapon()
    local itemID = GetInventoryItemID and GetInventoryItemID("player", 16)
    if not itemID or not C_Item then return nil end
    local _, _, subType, _, _, classID, subClassID = SK.Try(C_Item.GetItemInfoInstant, itemID)
    if classID ~= 2 then return nil end
    return subClassID, WEAPON_WORDS[subClassID] or (subType and subType:lower())
end

-- Does this imbue fit the main-hand weapon? (true if we can't tell)
function SK.ImbueFits(scroll)
    if not scroll.imbueFor then return true end
    local kinds = WEAPON_KINDS[scroll.imbueFor]
    if not kinds then return true end
    local subClassID = SK.MainHandWeapon()
    return subClassID ~= nil and kinds[subClassID] == true
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

    local groups = {}
    for _, category in ipairs(SK.SCROLL_CATEGORIES) do
        local scrolls = byKey[category.key]
        if scrolls then
            -- Highest level first; usable before not-yet-usable.
            table.sort(scrolls, function(a, b)
                if a.usable ~= b.usable then return a.usable end
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
