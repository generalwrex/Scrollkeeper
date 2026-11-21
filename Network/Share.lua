-- Scrollkeeper: Network/Share.lua
-- Sharing what you've learned, and adding up what others share.
--
--   T|tier#part|itemID:count,...     what your deciphers of that tier became
--   U|tier#part|color:ups/tries,... your skill-ups by color at that tier
--   L|mapID|x|y|name                 a library you've used Study in
--   P|mapID#part|cell:count,...      where you've looted untranslated scrolls
--   K|mapID#part|cell:count,...      where you've looted books for the librarians
--   D|mapID#part|tier:count,...      untranslated scrolls looted per zone, by tier (1.1.5)
--   I|0#part|itemID,...              item IDs you've learned are books
--   J|mapID#part|cell:itemID,...     which book was found at each book spot (1.2.2)
--   E|mapID#part|cell:tier:count,... which tier dropped at each scroll spot (1.2.2)
--   W|instance|x|y|name              a library spot as a world position
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
--                          skillups = {[tier] = {[color] = {ups, tries}}},
--                          drops = {[mapID] = {[cell] = n}} }
------------------------------------------------------------------------

local function Entry(sender)
    SK.db.community = SK.db.community or {}
    local entry = SK.db.community[sender]
    if not entry then
        entry = { results = {}, skillups = {}, drops = {}, books = {} }
        SK.db.community[sender] = entry
    end
    entry.books = entry.books or {}
    entry.dropTiers = entry.dropTiers or {}
    entry.bookItems = entry.bookItems or {}
    entry.cellTiers = entry.cellTiers or {}
    entry.at = time()
    local peer = SK.peers and SK.peers[sender]
    if peer and peer.exportID then entry.exportID = peer.exportID end
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
    for color, ups, tries in (f[2] or ""):gmatch("(%a+):(%d+)/(%d+)") do
        ups, tries = tonumber(ups), tonumber(tries)
        if tries > 0 and tries <= MAX_COUNT and ups <= tries then list[color] = { ups, tries } end
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

Net.Handle("D", function(sender, f)
    local mapID, part = Head(f[1])
    if not (mapID and part) then return end
    local tiers = Target(Entry(sender).dropTiers, mapID, part)
    for tier, count in (f[2] or ""):gmatch("(%d+):(%d+)") do
        tier, count = tonumber(tier), tonumber(count)
        if SK.TIER_RESULTS[tier] and count > 0 and count <= MAX_COUNT then tiers[tier] = count end
    end
    SK.Send("DROPS_CHANGED")
end)

Net.Handle("K", function(sender, f)
    local mapID, part = Head(f[1])
    if not (mapID and part) then return end
    local cells = Target(Entry(sender).books, mapID, part)
    for cell, count in (f[2] or ""):gmatch("(%d+%.%d+):(%d+)") do
        count = tonumber(count)
        if count > 0 and count <= MAX_COUNT and SK.CellCenter(cell) then cells[cell] = count end
    end
    SK.Send("DROPS_CHANGED")
end)

Net.Handle("J", function(sender, f)
    local mapID, part = Head(f[1])
    if not (mapID and part) then return end
    local cells = Target(Entry(sender).bookItems, mapID, part)
    for cell, itemID in (f[2] or ""):gmatch("(%d+%.%d+):(%d+)") do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 and SK.CellCenter(cell) then cells[cell] = itemID end
    end
    SK.Send("DROPS_CHANGED")
end)

Net.Handle("E", function(sender, f)
    local mapID, part = Head(f[1])
    if not (mapID and part) then return end
    local cells = Target(Entry(sender).cellTiers, mapID, part)
    for cell, tier, count in (f[2] or ""):gmatch("(%d+%.%d+):(%d+):(%d+)") do
        tier, count = tonumber(tier), tonumber(count)
        if SK.TIER_RESULTS[tier] and count > 0 and count <= MAX_COUNT and SK.CellCenter(cell) then
            cells[cell] = cells[cell] or {}
            cells[cell][tier] = count
        end
    end
    SK.Send("DROPS_CHANGED")
end)

