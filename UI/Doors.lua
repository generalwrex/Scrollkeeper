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
--   G|place|scrolls|mapID|auto   my door: where I rest ("" = not one now),
--                                Liminal Passage scrolls carried, the
--                                zone's map ID, "1" if I invite by myself
--   DA                           whisper: "can I come to you?"
--   DY / DN                      whisper: "inviting you" / "not right now"

local _, SK = ...
local L = SK.L
local Net = SK.Net

SK.LIMINAL_PASSAGE = 213548
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
    -- Alliance
    { town = "Goldshire", map = 1429, side = "Alliance" },
    { town = "Sentinel Hill", map = 1436, side = "Alliance" },
    { town = "Lakeshire", map = 1433, side = "Alliance" },
    { town = "Darkshire", map = 1431, side = "Alliance" },
    { town = "Kharanos", map = 1426, side = "Alliance" },
    { town = "Thelsamar", map = 1432, side = "Alliance" },
    { town = "Menethil Harbor", map = 1437, side = "Alliance" },
    { town = "Southshore", map = 1424, side = "Alliance" },
    { town = "Refuge Pointe", map = 1417, side = "Alliance" },
    { town = "Aerie Peak", map = 1425, side = "Alliance" },
    { town = "Nethergarde Keep", map = 1419, side = "Alliance" },
    { town = "Morgan's Vigil", map = 1428, side = "Alliance" },
    { town = "Dolanaar", map = 1438, side = "Alliance" },
    { town = "Auberdine", map = 1439, side = "Alliance" },
    { town = "Astranaar", map = 1440, side = "Alliance" },
    { town = "Stonetalon Peak", map = 1442, side = "Alliance" },
    { town = "Nijel's Point", map = 1443, side = "Alliance" },
    { town = "Theramore Isle", map = 1445, side = "Alliance" },
    { town = "Feathermoon Stronghold", map = 1444, side = "Alliance" },
    -- Horde
    { town = "Razor Hill", map = 1411, side = "Horde" },
    { town = "Bloodhoof Village", map = 1412, side = "Horde" },
    { town = "The Crossroads", map = 1413, side = "Horde" },
    { town = "Camp Taurajo", map = 1413, side = "Horde" },
    { town = "Brill", map = 1420, side = "Horde" },
    { town = "The Sepulcher", map = 1421, side = "Horde" },
    { town = "Tarren Mill", map = 1424, side = "Horde" },
    { town = "Hammerfall", map = 1417, side = "Horde" },
    { town = "Grom'gol Base Camp", map = 1434, side = "Horde" },
    { town = "Kargath", map = 1418, side = "Horde" },
    { town = "Stonard", map = 1435, side = "Horde" },
    { town = "Splintertree Post", map = 1440, side = "Horde" },
    { town = "Sun Rock Retreat", map = 1442, side = "Horde" },
    { town = "Shadowprey Village", map = 1443, side = "Horde" },
    { town = "Freewind Post", map = 1441, side = "Horde" },
    { town = "Camp Mojache", map = 1444, side = "Horde" },
    { town = "Brackenwall Village", map = 1445, side = "Horde" },
    { town = "Revantusk Village", map = 1425, side = "Horde" },
    -- capitals (teleport = the mage spell that already goes there)
    { town = "Stormwind City", map = 1453, side = "Alliance", capital = true, teleport = 3561 },
    { town = "Ironforge", map = 1455, side = "Alliance", capital = true, teleport = 3562 },
    { town = "Darnassus", map = 1457, side = "Alliance", capital = true, teleport = 3565 },
    { town = "Orgrimmar", map = 1454, side = "Horde", capital = true, teleport = 3567 },
    { town = "Thunder Bluff", map = 1456, side = "Horde", capital = true, teleport = 3566 },
    { town = "Undercity", map = 1458, side = "Horde", capital = true, teleport = 3563 },
}
SK.DOOR_PLACES = PLACES

local function ZoneName(mapID)
    local info = C_Map and C_Map.GetMapInfo and SK.Try(C_Map.GetMapInfo, mapID)
    return type(info) == "table" and info.name or nil
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

local lastSent
local function SendDoor(force)
    local place = SK.MyDoorPlace() or ""
    local auto = SK.db.doorAutoInvite and "1" or ""
    local text = table.concat({ place, SK.LiminalCount(), tostring(MyMapID()), auto }, "#")
    if text == lastSent and not force then return end
    lastSent = text
    Net.Send("G", place, SK.LiminalCount(), place ~= "" and MyMapID() or "", auto)
end
SK.SendDoor = SendDoor

local doorQueued
local function DoorSoon()
    if doorQueued then return end
    doorQueued = true
    C_Timer.After(4, function() doorQueued = false SK.Safely("door", SendDoor) end)
