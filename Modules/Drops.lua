-- Scrollkeeper: Modules/Drops.lua
-- Remembers where you looted untranslated scrolls, for the map.
--
-- Positions are rounded to a grid of 2% of the zone map, so nearby
-- drops add up in one spot: drops[mapID][cell] = count, where
-- cell = "x.y" in grid units (0 to 49).

local _, SK = ...

SK.DROP_GRID = 50

function SK.CellFor(x, y)
    local gx = math.min(SK.DROP_GRID - 1, math.floor(x * SK.DROP_GRID))
    local gy = math.min(SK.DROP_GRID - 1, math.floor(y * SK.DROP_GRID))
    return gx .. "." .. gy
end

function SK.CellCenter(cell)
    local gx, gy = cell:match("^(%d+)%.(%d+)$")
    if not gx then return nil end
    return (tonumber(gx) + 0.5) / SK.DROP_GRID, (tonumber(gy) + 0.5) / SK.DROP_GRID
end

-- The Comprehension an item link needs if it's an untranslated scroll
-- (its tier: 1, 15, 50, 175), or nil.
local function UntranslatedTier(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local data = SK.Try(C_TooltipInfo.GetHyperlink, link)
    return type(data) == "table" and SK.RequirementFromLines(data.lines) or nil
end
SK.UntranslatedTier = UntranslatedTier

------------------------------------------------------------------------
-- Loot log: every untranslated scroll and book looted, with everything
-- we can tell about it, in case it's useful later. Kept on this computer
-- (and in a dev copy's export). At most LOG_MAX entries, oldest dropped.
--   SK.db.lootLog = { { t, kind, item, tier, map, x, y, zone, sub,
--                       src, srcID, srcName, lvl, class, count }, ... }
--   kind "scroll" or "book"; src "npc", "object" or "item"; x, y in 0-100.
------------------------------------------------------------------------

local LOG_MAX = 1500
-- What each loot window slot came from, by item ID (set when it opens).
local sources = {}

local function ParseGUID(guid)
    if type(guid) ~= "string" then return nil end
    -- "Creature-0-1234-0-5678-2240-0000ABCD": the 6th part is the NPC or object ID.
    local parts = {}
    for part in (guid .. "-"):gmatch("(.-)%-") do parts[#parts + 1] = part end
    local kind, id = parts[1], parts[6]
    if kind == "Creature" or kind == "Vehicle" then return "npc", tonumber(id) end
    if kind == "GameObject" then return "object", tonumber(id) end
    if kind == "Item" then return "item", nil end
    return kind and kind:lower() or nil, tonumber(id)
end

SK.On("LOOT_OPENED", function()
    sources = {}
    if not (GetNumLootItems and GetLootSlotLink and GetLootSourceInfo) then return end
    local targetName = SK.Known(UnitName and UnitName("target"))
    local targetGUID = SK.Known(UnitGUID and UnitGUID("target"))
    for slot = 1, GetNumLootItems() or 0 do
        local link = SK.Try(GetLootSlotLink, slot)
        local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if itemID then
            local guid = SK.Known(SK.Try(GetLootSourceInfo, slot))
            local src, srcID = ParseGUID(guid)
            sources[itemID] = { src = src, srcID = srcID,
                srcName = (guid and guid == targetGUID) and targetName or nil }
        end
    end
end)

function SK.LogLoot(kind, itemID, tier, count)
    SK.db.lootLog = SK.db.lootLog or {}
    local mapID, x, y = SK.PlayerMapPosition()
    local source = itemID and sources[itemID] or {}
    local _, class = UnitClass and UnitClass("player")
    table.insert(SK.db.lootLog, {
        t = time(), kind = kind, item = itemID, tier = tier, count = count or 1,
        map = mapID, x = x and math.floor(x * 1000 + 0.5) / 10, y = y and math.floor(y * 1000 + 0.5) / 10,
        zone = GetRealZoneText and GetRealZoneText() or nil, sub = GetSubZoneText and GetSubZoneText() or nil,
        src = source.src, srcID = source.srcID, srcName = source.srcName,
        lvl = UnitLevel and UnitLevel("player") or nil, class = class,
    })
    while #SK.db.lootLog > LOG_MAX do table.remove(SK.db.lootLog, 1) end
end

-- "You receive loot: [Scroll: CWAL]" (deciphering says "You receive item:",
-- and never produces an untranslated scroll, so it can't be counted here).
SK.On("CHAT_MSG_LOOT", function(message, _, _, _, looter)
    if type(message) ~= "string" then return end
    local link = message:match("(|c.-|h|r)")
    local tier = link and UntranslatedTier(link)
    if not tier then return end
    -- Only your own loot: the message is in the "You receive" form.
    local mine = LOOT_ITEM_SELF and message:find(LOOT_ITEM_SELF:match("^(.-)%%s"), 1, true)
    if LOOT_ITEM_SELF and not mine then return end

    local mapID, x, y = SK.PlayerMapPosition()
    if not mapID then return end
    local count = tonumber(message:match("x(%d+)%.?$")) or 1
    SK.db.drops = SK.db.drops or {}
    SK.db.drops[mapID] = SK.db.drops[mapID] or {}
    local cell = SK.CellFor(x, y)
    SK.db.drops[mapID][cell] = (SK.db.drops[mapID][cell] or 0) + count
    -- And which tier, per zone, so the plan can say where each tier drops:
    -- dropTiers[mapID][tier] = count.
    SK.db.dropTiers = SK.db.dropTiers or {}
    SK.db.dropTiers[mapID] = SK.db.dropTiers[mapID] or {}
    SK.db.dropTiers[mapID][tier] = (SK.db.dropTiers[mapID][tier] or 0) + count
    -- And which tier at this spot: cellTiers[mapID][cell][tier] = count.
    SK.db.cellTiers = SK.db.cellTiers or {}
    SK.db.cellTiers[mapID] = SK.db.cellTiers[mapID] or {}
    SK.db.cellTiers[mapID][cell] = SK.db.cellTiers[mapID][cell] or {}
    SK.db.cellTiers[mapID][cell][tier] = (SK.db.cellTiers[mapID][cell][tier] or 0) + count
    -- Which untranslated scroll (item ID), kept for later:
    -- cellItems[mapID][cell][itemID] = count.
    local itemID = tonumber(link:match("item:(%d+)"))
    if itemID then
        SK.db.cellItems = SK.db.cellItems or {}
        SK.db.cellItems[mapID] = SK.db.cellItems[mapID] or {}
        SK.db.cellItems[mapID][cell] = SK.db.cellItems[mapID][cell] or {}
        SK.db.cellItems[mapID][cell][itemID] = (SK.db.cellItems[mapID][cell][itemID] or 0) + count
    end
    SK.Safely("loot log", SK.LogLoot, "scroll", itemID, tier, count)
    SK.Send("SCROLL_LOOTED", count)
    SK.Send("DROPS_CHANGED")
    SK.Send("MY_DATA_CHANGED")
end)