-- How often their Comprehend Scroll backfired, by tier.
Net.Handle("B", function(sender, f)
    local entry = Entry(sender)
    entry.backfires = {}
    for tier, b, t in (f[2] or ""):gmatch("(%d+):(%d+)/(%d+)") do
        tier, b, t = tonumber(tier), tonumber(b), tonumber(t)
        if SK.TIER_RESULTS[tier] and t > 0 and t <= MAX_COUNT and b <= t then entry.backfires[tier] = { b = b, t = t } end
    end
end)

-- Books others have learned: learn them too (a few hundred at most).
Net.Handle("I", function(sender, f)
    SK.db.bookIDs = SK.db.bookIDs or {}
    local known = 0
    for _ in pairs(SK.db.bookIDs) do known = known + 1 end
    for id in (f[2] or ""):gmatch("(%d+)") do
        id = tonumber(id)
        if known >= 500 then break end
        if id and id > 0 and not SK.db.bookIDs[id] then
            SK.db.bookIDs[id] = true
            known = known + 1
        end
    end
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

-- W: a library spot as a world position (instance, x, y in yards, name).
Net.Handle("W", function(sender, f)
    local inst, x, y, name = tonumber(f[1]), tonumber(f[2]), tonumber(f[3]), f[4]
    if not (inst and x and y and name and name ~= "") then return end
    if math.abs(x) > 100000 or math.abs(y) > 100000 then return end
    SK.db.sharedLibraries = SK.db.sharedLibraries or {}
    local key = ("%d_%d_%d"):format(inst, math.floor(x / 10), math.floor(y / 10))
    local entry = SK.db.sharedLibraries[key] or { inst = inst, x = x, y = y, name = name, from = {} }
    entry.from[sender] = true
    SK.db.sharedLibraries[key] = entry
    SK.Send("DROPS_CHANGED")
end)

------------------------------------------------------------------------
-- Adding it all up (other players + you)
------------------------------------------------------------------------

-- Community results for a tier: list of { itemID, name, count, share } and the total.
-- Shipped community data (Data/Community.lua), minus your own export:
-- your own numbers already count as yours.
function SK.ShippedCommunity()
    local list = {}
    for exportID, entry in pairs(SK.COMMUNITY_DATA or {}) do
        if exportID ~= SK.db.exportID then list[#list + 1] = entry end
    end
    return list
end

function SK.CommunityOdds(tier)
    local totals, total, players = {}, 0, 0
    local function Add(results)
        for id, count in pairs(results or {}) do
            -- Older versions sometimes logged other loot (a recipe, water)
            -- as a result; leave those out.
            if SK.IsDecipherResult(id) then
                totals[id] = (totals[id] or 0) + count
                total = total + count
            end
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
    for _, entry in ipairs(SK.ShippedCommunity()) do
        if entry.results and entry.results[tier] and next(entry.results[tier]) then
            Add(entry.results[tier])
            players = players + 1
        end
    end

    local list = {}
    for id, count in pairs(totals) do
        local shippedName
        for _, entry in ipairs(SK.ShippedCommunity()) do
            shippedName = shippedName or (entry.names and entry.names[id])
        end
        local name = (SK.db.itemNames and SK.db.itemNames[id]) or (SK.demoNames and SK.demoNames[id]) or shippedName
            or (C_Item and SK.Try(C_Item.GetItemNameByID, id)) or ("item " .. id)
        list[#list + 1] = { itemID = id, name = name, count = count, share = count / total }
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list, total, players
end

-- Drop cells for a map, yours and everyone's: cells[cell] = { mine, others }.
-- kind "books" gives book spots instead of scroll spots.
function SK.DropCells(mapID, kind)
    local field = kind == "books" and "books" or "drops"
    local myTable = kind == "books" and SK.db.bookDrops or SK.db.drops
    local cells = {}
    for cell, count in pairs(myTable and myTable[mapID] or {}) do
        cells[cell] = { mine = count, others = 0 }
    end
    local function AddOthers(drops)
        for cell, count in pairs(drops and drops[mapID] or {}) do
            cells[cell] = cells[cell] or { mine = 0, others = 0 }
            cells[cell].others = cells[cell].others + count
        end
    end
    for _, entry in pairs(SK.db.community or {}) do AddOthers(entry[field]) end
    for _, peer in pairs(SK.demoCommunity or {}) do AddOthers(peer[field]) end
    for _, entry in ipairs(SK.ShippedCommunity()) do AddOthers(entry[field]) end
    return cells
end

-- Which tiers dropped at these spots of a map (yours and everyone's):
-- { [tier] = count }, or nil if nobody recorded it per spot.
function SK.TiersAt(mapID, cellList)
    local wanted, totals, any = {}, {}, false
    for _, cell in ipairs(cellList) do wanted[cell] = true end
    local function Add(byMap)
        for cell, tiers in pairs(byMap and byMap[mapID] or {}) do
            if wanted[cell] then
                for tier, count in pairs(tiers) do totals[tier] = (totals[tier] or 0) + count; any = true end
            end
        end
    end
    Add(SK.db.cellTiers)
    for _, entry in pairs(SK.db.community or {}) do Add(entry.cellTiers) end
    for _, entry in ipairs(SK.ShippedCommunity()) do Add(entry.cellTiers) end
    return any and totals or nil
end

-- Which tiers dropped anywhere in a zone (yours and everyone's): { [tier] = count } or nil.
function SK.TiersInZone(mapID)
    local totals, any = {}, false
    local function Add(byMap)
        for tier, count in pairs(byMap and byMap[mapID] or {}) do totals[tier] = (totals[tier] or 0) + count; any = true end
    end
    Add(SK.db.dropTiers)
    for _, entry in pairs(SK.db.community or {}) do Add(entry.dropTiers) end
    for _, entry in ipairs(SK.ShippedCommunity()) do Add(entry.dropTiers) end
    return any and totals or nil
end

-- Which book sits at a book spot: its item ID, from your finds or anyone's
-- (shared, or shipped with the addon). nil if nobody said.
function SK.BookAt(mapID, cell)
    local mine = SK.db.bookItems and SK.db.bookItems[mapID]
    if mine and mine[cell] then return mine[cell] end
    for _, entry in pairs(SK.db.community or {}) do
        local cells = entry.bookItems and entry.bookItems[mapID]
        if cells and cells[cell] then return cells[cell] end
    end
    for _, entry in ipairs(SK.ShippedCommunity()) do
        local cells = entry.bookItems and entry.bookItems[mapID]
        if cells and cells[cell] then return cells[cell] end
    end
end

-- Libraries to pin on a map: list of { x, y, name, mine, known, count }.
-- Library spots are kept as world positions and placed on whichever
-- map is open (city, zone or continent).
function SK.LibraryPins(mapID)
    local pins, seen = {}, {}
    local function Add(entry, x, y)
        if not x then return end
        -- One pin per spot, even if it's known, yours and shared.
        local key = ("%.2f:%.2f"):format(x, y)
        if seen[key] then
            local pin = seen[key]
            pin.mine = pin.mine or entry.mine
            pin.count = (pin.count or 0) + (entry.count or 0)
            return
        end
        entry.x, entry.y = x, y
        seen[key] = entry
        pins[#pins + 1] = entry
    end
    local function Place(pin)
        if pin.inst then return SK.WorldToMap(pin.inst, pin.x, pin.y, mapID) end
        if pin.mapID == mapID then return pin.x, pin.y end   -- older saved format
    end

    -- Only your faction's library: the other one is no use to you. Saved
    -- and shared spots near the other faction's library are left out too.
    local faction = UnitFactionGroup and SK.Known(UnitFactionGroup("player"))
    local others = {}
    for _, library in ipairs(SK.KnownLibraries and SK.KnownLibraries() or {}) do
        if faction and library.side and library.side ~= faction then others[#others + 1] = library end
    end
    local function OtherSide(pin)
        for _, library in ipairs(others) do
            if pin.name and pin.name == library.name then return true end
            if pin.inst and pin.inst == library.inst and pin.x and pin.y
                and (pin.x - library.x) ^ 2 + (pin.y - library.y) ^ 2 < 150 ^ 2 then return true end
        end
        return false
    end

    for _, library in ipairs(SK.KnownLibraries and SK.KnownLibraries() or {}) do
        if not OtherSide(library) then Add({ name = library.name, known = true }, Place(library)) end
    end
    for _, pin in pairs(SK.db.libraryPins or {}) do
        if not OtherSide(pin) then Add({ name = pin.name, mine = true }, Place(pin)) end
    end
    for _, pin in pairs(SK.db.sharedLibraries or {}) do
        if not OtherSide(pin) then
            local count = 0
            for _ in pairs(pin.from or {}) do count = count + 1 end
            Add({ name = pin.name, count = count }, Place(pin))
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
        local tier, color = key:match("^(%d+) (%a+)$")
        if tier then
            byTier[tier] = byTier[tier] or {}
            table.insert(byTier[tier], ("%s:%d/%d"):format(color, seen.ups, seen.tries))
        end
    end
    for tier, items in pairs(byTier) do Net.SendList("U", tier, items) end
    for mapID, cells in pairs(db.drops or {}) do
        local items = {}
        for cell, count in pairs(cells) do items[#items + 1] = cell .. ":" .. count end
        if #items > 0 then Net.SendList("P", mapID, items) end
    end
    for mapID, cells in pairs(db.bookDrops or {}) do
        local items = {}
        for cell, count in pairs(cells) do items[#items + 1] = cell .. ":" .. count end
        if #items > 0 then Net.SendList("K", mapID, items) end
    end
    for mapID, tiers in pairs(db.dropTiers or {}) do
        local items = {}
        for tier, count in pairs(tiers) do items[#items + 1] = tier .. ":" .. count end
        if #items > 0 then Net.SendList("D", mapID, items) end
    end
    for mapID, cells in pairs(db.cellTiers or {}) do
        local items = {}
        for cell, tiers in pairs(cells) do
            for tier, count in pairs(tiers) do items[#items + 1] = cell .. ":" .. tier .. ":" .. count end
        end
        if #items > 0 then Net.SendList("E", mapID, items) end
    end
    for mapID, cells in pairs(db.bookItems or {}) do
        local items = {}
        for cell, itemID in pairs(cells) do items[#items + 1] = cell .. ":" .. itemID end
        if #items > 0 then Net.SendList("J", mapID, items) end
    end
    local backfires = {}
    for tier, seen in pairs(db.backfires or {}) do
        if (seen.t or 0) > 0 then backfires[#backfires + 1] = ("%d:%d/%d"):format(tier, seen.b or 0, seen.t) end
    end
    if #backfires > 0 then Net.Send("B", "0", table.concat(backfires, ",")) end
    local bookIDs = {}
    for id in pairs(db.bookIDs or {}) do bookIDs[#bookIDs + 1] = tostring(id) end
    if #bookIDs > 0 then Net.SendList("I", 0, bookIDs) end
    for _, pin in pairs(db.libraryPins or {}) do
        if pin.inst then
            Net.Send("W", pin.inst, ("%.1f"):format(pin.x), ("%.1f"):format(pin.y), pin.name)
        elseif pin.mapID then
            Net.Send("L", pin.mapID, ("%.3f"):format(pin.x), ("%.3f"):format(pin.y), pin.name)
        end
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

-- When someone new asks "who's there?", guild and group answer with their
-- data so newcomers catch up. On the public channel (150+ players) that
-- would be thousands of messages per login: there each of us sends our
-- data at most once every 30 minutes (plus on login and when it changes).
local lastDataForChannel = 0
-- (A friend's whispered ask counts like the channel: our data still goes
-- to everyone, so it must not go out every time someone pings.)
local SMALL = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }
Net.Handle("Q", function(_, _, source)
    if not SMALL[source] then
        if time() - lastDataForChannel < 30 * 60 then return end
        lastDataForChannel = time()
        C_Timer.After(20 + math.random() * 100, SK.SendMyData)
        return
    end
    -- Only to where they asked (their guild or group): not the public
    -- channel too, or every guildie's login would flood it.
    C_Timer.After(5 + math.random() * 20, function()
        Net.onlyTo = source
        SK.Safely("send data", SK.SendMyData)
        Net.onlyTo = nil
    end)
end)

SK.Listen("NET_READY", function()
    -- Forget players not heard from in a month.
    local cutoff = time() - KEEP_DAYS * 86400
    for name, entry in pairs(SK.db.community or {}) do
        if (entry.at or 0) < cutoff then SK.db.community[name] = nil end
    end
    C_Timer.After(20, SK.SendMyData)
end)
