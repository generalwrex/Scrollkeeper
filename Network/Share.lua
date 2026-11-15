-- Scrollkeeper: Network/Share.lua
-- Sharing what you've learned, and adding up what others share.
--
--   T|tier#part|itemID:count,...     what your deciphers of that tier became
--   U|tier#part|colour:ups/tries,... your skill-ups by colour at that tier
--   L|mapID|x|y|name                 a library you've used Study in
--   P|mapID#part|cell:count,...      where you've looted untranslated scrolls
--
-- Each player's totals REPLACE their previous ones, so hearing the same
-- player twice never counts twice, and one player can't flood the
-- numbers. Impossible values are dropped.

local _, SK = ...
local Net = SK.Net

local MAX_COUNT = 5000          -- no one has read more of one tier than this
local KEEP_DAYS = 30            -- forget players not heard from in a month

------------------------------------------------------------------------
-- Storage of what others sent
--   community[sender] = { at, results = {[tier] = {[itemID] = n}},
--                          skillups = {[tier] = {[colour] = {ups, tries}}},
--                          drops = {[mapID] = {[cell] = n}} }
------------------------------------------------------------------------

local function Entry(sender)
    SK.db.community = SK.db.community or {}
    local entry = SK.db.community[sender]
    if not entry then
        entry = { results = {}, skillups = {}, drops = {} }
        SK.db.community[sender] = entry
    end
    entry.at = time()
    return entry
end

-- "15#2" -> 15, 2
local function Head(text)
    local value, part = tostring(text):match("^(%d+)#(%d+)$")
    return tonumber(value), tonumber(part)
end

-- A list message arrives in parts. Part 1 starts fresh; later parts add.
local function Target(parent, key, part)
    if part == 1 or not parent[key] then parent[key] = {} end
    return parent[key]
end

Net.Handle("T", function(sender, f)
    local tier, part = Head(f[1])
    if not (tier and part and SK.TIER_RESULTS[tier]) then return end
    local list = Target(Entry(sender).results, tier, part)
    for id, count in (f[2] or ""):gmatch("(%d+):(%d+)") do
        count = tonumber(count)
        if count > 0 and count <= MAX_COUNT then list[tonumber(id)] = count end
    end
    SK.Send("COMMUNITY_CHANGED")
end)

Net.Handle("U", function(sender, f)
    local tier, part = Head(f[1])
    if not (tier and part and SK.TIER_RESULTS[tier]) then return end
    local list = Target(Entry(sender).skillups, tier, part)
    for colour, ups, tries in (f[2] or ""):gmatch("(%a+):(%d+)/(%d+)") do
        ups, tries = tonumber(ups), tonumber(tries)
        if tries > 0 and tries <= MAX_COUNT and ups <= tries then list[colour] = { ups, tries } end
    end
end)

Net.Handle("P", function(sender, f)
    local mapID, part = Head(f[1])
    if not (mapID and part) then return end
    local cells = Target(Entry(sender).drops, mapID, part)
    for cell, count in (f[2] or ""):gmatch("(%d+%.%d+):(%d+)") do
        count = tonumber(count)
        if count > 0 and count <= MAX_COUNT and SK.CellCenter(cell) then cells[cell] = count end
    end
    SK.Send("DROPS_CHANGED")
end)

Net.Handle("L", function(sender, f)
    local mapID, x, y, name = tonumber(f[1]), tonumber(f[2]), tonumber(f[3]), f[4]
    if not (mapID and x and y and name and name ~= "") then return end
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    SK.db.sharedLibraries = SK.db.sharedLibraries or {}
    local key = mapID .. " / " .. name
    local entry = SK.db.sharedLibraries[key] or { mapID = mapID, x = x, y = y, name = name, from = {} }
    entry.from[sender] = true
    SK.db.sharedLibraries[key] = entry
    SK.Send("DROPS_CHANGED")
end)

------------------------------------------------------------------------
-- Adding it all up (other players + you)
------------------------------------------------------------------------

