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

-- Is this item link an untranslated scroll? (has "Requires Comprehension")
local function IsUntranslated(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
    local data = SK.Try(C_TooltipInfo.GetHyperlink, link)
    return type(data) == "table" and SK.RequirementFromLines(data.lines) ~= nil
end

-- "You receive loot: [Scroll: CWAL]" (deciphering says "You receive item:",
-- and never produces an untranslated scroll, so it can't be counted here).
SK.On("CHAT_MSG_LOOT", function(message, _, _, _, looter)
    if type(message) ~= "string" then return end
    local link = message:match("(|c.-|h|r)")
    if not link or not IsUntranslated(link) then return end
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
    SK.Send("SCROLL_LOOTED", count)
    SK.Send("DROPS_CHANGED")
    SK.Send("MY_DATA_CHANGED")
end)