end
SK.On("PLAYER_UPDATE_RESTING", DoorSoon)
SK.On("ZONE_CHANGED_NEW_AREA", DoorSoon)
SK.On("ZONE_CHANGED", DoorSoon)
SK.On("PLAYER_REGEN_ENABLED", DoorSoon)
SK.Listen("BAGS_CHANGED", DoorSoon)
SK.Listen("NET_READY", function()
    C_Timer.After(30, function() SK.Safely("door", SendDoor, true) end)
    C_Timer.NewTicker(5 * 60, function() SK.Safely("door", SendDoor, true) end)
end)
Net.Handle("Q", function() C_Timer.After(6 + math.random() * 20, function() SK.Safely("door", SendDoor, true) end) end)

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
    }
    SK.Send("DOORS_CHANGED")
end)

local DEMO_DOORS = {
    { name = "Kaelith", place = "Booty Bay, Stranglethorn Vale", map = 1434, auto = true },
    { name = "Brannoc", place = "Gadgetzan, Tanaris", map = 1446 },
    { name = "Mirelle", place = "Goldshire, Elwynn Forest", map = 1429, auto = true },
}

-- Every open door you can reach: list of { sender, short, place, scrolls, map, auto, demo }.
function SK.OpenDoors()
    local list, fresh = {}, {}
    for _, entry in ipairs(SK.PeerList and SK.PeerList() or {}) do fresh[entry.sender] = true end
    for sender, door in pairs(SK.doors) do
        if door.place and fresh[sender] and not Net.IsMe(sender) and time() - door.at < 15 * 60 then
            list[#list + 1] = { sender = sender, short = Net.ShortName(sender), place = door.place,
                scrolls = door.scrolls, map = door.map, auto = door.auto }
        end
    end
    if SK.demoCommunity then
        for _, demo in ipairs(DEMO_DOORS) do
            list[#list + 1] = { sender = demo.name, short = demo.name, place = demo.place, scrolls = 0,
                map = demo.map, auto = demo.auto, demo = true }
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
            local zone = ZoneName(place.map)
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

function SK.DoorPlaces()
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    local counts = {}
    for _, door in ipairs(SK.OpenDoors()) do
        local place = PlaceOfDoor(door)
        if place then counts[place] = (counts[place] or 0) + 1 end
    end
    local list = {}
    for order, place in ipairs(PLACES) do
        if place.side == "both" or not mine or place.side == mine then
            list[#list + 1] = { place = place, doors = counts[place] or 0, order = order,
                own = (place.capital and KnowsSpell(place.teleport)) and true or false }
        end
    end
    -- A to Z ("The Crossroads" under C). Door counts show next to each.
    local function Key(entry) return (entry.place.town:gsub("^The ", "")):lower() end
    table.sort(list, function(a, b) return Key(a) < Key(b) end)
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
local function SearchWho(place)
    if not (C_FriendList and C_FriendList.SendWho) or not SK.DoorWhoReady() then return end
    local zone = ZoneName(place.map)
    if not zone then return end
    lastWho = time()
    whoPending = place
    if C_FriendList.SetWhoToUi then SK.Try(C_FriendList.SetWhoToUi, true) end
    -- The game opens a window with the results (FriendsFrame, or Forever's
    -- Looking For Group list). Note which were already open, to close only
    -- the one our search opens.
    whoWindowsOpen = {}
    for _, name in ipairs(WHO_WINDOWS) do
        local frame = _G[name]
        whoWindowsOpen[name] = type(frame) == "table" and frame.IsShown and frame:IsShown() or false
    end
    C_FriendList.SendWho(('z-"%s"'):format(zone))
    SK.Print(L["looking for players in %s..."]:format(zone))
end

SK.On("WHO_LIST_UPDATE", function()
    if not whoPending then return end
    local place = whoPending
    whoPending = nil
    local zone = ZoneName(place.map)
    local me = UnitName("player")
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
    -- The game opens its Who window with the results; we show them here.
    C_Timer.After(0, function()
        for _, name in ipairs(WHO_WINDOWS) do
            local frame = _G[name]
            if type(frame) == "table" and frame.IsShown and frame:IsShown() and not whoWindowsOpen[name] then
                if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
            end
        end
    end)
    SK.Send("DOORS_CHANGED")
end)

------------------------------------------------------------------------
-- The trip: ask, get invited (accepted by itself), teleport, leave.
------------------------------------------------------------------------

local trip   -- { short, target, kind, place, askedAt, teleported }

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
            me = UnitName and UnitName("player") or "",
            scroll = link or L["Scroll of Liminal Passage"],
        }
        return (custom:gsub("{(%a+)}", function(key) return values[key:lower()] end))
    end
    if place then
        return L["Hi! Mind inviting me for a sec? I've got a Scroll of Liminal Passage and can teleport to you while you're resting in %s. I'll leave the group right after. Thanks!"]:format(place)
    end
    return L["Hi! Mind inviting me for a sec? I've got a Scroll of Liminal Passage and can teleport to you while you're resting at an inn or in a city. I'll leave the group right after. Thanks!"]
