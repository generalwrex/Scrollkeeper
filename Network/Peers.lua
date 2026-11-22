-- Scrollkeeper: Network/Peers.lua
-- Who else runs Scrollkeeper, and what their mages can use.
--
--   Q                       "who's there?"  Everyone answers with H.
--   H|protocol|version|class|level|skill|max|tiers|upgrades|guid|exportID|anon|alt|altSkill|altTiers
--        alt...    on a non-mage: their best mage (same realm and faction)
--        ruleset   (field 15) "PvE", "PvP", "RP" or "RP-PvP"
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

-- Someone runs a newer Scrollkeeper: say so once per session. (Also with
-- sharing set to None: Network/Comm.lua passes just the version along.)
function SK.NoteVersion(version)
    if warnedNewer or not (SK.db and SK.db.updateNotice ~= false) then return end
    if VersionNumber(version) > VersionNumber(SK.version) then
        warnedNewer = true
        SK.Print(L["a newer version (%s) is out. You have %s. Update it on CurseForge, Wago or WowUp."]:format(tostring(version), SK.version))
    end
end

------------------------------------------------------------------------
-- Telling others about me
------------------------------------------------------------------------

local function MyTiers()
    local skill = SK.GetComprehension()
    -- Not learned yet (trains at level 6): tier 1 scrolls are the first
    -- they'll read, so others can send some for later.
    if not skill.known then return "1" end
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
            local english = SK.EnglishScrollName and SK.EnglishScrollName(scroll.itemID) or scroll.name
            if english == upgrade.scroll or scroll.name == upgrade.scroll then held[#held + 1] = upgrade.short end
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

-- On a non-mage: your best mage on this realm and faction, so others can
-- mail it scrolls: name, skill, and the tiers it still levels from.
local function AltMageFields()
    if SK.isMage or not SK.MailableMages then return "", "", "" end
    local mage = SK.MailableMages()[1]
    if not mage then return "", "", "" end
    if (mage.skill or 0) <= 0 then return (tostring(mage.name):gsub("|", "")), 0, "1" end
    local tiers = {}
    for _, tier in ipairs(SK.TIERS) do
        local chance = SK.SkillUpChance(tier, mage.skill)
        if mage.skill >= tier and chance and chance.gives then tiers[#tiers + 1] = tier end
    end
    return (tostring(mage.name):gsub("|", "")), mage.skill, table.concat(tiers, ".")
end

local function HelloFields()
    local _, class = UnitClass("player")
    local skill = SK.GetComprehension()
    -- A dev copy says "dev": older versions read that as 0, so they never
    -- tell their player to update because of it.
    return Net.PROTOCOL, SK.devCopy and "dev" or SK.version, class, UnitLevel("player"),
        skill.rank, skill.max, SK.isMage and MyTiers() or "", SK.isMage and MyUpgrades() or "",
        UnitGUID("player"), SK.db.share and SK.ExportID() or "", SK.db.anonymous and "1" or "",
        AltMageFields()
end

-- The hello, with your ruleset (PvE, PvP, RP, RP-PvP) at the end: the
-- most reliable way for others to know if they can reach you.
local function HelloWithRuleset()
    local fields = { HelloFields() }
    for i = #fields + 1, 14 do fields[i] = "" end
    fields[15] = SK.ServerKind and SK.ServerKind() or ""
    return (unpack or table.unpack)(fields, 1, 15)
end

local lastHelloAt = 0
function SK.SendHello()
    lastHelloAt = time()
    Net.Send("H", HelloWithRuleset())
end

-- Friends who aren't in your guild or group: ask each online friend
-- directly. Only ones running Scrollkeeper answer.
-- At most once every 2 minutes (it runs on login, every 10 minutes and
-- at every mailbox visit; each whisper spends the sending budget).
local lastPingAt = 0
local function PingFriends()
    if not (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex) then return end
    if time() - lastPingAt < 120 then return end
    lastPingAt = time()
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
        C_Timer.After(1 + math.random() * 2, function() Net.Whisper(sender, "H", HelloWithRuleset()) end)
        return
    end
    -- On the public channel everyone hears everyone's hello anyway (every 5
    -- minutes): only answer if we haven't said hello in the last minute, so
    -- one login doesn't make 150 players answer at once.
    if source == "CHANNEL" and time() - lastHelloAt < 60 then return end
    -- Answer after a short random wait so a whole guild doesn't reply at once.
    C_Timer.After(1 + math.random() * (source == "CHANNEL" and 20 or 4), function()
        if source == "CHANNEL" and time() - lastHelloAt < 60 then return end
        SK.SendHello()
    end)
end)

