-- Scrollkeeper: Network/Peers.lua
-- Who else runs Scrollkeeper, and what their mages can use.
--
--   Q                       "who's there?"  Everyone answers with H.
--   H|protocol|version|class|level|skill|max|tiers|upgrades|guid
--        tiers     tiers this mage still gets skill-ups from, e.g. "15.50"
--        upgrades  weapon-upgrade scrolls held, e.g. "Saber"

local _, SK = ...
local L = SK.L
local Net = SK.Net

-- peers[name] = { version, class, level, skill, max, tiers = {[15]=true}, upgrades = {...},
--                 seen = time(), source = "GUILD"/"PARTY"/..., demo = true/nil }
SK.peers = {}

local STALE_SECONDS = 15 * 60
local warnedNewer

local function VersionNumber(text)
    local a, b, c = tostring(text):match("(%d+)%.(%d+)%.?(%d*)")
    if not a then return 0 end
    return tonumber(a) * 10000 + tonumber(b) * 100 + (tonumber(c) or 0)
end

------------------------------------------------------------------------
-- Telling others about me
------------------------------------------------------------------------

local function MyTiers()
    local skill = SK.GetComprehension()
    local tiers = {}
    for _, tier in ipairs(SK.TIERS) do
        local chance = SK.SkillUpChance(tier, skill.rank)
        if skill.effective >= tier and chance and chance.gives then tiers[#tiers + 1] = tier end
    end
    return table.concat(tiers, ".")
end

local function MyUpgrades()
    local held = {}
    for _, upgrade in ipairs(SK.WEAPON_UPGRADES) do
        for _, scroll in ipairs(SK.bags.translated) do
            if scroll.name == upgrade.scroll then held[#held + 1] = upgrade.short end
        end
    end
    return table.concat(held, ".")
end

-- A random code made once per account; sent with your hello so other
-- players' exports can include your data without your name. Says nothing
-- about who you are.
function SK.ExportID()
    if not SK.db.exportID then
        SK.db.exportID = ("%04x%04x"):format(math.random(0, 0xffff), math.random(0, 0xffff))
    end
    return SK.db.exportID
end

local function HelloFields()
    local _, class = UnitClass("player")
    local skill = SK.GetComprehension()
    return Net.PROTOCOL, SK.version, class, UnitLevel("player"),
        skill.rank, skill.max, SK.isMage and MyTiers() or "", SK.isMage and MyUpgrades() or "",
        UnitGUID("player"), SK.db.share and SK.ExportID() or ""
end

function SK.SendHello()
    Net.Send("H", HelloFields())
end

-- Friends who aren't in your guild or group: ask each online friend
-- directly. Only ones running Scrollkeeper answer.
local function PingFriends()
    if not (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex) then return end
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local friend = C_FriendList.GetFriendInfoByIndex(i)
        if friend and friend.connected and friend.name then Net.Whisper(friend.name, "Q") end
    end
end
SK.PingFriends = PingFriends

SK.Listen("READY", function()
    C_Timer.After(20, PingFriends)
    if C_Timer.NewTicker then C_Timer.NewTicker(10 * 60, PingFriends) end
end)

------------------------------------------------------------------------
-- Hearing about others
------------------------------------------------------------------------

Net.Handle("Q", function(sender, _, source)
    if source == "WHISPER" then
        -- A friend asked us directly: answer them directly.
        C_Timer.After(1 + math.random() * 2, function() Net.Whisper(sender, "H", HelloFields()) end)
        return
    end
    -- Answer after a short random wait so a whole guild doesn't reply at once.
    C_Timer.After(1 + math.random() * 4, SK.SendHello)
end)

Net.Handle("H", function(sender, f, source)
    local protocol = tonumber(f[1]) or 0
    if protocol ~= Net.PROTOCOL then return end
    local peer = {
        version = f[2], class = f[3], level = tonumber(f[4]) or 0,
        skill = math.min(tonumber(f[5]) or 0, 300), max = math.min(tonumber(f[6]) or 0, 300),
        tiers = {}, upgrades = {}, seen = time(), source = source,
    }
    for tier in (f[7] or ""):gmatch("%d+") do peer.tiers[tonumber(tier)] = true end
    for upgrade in (f[8] or ""):gmatch("[^.]+") do peer.upgrades[#peer.upgrades + 1] = upgrade end
    local exportID = tostring(f[10] or ""):match("^%x%x%x%x%x%x%x%x$")
    peer.exportID = exportID
    SK.peers[sender] = peer
    if exportID and SK.db.community and SK.db.community[sender] then
        SK.db.community[sender].exportID = exportID
    end

    if not warnedNewer and VersionNumber(peer.version) > VersionNumber(SK.version) then
        warnedNewer = true
        SK.Print(L["a newer version (%s) is out. You have %s."]:format(peer.version, SK.version))
    end
    SK.Send("PEERS_CHANGED")
end)

------------------------------------------------------------------------
-- Questions other files ask
------------------------------------------------------------------------

-- Is this peer someone we can still see? (heard from recently)
local function Fresh(peer)
    return peer.demo or (time() - peer.seen) < STALE_SECONDS
end

-- Where we know a peer from, in words: "guild", "group", "friend" or "public".
local function KindOf(name, peer)
    local source = peer.source
    if source == "PARTY" or source == "RAID" or source == "INSTANCE_CHAT"
        or (UnitInParty and UnitInParty(Net.ShortName(name))) then return "group" end
    if source == "GUILD" then return "guild" end
    if source == "WHISPER" then return "friend" end
    if peer.demo then return "guild" end
    return "public"
end

-- Every mage running Scrollkeeper we've heard from recently:
-- list of { name (to mail), short, skill, tiers, kind }.
function SK.FreshMages()
    local list = {}
    for name, peer in pairs(SK.peers) do
        if Fresh(peer) and peer.class == "MAGE" and not Net.IsMe(name) then
            list[#list + 1] = { name = name, short = Net.ShortName(name), skill = peer.skill or 0,
                tiers = peer.tiers or {}, kind = KindOf(name, peer) }
        end
    end
    return list
end

-- Mages who get a skill-up from scrolls of this tier.
-- Returns a list of { name, skill, group = true/false }, group members first.
function SK.MagesWhoNeed(tier)
    local list = {}
    for name, peer in pairs(SK.peers) do
        if Fresh(peer) and peer.class == "MAGE" and peer.tiers[tier] then
            local inGroup = peer.source == "PARTY" or peer.source == "RAID" or peer.source == "INSTANCE_CHAT"
                or (UnitInParty and UnitInParty(Net.ShortName(name)))
            list[#list + 1] = { name = Net.ShortName(name), skill = peer.skill, group = inGroup and true or false }
        end
    end
    table.sort(list, function(a, b)
        if a.group ~= b.group then return a.group end
        return a.skill < b.skill
    end)
    return list
end

-- Everyone heard from recently, mages first.
function SK.PeerList()
    local list = {}
    for name, peer in pairs(SK.peers) do
        if Fresh(peer) then
            list[#list + 1] = { name = Net.ShortName(name), peer = peer }
        end
    end
    table.sort(list, function(a, b)
        local am, bm = a.peer.class == "MAGE", b.peer.class == "MAGE"
        if am ~= bm then return am end
        return a.peer.skill > b.peer.skill
    end)
    return list
end

------------------------------------------------------------------------
-- When to say hello
------------------------------------------------------------------------

local helloPending
local function HelloSoon()
    if helloPending then return end
    helloPending = true
    C_Timer.After(5, function()
        helloPending = false
        SK.SendHello()
    end)
end

SK.Listen("NET_READY", function()
    Net.Send("Q")
    SK.SendHello()
    C_Timer.NewTicker(5 * 60, SK.SendHello)
end)
SK.Listen("SKILL_CHANGED", HelloSoon)
SK.On("GROUP_JOINED", function() Net.Send("Q") HelloSoon() end)
