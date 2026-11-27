-- Scrollkeeper: UI/Doors.lua
-- Doorways (/sk doors): getting somewhere with Scroll of Liminal Passage.
--
-- The scroll teleports a mage to a group member, as long as both are
-- resting (an inn or a city). So to reach Booty Bay you need someone
-- resting in Booty Bay to group with. The window:
--   left    places with an inn, neutral towns first; capitals you can
--           teleport to yourself are greyed out
--   right   hosts for the place you picked: Scrollkeeper users who offer
--           to be a "door" first (one click: they invite you, you accept
--           by itself), then anyone /who finds there (a whisper ready to
--           send; they need no addon)
--   bottom  one button that does the next step: Ask, Teleport, Leave group
--
-- Network (doors are opt-in: "Be a door"):
--   G|place|scrolls|mapID|auto|x|y  my door: where I rest ("" = not one now),
--                                Liminal Passage scrolls carried, the
--                                zone's map ID, "1" if I invite by myself,
--                                and where on that map (0-100, 1.2.2+)
--   DA                           whisper: "can I come to you?"
--   DY / DN                      whisper: "inviting you" / "not right now"

local _, SK = ...
local L = SK.L
local Net = SK.Net

SK.LIMINAL_PASSAGE = 213548
-- Mage city teleports (whichever you know show in the Teleport pop-up).
SK.MAGE_TELEPORTS = { 3561, 3562, 3565, 32271, 49359, 3567, 3563, 3566, 32272, 49358 }
local PLACE_ROWS, HOST_ROWS = 27, 9
local LEFT_W, RIGHT_W = 200, 300
local INVITES_PER_10MIN = 6

------------------------------------------------------------------------
-- Places with an inn. map = the zone's map ID (the game gives its name in
-- your language); side = who can rest there.
------------------------------------------------------------------------

local PLACES = {
    -- neutral towns
    { town = "Booty Bay", map = 1434, side = "both" },
    { town = "Gadgetzan", map = 1446, side = "both" },
    { town = "Ratchet", map = 1413, side = "both" },
    { town = "Everlook", map = 1452, side = "both" },
    { town = "Cenarion Hold", map = 1451, side = "both" },
    { town = "Nighthaven", map = 1450, side = "both" },
    -- Elderwild, in Forever's new Hyjal (its map ID isn't known yet: zone =
    -- its name for /who). Thanks Curnil.
    { town = "Elderwild", zone = "Hyjal", side = "both", continent = "Kalimdor" },
    -- Forever's own places with an inn (sides from lostgamer.io's inn list;
    -- Riverglades is map 2548).
    { town = "Powderfuse Port", map = 2548, side = "both", x = 78, y = 53 },
    { town = "Farholde Keep", map = 2548, side = "Alliance" },
    { town = "Valanaar", zone = "Valanaar", side = "Alliance", continent = "Forever" },
    { town = "Shen'dralas", zone = "Shen'dralas", side = "Alliance", continent = "Kalimdor" },
    { town = "Rog'mar", map = 2548, side = "Horde" },
    -- Alliance
    { town = "Goldshire", map = 1429, side = "Alliance", x = 43.8, y = 65.8 },
    { town = "Sentinel Hill", map = 1436, side = "Alliance" },
    { town = "Lakeshire", map = 1433, side = "Alliance" },
    { town = "Darkshire", map = 1431, side = "Alliance" },
    { town = "Kharanos", map = 1426, side = "Alliance" },
    { town = "Thelsamar", map = 1432, side = "Alliance" },
    { town = "Menethil Harbor", map = 1437, side = "Alliance" },
    { town = "Southshore", map = 1424, side = "Alliance" },
    { town = "Refuge Pointe", map = 1417, side = "Alliance" },
    { town = "Aerie Peak", map = 1425, side = "Alliance" },
    { town = "Morgan's Vigil", map = 1428, side = "Alliance" },
    { town = "Dolanaar", map = 1438, side = "Alliance" },
    { town = "Auberdine", map = 1439, side = "Alliance" },
    { town = "Astranaar", map = 1440, side = "Alliance", x = 37.0, y = 49.2 },
    { town = "Stonetalon Peak", map = 1442, side = "Alliance" },
    { town = "Nijel's Point", map = 1443, side = "Alliance" },
    { town = "Theramore Isle", map = 1445, side = "Alliance", teleport = 49359 },
    { town = "Feathermoon Stronghold", map = 1444, side = "Alliance" },
    -- Horde
    { town = "Razor Hill", map = 1411, side = "Horde" },
    { town = "Bloodhoof Village", map = 1412, side = "Horde" },
    { town = "The Crossroads", map = 1413, side = "Horde" },
    { town = "Camp Taurajo", map = 1413, side = "Horde" },
    { town = "Brill", map = 1420, side = "Horde" },
    { town = "The Sepulcher", map = 1421, side = "Horde" },
    { town = "Tarren Mill", map = 1424, side = "Horde" },
    { town = "Hammerfall", map = 1417, side = "Horde", x = 73.8, y = 32.6 },
    { town = "Grom'gol Base Camp", map = 1434, side = "Horde" },
    { town = "Kargath", map = 1418, side = "Horde" },
    { town = "Stonard", map = 1435, side = "Horde", teleport = 49358 },
    { town = "Splintertree Post", map = 1440, side = "Horde" },
    { town = "Sun Rock Retreat", map = 1442, side = "Horde" },
    { town = "Shadowprey Village", map = 1443, side = "Horde" },
    { town = "Freewind Post", map = 1441, side = "Horde" },
    { town = "Camp Mojache", map = 1444, side = "Horde" },
    { town = "Brackenwall Village", map = 1445, side = "Horde" },
    { town = "Revantusk Village", map = 1425, side = "Horde" },
    -- capitals (teleport = the mage spell that already goes there)
    { town = "Stormwind City", map = 1453, side = "Alliance", capital = true, teleport = 3561, x = 52.6, y = 65.6 },
    { town = "Ironforge", map = 1455, side = "Alliance", capital = true, teleport = 3562 },
    { town = "Darnassus", map = 1457, side = "Alliance", capital = true, teleport = 3565 },
    { town = "Orgrimmar", map = 1454, side = "Horde", capital = true, teleport = 3567 },
    { town = "Thunder Bluff", map = 1456, side = "Horde", capital = true, teleport = 3566 },
    { town = "Undercity", map = 1458, side = "Horde", capital = true, teleport = 3563, x = 67.8, y = 38.2 },
}
SK.DOOR_PLACES = PLACES

local function ZoneName(mapID)
    local info = C_Map and C_Map.GetMapInfo and SK.Try(C_Map.GetMapInfo, mapID)
    return type(info) == "table" and info.name or nil
end