------------------------------------------------------------------------
-- Are they still online? (hovering a name in Fellow Mages)
-- We whisper them a hidden "Q". Online: they answer with a hello. Gone (or
-- the other faction): the game says "No player named ... is currently
-- playing", which we hide and mark them offline. Once per 30 seconds each.
------------------------------------------------------------------------

local pendingChecks = {}   -- short real name, lowercased -> the sender name we know them by
local function CheckKey(name) return (Net.ShortName(name or "")):lower() end

-- Kept apart from the peer: their answer (a hello) replaces the peer, and
-- the tooltip asking again right away made a whisper loop.
local checkedAt = {}
function SK.CheckOnline(sender)
    local peer = SK.peers[sender]
    if not peer or peer.demo or Net.IsMe(sender) then return end
    if checkedAt[sender] and time() - checkedAt[sender] < 30 then return end
    checkedAt[sender] = time()
    local target = SK.ContactName(sender)
    local key = CheckKey(target)
    pendingChecks[key] = sender
    Net.Whisper(target, "Q")
    C_Timer.After(6, function() if pendingChecks[key] == sender then pendingChecks[key] = nil end end)
end

-- Opening the panel or Fellow Mages: check everyone listed who hasn't been
-- heard from in a minute, a few at a time, so the list is right without
-- hovering each name. Each mage at most every 2 minutes.
local listCheckedAt = {}
function SK.CheckListedOnline()
    if not SK.PeerList then return end
    local now, delay = time(), 0
    for _, entry in ipairs(SK.PeerList()) do
        local sender, peer = entry.sender, entry.peer
        if not peer.offline and not peer.demo and now - (peer.seen or 0) > 60
            and (not listCheckedAt[sender] or now - listCheckedAt[sender] >= 120) then
            listCheckedAt[sender] = now
            C_Timer.After(delay, function() SK.Safely("online check", SK.CheckOnline, sender) end)
            delay = delay + 0.25
        end
    end
end

-- "No player named '%s' is currently playing." as a pattern.
local function NotFoundPattern()
    local text = ERR_CHAT_PLAYER_NOT_FOUND_S
    if type(text) ~= "string" then return nil end
    text = text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)")
    return "^" .. text .. "$"
end

if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message)
        local pattern = type(message) == "string" and next(pendingChecks) and NotFoundPattern()
        local name = pattern and message:match(pattern)
        local sender = name and pendingChecks[CheckKey(name)]
        if not sender then return false end
        pendingChecks[CheckKey(name)] = nil
        if SK.peers[sender] then SK.peers[sender].offline, SK.peers[sender].offlineAt = true, time() end
        SK.Send("PEERS_CHANGED")
        return true   -- our own check: don't show the error in chat
    end)
end

