-- Scrollkeeper: Modules/Bags.lua
-- Finds mage scrolls, Light Feathers and Bundles of Scrolls in the bags.

local _, SK = ...

local FIRST_BAG, LAST_BAG = 0, 5   -- backpack, four bags, reagent bag

------------------------------------------------------------------------
-- Reading the "Requires Comprehension (15)" line
-- The pattern is built from the game's own text, so it works in every
-- language the client supports.
------------------------------------------------------------------------

local requirementPattern

local function EscapeForPattern(text)
    return (text:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"))
end

local function BuildRequirementPattern()
    -- The game's template is "Requires %s (%d)" in English. Some languages
    -- use numbered slots like "%1$s" and "%2$d"; treat those the same way.
    local template = ITEM_MIN_SKILL or "Requires %s (%d)"
    template = template:gsub("%%%d%$s", "%%s"):gsub("%%%d%$d", "%%d")

    local skillName = EscapeForPattern(SK.GetComprehension().name)
    local before, after = template:match("^(.-)%%s(.*)$")
    if not before then return "Comprehension %((%d+)%)" end
    local middle, tail = after:match("^(.-)%%d(.*)$")
    if not middle then return "Comprehension %((%d+)%)" end

    return EscapeForPattern(before) .. skillName .. EscapeForPattern(middle) .. "(%d+)" .. EscapeForPattern(tail)
end

-- Given tooltip lines, return the Comprehension needed, or nil.
function SK.RequirementFromLines(lines)
    if type(lines) ~= "table" then return nil end
    requirementPattern = requirementPattern or BuildRequirementPattern()
    for _, line in ipairs(lines) do
        local text = type(line) == "table" and line.leftText or line
        if type(text) == "string" then
            local needed = text:match(requirementPattern)
            if needed then return tonumber(needed) end
        end
    end
    return nil
end

-- True if the tooltip has a "Classes: Mage" line.
local function IsMageOnly(lines)
    local template = ITEM_CLASSES_ALLOWED or "Classes: %s"
    local prefix = template:match("^(.-)%%s") or "Classes: "
    local mage = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.MAGE) or "Mage"
    for _, line in ipairs(lines) do
        local text = type(line) == "table" and line.leftText or line
        if type(text) == "string" and text:sub(1, #prefix) == prefix and text:find(mage, 1, true) then
            return true
        end
    end
    return false
end

-- Reads one bag slot's tooltip. Returns the Comprehension needed (or nil)
-- and whether the item is for mages only.
local function ReadSlotTooltip(bag, slot)
    local data = C_TooltipInfo and SK.Try(C_TooltipInfo.GetBagItem, bag, slot)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil, false end
    return SK.RequirementFromLines(data.lines), IsMageOnly(data.lines)
end

------------------------------------------------------------------------
-- Scanning
------------------------------------------------------------------------

local function IsScrollItem(itemID)
    if not C_Item then return false end
    local _, _, _, _, _, classID, subClassID = SK.Try(C_Item.GetItemInfoInstant, itemID)
    return classID == SK.ITEM_CLASS_CONSUMABLE and subClassID == SK.ITEM_SUBCLASS_SCROLL
end

-- Returns a table describing what is in the bags right now:
--   untranslated  list of { bag, slot, itemID, name, needs }   (needs = Comprehension required)
--   translated    list of { itemID, name, count, icon }, one entry per kind of usable mage scroll
--   feathers      number of Light Feathers
--   bundles       number of unopened Bundles of Scrolls
--   counts        [itemID] = how many, for every item (used by the luck log)
--   names         [itemID] = item name
function SK.ScanBags()
    local found = { untranslated = {}, translated = {}, feathers = 0, bundles = 0, counts = {}, names = {} }
    if not C_Container then return found end
    local translatedByID = {}

    for bag = FIRST_BAG, LAST_BAG do
        local slots = SK.Try(C_Container.GetContainerNumSlots, bag) or 0
        for slot = 1, slots do
            local item = SK.Try(C_Container.GetContainerItemInfo, bag, slot)
            if type(item) == "table" and item.itemID then
                local id, count = item.itemID, item.stackCount or 1
                local name = item.itemName or (C_Item and SK.Try(C_Item.GetItemNameByID, id)) or ""
                found.counts[id] = (found.counts[id] or 0) + count
                found.names[id] = name

                if id == SK.ITEM_LIGHT_FEATHER then
                    found.feathers = found.feathers + count
                elseif name == "Bundle of Scrolls" then
                    found.bundles = found.bundles + count
                    found.bundleBag, found.bundleSlot = bag, slot
                elseif IsScrollItem(id) then
                    local needs, mageOnly = ReadSlotTooltip(bag, slot)
                    if needs then
                        table.insert(found.untranslated, {
                            bag = bag, slot = slot, itemID = id, name = name, needs = needs,
                        })
                    elseif mageOnly then
                        local entry = translatedByID[id]
                        if not entry then
                            entry = {
                                itemID = id, name = name, count = 0,
                                icon = item.iconFileID or (C_Item and SK.Try(C_Item.GetItemIconByID, id)),
                            }
                            translatedByID[id] = entry
                            table.insert(found.translated, entry)
                        end
                        entry.count = entry.count + count
                    end
                end
            end
        end
    end

    -- Easiest scrolls first, so the decipher button works up through them.
    table.sort(found.untranslated, function(a, b)
        if a.needs ~= b.needs then return a.needs < b.needs end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    table.sort(found.translated, function(a, b) return a.name < b.name end)
    return found
end

-- The most recent scan. Other files read SK.bags instead of rescanning.
SK.bags = { untranslated = {}, translated = {}, feathers = 0, bundles = 0, counts = {}, names = {} }

local function Refresh()
    local previous = SK.bags
    SK.bags = SK.ScanBags()
    SK.Send("BAGS_CHANGED", SK.bags, previous)
end

SK.On("BAG_UPDATE_DELAYED", Refresh)
SK.On("PLAYER_ENTERING_WORLD", Refresh)
SK.Listen("SKILL_CHANGED", function() requirementPattern = nil end)