end

-- The default, with {place} where the town goes, to start editing from.
local function DefaultTemplate()
    return (L["Hi! Mind inviting me for a sec? I've got a Scroll of Liminal Passage and can teleport to you while you're resting in %s. I'll leave the group right after. Thanks!"]:gsub("%%s", "{place}"))
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

local function Ask(host)
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
    elseif ChatFrame_OpenChat then
        -- Short and friendly: what you want, why it's quick, that you'll go.
        -- Name the town only when /who says they're standing in it (their
        -- own words for it, so it's right in any language). Someone
        -- elsewhere in the zone gets the general version.
        local inTown = host.who and host.who.inTown
            and (trip.place and trip.place.capital and (ZoneName(trip.place.map) or trip.place.town) or host.who.area)
        local text = SK.DoorWhisper(inTown, { name = trip.short,
            zone = trip.place and (ZoneName(trip.place.map) or trip.place.town) })
        -- The whole message in chat (only you see it), since the chat box
        -- is too narrow to read it, then the box ready to send.
        SK.Print(L["whisper to %s, press Enter to send it (or Escape to cancel):"]:format(trip.short))
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff80ff" .. text .. "|r") end
        ChatFrame_OpenChat(("/w %s %s"):format(target, text))
    end
    SK.Send("DOORS_CHANGED")
end

-- Accept the invite from the host we asked (only theirs, only for 3 minutes).
SK.On("PARTY_INVITE_REQUEST", function(inviter)
    inviter = SK.Known(inviter)
    if not (trip and trip.askedAt and time() - trip.askedAt < 180 and type(inviter) == "string") then return end
    if Net.ShortName(inviter):lower() ~= trip.short:lower() then return end
    if AcceptGroup then SK.Try(AcceptGroup) end
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    SK.Print(L["joined %s's group. Click Teleport when you're both resting."]:format(trip.short))
end)

-- Notice when the scroll was used, for the Leave group step.
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    unit, spellID = SK.Known(unit), SK.Known(spellID)
    if unit ~= "player" or not trip then return end
    local _, scrollSpell = SK.Try(C_Item and C_Item.GetItemSpell or GetItemSpell, SK.LIMINAL_PASSAGE)
    if scrollSpell and spellID == scrollSpell then
        trip.teleported = true
        SK.Send("DOORS_CHANGED")
    end
end)

SK.On("GROUP_LEFT", function()
    if trip and trip.teleported then trip = nil end
    SK.Send("DOORS_CHANGED")
end)

------------------------------------------------------------------------
-- Being asked (as a door)
------------------------------------------------------------------------

local askedAt, invitesSent = {}, {}

local function CanInviteNow()
    if not (IsInGroup and IsInGroup()) then return true end
    local leader = UnitIsGroupLeader and SK.Known(UnitIsGroupLeader("player"))
    local size = GetNumGroupMembers and GetNumGroupMembers() or 0
    return leader and not (IsInRaid and IsInRaid()) and size < 5
end

local function RecentInvites()
    local now, count = time(), 0
    for i = #invitesSent, 1, -1 do
        if now - invitesSent[i] > 600 then table.remove(invitesSent, i) else count = count + 1 end
    end
    return count
end