Net.Handle("H", function(sender, f, source)
    local protocol = tonumber(f[1]) or 0
    if protocol ~= Net.PROTOCOL then return end
    -- The answer to an online check comes from their real name, which can
    -- differ from the (titled) name we list them by: update that one.
    local checked = source == "WHISPER" and pendingChecks[CheckKey(sender)]
    if checked and SK.peers[checked] and checked ~= sender then
        pendingChecks[CheckKey(sender)] = nil
        SK.peers[checked].seen, SK.peers[checked].offline, SK.peers[checked].offlineAt = time(), nil, nil
        SK.Send("PEERS_CHANGED")
        return
    end
    if checked then pendingChecks[CheckKey(sender)] = nil end
    -- Keep where we first heard them (an online check answers by whisper).
    local old = SK.peers[sender]
    if source == "WHISPER" and old and old.source then source = old.source end
    local peer = {
        version = f[2], class = f[3], level = tonumber(f[4]) or 0,
        skill = math.min(tonumber(f[5]) or 0, 300), max = math.min(tonumber(f[6]) or 0, 300),
        tiers = {}, upgrades = {}, seen = time(), source = source,
    }
    for tier in (f[7] or ""):gmatch("%d+") do peer.tiers[tonumber(tier)] = true end
    for upgrade in (f[8] or ""):gmatch("[^.]+") do peer.upgrades[#peer.upgrades + 1] = upgrade end
    local exportID = tostring(f[10] or ""):match("^%x%x%x%x%x%x%x%x$")
    peer.exportID = exportID
    -- Their character's unique ID, for their real name (see SK.ContactName).
    peer.guid = tostring(f[9] or ""):match("^Player%-[%x%-]+$")
    SK.peers[sender] = peer
    -- Anonymous players still count, but never show up by name.
    peer.anonymous = f[11] == "1"
    local RULESETS = { PvE = true, PvP = true, RP = true, ["RP-PvP"] = true, Hardcore = true }
    peer.ruleset = RULESETS[f[15] or ""] and f[15] or nil
    -- Playing another class but has a mage: remember it, to list and mail it.
    local altName = tostring(f[12] or ""):sub(1, 40)
    if peer.class ~= "MAGE" and altName ~= "" then
        local alt = { name = altName, skill = math.min(tonumber(f[13]) or 0, 300), tiers = {} }
        for tier in (f[14] or ""):gmatch("%d+") do alt.tiers[tonumber(tier)] = true end
        peer.alt = alt
    end
    if SK.db.community and SK.db.community[sender] then
        SK.db.community[sender].exportID = exportID
    end

    SK.NoteVersion(peer.version)
    SK.Safely("mage history", SK.RememberMage, sender, peer)
    SK.Send("PEERS_CHANGED")
end)

------------------------------------------------------------------------
-- Questions other files ask
------------------------------------------------------------------------

-- The name to whisper or mail someone by. On Forever the sender name that
-- comes with their messages can include their title ("Lofi Frostbeats"),
-- which whispers and mail don't accept. Their hello carries their
-- character's ID, and the game turns that into the real name.
function SK.ContactName(sender)
    local peer = SK.peers[sender]
    if peer and peer.guid and GetPlayerInfoByGUID then
        local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, peer.guid)
        if ok and type(name) == "string" and name ~= "" then
            -- On Forever the realms of one server (Realm 1 PvE, Realm 3
            -- PvE...) are layers: whispers and mail only work by the plain
            -- name there. Keep the realm only for a different server.
            if type(realm) == "string" and realm ~= "" and not (SK.SameServerRealm and SK.SameServerRealm(realm)) then
                return name .. "-" .. realm:gsub("[%s%-]", "")
            end
            return name
        end
    end
    return Net.ShortName(sender)
end

-- The name to mail someone's mage by (they're on another class right now).
function SK.AltMailName(sender)
    local peer = SK.peers[sender]
    if not (peer and peer.alt) then return nil end
    local realm = SK.ContactName(sender):match("%-([^%-]+)$")
    return realm and (peer.alt.name .. "-" .. realm) or peer.alt.name
end

-- Faction by race, for players the game only tells us the race of.
local RACE_FACTION = {
    Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance",
    Draenei = "Alliance", Worgen = "Alliance", VoidElf = "Alliance", LightforgedDraenei = "Alliance",
    DarkIronDwarf = "Alliance", KulTiran = "Alliance", Mechagnome = "Alliance",
    Orc = "Horde", Scourge = "Horde", Tauren = "Horde", Troll = "Horde", BloodElf = "Horde",
    Goblin = "Horde", Nightborne = "Horde", HighmountainTauren = "Horde", MagharOrc = "Horde",
    ZandalariTroll = "Horde", Vulpera = "Horde",
    Pandaren = "either", Dracthyr = "either", EarthenDwarf = "either",
}

function SK.FactionOfRace(englishRace) return RACE_FACTION[englishRace or ""] end