-- The continent a map is on (its name), from the game's map tree.
local continentOf = {}
local function ContinentName(mapID)
    if not mapID then return nil end
    if continentOf[mapID] ~= nil then return continentOf[mapID] or nil end
    local id, name = mapID, nil
    for _ = 1, 6 do
        local info = C_Map and C_Map.GetMapInfo and SK.Try(C_Map.GetMapInfo, id)
        if type(info) ~= "table" then break end
        if info.mapType == ((Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2) then name = info.name break end
        id = info.parentMapID
        if not id or id == 0 then break end
    end
    continentOf[mapID] = name or false
    return name
end

-- A place's zone name: from its map ID (in your language), else the
-- name it was listed with.
local function PlaceZone(place)
    return place and (place.map and ZoneName(place.map) or place.zone) or nil
end

local function KnowsSpell(id)
    if not id then return false end
    return (IsPlayerSpell and SK.Try(IsPlayerSpell, id)) or (IsSpellKnown and SK.Try(IsSpellKnown, id)) or false
end

------------------------------------------------------------------------
-- My door
------------------------------------------------------------------------

function SK.LiminalCount()
    local count = SK.Try(C_Item and C_Item.GetItemCount, SK.LIMINAL_PASSAGE) or SK.Try(GetItemCount, SK.LIMINAL_PASSAGE)
    return tonumber(count) or 0
end

local function Resting() return IsResting and IsResting() and true or false end

-- Where I'm resting, in words: "Goldshire, Elwynn Forest" or "Ironforge".
local function RestingPlace()
    if not Resting() then return nil end
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if zone == "" then return nil end
    if sub ~= "" and sub ~= zone then return sub .. ", " .. zone end
    return zone
end

function SK.MyDoorPlace()
    if not SK.db.liminalDoor or SK.InCombat() then return nil end
    return RestingPlace()
end

local function MyMapID()
    return C_Map and C_Map.GetBestMapForUnit and SK.Try(C_Map.GetBestMapForUnit, "player") or ""
end

-- Where I am on my zone's map, rounded to 1% (only sent while a door).
local function MyMapSpot()
    local _, x, y = SK.PlayerMapPosition and SK.PlayerMapPosition()
    if not (x and y) then return "", "" end
    return ("%d"):format(x * 100 + 0.5), ("%d"):format(y * 100 + 0.5)
end

local lastSent
local function SendDoor(force)
    local place = SK.MyDoorPlace() or ""
    local auto = SK.db.doorAutoInvite and "1" or ""
    local x, y = "", ""
    if place ~= "" then x, y = MyMapSpot() end
    local text = table.concat({ place, SK.LiminalCount(), tostring(MyMapID()), auto, x, y }, "#")
    if text == lastSent and not force then return end
    lastSent = text
    Net.Send("G", place, SK.LiminalCount(), place ~= "" and MyMapID() or "", auto, x, y)
end
SK.SendDoor = SendDoor

local doorQueued
local function DoorSoon()
    if doorQueued then return end
    doorQueued = true
    C_Timer.After(4, function() doorQueued = false SK.Safely("door", SendDoor) end)
end
SK.On("PLAYER_UPDATE_RESTING", DoorSoon)
-- Anywhere you rest: remember where (for the map, and new places).
-- (Also after logging in or a /reload while already resting, and when you
-- walk into a new subzone, since resting doesn't change then.)
local function LearnMySpot()
    C_Timer.After(2, function()
        local place = RestingPlace()
        if not place then return end
        local x, y = MyMapSpot()
        SK.Safely("inn spot", SK.LearnInnSpot, { place = place, map = tonumber(MyMapID()), x = tonumber(x), y = tonumber(y) })
    end)
end
SK.On("PLAYER_UPDATE_RESTING", LearnMySpot)
SK.On("PLAYER_ENTERING_WORLD", LearnMySpot)
SK.On("ZONE_CHANGED", LearnMySpot)
SK.On("ZONE_CHANGED_NEW_AREA", DoorSoon)
SK.On("ZONE_CHANGED", DoorSoon)
SK.On("PLAYER_REGEN_ENABLED", DoorSoon)
SK.Listen("BAGS_CHANGED", DoorSoon)
SK.Listen("NET_READY", function()
    C_Timer.After(30, function() SK.Safely("door", SendDoor, true) end)
    C_Timer.NewTicker(5 * 60, function() SK.Safely("door", SendDoor, true) end)
end)
-- Answer "who's there?" with our door (on the public channel at most
-- every 10 minutes, and only if we are one: no door, nothing to say).
local lastDoorAnswer = 0
Net.Handle("Q", function(_, _, source)
    if not SK.db.liminalDoor then return end
    local small = source == "GUILD" or source == "PARTY" or source == "RAID" or source == "INSTANCE_CHAT"
    if not small and time() - lastDoorAnswer < 600 then return end
    lastDoorAnswer = time()
    C_Timer.After(6 + math.random() * 20, function() SK.Safely("door", SendDoor, true) end)
end)

------------------------------------------------------------------------
-- Everyone's doors
------------------------------------------------------------------------

-- SK.doors[sender] = { place, scrolls, map, auto, at }
SK.doors = {}

Net.Handle("G", function(sender, f)
    local place = tostring(f[1] or ""):sub(1, 80)
    SK.doors[sender] = {
        place = place ~= "" and place or nil, scrolls = math.min(tonumber(f[2]) or 0, 99),
        map = tonumber(f[3]), auto = f[4] == "1", at = time(),
        x = tonumber(f[5]), y = tonumber(f[6]),
    }
    local door = SK.doors[sender]
    if door.x and (door.x < 0 or door.x > 100) then door.x = nil end
    if door.y and (door.y < 0 or door.y > 100) then door.y = nil end
    if SK.LearnInnSpot then SK.Safely("inn spot", SK.LearnInnSpot, door) end
    SK.Send("DOORS_CHANGED")
end)

local DEMO_DOORS = {
    { name = "Kaelith", place = "Booty Bay, Stranglethorn Vale", map = 1434, auto = true, x = 27, y = 77 },
    { name = "Brannoc", place = "Gadgetzan, Tanaris", map = 1446, x = 52, y = 28 },
    { name = "Mirelle", place = "Goldshire, Elwynn Forest", map = 1429, auto = true, x = 44, y = 66 },
}

-- Every open door you can reach: list of { sender, short, place, scrolls, map, auto, demo }.
function SK.OpenDoors()
    local list, fresh = {}, {}
    for _, entry in ipairs(SK.PeerList and SK.PeerList() or {}) do fresh[entry.sender] = true end
    for sender, door in pairs(SK.doors) do
        if door.place and fresh[sender] and not Net.IsMe(sender) and time() - door.at < 15 * 60 then
            list[#list + 1] = { sender = sender, short = Net.ShortName(sender), place = door.place,
                scrolls = door.scrolls, map = door.map, auto = door.auto, x = door.x, y = door.y }
        end
    end
    if SK.demoCommunity then
        for _, demo in ipairs(DEMO_DOORS) do
            list[#list + 1] = { sender = demo.name, short = demo.name, place = demo.place, scrolls = 0,
                map = demo.map, auto = demo.auto, demo = true, x = demo.x, y = demo.y }
        end
    end
    return list
end

-- Which place a door is at: the town its place text starts with, else the
-- first place in its zone.
local function PlaceOfDoor(door)
    local first
    for _, place in ipairs(PLACES) do
        if door.place:find(place.town, 1, true) == 1 then return place end
        if not first and door.map and place.map == door.map then first = place end
    end
    if not first then
        -- An old door message without a map ID: match the zone by name.
        for _, place in ipairs(PLACES) do
            local zone = PlaceZone(place)
            if zone and door.place:find(zone, 1, true) then return place end
        end
    end
    return first
end

------------------------------------------------------------------------
-- The places list
------------------------------------------------------------------------

local selected      -- the PLACES entry picked, or "all"
local whoResults    -- { place = entry, at = time(), people = {...} }

------------------------------------------------------------------------
-- Inn spots on the map: where to stand in each town. Some come with the
-- list (x, y above); the rest are learned from doors (theirs and yours),
-- in SK.db.innSpots[town] = { map, x, y }.
------------------------------------------------------------------------

-- Places you can rest that aren't in the list (Forever keeps adding
-- them): found by you or by Scrollkeeper doors (same faction: the
-- channel is), kept in SK.db.foundInns[town] = { zone, map, x, y, side }.
local function AddFound(town, f)
    for _, place in ipairs(PLACES) do if place.town == town then return place end end
    local place = { town = town, map = f.map, zone = f.zone, side = f.side or "both", found = true }
    PLACES[#PLACES + 1] = place
    return place
end

local function FoundInn(door)
    local town, zone = tostring(door.place):match("^([^,]+), (.+)$")
    town = town or door.place
    if not town or town == "" then return nil end
    SK.db.foundInns = type(SK.db.foundInns) == "table" and SK.db.foundInns or {}
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    local f = SK.db.foundInns[town] or { zone = zone or town, map = door.map, side = mine or "both" }
    if f.side ~= "both" and mine and f.side ~= mine then f.side = "both" end
    f.map = f.map or door.map
    SK.db.foundInns[town] = f
    return AddFound(town, f)
end

SK.Listen("READY", function()
    for town, f in pairs(type(SK.db.foundInns) == "table" and SK.db.foundInns or {}) do
        if type(f) == "table" then AddFound(town, f) end
    end
end)

function SK.LearnInnSpot(door)
    if not (door and door.place) then return end
    local place = PlaceOfDoor(door)
    if not place then place = FoundInn(door) end
    if not (place and door.map and door.x and door.y) or place.x then return end
    if place.map and place.map ~= door.map then return end
    SK.db.innSpots = type(SK.db.innSpots) == "table" and SK.db.innSpots or {}
    local have = SK.db.innSpots[place.town]
    if have and have.map == door.map then return end
    SK.db.innSpots[place.town] = { map = door.map, x = door.x, y = door.y }
end

-- The inns on a map you can use: { town, x, y (0-1), doors, capital }.
function SK.InnPins(mapID)
    local out = {}
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    local open = {}
    for _, door in ipairs(SK.OpenDoors()) do
        local place = PlaceOfDoor(door)
        if place then open[place] = (open[place] or 0) + 1 end
    end
    local spots = type(SK.db.innSpots) == "table" and SK.db.innSpots or {}
    for _, place in ipairs(PLACES) do
        if place.side == "both" or not mine or place.side == mine then
            local spot = place.x and { map = place.map, x = place.x, y = place.y } or spots[place.town]
            if spot and spot.map == mapID then
                out[#out + 1] = { town = place.town, x = spot.x / 100, y = spot.y / 100, doors = open[place] or 0,
                    capital = place.capital }
            end
        end
    end
    return out
end

-- You, when you're a door right now (shown first, can't be picked).
local function MyDoor()
    local place = SK.MyDoorPlace()
    if not place then return nil end
    local me = (SK.PlayerFullName and SK.PlayerFullName()) or UnitName("player") or "?"
    return { place = place, map = C_Map and C_Map.GetBestMapForUnit and SK.Try(C_Map.GetBestMapForUnit, "player") or nil,
        sender = me, short = me, auto = SK.db.doorAutoInvite, mine = true }
end

function SK.DoorPlaces()
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    local counts = {}
    for _, door in ipairs(SK.OpenDoors()) do
        local place = PlaceOfDoor(door)
        if place then counts[place] = (counts[place] or 0) + 1 end
    end
    local me = MyDoor()
    local myPlace = me and PlaceOfDoor(me)
    if myPlace then counts[myPlace] = (counts[myPlace] or 0) + 1 end
    local list = {}
    for order, place in ipairs(PLACES) do
        if place.side == "both" or not mine or place.side == mine then
            list[#list + 1] = { place = place, doors = counts[place] or 0, order = order,
                own = KnowsSpell(place.teleport) and true or false }
        end
    end
    -- A to Z ("The Crossroads" under C); places you already have a
    -- teleport spell for go grey at the bottom. Door counts show next to each.
    local function Key(entry) return (entry.place.town:gsub("^The ", "")):lower() end
    table.sort(list, function(a, b)
        if a.own ~= b.own then return not a.own end
        return Key(a) < Key(b)
    end)
    return list
end

------------------------------------------------------------------------
-- Hosts for the picked place
------------------------------------------------------------------------

-- "guild", "friend" or nil: people you know go first and get a tag.
local function Relation(name, guild)
    if not name then return nil end
    local myGuild = GetGuildInfo and GetGuildInfo("player")
    if myGuild and guild and guild == myGuild then return "guild" end
    local short = Net.ShortName(name)
    if C_FriendList and C_FriendList.IsFriend and SK.Try(C_FriendList.IsFriend, short) then return "friend" end
    if C_FriendList and C_FriendList.GetFriendInfo and SK.Try(C_FriendList.GetFriendInfo, short) then return "friend" end
    return nil
end
SK.DoorRelation = Relation

function SK.DoorHosts()
    local list = {}
    for _, door in ipairs(SK.OpenDoors()) do
        if selected == "all" or PlaceOfDoor(door) == selected then
            local peer = SK.peers[door.sender]
            local relation = (peer and peer.source == "GUILD" and "guild") or Relation(door.sender)
            list[#list + 1] = { kind = "door", door = door, short = door.short, sender = door.sender, relation = relation }
        end
    end
    table.sort(list, function(a, b)
        if (a.relation and true or false) ~= (b.relation and true or false) then return a.relation and true or false end
        return a.short < b.short
    end)
    local me = MyDoor()
    if me and (selected == "all" or PlaceOfDoor(me) == selected) then
        table.insert(list, 1, { kind = "me", door = me, short = me.short, sender = me.sender })
    end
    if selected ~= "all" and whoResults and whoResults.place == selected then
        local doorNames = {}
        for _, host in ipairs(list) do doorNames[host.short:lower()] = true end
        for _, person in ipairs(whoResults.people) do
            if not doorNames[Net.ShortName(person.name):lower()] then
                list[#list + 1] = { kind = "who", short = Net.ShortName(person.name), target = person.name, who = person,
                    relation = person.relation }
            end
        end
    end
    return list
end

------------------------------------------------------------------------
-- /who: anyone in that zone. Results come back as WHO_LIST_UPDATE.
------------------------------------------------------------------------

local whoPending, lastWho, whoWindowsOpen = nil, 0, {}
local WHO_WINDOWS = { "LFGWhoListFrame", "FriendsFrame", "WhoFrame", "LFGParentFrame", "LFGBrowseFrame", "LFGListingFrame", "PVEFrame" }
local WHO_COOLDOWN = 15

function SK.DoorWhoReady() return time() - lastWho >= WHO_COOLDOWN end
-- The game opens a window with /who results (FriendsFrame, or Forever's
-- Looking For Group list). Note which were already open, to close only the
-- one our search opens.
local function NoteWhoWindows()
    if C_FriendList.SetWhoToUi then SK.Try(C_FriendList.SetWhoToUi, true) end
    whoWindowsOpen = {}
    for _, name in ipairs(WHO_WINDOWS) do
        local frame = _G[name]
        whoWindowsOpen[name] = type(frame) == "table" and frame.IsShown and frame:IsShown() or false
    end
end

local function CloseWhoWindows()
    C_Timer.After(0, function()
        for _, name in ipairs(WHO_WINDOWS) do
            local frame = _G[name]
            if type(frame) == "table" and frame.IsShown and frame:IsShown() and not whoWindowsOpen[name] then
                if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
            end
        end
    end)
end

local function SearchWho(place)
    if not (C_FriendList and C_FriendList.SendWho) or not SK.DoorWhoReady() then return end
    local zone = PlaceZone(place)
    if not zone then return end
    lastWho = time()
    whoPending = { kind = "zone", place = place }
    NoteWhoWindows()
    C_FriendList.SendWho(('z-"%s"'):format(zone))
    SK.Print(L["looking for players in %s..."]:format(zone))
end

-- Before whispering someone the zone search found, look them up again
-- (only them, in that zone): they may have moved on. done(person or nil,
-- checked) runs with what the game says; if it doesn't answer in a few
-- seconds (/who is throttled), done runs anyway with checked = false.
function SK.DoorRecheck(person, place, done)
    local zone = PlaceZone(place)
    if not (C_FriendList and C_FriendList.SendWho and zone) or whoPending then return done(person, false) end
    local pending = { kind = "check", name = person.name, place = place, done = done }
    whoPending = pending
    NoteWhoWindows()
    C_FriendList.SendWho(('n-"%s" z-"%s"'):format(Net.ShortName(person.name), zone))
    C_Timer.After(3, function()
        if whoPending == pending then whoPending = nil; done(person, false) end
    end)
end

SK.On("WHO_LIST_UPDATE", function()
    if not whoPending then return end
    local pending = whoPending
    whoPending = nil
    CloseWhoWindows()
    local place = pending.place
    local zone = PlaceZone(place)

    if pending.kind == "check" then
        local found
        for i = 1, (C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults()) or 0 do
            local info = C_FriendList.GetWhoInfo and C_FriendList.GetWhoInfo(i)
            if type(info) == "table" and info.fullName
                and Net.ShortName(info.fullName):lower() == Net.ShortName(pending.name):lower() then
                found = info
            end
        end
        -- Update (or drop) them in the list we show.
        local people = whoResults and whoResults.place == place and whoResults.people or {}
        for i = #people, 1, -1 do
            local person = people[i]
            if Net.ShortName(person.name):lower() == Net.ShortName(pending.name):lower() then
                if found then
                    person.area = found.area
                    person.inTown = place.capital or found.area == place.town
                else
                    table.remove(people, i)
                end
            end
        end
        local person
        if found then
            person = { name = found.fullName, level = found.level, class = found.classStr, area = found.area,
                inTown = place.capital or found.area == place.town, city = place.capital,
                relation = Relation(found.fullName, found.fullGuildName) }
        end
        SK.Send("DOORS_CHANGED")
        pending.done(person, true)
        return
    end

    local me = SK.PlayerFullName and SK.PlayerFullName() or UnitName("player")
    local people = {}
    for i = 1, (C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults()) or 0 do
        local info = C_FriendList.GetWhoInfo and C_FriendList.GetWhoInfo(i)
        -- The search already asked for that zone; "area" is where in it they
        -- are (Forever gives the subzone: "Tarren Mill", "Darrow Hill").
        -- A capital is resting all over (the Rises, the Valley of Spirits...),
        -- and its search only finds people inside it: they all count.
        if type(info) == "table" and info.fullName and info.fullName ~= me then
            people[#people + 1] = { name = info.fullName, level = info.level, class = info.classStr, race = info.raceStr,
                area = info.area, inTown = place.capital or info.area == place.town, city = place.capital,
                relation = Relation(info.fullName, info.fullGuildName) }
        end
    end
    table.sort(people, function(a, b)
        if (a.inTown and true or false) ~= (b.inTown and true or false) then return a.inTown and true or false end
        if (a.relation and true or false) ~= (b.relation and true or false) then return a.relation and true or false end
        return (a.level or 0) > (b.level or 0)
    end)
    whoResults = { place = place, at = time(), people = people }
    SK.Send("DOORS_CHANGED")
end)

------------------------------------------------------------------------
-- The trip: ask, get invited (accepted by itself), teleport, leave.
------------------------------------------------------------------------

local trip   -- { short, target, kind, place, askedAt, teleported }

-- Who we watch after a door (the log notes their "ty" and the like).
local watching = {}   -- short name -> { at, role = "host"/"trip", joined }
local function Watch(short, role)
    watching[short:lower()] = { at = time(), role = role, name = short }
end

local function InGroupWith(short)
    return short and UnitInParty and SK.Known(UnitInParty(short)) and true or false
end

-- The whisper to someone /who found. Yours if you wrote one (Whisper
-- text... in the window), else ours. Yours can use:
--   {place}  the town or city ("an inn or a city" if they're elsewhere)
--   {zone}   the zone you searched
--   {name}   who you're whispering
--   {me}     your name
--   {scroll} a link to Scroll of Liminal Passage
function SK.DoorWhisper(place, info)
    info = info or {}
    local custom = SK.db and SK.db.doorWhisper
    if type(custom) == "string" and custom:find("%S") then
        local link = C_Item and select(2, SK.Try(C_Item.GetItemInfo, SK.LIMINAL_PASSAGE))
        local values = {
            place = place or L["an inn or a city"],
            zone = info.zone or place or "",
            name = info.name or "",
            me = SK.PlayerFullName and SK.PlayerFullName() or "",
            scroll = link or L["Scroll of Liminal Passage"],
        }
        return (custom:gsub("{(%a+)}", function(key) return values[key:lower()] end))
    end
    if place then
        return L["Hi! Could we group up for a sec? I've got a Scroll of Liminal Passage and can teleport to you while you're resting in %s. Invite me, or say ok and I'll invite you. I'll leave right after. Thanks!"]:format(place)
    end
    return L["Hi! Could we group up for a sec? I've got a Scroll of Liminal Passage and can teleport to you while you're resting at an inn or in a city. Invite me, or say ok and I'll invite you. I'll leave right after. Thanks!"]
end

-- The default, with {place} where the town goes, to start editing from.
local function DefaultTemplate()
    return (L["Hi! Could we group up for a sec? I've got a Scroll of Liminal Passage and can teleport to you while you're resting in %s. Invite me, or say ok and I'll invite you. I'll leave right after. Thanks!"]:gsub("%%s", "{place}"))
end

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_DOOR_WHISPER"] = {
        text = L["Your whisper to people Doorways finds. You can use:"] .. "\n|cffffd100{place}|r " .. L["the town"]
            .. "   |cffffd100{zone}|r " .. L["the zone"] .. "   |cffffd100{name}|r " .. L["who you whisper"]
            .. "\n|cffffd100{me}|r " .. L["you"] .. "   |cffffd100{scroll}|r " .. L["a link to the scroll"],
        button1 = SAVE or "Save",
        button2 = CANCEL or "Cancel",
        button3 = L["Default"],
        hasEditBox = true,
        maxLetters = 230,
        editBoxWidth = 420,
        OnShow = function(self)
            local box = self.editBox or self.EditBox
            if box then
                box:SetText(SK.db.doorWhisper or DefaultTemplate())
                box:HighlightText()
            end
        end,
        OnAccept = function(self)
            local box = self.editBox or self.EditBox
            local text = box and box:GetText() or ""
            SK.db.doorWhisper = text:find("%S") and text ~= DefaultTemplate() and text or nil
            SK.Print(L["whisper saved. It reads:"] .. " |cffff80ff" .. SK.DoorWhisper("Tarren Mill", { name = "Runey", zone = "Hillsbrad Foothills" }) .. "|r")
        end,
        OnAlt = function()
            SK.db.doorWhisper = nil
            SK.Print(L["whisper back to the default."])
        end,
        EditBoxOnEnterPressed = function(box)
            local popup = box:GetParent()
            if popup and popup.button1 then popup.button1:Click() end
        end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- Can I invite someone right now? (Not in a group, or leading one with room.)
local function RoomToInvite()
    if not (IsInGroup and IsInGroup()) then return true end
    if IsInRaid and IsInRaid() then return false end
    local leader = UnitIsGroupLeader and SK.Known(UnitIsGroupLeader("player"))
    local size = GetNumGroupMembers and GetNumGroupMembers() or 0
    return leader and size < 5 or false
end

-- Show the whole whisper in chat (only you see it: the chat box is too
-- narrow to read it), then open the chat box with it, ready to send.
local function OpenWhisper(target, text)
    if not ChatFrame_OpenChat then return end
    SK.Print(L["whisper to %s, press Enter to send it (or Escape to cancel):"]:format(Net.ShortName(target)))
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff80ff" .. text .. "|r") end
    ChatFrame_OpenChat(("/w %s %s"):format(target, text))
end

local Ask
function Ask(host)
    -- Someone the zone search found: check they're still there first.
    if host.kind == "who" and not host.rechecked and type(selected) == "table" then
        SK.Print(L["checking %s is still in %s..."]:format(host.short, PlaceZone(selected) or selected.town))
        SK.DoorRecheck(host.who, selected, function(person, checked)
            if checked and not person then
                SK.Print(L["%s isn't in %s anymore. Pick someone else."]:format(host.short, PlaceZone(selected) or selected.town))
                return
            end
            local again = { kind = "who", short = host.short, target = host.target, rechecked = true,
                who = person or host.who, relation = host.relation }
            Ask(again)
        end)
        return
    end
    if host.kind == "door" and host.door.demo then
        SK.Print(L["%s is a demo door: real ones invite you, and the invite is accepted for you."]:format(host.short))
        return
    end
    local target = host.target or SK.ContactName(host.sender)
    trip = { short = Net.ShortName(target), target = target, kind = host.kind, askedAt = time(),
        place = selected ~= "all" and selected or nil }
    if host.kind == "door" then
        Net.Whisper(target, "DA")
        SK.Print(L["asked %s to invite you. Accept the invite (Scrollkeeper does it for you), then click Teleport."]:format(trip.short))
    else
        -- Name the town only when /who says they're standing in it (their
        -- own words for it, so it's right in any language). Someone
        -- elsewhere in the zone gets the general version.
        trip.where = host.who and host.who.inTown
            and (trip.place and trip.place.capital and (PlaceZone(trip.place) or trip.place.town) or host.who.area)
        trip.info = { name = trip.short, zone = trip.place and (PlaceZone(trip.place) or trip.place.town) }
        -- Ask first, never invite out of the blue: the whisper offers both
        -- ways (they invite you, or they say ok and you click Invite).
        OpenWhisper(target, SK.DoorWhisper(trip.where, trip.info))
    end
    SK.Send("DOORS_CHANGED")
end

-- The game's answer to our invite, as a pattern for its "%s ..." text.
local function SystemPattern(text)
    if type(text) ~= "string" then return nil end
    return "^" .. text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
end

SK.On("CHAT_MSG_SYSTEM", function(message)
    message = SK.Known(message)
    if not (trip and trip.invited and type(message) == "string") then return end
    local function Matches(text)
        local pattern = SystemPattern(text)
        local name = pattern and message:match(pattern)
        return name and Net.ShortName(name):lower() == trip.short:lower()
    end
    if Matches(ERR_ALREADY_IN_GROUP_S) then
        SK.DoorLog(trip.short, L["was already in a group"], "problem")
        trip.invited = nil
        SK.Print(L["%s is in a group already, so they'll have to invite you."]:format(trip.short))
    elseif Matches(ERR_DECLINE_GROUP_S) then
        SK.DoorLog(trip.short, L["said no to your invite"], "problem")
        trip.invited = nil
        SK.Print(L["%s said no to the invite. Pick someone else."]:format(trip.short))
    end
end)

-- Accept the invite from the host we asked (only theirs, only for 3 minutes).
SK.On("PARTY_INVITE_REQUEST", function(inviter)
    inviter = SK.Known(inviter)
    if not (trip and trip.askedAt and time() - trip.askedAt < 180 and type(inviter) == "string") then return end
    if Net.ShortName(inviter):lower() ~= trip.short:lower() then return end
    if AcceptGroup then SK.Try(AcceptGroup) end
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    SK.Print(L["joined %s's group. Click Teleport when you're both resting."]:format(trip.short))
    SK.DoorLog(trip.short, L["you joined their group"], "ok")
    Watch(trip.short, "trip")
end)

-- Being a door: a mage who invites you while you rest gets in without the
-- invite box (setting doorAcceptMages). Others still get the usual box.
SK.On("PARTY_INVITE_REQUEST", function(inviter, ...)
    inviter = SK.Known(inviter)
    if SK.db.doorAcceptMages == false or not SK.MyDoorPlace() or type(inviter) ~= "string" then return end
    if trip and trip.askedAt and time() - trip.askedAt < 180 then return end   -- your own trip: handled above
    if IsInGroup and IsInGroup() then return end
    local guid
    for i = 1, select("#", ...) do
        local v = SK.Known((select(i, ...)))
        if type(v) == "string" and v:find("^Player%-") then guid = v end
    end
    local class = guid and GetPlayerInfoByGUID and select(2, SK.Try(GetPlayerInfoByGUID, guid))
    local short = Net.ShortName(inviter)
    if class ~= "MAGE" then return end
    if AcceptGroup then SK.Try(AcceptGroup) end
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    SK.Print(L["%s (a mage) invited you while you're a door: accepted."]:format(short))
    SK.DoorLog(short, L["invited you (a mage, while you're a door): accepted"], "ok")
    Watch(short, "host")
end)

-- Notice when the scroll was used, for the Leave group step.
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    unit, spellID = SK.Known(unit), SK.Known(spellID)
    if unit ~= "player" or not trip then return end
    local _, scrollSpell = SK.Try(C_Item and C_Item.GetItemSpell or GetItemSpell, SK.LIMINAL_PASSAGE)
    if scrollSpell and spellID == scrollSpell then
        trip.teleported = true
        SK.DoorLog(trip.short, L["you teleported to them"], "ok")
        SK.Send("DOORS_CHANGED")
    end
end)

SK.On("GROUP_LEFT", function()
    if trip and trip.teleported then trip = nil end
    SK.Send("DOORS_CHANGED")
end)

------------------------------------------------------------------------
-- Teleport pop-up: once you're grouped with a door, a small "Teleport to X"
-- button shows up by itself (setting doorTeleportPop), so you don't have to
-- dig the scroll out of your bags. Works however you got there: the
-- Doorways window, your own whisper, or their invite. A door is someone
-- you asked from Doorways, a Scrollkeeper door, or someone you whispered in
-- the last 10 minutes.
------------------------------------------------------------------------

local whispered = {}   -- short name (lower) -> time you last whispered them
SK.On("CHAT_MSG_WHISPER_INFORM", function(_, target)
    target = SK.Known(target)
    if type(target) == "string" then whispered[Net.ShortName(target):lower()] = time() end
end)

local pop, popWho, popPending, popDone
local Resting = Resting

local function DoorInGroup()
    if not (IsInGroup and IsInGroup()) then return nil end
    if IsInRaid and IsInRaid() then return nil end
    if trip and not trip.teleported and InGroupWith(trip.short) then return trip.short end
    local doorNames = {}
    for _, door in ipairs(SK.OpenDoors()) do doorNames[door.short:lower()] = true end
    for i = 1, 4 do
        local name = UnitName and SK.Known(UnitName("party" .. i))
        if type(name) == "string" then
            local key = Net.ShortName(name):lower()
            if doorNames[key] or (whispered[key] and time() - whispered[key] < 600) then
                return Net.ShortName(name)
            end
        end
    end
end

local function BuildPop()
    pop = CreateFrame("Frame", "ScrollkeeperTeleportPop", UIParent, "BackdropTemplate")
    pop:SetSize(230, 74)
    pop:SetPoint("TOP", UIParent, "TOP", 0, -160)
    pop:SetFrameStrata("DIALOG")
    pop:SetMovable(true)
    pop:EnableMouse(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", pop.StartMoving)
    pop:SetScript("OnDragStop", pop.StopMovingOrSizing)
    if pop.SetBackdrop then
        pop:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        pop:SetBackdropColor(0.05, 0.05, 0.1, 0.92)
    end
    pop.title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pop.title:SetPoint("TOPLEFT", 10, -8)
    pop.title:SetPoint("RIGHT", pop, "RIGHT", -24, 0)
    pop.title:SetWordWrap(true)
    pop.title:SetJustifyH("LEFT")
    pop.title:SetText(L["Doorways"])
    local close = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() if not SK.InCombat() then pop:Hide() end popWho, popDone = nil, nil end)
    -- After the teleport: leave the group, if you want to.
    local function Leave()
        if C_PartyInfo and C_PartyInfo.LeaveParty then SK.Try(C_PartyInfo.LeaveParty)
        elseif LeaveParty then SK.Try(LeaveParty) end
        popDone = nil
        if not SK.InCombat() then pop:Hide() end
    end
    local leave = CreateFrame("Frame", nil, pop)
    leave:SetSize(206, 24)
    leave:SetPoint("BOTTOM", pop, "BOTTOM", 0, 8)
    local thanks = CreateFrame("Button", nil, leave, "UIPanelButtonTemplate")
    thanks:SetSize(118, 24)
    thanks:SetPoint("LEFT", leave, "LEFT", 0, 0)
    thanks:SetText(L["Thanks & leave"])
    thanks:SetScript("OnClick", function()
        SK.Track("doors.popthanks")
        if SendChatMessage then SK.Try(SendChatMessage, L["Thanks for the door!"], "PARTY") end
        C_Timer.After(1, Leave)
    end)
    local plain = CreateFrame("Button", nil, leave, "UIPanelButtonTemplate")
    plain:SetSize(84, 24)
    plain:SetPoint("RIGHT", leave, "RIGHT", 0, 0)
    plain:SetText(L["Leave group"])
    plain:SetScript("OnClick", function() SK.Track("doors.popleave") Leave() end)
    if SK.UI and SK.UI.SkinButton then SK.UI.SkinButton(thanks) SK.UI.SkinButton(plain) end
    leave:Hide()
    pop.leave = leave
    local b = CreateFrame("Button", "ScrollkeeperTeleportPopButton", pop, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(200, 24)
    b:SetPoint("BOTTOM", pop, "BOTTOM", 0, 8)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "macro")
    b:HookScript("OnClick", function() SK.Track("doors.popteleport") end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Scroll of Liminal Passage"])
        GameTooltip:AddLine(L["Targets them and reads the scroll. You both have to be resting."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if SK.UI and SK.UI.SkinButton then SK.UI.SkinButton(b) end
    pop.button = b
    -- Your mage teleports, for when you're not resting yet (any city counts).
    pop.ports = {}
    for i, spellID in ipairs(SK.MAGE_TELEPORTS) do
        local icon = CreateFrame("Button", "ScrollkeeperTeleportPopPort" .. i, pop, "SecureActionButtonTemplate")
        icon:SetSize(24, 24)
        icon:RegisterForClicks("AnyUp", "AnyDown")
        icon:SetAttribute("type", "spell")
        icon:SetAttribute("spell", spellID)
        local tex = icon:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        local texture = (C_Spell and C_Spell.GetSpellTexture and SK.Try(C_Spell.GetSpellTexture, spellID))
            or (GetSpellTexture and SK.Try(GetSpellTexture, spellID))
        if texture then tex:SetTexture(texture) end
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(spellID) end
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        icon.spellID = spellID
        icon:Hide()
        pop.ports[i] = icon
    end
    pop:Hide()
end

-- Lay out the teleports you know (out of combat only).
local function ShowPorts(on)
    local known = {}
    for _, icon in ipairs(pop.ports) do
        local has = on and ((IsSpellKnown and SK.Try(IsSpellKnown, icon.spellID)) or (IsPlayerSpell and SK.Try(IsPlayerSpell, icon.spellID)))
        if has then known[#known + 1] = icon else icon:Hide() end
    end
    local width = #known * 26 - 2
    for i, icon in ipairs(known) do
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", pop, "TOP", -width / 2 + (i - 1) * 26, -38)
        icon:Show()
    end
    pop:SetHeight(#known > 0 and 104 or 74)
    pop:SetWidth(math.max(230, width + 20))
end

function SK.UpdateTeleportPop()
    if SK.db.doorTeleportPop == false or not SK.ModuleOn("Doors") then
        if pop and pop:IsShown() and not SK.InCombat() then pop:Hide() end
        return
    end
    if SK.InCombat() then popPending = true return end
    popPending = nil
    -- Teleported already: keep the Leave group button while you're still
    -- grouped with them.
    if popDone then
        if not (pop and IsInGroup and IsInGroup() and InGroupWith(popDone)) then
            popDone = nil
            if pop then pop.leave:Hide() pop.button:Show() pop:Hide() pop.mode = nil end
            popWho = nil
        end
        return
    end
    local who = (SK.LiminalCount() > 0) and DoorInGroup() or nil
    if not who then
        if pop then pop:Hide() end
        popWho = nil
        return
    end
    if not pop then BuildPop() end
    -- Both of you have to be resting. Not resting yet: the button hearths
    -- you home first (if the Hearthstone is ready), then turns into Teleport.
    local resting = Resting()
    local mode = resting and "teleport" or "hearth"
    if who ~= popWho or mode ~= pop.mode then
        local fresh = who ~= popWho
        popWho, pop.mode = who, mode
        if resting then
            pop.button:SetAttribute("macrotext", "/target " .. who .. "\n/use item:" .. SK.LIMINAL_PASSAGE)
            pop.button:SetText(L["Teleport to %s"]:format(who))
            pop.title:SetText(L["Doorways: grouped with %s"]:format(who))
            ShowPorts(false)
        else
            local start, duration = 0, 0
            if C_Container and C_Container.GetItemCooldown then start, duration = SK.Try(C_Container.GetItemCooldown, 6948)
            elseif GetItemCooldown then start, duration = SK.Try(GetItemCooldown, 6948) end
            local left = (start or 0) > 0 and (duration or 0) > 1.5 and math.ceil((start + duration - GetTime()) / 60) or 0
            pop.button:SetAttribute("macrotext", "/use item:6948")
            pop.button:SetText(left > 0 and L["Hearthstone (%d min)"]:format(left) or L["Hearth first"])
            pop.title:SetText(L["Not resting: teleport to a city or hearth first, then go to %s."]:format(who))
            ShowPorts(true)
        end
        if fresh or not pop:IsShown() then pop:Show() end
    end
end

local function PopSoon() C_Timer.After(0.5, function() SK.Safely("teleport pop", SK.UpdateTeleportPop) end) end
SK.On("GROUP_ROSTER_UPDATE", PopSoon)
SK.On("GROUP_JOINED", PopSoon)
SK.On("GROUP_LEFT", PopSoon)
SK.On("PLAYER_UPDATE_RESTING", PopSoon)
SK.On("PLAYER_REGEN_ENABLED", function() if popPending then PopSoon() end end)
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    unit, spellID = SK.Known(unit), SK.Known(spellID)
    if unit ~= "player" or not (pop and pop:IsShown()) then return end
    local _, scrollSpell = SK.Try(C_Item and C_Item.GetItemSpell or GetItemSpell, SK.LIMINAL_PASSAGE)
    if scrollSpell and spellID == scrollSpell and popWho then
        if not trip then SK.DoorLog(popWho, L["you teleported to them"], "ok") end
        popDone = popWho
        if not SK.InCombat() then
            pop.button:Hide()
            ShowPorts(false)
            pop.leave:Show()
            pop.title:SetText(L["Teleported to %s. Leave the group?"]:format(popDone))
        end
    end
end)

local function Button(parent, text, width, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(text)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if SK.UI.SkinButton then SK.UI.SkinButton(b) end
    return b
end

------------------------------------------------------------------------
-- Doorways log: who used you as a door (or you them), what happened, and
-- what they said after. SK.db.doorLog, newest last, the last 150.
------------------------------------------------------------------------

local LOG_MAX = 150

function SK.DoorLog(who, what, kind)
    SK.db.doorLog = type(SK.db.doorLog) == "table" and SK.db.doorLog or {}
    local log = SK.db.doorLog
    log[#log + 1] = { at = time(), who = who, what = what, kind = kind or "info" }
    while #log > LOG_MAX do table.remove(log, 1) end
    if SK.RefreshDoorLog then SK.Safely("door log", SK.RefreshDoorLog) end
end


-- Their whispers in the 15 minutes after a door: "ty!" and the like.
SK.On("CHAT_MSG_WHISPER", function(text, sender)
    text, sender = SK.Known(text), SK.Known(sender)
    if type(text) ~= "string" or type(sender) ~= "string" then return end
    local w = watching[Net.ShortName(sender):lower()]
    if not (w and time() - w.at < 900) then return end
    local thanks = text:lower():find("ty") or text:lower():find("thank") or text:lower():find("thx") or text:find("<3")
    SK.DoorLog(w.name, L["said: %s"]:format(text:gsub("|", "/"):sub(1, 120)), thanks and "thanks" or "said")
end)

-- Joining and leaving: did they come through?
SK.On("GROUP_ROSTER_UPDATE", function()
    for key, w in pairs(watching) do
        if time() - w.at < 900 and w.role == "host" then
            local inGroup = UnitInParty and SK.Known(UnitInParty(w.name)) or false
            if inGroup and not w.joined then
                w.joined = true
                SK.DoorLog(w.name, L["joined your group"], "ok")
                -- Say hi in party (setting doorGreet, your own text in doorGreetText).
                if SK.db.doorGreet ~= false and SendChatMessage and IsInGroup and IsInGroup() then
                    local text = (SK.db.doorGreetText and SK.db.doorGreetText ~= "") and SK.db.doorGreetText
                        or L["Welcome! Use your Scroll of Liminal Passage on me and I'll see you here."]
                    text = text:gsub("{name}", w.name):gsub("|", "")
                    C_Timer.After(1, function() SK.Try(SendChatMessage, text, "PARTY") end)
                    -- And a little plug, once (setting doorGreetPlug).
                    if SK.db.doorGreetPlug ~= false then
                        C_Timer.After(2.5, function()
                            SK.Try(SendChatMessage, L["(Doorways is part of Scrollkeeper, a mage scroll addon on CurseForge.)"], "PARTY")
                        end)
                    end
                end
            elseif w.joined and not inGroup and not w.left then
                w.left = true
                SK.DoorLog(w.name, L["left your group (most likely teleported over)"], "ok")
            end
        elseif time() - w.at >= 900 then
            watching[key] = nil
        end
    end
end)

------------------------------------------------------------------------
-- Being asked (as a door)
------------------------------------------------------------------------

local askedAt, invitesSent = {}, {}

-- In a group you're not leading, the invite still goes out: the game
-- passes it to your leader as a suggested invite.
local function CanInviteNow()
    if not (IsInGroup and IsInGroup()) then return true end
    local size = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then return size < 40 end
    return size < 5
end

local function RecentInvites()
    local now, count = time(), 0
    for i = #invitesSent, 1, -1 do
        if now - invitesSent[i] > 600 then table.remove(invitesSent, i) else count = count + 1 end
    end
    return count
end

local function Invite(name)
    SK.DoorLog(Net.ShortName(name), L["you invited them"], "ok")
    Watch(Net.ShortName(name), "host")
    invitesSent[#invitesSent + 1] = time()
    if C_PartyInfo and C_PartyInfo.InviteUnit then SK.Try(C_PartyInfo.InviteUnit, name)
    elseif InviteUnit then SK.Try(InviteUnit, name) end
    Net.Whisper(name, "DY")
end

Net.Handle("DA", function(sender, _, source)
    if source ~= "WHISPER" then return end
    if not SK.MyDoorPlace() or RecentInvites() >= INVITES_PER_10MIN then
        SK.DoorLog(Net.ShortName(sender), SK.MyDoorPlace() and L["asked, but you'd invited a lot already (told them no)"]
            or L["asked, but you weren't resting anywhere (told them no)"], "problem")
        Net.Whisper(sender, "DN")
        return
    end
    if askedAt[sender] and time() - askedAt[sender] < 30 then return end
    askedAt[sender] = time()
    local short = Net.ShortName(sender)
    SK.DoorLog(short, L["asked to come to you at %s"]:format(SK.MyDoorPlace() or "?"), "info")
    if SK.db.doorAutoInvite and CanInviteNow() then
        Invite(sender)
        SK.Print(L["%s asked to come to you with Liminal Passage: invited."]:format(short))
        return
    end
    if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then SK.Try(PlaySound, SOUNDKIT.READY_CHECK) end
    if StaticPopup_Show then
        local popup = StaticPopup_Show("SCROLLKEEPER_DOOR", short, nil, sender)
        if type(popup) == "table" then popup.data = sender end
    else
        SK.Print(L["%s wants to come to you with Liminal Passage."]:format(short))
    end
end)

Net.Handle("DY", function(sender, _, source)
    if source ~= "WHISPER" then return end
    SK.Print(L["%s is inviting you."]:format(Net.ShortName(sender)))
end)

Net.Handle("DN", function(sender, _, source)
    if source ~= "WHISPER" then return end
    SK.DoorLog(Net.ShortName(sender), L["couldn't be your door right then"], "problem")
    SK.Print(L["%s can't be a door right now. Pick someone else."]:format(Net.ShortName(sender)))
end)

-- Whispers asking for a door ("can I teleport to you?", "liminal pls"):
-- while you're a door, invite them by themselves (setting doorWhisperInvite,
-- with your own words in doorWords). Same limits as Scrollkeeper asks.
local DEFAULT_WORDS = { "liminal", "door", "teleport to you", "tele to you", "tp to you", "port to you", "scroll to you",
    "come to you", "tele me", "inv", "invite" }

function SK.DoorWords()
    local words = {}
    for _, w in ipairs(SK.DoorTriggers()) do words[#words + 1] = w:lower() end
    return words
end

-- The triggers (SK.db.doorTriggers): they start as the defaults, and you
-- can change, remove or add to them all. Old comma lists come along too.
function SK.DoorTriggers()
    if type(SK.db.doorTriggers) ~= "table" then SK.db.doorTriggers = {} end
    if not SK.db.doorTriggersSeeded then
        SK.db.doorTriggersSeeded = true
        local list, have = SK.db.doorTriggers, {}
        for _, w in ipairs(list) do have[w:lower()] = true end
        for w in tostring(SK.db.doorWords or ""):gmatch("[^,]+") do
            w = w:gsub("^%s+", ""):gsub("%s+$", "")
            if #w >= 2 and not have[w:lower()] then table.insert(list, w); have[w:lower()] = true end
        end
        for _, w in ipairs(DEFAULT_WORDS) do
            if not have[w] then table.insert(list, w); have[w] = true end
        end
    end
    return SK.db.doorTriggers
end

function SK.ResetDoorTriggers()
    SK.db.doorTriggers, SK.db.doorTriggersSeeded, SK.db.doorWords = {}, nil, ""
    return SK.DoorTriggers()
end
SK.DOOR_DEFAULT_TRIGGERS = DEFAULT_WORDS

local remindedAt = {}
SK.On("CHAT_MSG_WHISPER", function(text, sender, ...)
    text, sender = SK.Known(text), SK.Known(sender)
    if not (SK.db.doorWhisperInvite and type(text) == "string" and type(sender) == "string") then return end
    local guid = SK.Known((select(10, ...)))
    local place = SK.MyDoorPlace()
    if not place then return end
    local lower = " " .. text:lower() .. " "
    local hit
    for _, w in ipairs(SK.DoorWords()) do
        -- Whole words only ("inv" isn't "inventory"), phrases anywhere.
        local pattern = "%f[%w]" .. w:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. "%f[%W]"
        if lower:find(pattern) then hit = w break end
    end
    if not hit then return end
    if askedAt[sender] and time() - askedAt[sender] < 30 then return end
    askedAt[sender] = time()
    local short = Net.ShortName(sender)
    -- Only mages can read Liminal Passage: anyone else can't use a door.
    local class = type(guid) == "string" and GetPlayerInfoByGUID and select(2, SK.Try(GetPlayerInfoByGUID, guid))
    if class and class ~= "MAGE" then
        SK.DoorLog(short, L["whispered for a door (\"%s\"), but isn't a mage (only mages can use Liminal Passage)"]:format(hit), "info")
        return
    end
    -- Already with you: tell them what to do instead (at most every 2 minutes).
    if UnitInParty and SK.Known(UnitInParty(short)) then
        if not remindedAt[sender] or time() - remindedAt[sender] > 120 then
            remindedAt[sender] = time()
            SK.Try(SendChatMessage, L["You're already in my group: use your Scroll of Liminal Passage on me!"], "WHISPER", nil, sender)
            SK.DoorLog(short, L["whispered for a door while already in your group: told them to use the scroll"], "info")
        end
        return
    end
    if RecentInvites() >= INVITES_PER_10MIN or not CanInviteNow() then
        SK.DoorLog(short, L["whispered for a door (\"%s\"), but you can't invite right now"]:format(hit), "problem")
        return
    end
    SK.DoorLog(short, L["whispered for a door (\"%s\")"]:format(hit), "info")
    if IsInGroup and IsInGroup() and not (UnitIsGroupLeader and SK.Known(UnitIsGroupLeader("player"))) then
        SK.DoorLog(short, L["you're not the group leader: the invite goes to your leader as a suggestion"], "info")
    end
    invitesSent[#invitesSent + 1] = time()
    if C_PartyInfo and C_PartyInfo.InviteUnit then SK.Try(C_PartyInfo.InviteUnit, sender)
    elseif InviteUnit then SK.Try(InviteUnit, sender) end
    SK.DoorLog(short, L["you invited them"], "ok")
    Watch(short, "host")
    SK.Print(L["%s whispered for a door: invited."]:format(short))
    SK.Track("doors.whisperinvite")
end)

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_DOOR_WORDS"] = {
        text = L["Invite triggers: words in a whisper that mean \"invite me\" while you're a door, split by commas. These are always on too: %s"],
        button1 = SAVE or L["Save"], button2 = CANCEL or L["Cancel"], hasEditBox = true, maxLetters = 200, editBoxWidth = 320,
        OnShow = function(self)
            local box = self.editBox or self.EditBox
            if box then box:SetText(SK.db.doorWords or "") end
        end,
        OnAccept = function(self)
            local box = self.editBox or self.EditBox
            SK.db.doorWords = box and box:GetText() or ""
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["SCROLLKEEPER_DOOR_GREET"] = {
        text = L["What to say in party when someone joins to use you as a door ({name} is their name). Empty: the default."],
        button1 = SAVE or L["Save"], button2 = CANCEL or L["Cancel"], hasEditBox = true, maxLetters = 200, editBoxWidth = 320,
        OnShow = function(self)
            local box = self.editBox or self.EditBox
            if box then box:SetText(SK.db.doorGreetText or L["Welcome! Use your Scroll of Liminal Passage on me and I'll see you here."]) end
        end,
        OnAccept = function(self)
            local box = self.editBox or self.EditBox
            SK.db.doorGreetText = box and (box:GetText() or ""):gsub("|", "") or ""
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["SCROLLKEEPER_DOOR"] = {
        text = L["Scrollkeeper: %s wants to come to you with Liminal Passage. Invite them to your group?"],
        button1 = L["Invite"],
        button2 = L["Not now"],
        OnAccept = function(self, data)
            data = data or self.data
            if data then Invite(data) end
        end,
        OnCancel = function(self, data, reason)
            data = data or self.data
            if data and reason == "clicked" then
                Net.Whisper(data, "DN")
                SK.DoorLog(Net.ShortName(data), L["you said not now"], "info")
            elseif data and reason == "timeout" then
                SK.DoorLog(Net.ShortName(data), L["asked, but the pop-up timed out"], "problem")
            end
        end,
        timeout = 60,
        whileDead = false,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local window
local state = {}   -- search text and the like (frames can't hold it in the test mock)

-- The scroll's auction price: Auctionator's or TSM's if you have one, else
-- the last Scrollkeeper scan's. Returns copper and when it was seen, or nil.
local function LiminalPrice()
    if SK.HasAuctionAddon and SK.HasAuctionAddon() and SK.AddonAuctionPrice then
        local price = SK.AddonAuctionPrice(SK.LIMINAL_PASSAGE)
        if price then return price, nil end
    end
    if SK.AuctionPrice then return SK.AuctionPrice(SK.LIMINAL_PASSAGE) end
end

-- The search button: its text, with the seconds left while it cools down.
local function UpdateWhoButton()
    if not (window and type(selected) == "table") then return end
    local zone = PlaceZone(selected) or selected.town
    local left = WHO_COOLDOWN - (time() - lastWho)
    window.who:SetEnabled(left <= 0)
    window.who:SetText(left > 0 and L["Find players in %s (%ds)"]:format(zone, left) or L["Find players in %s"]:format(zone))
end

-- What the big button does now: "ask", "teleport", "leave" or nil.
local function NextStep()
    if not trip then return nil end
    if trip.teleported and IsInGroup and IsInGroup() then return "leave" end
    if InGroupWith(trip.short) then return "teleport" end
    if trip.kind == "who" and RoomToInvite() then return "invite" end
    return "ask"
end

local function UpdateAction()
    if not window then return end
    local button, note = window.action, window.actionNote
    local step = NextStep()
    local count = SK.LiminalCount()
    if not SK.InCombat() then
        if step == "teleport" then
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext", "/target " .. trip.short .. "\n/use item:" .. SK.LIMINAL_PASSAGE)
        else
            button:SetAttribute("type", nil)
        end
    end
    if step == "teleport" then
        button:SetText(L["Teleport to %s"]:format(trip.short))
        button:SetEnabled(count > 0)
        note:SetText(count == 0 and L["You have no Scroll of Liminal Passage."]
            or not Resting() and L["Rest in an inn or a city first: you both have to be resting."]
            or L["You're grouped with %s. They have to be resting too."]:format(trip.short))
    elseif step == "invite" then
        button:SetText(L["Invite %s"]:format(trip.short))
        button:SetEnabled(true)
        note:SetText(trip.invited and L["Invited. Waiting for %s to accept."]:format(trip.short)
            or L["Send the whisper first. Click Invite once %s says ok, or wait for their invite (it's accepted for you)."]:format(trip.short))
    elseif step == "leave" then
        button:SetText(L["Leave group"])
        button:SetEnabled(true)
        note:SetText(L["You're there. Leave the group when you're ready."])
    elseif step == "ask" then
        button:SetText(L["Ask %s again"]:format(trip.short))
        button:SetEnabled(true)
        note:SetText(trip.kind == "door" and L["Waiting for %s to invite you."]:format(trip.short)
            or L["Send the whisper and wait for %s to invite you (it's accepted for you)."]:format(trip.short))
    else
        button:SetText(L["Pick a host"])
        button:SetEnabled(false)
        note:SetText(count == 0 and L["You have no Scroll of Liminal Passage. You can still be a door for others."]
            or L["Pick a place on the left, then a host on the right."])
    end
end

local function UpdateMine()
    if not window then return end
    window.doorCheck:SetChecked(SK.db.liminalDoor and true or false)
    window.autoCheck:SetChecked(SK.db.doorAutoInvite and true or false)
    window.autoCheck:SetEnabled(SK.db.liminalDoor and true or false)
    window.whisperCheck:SetChecked(SK.db.doorWhisperInvite and true or false)
    window.whisperCheck:SetEnabled(SK.db.liminalDoor and true or false)
    local place = SK.MyDoorPlace()
    if not SK.db.liminalDoor then
        window.status:SetText(L["Off: nobody can ask to come to you."])
    elseif place then
        window.status:SetText(L["You're a door in |cffffffff%s|r."]:format(place))
    else
        window.status:SetText(L["You're a door whenever you rest in an inn or a city."])
    end
    local text = L["Scrolls of Liminal Passage: |cffffffff%d|r"]:format(SK.LiminalCount())
    if SK.LiminalLowText and SK.LiminalLowText() then text = text .. "  |cffff9933" .. L["(running low)"] .. "|r" end
    local price = LiminalPrice()
    if price then text = text .. "   " .. L["AH: %s"]:format(SK.ShortMoney(price)) end
    window.count:SetText(text)
end

local function SmallCheck(label, onClick)
    local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check:SetScript("OnClick", onClick)
    local text = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", check, "RIGHT", 1, 0)
    text:SetText(label)
    return check
end

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperDoorsFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperDoorsFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(LEFT_W + RIGHT_W + 50, 664)
    window:SetPoint("CENTER", 120, 0)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle(L["Scrollkeeper: Doorways"])
    local icon = (C_Item and SK.Try(C_Item.GetItemIconByID, SK.LIMINAL_PASSAGE)) or "Interface\\Icons\\Spell_Arcane_Blink"
    if window.SetPortraitToAsset then window:SetPortraitToAsset(icon) end
    tinsert(UISpecialFrames, "ScrollkeeperDoorsFrame")

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)
    SK.UI.AddHelp(window, "doors")

    local intro = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 64, -34)
    intro:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["Scroll of Liminal Passage takes you to a group member resting in an inn or a city. Pick where you want to go, then who to go to."])

    -- How many scrolls you have and their auction price. Hover for the
    -- scroll's own tooltip; Shift-click links it in chat.
    local countButton = CreateFrame("Button", nil, window)
    countButton:SetPoint("TOPRIGHT", -16, -56)
    countButton:SetSize(260, 16)
    window.count = countButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    window.count:SetPoint("RIGHT")
    countButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetItemByID(SK.LIMINAL_PASSAGE)
        local price, at = LiminalPrice()
        if price then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L["Auction house"], SK.Money(price), 1, 0.82, 0, 1, 1, 1)
            if at then GameTooltip:AddLine(L["seen %s"]:format(SK.TimeAgo(at)), 0.6, 0.6, 0.6) end
        end
        GameTooltip:AddLine(L["Shift-click to link it in chat."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    countButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    countButton:SetScript("OnClick", function()
        if not (IsModifiedClick and IsModifiedClick("CHATLINK")) then return end
        local link = C_Item and select(2, SK.Try(C_Item.GetItemInfo, SK.LIMINAL_PASSAGE))
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    end)

    -- Places
    local placesHeader = SK.UI.CreateHeader(window, L["Where to"], LEFT_W)
    placesHeader:SetPoint("TOPLEFT", 15, -76)
    window.places = SK.UI.CreateScrollList(window, LEFT_W, PLACE_ROWS)
    -- Search: type a bit of a town's name (or its zone), in any order of
    -- spelling: "rogmar", "gadg", "stv" all work.
    local search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    search:SetSize(LEFT_W - 8, 18)
    search:SetPoint("TOPLEFT", placesHeader, "BOTTOMLEFT", 6, -4)
    search:SetAutoFocus(false)
    local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", 2, 0)
    searchHint:SetText(L["Search towns"])
    search:SetScript("OnTextChanged", function(self)
        state.search = (self:GetText() or ""):lower()
        searchHint:SetShown(state.search == "" and not self:HasFocus())
        SK.RefreshDoors()
    end)
    search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) searchHint:SetShown((self:GetText() or "") == "") end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    window.places:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -6, -4)

    -- Hosts
    local hostsHeader = SK.UI.CreateHeader(window, L["Who to go to"], RIGHT_W)
    hostsHeader:SetPoint("TOPLEFT", placesHeader, "TOPRIGHT", 20, 0)
    window.hostsHeader = hostsHeader
    window.hosts = SK.UI.CreateScrollList(window, RIGHT_W, HOST_ROWS, true)
    window.hosts:SetPoint("TOPLEFT", hostsHeader, "BOTTOMLEFT", 0, -4)

    local who = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    who:SetSize(RIGHT_W, 22)
    who:SetPoint("TOPLEFT", hostsHeader, "BOTTOMLEFT", 0, -(HOST_ROWS * 30 + 10))
    who:SetScript("OnClick", function()
        SK.Track("doors.who")
        if type(selected) == "table" then SearchWho(selected) end
        SK.RefreshDoors()
    end)
    -- Hover works on it while it's cooling down too.
    if who.SetMotionScriptsWhileDisabled then who:SetMotionScriptsWhileDisabled(true) end
    who:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Find players"])
        GameTooltip:AddLine(L["Uses the game's /who search to find everyone in that zone. People standing in the town come first, but /who can't tell if they're resting."], 1, 1, 1, true)
        GameTooltip:AddLine(L["The game allows one search every 15 seconds."], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    who:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.who = who

    -- The next step
    local action = CreateFrame("Button", "ScrollkeeperDoorsAction", window, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    action:SetSize(RIGHT_W, 26)
    action:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -10)
    action:RegisterForClicks("AnyUp", "AnyDown")
    action:HookScript("OnClick", function(_, _, down)
        if down then return end
        local step = NextStep()
        SK.Track("doors." .. (step or "none"))
        if step == "ask" then
            for _, host in ipairs(SK.DoorHosts()) do
                if host.short == trip.short then Ask(host) return end
            end
            Ask({ kind = trip.kind, short = trip.short, target = trip.target, sender = trip.target })
        elseif step == "invite" then
            trip.invited = true
            if C_PartyInfo and C_PartyInfo.InviteUnit then SK.Try(C_PartyInfo.InviteUnit, trip.target)
            elseif InviteUnit then SK.Try(InviteUnit, trip.target) end
        elseif step == "leave" then
            if C_PartyInfo and C_PartyInfo.LeaveParty then SK.Try(C_PartyInfo.LeaveParty)
            elseif LeaveParty then SK.Try(LeaveParty) end
            trip = nil
            SK.RefreshDoors()
        end
    end)
    window.action = action
    window.actionNote = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.actionNote:SetPoint("TOPLEFT", action, "BOTTOMLEFT", 2, -4)
    window.actionNote:SetWidth(RIGHT_W)
    window.actionNote:SetJustifyH("LEFT")

    -- Your door
    -- Write your own whisper (the one /who finds get).
    local whisperEdit = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    whisperEdit:SetSize(110, 18)
    whisperEdit:SetPoint("TOPRIGHT", action, "BOTTOMRIGHT", 0, -16)
    whisperEdit:SetText(L["Whisper text..."])
    if whisperEdit.GetFontString and whisperEdit:GetFontString() then whisperEdit:GetFontString():SetFontObject("GameFontNormalSmall") end
    whisperEdit:SetScript("OnClick", function() SK.Track("doors.editwhisper") if StaticPopup_Show then StaticPopup_Show("SCROLLKEEPER_DOOR_WHISPER") end end)
    whisperEdit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Whisper text"])
        GameTooltip:AddLine(SK.DoorWhisper("Tarren Mill", { name = "Runey", zone = "Hillsbrad Foothills" }), 1, 0.5, 1, true)
        GameTooltip:AddLine(L["Click to write your own."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    whisperEdit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local mine = SK.UI.CreateHeader(window, L["Your door"], RIGHT_W)
    mine:SetPoint("TOPLEFT", action, "BOTTOMLEFT", 0, -34)
    window.doorCheck = SmallCheck(L["Be a door"], function(self)
        SK.db.liminalDoor = self:GetChecked() and true or false
        SK.Track(SK.db.liminalDoor and "doors.bedoor.on" or "doors.bedoor.off")
        SK.Safely("door", SendDoor, true)
        UpdateMine()
    end)
    window.doorCheck:SetPoint("TOPLEFT", mine, "BOTTOMLEFT", 0, -2)
    window.autoCheck = SmallCheck(L["Skip the pop-up"], function(self)
        SK.db.doorAutoInvite = self:GetChecked() and true or false
        SK.Track(SK.db.doorAutoInvite and "doors.autoinvite.on" or "doors.autoinvite.off")
        SK.Safely("door", SendDoor, true)
        UpdateMine()
    end)
    window.autoCheck:SetPoint("LEFT", window.doorCheck, "RIGHT", 100, 0)
    window.autoCheck:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Skip the pop-up"])
        GameTooltip:AddLine(L["When a Scrollkeeper mage asks to come to you, invite them right away instead of asking you first with a pop-up."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    window.autoCheck:HookScript("OnLeave", function() GameTooltip:Hide() end)
    window.status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.status:SetPoint("TOPLEFT", window.doorCheck, "BOTTOMLEFT", 4, -2)
    window.status:SetWidth(RIGHT_W - 8)
    window.status:SetJustifyH("LEFT")
    window.whisperCheck = SmallCheck(L["Answer whispers"], function(self)
        SK.db.doorWhisperInvite = self:GetChecked() and true or false
        SK.Track(SK.db.doorWhisperInvite and "doors.whisper.on" or "doors.whisper.off")
        UpdateMine()
    end)
    window.whisperCheck:SetPoint("TOPLEFT", window.doorCheck, "BOTTOMLEFT", 0, -16)
    window.whisperCheck:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Answer whispers"])
        GameTooltip:AddLine(L["While you're a door, anyone who whispers you something like \"can I teleport to you?\" or \"liminal pls\" gets invited by themselves. They don't need Scrollkeeper. Type your own words in the box next to it."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    window.whisperCheck:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local triggers = Button(window, L["Invite triggers..."], 112, function() SK.ToggleDoorTriggers() end,
        L["The words in a whisper that mean \"invite me\" while you're a door. They start as a few common ones: change, remove or add your own."])
    triggers:SetPoint("LEFT", window.whisperCheck, "RIGHT", 92, 0)
    local greet = Button(window, L["Greeting..."], 74, function() StaticPopup_Show("SCROLLKEEPER_DOOR_GREET") end,
        L["What you say in party when someone joins to use you as a door. Off in /sk options."])
    greet:SetPoint("LEFT", triggers, "RIGHT", 4, 0)

    -- The log, right here: the latest first few lines (scroll for more).
    local logHead = SK.UI.CreateHeader(window, L["Log"], RIGHT_W)
    logHead:SetPoint("TOPLEFT", window.whisperCheck, "BOTTOMLEFT", 0, -6)
    local log = CreateFrame("ScrollingMessageFrame", nil, window)
    log:SetPoint("TOPLEFT", logHead, "BOTTOMLEFT", 4, -4)
    log:SetSize(RIGHT_W - 8, 62)
    log:SetFontObject("GameFontHighlightSmall")
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(150)
    log:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP or "TOP")
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta) if delta > 0 then self:ScrollUp() else self:ScrollDown() end end)
    log:SetHyperlinksEnabled(false)
    window.log = log

    window:SetScript("OnShow", function() SK.RefreshDoors(); SK.RefreshDoorLog() end)
    window:Hide()
end

local function HostLine(host)
    if host.kind == "me" then
        local how = SK.db.doorAutoInvite and L["they get invited right away"] or L["you get a pop-up first"]
        return "|cffffd100" .. L["Your door"] .. "|r  |cffffffff" .. host.door.place .. "|r  |cff808080" .. how .. "|r"
    end
    if host.kind == "door" then
        local door = host.door
        local how = door.auto and L["invites you by itself"] or L["gets a pop-up to invite you"]
        return "|cff40ff40" .. L["Scrollkeeper door"] .. "|r  |cffffffff" .. door.place .. "|r  |cff808080" .. how .. "|r"
    end
    local who = host.who
    return ("|cffffffff%s %s|r  |cff808080%s|r"):format(tostring(who.level or "?"),
        who.class or "", who.city and ("|cff40ff40" .. L["resting in %s"]:format(who.area or "") .. "|r")
        or who.inTown and ("|cff40ff40" .. L["in %s"]:format(who.area) .. "|r")
        or (who.area and L["in %s, may not be resting"]:format(who.area)) or L["may not be resting"])
end

function SK.RefreshDoors()
    if not (window and window:IsShown()) then return end
    if selected == nil then selected = "all" end

    local places = SK.DoorPlaces()
    local items = { { all = true, doors = #SK.OpenDoors() } }
    local query = state.search or ""
    local scored = {}
    for i, entry in ipairs(places) do
        local score = query == "" and 0 or SK.FuzzyScore(query, entry.place.town .. " " .. (PlaceZone(entry.place) or ""))
        if score then scored[#scored + 1] = { entry = entry, score = score, i = i } end
    end
    if query ~= "" then
        table.sort(scored, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.i < b.i end)
    end
    if query ~= "" then
        for _, s in ipairs(scored) do items[#items + 1] = s.entry end
    else
        -- Continent, then zone, then towns: each group can fold up (kept in
        -- SK.db.doorFolded), with its door count.
        SK.db.doorFolded = type(SK.db.doorFolded) == "table" and SK.db.doorFolded or {}
        local folded = SK.db.doorFolded
        local tree, order = {}, {}
        for _, entry in ipairs(places) do
            local place = entry.place
            local cont = place.continent or ContinentName(place.map) or L["Other"]
            local zone = PlaceZone(place) or place.town
            if not tree[cont] then tree[cont] = { zones = {}, order = {}, doors = 0 }; order[#order + 1] = cont end
            local c = tree[cont]
            if not c.zones[zone] then c.zones[zone] = { towns = {}, doors = 0 }; c.order[#c.order + 1] = zone end
            table.insert(c.zones[zone].towns, entry)
            c.zones[zone].doors = c.zones[zone].doors + entry.doors
            c.doors = c.doors + entry.doors
        end
        local RANK = { ["Eastern Kingdoms"] = 1, ["Kalimdor"] = 2 }
        table.sort(order, function(a, b)
            local ra, rb = RANK[a] or 9, RANK[b] or 9
            if ra ~= rb then return ra < rb end
            return a < b
        end)
        for _, cont in ipairs(order) do
            local c = tree[cont]
            items[#items + 1] = { group = "continent", name = cont, doors = c.doors, key = "c:" .. cont }
            if not folded["c:" .. cont] then
                table.sort(c.order)
                for _, zone in ipairs(c.order) do
                    local z = c.zones[zone]
                    local key = "z:" .. cont .. ":" .. zone
                    -- A zone with one town that has the same name (a city): just the town.
                    if #z.towns == 1 and z.towns[1].place.town == zone then
                        items[#items + 1] = { indent = 1, entry = z.towns[1] }
                    else
                        items[#items + 1] = { group = "zone", name = zone, doors = z.doors, key = key }
                        if not folded[key] then
                            for _, entry in ipairs(z.towns) do items[#items + 1] = { indent = 2, entry = entry } end
                        end
                    end
                end
            end
        end
    end
    window.places:SetRows(items, function(row, item)
        row.itemID = nil
        if item.group then
            local open = not SK.db.doorFolded[item.key]
            local pad = item.group == "zone" and "   " or ""
            local color = item.group == "continent" and "|cffffd100" or "|cffd8c890"
            row.label:SetText(pad .. color .. (open and "- " or "+ ") .. item.name .. "|r")
            row.value:SetText(item.doors > 0 and ("|cff40ff40" .. item.doors .. "|r") or "")
            row.tipFunc = function(tip)
                tip:AddLine(item.name)
                tip:AddLine(L["%d open doors"]:format(item.doors), 0.25, 1, 0.25)
                tip:AddLine(open and L["Click to fold up."] or L["Click to open."], 0.6, 0.6, 0.6)
            end
            row.onClick = function()
                SK.db.doorFolded[item.key] = open or nil
                SK.RefreshDoors()
            end
            return
        end
        local entry = item.entry or item
        local indent = item.indent == 2 and "      " or item.indent == 1 and "   " or ""
        local picked = (entry.all and selected == "all") or entry.place == selected
        local name = entry.all and L["All open doors"] or entry.place.town
        local color = picked and "|cffffffff" or entry.own and "|cff808080" or ""
        local cityTag = (not entry.all and entry.place.capital) and ("  |cff66bbff" .. L["city"] .. "|r") or ""
        row.label:SetText(indent .. (picked and "> " or "") .. color .. name .. (color ~= "" and "|r" or "") .. cityTag)
        row.value:SetText(entry.doors > 0 and ("|cff40ff40" .. entry.doors .. "|r") or "")
        row.tipFunc = function(tip)
            tip:AddLine(name)
            if not entry.all then
                tip:AddLine(PlaceZone(entry.place) or "", 1, 1, 1)
                if entry.place.capital then
                    tip:AddLine(L["A city: resting everywhere in it, so anyone found here works."], 0.4, 0.73, 1, true)
                end
                if entry.own then tip:AddLine(L["You can teleport here with your own spell."], 0.6, 0.6, 0.6) end
            end
            tip:AddLine(L["%d open doors"]:format(entry.doors), 0.25, 1, 0.25)
        end
        row.onClick = function()
            SK.Track(entry.all and "doors.place.all" or "doors.place")
            selected = entry.all and "all" or entry.place
            SK.RefreshDoors()
        end
    end)

    local hosts = SK.DoorHosts()
    window.hosts:SetRows(hosts, function(row, host)
        row.itemID = nil
        local picked = trip and trip.short == host.short
        local tag = host.relation == "guild" and ("  |cff40ff40<" .. L["guild"] .. ">|r")
            or host.relation == "friend" and ("  |cff66bbff<" .. L["friend"] .. ">|r") or ""
        if host.kind == "me" then tag = "  |cffffd100(" .. L["you"] .. ")|r" end
        row.label:SetText((picked and "> |cffffffff" or "") .. host.short .. (picked and "|r" or "") .. tag)
        row.sub:SetText(HostLine(host))
        row.tipFunc = function(tip)
            tip:AddLine(host.short)
            if host.kind == "me" then
                tip:AddLine(L["You're a door here: other mages see you in their list and can ask to come to you."], 1, 1, 1, true)
            elseif host.kind == "door" then
                tip:AddLine(L["Resting in %s"]:format(host.door.place), 1, 1, 1)
                tip:AddLine(L["Click: ask them to invite you. The invite is accepted for you."], 0.6, 0.6, 0.6, true)
            else
                tip:AddLine(L["Click: whisper them asking for an invite. They don't need any addon, but they have to be resting."], 0.6, 0.6, 0.6, true)
            end
        end
        row.onClick = function()
            if host.kind == "me" then return end
            SK.Track("doors.host." .. tostring(host.kind or "?"))
            Ask(host)
        end
    end, selected == "all" and L["No open doors right now. Pick a place to find players there."]
        or L["No doors here. Search below to find anyone in this zone."])

    if type(selected) == "table" then
        window.who:Show()
        UpdateWhoButton()
    else
        window.who:Hide()
    end
    UpdateMine()
    UpdateAction()
end

-- Open Doorways on a town (clicking an inn on the map).
function SK.ShowDoorTown(town)
    if SK.InCombat() then SK.Print(L["Doorways can be opened after combat."]) return end
    if not window then Build() end
    for _, place in ipairs(PLACES) do if place.town == town then selected = place end end
    window:Show()
    SK.RefreshDoors()
end

-- Open Doorways on a door's place (clicking a door on the map).
function SK.ShowDoor(sender)
    if SK.InCombat() then
        SK.Print(L["Doorways can be opened after combat."])
        return
    end
    if not window then Build() end
    for _, door in ipairs(SK.OpenDoors()) do
        if door.sender == sender then selected = PlaceOfDoor(door) or "all" end
    end
    window:Show()
    SK.RefreshDoors()
end

function SK.ToggleDoors()
    if not SK.ModuleOn("Doors") then
        SK.Print(L["%s is turned off. Turn it on in /sk options (Modules)."]:format(L["Doorways"]))
        return
    end
    -- The window holds a secure button (Teleport), so the game won't let
    -- addons show or hide it in combat.
    if SK.InCombat() then
        SK.Print(L["Doorways can be opened after combat."])
        return
    end
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

SK.Listen("DOORS_CHANGED", SK.RefreshDoors)
SK.Listen("PEERS_CHANGED", SK.RefreshDoors)
SK.Listen("BAGS_CHANGED", SK.RefreshDoors)
SK.On("GROUP_ROSTER_UPDATE", function() SK.RefreshDoors() end)
SK.On("PLAYER_UPDATE_RESTING", function() C_Timer.After(0.5, SK.RefreshDoors) end)
SK.On("PLAYER_REGEN_ENABLED", function() SK.RefreshDoors() end)
-- The search button counts down its cooldown.
SK.Listen("READY", function() C_Timer.NewTicker(1, function() if window and window:IsShown() and window.who:IsShown() then UpdateWhoButton() end end) end)

------------------------------------------------------------------------
-- The log window
------------------------------------------------------------------------

local logWindow
local KIND_COLORS = { ok = "|cff40ff40", problem = "|cffff6060", thanks = "|cffff7aa8", said = "|cffffffff", info = "|cffc0c0c0" }

local function LogLine(e, short)
    return ("|cff808080%s|r  |cff69ccf0%s|r %s%s|r"):format(date(short and "%H:%M" or "%b %d %H:%M", e.at or 0), e.who or "?",
        KIND_COLORS[e.kind] or "|cffffffff", e.what or "")
end

-- The log box on Doorways (newest on top).
local function RefreshInlineLog()
    if not (window and window.log) then return end
    window.log:Clear()
    local log = type(SK.db.doorLog) == "table" and SK.db.doorLog or {}
    if #log == 0 then window.log:AddMessage("|cff808080" .. L["Nothing yet. Be a door (or use one) and it shows up here."] .. "|r") end
    for _, e in ipairs(log) do window.log:AddMessage(LogLine(e, true)) end
end

function SK.RefreshDoorLog()
    SK.Safely("door log", RefreshInlineLog)
    if not (logWindow and logWindow:IsShown()) then return end
    local text = logWindow.text
    text:Clear()
    local log = type(SK.db.doorLog) == "table" and SK.db.doorLog or {}
    if #log == 0 then text:AddMessage("|cff808080" .. L["Nothing yet. Be a door (or use one) and it shows up here."] .. "|r") end
    for _, e in ipairs(log) do
        text:AddMessage(LogLine(e))
    end
    text:ScrollToBottom()
end

function SK.ToggleDoorLog()
    if not logWindow then
        local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperDoorLog", UIParent, "BasicFrameTemplateWithInset")
        logWindow = ok and frame or CreateFrame("Frame", "ScrollkeeperDoorLog", UIParent)
        logWindow:SetSize(480, 320)
        logWindow:SetPoint("CENTER", 300, 60)
        logWindow:SetFrameStrata("HIGH")
        logWindow:SetToplevel(true)
        logWindow:SetMovable(true)
        logWindow:EnableMouse(true)
        logWindow:RegisterForDrag("LeftButton")
        logWindow:SetScript("OnDragStart", logWindow.StartMoving)
        logWindow:SetScript("OnDragStop", logWindow.StopMovingOrSizing)
        tinsert(UISpecialFrames, "ScrollkeeperDoorLog")
        local title = logWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -6)
        title:SetText(L["Doorways log"])
        local text = CreateFrame("ScrollingMessageFrame", nil, logWindow)
        text:SetPoint("TOPLEFT", 12, -30)
        text:SetPoint("BOTTOMRIGHT", -12, 36)
        text:SetFontObject("GameFontHighlightSmall")
        text:SetJustifyH("LEFT")
        text:SetFading(false)
        text:SetMaxLines(200)
        text:EnableMouseWheel(true)
        text:SetScript("OnMouseWheel", function(self, delta) if delta > 0 then self:ScrollUp() else self:ScrollDown() end end)
        logWindow.text = text
        local clear = Button(logWindow, L["Clear"], 70, function() SK.db.doorLog = {}; SK.RefreshDoorLog() end)
        clear:SetPoint("BOTTOMRIGHT", -12, 8)
        logWindow:SetScript("OnShow", function() SK.RefreshDoorLog() end)
        logWindow:Hide()
    end
    logWindow:SetShown(not logWindow:IsShown())
end

------------------------------------------------------------------------
-- Invite triggers window: the built-in words (gray, can't change) and
-- yours. Type one and Add; click one of yours to change or remove it.
------------------------------------------------------------------------

local trigWindow, trigList, trigBox, trigEditing

function SK.RefreshDoorTriggers()
    if not (trigWindow and trigWindow:IsShown()) then return end
    local rows = {}
    for i, w in ipairs(SK.DoorTriggers()) do rows[#rows + 1] = { text = w, index = i } end
    trigList:SetRows(rows, function(row, r)
        local editing = trigEditing and r.index == trigEditing
        row.label:SetText(r.builtIn and ("|cff808080" .. r.text .. "  (" .. L["built in"] .. ")|r")
            or ((editing and "> " or "") .. "|cffffffff" .. r.text .. "|r"))
        row.tipFunc = function(tip)
            tip:AddLine(r.text)
            tip:AddLine(r.builtIn and L["Built in: always on."] or L["Click to change or remove it."], 0.7, 0.7, 0.7)
        end
        row.onClick = function()
            if r.builtIn then return end
            trigEditing = r.index
            trigBox:SetText(r.text)
            trigBox:SetFocus()
            SK.RefreshDoorTriggers()
        end
    end)
    trigWindow.add:SetText(trigEditing and L["Save"] or L["Add"])
    trigWindow.remove:SetEnabled(trigEditing ~= nil)
end

function SK.ToggleDoorTriggers()
    if not trigWindow then
        local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperDoorTriggers", UIParent, "BasicFrameTemplateWithInset")
        trigWindow = ok and frame or CreateFrame("Frame", "ScrollkeeperDoorTriggers", UIParent)
        trigWindow:SetSize(320, 380)
        trigWindow:SetPoint("CENTER", 260, 40)
        trigWindow:SetFrameStrata("HIGH")
        trigWindow:SetToplevel(true)
        trigWindow:SetMovable(true)
        trigWindow:EnableMouse(true)
        trigWindow:RegisterForDrag("LeftButton")
        trigWindow:SetScript("OnDragStart", trigWindow.StartMoving)
        trigWindow:SetScript("OnDragStop", trigWindow.StopMovingOrSizing)
        tinsert(UISpecialFrames, "ScrollkeeperDoorTriggers")
        local title = trigWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -6)
        title:SetText(L["Invite triggers"])
        local note = trigWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", 14, -30)
        note:SetWidth(292)
        note:SetJustifyH("LEFT")
        note:SetText(L["While you're a door, a mage whose whisper has any of these gets an invite."])
        trigList = SK.UI.CreateScrollList(trigWindow, 292, 12)
        trigList:SetPoint("TOPLEFT", 14, -56)
        trigBox = CreateFrame("EditBox", nil, trigWindow, "InputBoxTemplate")
        trigBox:SetSize(170, 20)
        trigBox:SetPoint("BOTTOMLEFT", 20, 14)
        trigBox:SetAutoFocus(false)
        trigBox:SetMaxLetters(40)
        local function Add()
            local w = (trigBox:GetText() or ""):gsub("[|,]", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if #w < 2 then return end
            local list = SK.DoorTriggers()
            if trigEditing and list[trigEditing] then list[trigEditing] = w else table.insert(list, w) end
            trigEditing = nil
            trigBox:SetText("")
            SK.Track("doors.trigger.add")
            SK.RefreshDoorTriggers()
        end
        trigBox:SetScript("OnEnterPressed", Add)
        trigBox:SetScript("OnEscapePressed", function(self)
            trigEditing = nil
            self:SetText("")
            self:ClearFocus()
            SK.RefreshDoorTriggers()
        end)
        trigWindow.add = Button(trigWindow, L["Add"], 56, Add)
        trigWindow.add:SetPoint("LEFT", trigBox, "RIGHT", 6, 0)
        trigWindow.remove = Button(trigWindow, L["Remove"], 64, function()
            local list = SK.DoorTriggers()
            if trigEditing and list[trigEditing] then table.remove(list, trigEditing) end
            trigEditing = nil
            trigBox:SetText("")
            SK.RefreshDoorTriggers()
        end)
        trigWindow.remove:SetPoint("LEFT", trigWindow.add, "RIGHT", 4, 0)
        local reset = Button(trigWindow, L["Defaults"], 70, function()
            SK.ResetDoorTriggers()
            trigEditing = nil
            trigBox:SetText("")
            SK.RefreshDoorTriggers()
        end, L["Put the list back to the starting words."])
        reset:SetPoint("TOPRIGHT", -12, -28)
        trigWindow:SetScript("OnShow", function() SK.RefreshDoorTriggers() end)
        trigWindow:Hide()
    end
    trigWindow:SetShown(not trigWindow:IsShown())
end

------------------------------------------------------------------------
-- /sk innscan: read the innkeeper icons the game itself puts on the world
-- map, so Doorways knows where every inn is. "/sk innscan" reads the map
-- you have open; "/sk innscan all" flips through every zone map (keep the
-- world map open while it runs). Results print in chat and are kept in
-- SK.db.innScan (map ID -> list of { x, y, label }).
------------------------------------------------------------------------

-- Every icon on the world map right now, whatever this client calls it.
local function AllPins()
    local list = {}
    local map = WorldMapFrame
    local function Add(pin) if type(pin) == "table" then list[#list + 1] = pin end end
    local ok = map.EnumerateAllPins and pcall(function()
        for pin in map:EnumerateAllPins() do Add(pin) end
    end)
    if ok and #list > 0 then return list end
    list = {}
    local pools = map.pinPools
    if type(pools) == "table" then
        if pools.EnumerateActive then
            pcall(function() for pin in pools:EnumerateActive() do Add(pin) end end)
        else
            for _, pool in pairs(pools) do
                if type(pool) == "table" and pool.EnumerateActive then
                    pcall(function() for pin in pool:EnumerateActive() do Add(pin) end end)
                end
            end
        end
    end
    return list
end

local function PinStrings(pin, out)
    local function Take(t, depth)
        if type(t) ~= "table" or depth > 2 then return end
        if depth > 0 and t.GetObjectType then return end
        for k, v in pairs(t) do
            if type(v) == "string" and #v < 120 then out[#out + 1] = v
            elseif type(v) == "table" and type(k) == "string" and not v.GetObjectType then Take(v, depth + 1) end
        end
    end
    Take(pin, 0)
    for _, region in ipairs({ pin.GetRegions and pin:GetRegions() }) do
        if region.GetAtlas then local a = region:GetAtlas() if type(a) == "string" then out[#out + 1] = a end end
        if region.GetTexture then
            local t = region:GetTexture()
            if type(t) == "string" then out[#out + 1] = t
            elseif t == 136458 then out[#out + 1] = "Interface\\Minimap\\Tracking\\Innkeeper" end
        end
    end
    return out
end

local function ScanMap(mapID)
    local found = {}
    if not WorldMapFrame then return found end
    for _, pin in ipairs(AllPins()) do
        if pin.data == nil or type(pin.data) ~= "table" or pin.data.kind ~= "inn" then
            local strings = PinStrings(pin, {})
            local hit, label
            for _, text in ipairs(strings) do
                local low = text:lower()
                if low:find("innkeeper") or low:find("tracking\\innkeeper") or low:find("^inn$") then hit = true end
                if not label and (low:find("innkeeper") and not low:find("interface")) then label = text end
            end
            if not label then
                for _, k in ipairs({ "name", "label", "title" }) do
                    if type(pin[k]) == "string" then label = pin[k] break end
                end
            end
            local x, y = pin.normalizedX, pin.normalizedY
            if hit and x and y then
                found[#found + 1] = { x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10, label = label or "?" }
            end
        end
    end
    return found
end

-- /sk innscan debug: what each icon on the open map is, so we can tell
-- how the game draws its innkeepers.
local function DumpPins()
    local pins = AllPins()
    for n, pin in ipairs(pins) do
        if n > 40 then break end
        local ok, line = pcall(function()
            local strings = PinStrings(pin, {})
            local textures = {}
            for _, region in ipairs({ pin.GetRegions and pin:GetRegions() }) do
                local t = region.GetAtlas and region:GetAtlas() or (region.GetTexture and region:GetTexture())
                if t then textures[#textures + 1] = tostring(t) end
            end
            return ("%d %s %.1f,%.1f | %s | %s"):format(n, tostring(pin.pinTemplate or "?"),
                (tonumber(pin.normalizedX) or 0) * 100, (tonumber(pin.normalizedY) or 0) * 100,
                table.concat(strings, "; "):sub(1, 140), table.concat(textures, ", "):sub(1, 100))
        end)
        SK.Print(ok and line or (n .. " ? " .. tostring(line)))
    end
    SK.Print(("%d pins on this map."):format(#pins))
end

local function ReportScan(mapID, found)
    SK.db.innScan = type(SK.db.innScan) == "table" and SK.db.innScan or {}
    if #found == 0 then return 0 end
    SK.db.innScan[mapID] = found
    local info = C_Map and SK.Try(C_Map.GetMapInfo, mapID)
    local name = type(info) == "table" and info.name or tostring(mapID)
    for _, inn in ipairs(found) do
        SK.Print(("%s (%d): %s at %.1f, %.1f"):format(name, mapID, inn.label, inn.x, inn.y))
    end
    return #found
end

function SK.InnScan(all, debug)
    if not (WorldMapFrame and WorldMapFrame.GetMapID) then return end
    if debug then DumpPins() return end
    if not all then
        local mapID = WorldMapFrame:GetMapID()
        if ReportScan(mapID, ScanMap(mapID)) == 0 then
            SK.Print(L["No innkeeper icons found on this map. Open the world map on a zone first."])
        end
        return
    end
    if not WorldMapFrame:IsShown() then SK.Print(L["Open the world map first, then /sk innscan all."]) return end
    local maps, seen = {}, {}
    for _, top in ipairs({ 947, 1414, 1415, 1945, 113, 1455 }) do
        for _, child in ipairs(SK.Try(C_Map.GetMapChildrenInfo, top, 3, true) or {}) do
            if child.mapID and not seen[child.mapID] then seen[child.mapID] = true maps[#maps + 1] = child.mapID end
        end
    end
    local back, i, total = WorldMapFrame:GetMapID(), 0, 0
    SK.Print(L["Scanning %d maps for inns..."]:format(#maps))
    local ticker
    ticker = C_Timer.NewTicker(1.5, function()
        if i > 0 then total = total + ReportScan(maps[i], ScanMap(maps[i])) end
        i = i + 1
        -- Nothing after 8 maps: something's off, so stop instead of
        -- flipping through the rest.
        if i > 8 and total == 0 then
            if ticker and ticker.Cancel then ticker:Cancel() end
            SK.Try(WorldMapFrame.SetMapID, WorldMapFrame, back)
            SK.Print(L["No inns on the first 8 maps, so the scan stopped. Try /sk innscan debug on a zone with an inn."])
            return
        end
        if i > #maps or not WorldMapFrame:IsShown() then
            if ticker and ticker.Cancel then ticker:Cancel() end
            SK.Try(WorldMapFrame.SetMapID, WorldMapFrame, back)
            SK.Print(L["Inn scan done: %d inns. /reload to save them."]:format(total))
            return
        end
        SK.Try(WorldMapFrame.SetMapID, WorldMapFrame, maps[i])
    end)
end