local function Invite(name)
    invitesSent[#invitesSent + 1] = time()
    if C_PartyInfo and C_PartyInfo.InviteUnit then SK.Try(C_PartyInfo.InviteUnit, name)
    elseif InviteUnit then SK.Try(InviteUnit, name) end
    Net.Whisper(name, "DY")
end

Net.Handle("DA", function(sender, _, source)
    if source ~= "WHISPER" then return end
    if not SK.MyDoorPlace() or RecentInvites() >= INVITES_PER_10MIN then Net.Whisper(sender, "DN") return end
    if askedAt[sender] and time() - askedAt[sender] < 30 then return end
    askedAt[sender] = time()
    local short = Net.ShortName(sender)
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
    SK.Print(L["%s can't be a door right now. Pick someone else."]:format(Net.ShortName(sender)))
end)

if StaticPopupDialogs then
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
            if data and reason == "clicked" then Net.Whisper(data, "DN") end
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
    local zone = ZoneName(selected.map) or selected.town
    local left = WHO_COOLDOWN - (time() - lastWho)
    window.who:SetEnabled(left <= 0)
    window.who:SetText(left > 0 and L["Find players in %s (%ds)"]:format(zone, left) or L["Find players in %s"]:format(zone))
end

-- What the big button does now: "ask", "teleport", "leave" or nil.
local function NextStep()
    if not trip then return nil end
    if trip.teleported and IsInGroup and IsInGroup() then return "leave" end
    if InGroupWith(trip.short) then return "teleport" end
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
    elseif step == "leave" then
        button:SetText(L["Leave group"])
        button:SetEnabled(true)
        note:SetText(L["You're there. Leave the group when you're ready."])
    elseif step == "ask" then
        button:SetText(L["Ask %s again"]:format(trip.short))
        button:SetEnabled(true)
        note:SetText(trip.kind == "door" and L["Waiting for %s to invite you."]:format(trip.short)
            or L["Send the whisper. If %s invites you, it's accepted for you."]:format(trip.short))
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
    local place = SK.MyDoorPlace()
    if not SK.db.liminalDoor then
        window.status:SetText(L["Off: nobody can ask to come to you."])
    elseif place then
        window.status:SetText(L["You're a door in |cffffffff%s|r."]:format(place))
    else
        window.status:SetText(L["You're a door whenever you rest in an inn or a city."])
    end
    local text = L["Scrolls of Liminal Passage: |cffffffff%d|r"]:format(SK.LiminalCount())
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
    window:SetSize(LEFT_W + RIGHT_W + 50, 556)
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
    background:SetColorTexture(0.05, 0.05, 0.06, 0.95)

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
    window.places:SetPoint("TOPLEFT", placesHeader, "BOTTOMLEFT", 0, -4)

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
        if step == "ask" then
            for _, host in ipairs(SK.DoorHosts()) do
                if host.short == trip.short then Ask(host) return end
            end
            Ask({ kind = trip.kind, short = trip.short, target = trip.target, sender = trip.target })
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
    whisperEdit:SetScript("OnClick", function() if StaticPopup_Show then StaticPopup_Show("SCROLLKEEPER_DOOR_WHISPER") end end)
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
        SK.Safely("door", SendDoor, true)
        UpdateMine()
    end)
    window.doorCheck:SetPoint("TOPLEFT", mine, "BOTTOMLEFT", 0, -2)
    window.autoCheck = SmallCheck(L["Invite by myself"], function(self)
        SK.db.doorAutoInvite = self:GetChecked() and true or false
        SK.Safely("door", SendDoor, true)
        UpdateMine()
    end)
    window.autoCheck:SetPoint("LEFT", window.doorCheck, "RIGHT", 100, 0)
    window.status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.status:SetPoint("TOPLEFT", window.doorCheck, "BOTTOMLEFT", 4, -2)
    window.status:SetWidth(RIGHT_W - 8)
    window.status:SetJustifyH("LEFT")

    window:SetScript("OnShow", function() SK.RefreshDoors() end)
    window:Hide()
end

local function HostLine(host)
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
    for _, entry in ipairs(places) do items[#items + 1] = entry end
    window.places:SetRows(items, function(row, entry)
        row.itemID = nil
        local picked = (entry.all and selected == "all") or entry.place == selected
        local name = entry.all and L["All open doors"] or entry.place.town
        local color = picked and "|cffffffff" or entry.own and "|cff808080" or ""
        local cityTag = (not entry.all and entry.place.capital) and ("  |cff66bbff" .. L["city"] .. "|r") or ""
        row.label:SetText((picked and "> " or "") .. color .. name .. (color ~= "" and "|r" or "") .. cityTag)
        row.value:SetText(entry.doors > 0 and ("|cff40ff40" .. entry.doors .. "|r") or "")
        row.tipFunc = function(tip)
            tip:AddLine(name)
            if not entry.all then
                tip:AddLine(ZoneName(entry.place.map) or "", 1, 1, 1)
                if entry.place.capital then
                    tip:AddLine(L["A city: resting everywhere in it, so anyone found here works."], 0.4, 0.73, 1, true)
                end
                if entry.own then tip:AddLine(L["You can teleport here with your own spell."], 0.6, 0.6, 0.6) end
            end
            tip:AddLine(L["%d open doors"]:format(entry.doors), 0.25, 1, 0.25)
        end
        row.onClick = function()
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
        row.label:SetText((picked and "> |cffffffff" or "") .. host.short .. (picked and "|r" or "") .. tag)
        row.sub:SetText(HostLine(host))
        row.tipFunc = function(tip)
            tip:AddLine(host.short)
            if host.kind == "door" then
                tip:AddLine(L["Resting in %s"]:format(host.door.place), 1, 1, 1)
                tip:AddLine(L["Click: ask them to invite you. The invite is accepted for you."], 0.6, 0.6, 0.6, true)
            else
                tip:AddLine(L["Click: whisper them asking for an invite. They don't need any addon, but they have to be resting."], 0.6, 0.6, 0.6, true)
            end
        end
        row.onClick = function() Ask(host) end
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

function SK.ToggleDoors()
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