-- Can we actually reach this player? The shared channel reaches every
-- Forever server (PvE, PvP, RP, RP-PvP) and maybe the other faction, but
-- whispers, mail and trades only work on your own server and faction, so
-- the lists leave everyone else out. (Their shared data still counts.)
local function Plain(text) return ((text or ""):gsub("[%s%-]", "")):lower() end
-- Our own server, as both spellings: the display name and the "normalized"
-- one that sender names carry ("Name-Server").
-- Forever has 4 rulesets (PvE, PvP, RP, RP-PvP), each made of connected
-- realms: "CAMWOW US1 Realm 1 PvE" and "...Realm 2 PvE" can whisper, mail
-- and group with each other. So a realm counts as ours when the game lists
-- it as connected, or when it's the same ruleset (ends in PvE...).
local function RealmKind(plain)
    -- Hardcore isn't out yet; this guesses its realm names end like this.
    for _, kind in ipairs({ "hardcore", "hc", "rppvp", "pvp", "rp", "pve" }) do
        if plain:sub(-#kind) == kind then return kind == "hc" and "hardcore" or kind end
    end
end

local function MyRealms()
    local realms = {}
    realms[Plain(SK.RealmName())] = true
    if GetNormalizedRealmName then
        local normalized = SK.Try(GetNormalizedRealmName)
        if type(normalized) == "string" then realms[Plain(normalized)] = true end
    end
    for _, connected in ipairs({ GetAutoCompleteRealms and SK.Try(GetAutoCompleteRealms) or nil }) do
        if type(connected) == "table" then
            for _, name in ipairs(connected) do realms[Plain(name)] = true end
        elseif type(connected) == "string" then
            realms[Plain(connected)] = true
        end
    end
    realms[""] = nil
    -- And the ruleset: any realm of the same ruleset is reachable.
    for name in pairs(realms) do
        local kind = RealmKind(name)
        if kind then realms.kind = kind end
    end
    -- Realm name empty right now: the ruleset we saw last time.
    if not realms.kind and SK.ServerKind then
        local label = SK.ServerKind()
        realms.kind = label and Plain(label)
    end
    return realms
end

-- Your ruleset as people say it: "PvE", "PvP", "RP" or "RP-PvP"
-- (nil if the realm name doesn't say).
local KIND_LABELS = { pve = "PvE", pvp = "PvP", rp = "RP", rppvp = "RP-PvP", hardcore = "Hardcore" }
-- The realm name is sometimes empty (seen right after logging in), so
-- the last one we got is remembered for this character.
function SK.ServerKind()
    local kind = RealmKind(Plain(SK.RealmName()))
    if not kind and GetNormalizedRealmName then kind = RealmKind(Plain(SK.Try(GetNormalizedRealmName))) end
    local guid = UnitGUID and SK.Known(UnitGUID("player"))
    local saved = SK.db and type(guid) == "string" and SK.db
    if saved then
        saved.rulesetOf = type(saved.rulesetOf) == "table" and saved.rulesetOf or {}
        if kind then saved.rulesetOf[guid] = kind else kind = saved.rulesetOf[guid] end
    end
    return kind and KIND_LABELS[kind]
end

-- Someone's ruleset: what their hello says (1.2.1+), else from their realm
-- (name suffix or character ID; no realm known means it's ours). Or nil.
function SK.RulesetOf(sender)
    local peer = SK.peers[sender]
    if peer and peer.ruleset then return peer.ruleset end
    local realm = sender:match("%-([^%-]+)$")
    if not realm and peer and peer.guid and GetPlayerInfoByGUID then
        local ok, _, _, _, _, _, _, guidRealm = pcall(GetPlayerInfoByGUID, peer.guid)
        if ok and type(guidRealm) == "string" then realm = guidRealm ~= "" and guidRealm or SK.RealmName() end
    end
    local kind = realm and RealmKind(Plain(realm))
    return kind and KIND_LABELS[kind]
end

-- "Fellow PvE Mages" (just "Fellow Mages" if the realm name doesn't say).
function SK.FellowMagesTitle()
    local kind = SK.ServerKind()
    return kind and L["Fellow %s Mages"]:format(kind) or L["Fellow Mages"]
end

-- Is this realm (as a sender suffix or from their ID) one we can reach?
local function OurRealm(realms, realm)
    local plain = Plain(realm)
    if realms[plain] then return true end
    -- Realm numbers are layers of one server: only the kind matters. If
    -- either name doesn't say its kind, keep them (better shown than hidden).
    local kind = RealmKind(plain)
    if not kind or not realms.kind then return true end
    return kind == realms.kind
end

-- Is this realm one of ours (same ruleset, any realm number)?
function SK.SameServerRealm(realm)
    return OurRealm(MyRealms(), realm)
end

local function Unreachable(sender, peer)
    if peer.demo then return false end
    -- They told us their ruleset (1.2.0 and up): that settles it.
    local mine = SK.ServerKind and SK.ServerKind()
    if peer.ruleset and mine and peer.ruleset ~= mine then return true end
    local realms = MyRealms()
    -- Another ruleset: the sender name says so ("Name-Realm"), or their ID does.
    local senderRealm = sender:match("%-([^%-]+)$")
    if senderRealm and next(realms) and not OurRealm(realms, senderRealm) then return true end
    if not (peer.guid and GetPlayerInfoByGUID) then return false end
    local ok, _, _, _, englishRace, _, _, realm = pcall(GetPlayerInfoByGUID, peer.guid)
    if not ok then return false end
    if type(realm) == "string" and realm ~= "" and next(realms) and not OurRealm(realms, realm) then return true end
    -- The other faction (Pandaren and unknown races could be either: keep them).
    local faction = RACE_FACTION[englishRace or ""]
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    return faction ~= nil and faction ~= "either" and mine ~= nil and faction ~= mine
end
SK.IsUnreachable = function(sender) return SK.peers[sender] and Unreachable(sender, SK.peers[sender]) or false end

-- Is this peer someone we can still see? (heard from recently)
-- Found offline by a hover check: gone from the lists after this many
-- minutes (the "Keep offline mages for" setting, 5 by default).
local function Fresh(peer)
    if peer.demo then return true end
    local keep = (tonumber(SK.db and SK.db.offlineMinutes) or 5) * 60
    if peer.offline and peer.offlineAt and time() - peer.offlineAt >= keep then return false end
    -- Their ruleset is unknown (old version, or the empty-realm bug) and a
    -- whisper can't reach them: most likely another ruleset. Gone at once
    -- instead of grayed out for a while.
    if peer.offline and not peer.ruleset then return false end
    return (time() - peer.seen) < STALE_SECONDS
end

-- Where we know a peer from, in words: "guild", "group", "friend" or "public".
local function KindOf(name, peer)
    local source = peer.source
    if source == "PARTY" or source == "RAID" or source == "INSTANCE_CHAT"
        or (UnitInParty and SK.Known(UnitInParty(Net.ShortName(name)))) then return "group" end
    if source == "GUILD" then return "guild" end
    if source == "WHISPER" then return "friend" end
    if peer.demo then return "guild" end
    return "public"
end

------------------------------------------------------------------------
-- Mage history: the last few mages you could reach, saved, so you can
-- still mail them scrolls after they log off. Small on purpose: at most
-- HISTORY_MAX mages, each forgotten after HISTORY_DAYS without a word.
--   SK.db.mageHistory[real name] = { name, level, skill, tiers = { 15, 50 }, seen }
------------------------------------------------------------------------

local HISTORY_MAX, HISTORY_DAYS = 15, 7

local function PruneHistory()
    local history = SK.db.mageHistory or {}
    -- Names saved with a realm of our own server (before 1.2.0 knew realms
    -- were layers) lose it: mail only reaches the plain name.
    for key, entry in pairs(history) do
        local base, realm = key:match("^(.-)%-([^%-]+)$")
        if base and SK.SameServerRealm and SK.SameServerRealm(realm) then
            history[key] = nil
            entry.name = base
            if not history[base] or (history[base].seen or 0) < (entry.seen or 0) then history[base] = entry end
        end
    end
    local cutoff, list = time() - HISTORY_DAYS * 86400, {}
    for key, entry in pairs(history) do
        if (entry.seen or 0) < cutoff then history[key] = nil else list[#list + 1] = key end
    end
    table.sort(list, function(a, b) return history[a].seen > history[b].seen end)
    for i = HISTORY_MAX + 1, #list do history[list[i]] = nil end
end

-- Do we really know where they are? Their ruleset, a realm on their name,
-- or a realm from their ID (the game often doesn't know far-away players).
local function WhereKnown(sender, peer)
    if peer.ruleset or sender:find("%-") then return true end
    if not (peer.guid and GetPlayerInfoByGUID) then return false end
    local ok, _, _, _, _, _, _, realm = pcall(GetPlayerInfoByGUID, peer.guid)
    return ok and type(realm) == "string" and realm ~= ""
end

function SK.RememberMage(sender, peer)
    if peer.anonymous or peer.demo or Net.IsMe(sender) or Unreachable(sender, peer) then return end
    -- The history is only for people we're sure about.
    if not WhereKnown(sender, peer) then return end
    local mage, name, level = peer, SK.ContactName(sender), peer.level
    if peer.class ~= "MAGE" then
        if not peer.alt then return end
        mage, name, level = peer.alt, SK.AltMailName(sender), nil
    end
    if not name or name == "" then return end
    local tiers = {}
    for _, tier in ipairs(SK.TIERS) do if mage.tiers[tier] then tiers[#tiers + 1] = tier end end
    SK.db.mageHistory = SK.db.mageHistory or {}
    -- Saved account-wide: note the ruleset and faction, so only characters
    -- who can reach them list them.
    SK.db.mageHistory[name] = { name = name, level = level, skill = mage.skill, tiers = tiers, seen = time(),
        ruleset = SK.ServerKind and SK.ServerKind() or nil, faction = UnitFactionGroup and UnitFactionGroup("player") or nil }
    PruneHistory()
end

-- Mages from the history who aren't online right now (newest first):
-- list of { name, level, skill, tiers = { [15] = true }, seen }.
function SK.MageHistory()
    if not SK.db then return {} end
    PruneHistory()
    local online = {}
    for name, peer in pairs(SK.peers) do
        -- Anyone still in the live list (even grayed out as offline) isn't
        -- repeated from the history.
        if Fresh(peer) then
            online[SK.ContactName(name):lower()] = true
            local alt = SK.AltMailName(name)
            if alt then online[alt:lower()] = true end
        end
    end
    local list = {}
    local ruleset = SK.ServerKind and SK.ServerKind() or nil
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    for key, entry in pairs(SK.db.mageHistory or {}) do
        -- Only mages this character can reach: same ruleset and faction.
        -- (Both sides must be known: nil matching nil let other rulesets in.)
        local reachable = ruleset ~= nil and entry.ruleset == ruleset and entry.faction == faction
        if reachable and not online[key:lower()] then
            local tiers = {}
            for _, tier in ipairs(entry.tiers or {}) do tiers[tier] = true end
            list[#list + 1] = { name = entry.name, level = entry.level, skill = entry.skill or 0, tiers = tiers, seen = entry.seen }
        end
    end
    table.sort(list, function(a, b) return a.seen > b.seen end)
    return list
end

-- Every mage running Scrollkeeper we've heard from recently:
-- list of { name (to mail), short, skill, tiers, kind }.
-- Anonymous players are left out unless includeAnonymous (for counts only).
function SK.FreshMages(includeAnonymous)
    local list = {}
    for name, peer in pairs(SK.peers) do
        if Fresh(peer) and peer.class == "MAGE" and not Net.IsMe(name) and not Unreachable(name, peer)
            and (includeAnonymous or not peer.anonymous) then
            list[#list + 1] = { name = SK.ContactName(name), short = Net.ShortName(name), skill = peer.skill or 0,
                tiers = peer.tiers or {}, kind = KindOf(name, peer) }
        elseif Fresh(peer) and peer.alt and not Net.IsMe(name) and not Unreachable(name, peer)
            and (includeAnonymous or not peer.anonymous) then
            -- On another class, but has a mage: mail goes to the mage.
            list[#list + 1] = { name = SK.AltMailName(name), short = peer.alt.name, skill = peer.alt.skill,
                tiers = peer.alt.tiers, kind = KindOf(name, peer), altOf = Net.ShortName(name) }
        end
    end
    return list
end

-- Mages who get a skill-up from scrolls of this tier.
-- Returns a list of { name, skill, group = true/false }, group members first.
function SK.MagesWhoNeed(tier)
    local list = {}
    for name, peer in pairs(SK.peers) do
        local mage = peer.class == "MAGE" and peer or peer.alt
        if Fresh(peer) and mage and mage.tiers[tier] and not peer.anonymous and not Unreachable(name, peer) then
            local inGroup = peer.source == "PARTY" or peer.source == "RAID" or peer.source == "INSTANCE_CHAT"
                or (UnitInParty and SK.Known(UnitInParty(Net.ShortName(name))))
            list[#list + 1] = { name = mage == peer and Net.ShortName(name) or mage.name, skill = mage.skill,
                group = inGroup and true or false }
        end
    end
    table.sort(list, function(a, b)
        if a.group ~= b.group then return a.group end
        return a.skill < b.skill
    end)
    return list
end

-- How many anonymous players we've heard from recently.
function SK.AnonymousCount()
    local count = 0
    for name, peer in pairs(SK.peers) do
        -- Only ones on your ruleset and faction, like everyone else listed.
        if Fresh(peer) and peer.anonymous and not Net.IsMe(name) and not Unreachable(name, peer) then count = count + 1 end
    end
    return count
end

-- Everyone heard from recently, mages first (anonymous players aren't listed).
function SK.PeerList()
    local list = {}
    for name, peer in pairs(SK.peers) do
        if Fresh(peer) and not peer.anonymous and not Unreachable(name, peer) then
            list[#list + 1] = { name = Net.ShortName(name), sender = name, peer = peer }
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
SK.On("PLAYER_LEVEL_UP", HelloSoon)
SK.On("GROUP_JOINED", function()
    Net.Send("Q")
    HelloSoon()
    if Net.SendVersionOnly then C_Timer.After(5, Net.SendVersionOnly) end
end)