-- Community results for a tier: list of { itemID, name, count, share } and the total.
function SK.CommunityOdds(tier)
    local totals, total, players = {}, 0, 0
    local function Add(results)
        for id, count in pairs(results or {}) do
            totals[id] = (totals[id] or 0) + count
            total = total + count
        end
    end
    Add(SK.db.resultsByID and SK.db.resultsByID[tier])
    if SK.db.resultsByID and SK.db.resultsByID[tier] then players = 1 end
    for name, entry in pairs(SK.db.community or {}) do
        if entry.results[tier] and next(entry.results[tier]) then
            Add(entry.results[tier])
            players = players + 1
        end
    end
    for _, peer in pairs(SK.demoCommunity or {}) do
        if peer.results[tier] then Add(peer.results[tier]) players = players + 1 end
    end

    local list = {}
    for id, count in pairs(totals) do
        local name = (SK.db.itemNames and SK.db.itemNames[id]) or (SK.demoNames and SK.demoNames[id])
            or (C_Item and SK.Try(C_Item.GetItemNameByID, id)) or ("item " .. id)
        list[#list + 1] = { itemID = id, name = name, count = count, share = count / total }
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list, total, players
end

-- Drop cells for a map, yours and everyone's: cells[cell] = { mine, others }.
function SK.DropCells(mapID)
    local cells = {}
    for cell, count in pairs(SK.db.drops and SK.db.drops[mapID] or {}) do
        cells[cell] = { mine = count, others = 0 }
    end
    local function AddOthers(drops)
        for cell, count in pairs(drops and drops[mapID] or {}) do
            cells[cell] = cells[cell] or { mine = 0, others = 0 }
            cells[cell].others = cells[cell].others + count
        end
    end
    for _, entry in pairs(SK.db.community or {}) do AddOthers(entry.drops) end
    for _, peer in pairs(SK.demoCommunity or {}) do AddOthers(peer.drops) end
    return cells
end

-- Libraries to pin on a map: list of { x, y, name, mine = true/false, count }
function SK.LibraryPins(mapID)
    local pins = {}
    for _, pin in pairs(SK.db.libraryPins or {}) do
        if pin.mapID == mapID then pins[#pins + 1] = { x = pin.x, y = pin.y, name = pin.name, mine = true } end
    end
    for _, pin in pairs(SK.db.sharedLibraries or {}) do
        if pin.mapID == mapID then
            local count = 0
            for _ in pairs(pin.from) do count = count + 1 end
            pins[#pins + 1] = { x = pin.x, y = pin.y, name = pin.name, mine = false, count = count }
        end
    end
    return pins
end

------------------------------------------------------------------------
-- Sending my data
------------------------------------------------------------------------

function SK.SendMyData()
    local db = SK.db
    for tier, results in pairs(db.resultsByID or {}) do
        local items = {}
        for id, count in pairs(results) do items[#items + 1] = id .. ":" .. count end
        if #items > 0 then Net.SendList("T", tier, items) end
    end
    local byTier = {}
    for key, seen in pairs(db.skillups or {}) do
        local tier, colour = key:match("^(%d+) (%a+)$")
        if tier then
            byTier[tier] = byTier[tier] or {}
            table.insert(byTier[tier], ("%s:%d/%d"):format(colour, seen.ups, seen.tries))
        end
    end
    for tier, items in pairs(byTier) do Net.SendList("U", tier, items) end
    for mapID, cells in pairs(db.drops or {}) do
        local items = {}
        for cell, count in pairs(cells) do items[#items + 1] = cell .. ":" .. count end
        if #items > 0 then Net.SendList("P", mapID, items) end
    end
    for _, pin in pairs(db.libraryPins or {}) do
        Net.Send("L", pin.mapID, ("%.3f"):format(pin.x), ("%.3f"):format(pin.y), pin.name)
    end
end

-- Send after a change, but at most once a minute.
local sendPending
SK.Listen("MY_DATA_CHANGED", function()
    if sendPending then return end
    sendPending = true
    C_Timer.After(60, function()
        sendPending = false
        SK.SendMyData()
    end)
end)

-- Everyone sends their data when someone new says hello, so newcomers
-- catch up. Spread out to avoid everyone answering at once.
Net.Handle("Q", function()
    C_Timer.After(5 + math.random() * 20, SK.SendMyData)
end)

SK.Listen("NET_READY", function()
    -- Forget players not heard from in a month.
    local cutoff = time() - KEEP_DAYS * 86400
    for name, entry in pairs(SK.db.community or {}) do
        if (entry.at or 0) < cutoff then SK.db.community[name] = nil end
    end
    C_Timer.After(20, SK.SendMyData)
end)
