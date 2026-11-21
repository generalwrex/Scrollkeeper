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
    SK.Send("SCROLL_LOOTED", count)
    SK.Send("DROPS_CHANGED")
    SK.Send("MY_DATA_CHANGED")
end)
