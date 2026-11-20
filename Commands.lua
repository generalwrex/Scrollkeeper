-- Scrollkeeper: Commands.lua
-- /sk            show or hide the panel
-- /sk log        the Luck Log window: what your deciphers have produced
-- /sk logchat    the same, printed in chat
-- /sk tooltips   turn the tooltip lines on or off
-- /sk announce   turn the "deciphered: ..." chat line on or off
-- /sk reset      move the panel (and scroll icon) back to the middle of the screen
-- /sk options    open the settings page
-- /sk simple     simple panel: buttons, bars and your scrolls
-- /sk advanced   advanced panel: everything
-- /sk plan       the Farming Plan window
-- /sk net        the Fellow Mages window: other mages and community odds
-- /sk swap       the Scroll Swap window
-- /sk doors      Liminal Passage doors: who you can teleport to
-- /sk mail       who could use your spare scrolls
-- /sk demo       fill Fellow Mages, the map and tooltips with made-up players
-- /sk export     copy your scroll data to share (GitHub issue "Share your data")
-- /sk backup     copy all your Scrollkeeper data; /sk restore puts it back
-- /sk setup      the first-time setup window
-- /sk about      version and links
-- /sk bug        copy a bug report (GitHub issue "Bug report")
-- /sk scan       scan the auction house for scroll prices
--                (in the dev copy, Dev/Scan.lua makes it a data dump instead)

local _, SK = ...
local L = SK.L

local function OnOff(value) return value and L["on"] or L["off"] end

local commands = {}

commands[""] = function()
    if SK.isMage then
        SK.TogglePanel()
    elseif #SK.MyOtherMages() > 0 then
        SK.ToggleAltPanel()
    else
        SK.Print(L["log in on a mage once, and this character will show your mages' skill and Study timers."])
    end
end

commands.log = function() SK.ToggleLog() end
commands.logchat = function() SK.PrintLog() end

commands.tooltips = function()
    SK.db.showTooltips = not SK.db.showTooltips
    SK.Print(L["tooltip lines "] .. OnOff(SK.db.showTooltips))
end

commands.announce = function()
    SK.db.announce = not SK.db.announce
    SK.Print(L["decipher messages "] .. OnOff(SK.db.announce))
end

commands.reset = function()
    if SK.InCombat() then SK.Print(L["not in combat."]) return end
    SK.db.panelPoint = nil
    SK.db.scale = 1
    if ScrollkeeperPanel then
        ScrollkeeperPanel:ClearAllPoints()
        ScrollkeeperPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        ScrollkeeperPanel:SetScale(1)
    end
    SK.Print(L["panel moved to the middle of the screen."])
    -- The scroll icon too, if it's in use (it can get lost off screen).
    if SK.db.scrollIcon and SK.ResetIconPosition then SK.ResetIconPosition() end
end

commands.options = function() SK.OpenOptions() end
commands.simple = function() SK.db.viewMode = "compact"; SK.ApplyPanelSettings() end
commands.advanced = function() SK.db.viewMode = "full"; SK.ApplyPanelSettings() end
commands.net = function() SK.ToggleNetwork() end
commands.network = commands.net
commands.demo = function() SK.ToggleDemo() end
commands.export = function() SK.ShowExport() end
-- /sk mail: who could use your spare scrolls (same list as the mailbox).
commands.mail = function()
    local plan = SK.MailPlan and SK.MailPlan() or {}
    local spare = #(SK.bags.untranslated or {})
    if #plan == 0 then
        SK.Print(L["mail list is empty. You're carrying %d untranslated |4scroll:scrolls;; "]:format(spare)
            .. L["nobody known (your other mages, or Scrollkeeper users online) can use the spare ones."])
        return
    end
    SK.Print(L["who could use your scrolls:"])
    for _, person in ipairs(plan) do
        print(L["  %s (%s): %d skill-up, %d they can read, %d for later"]:format(person.name, person.kind,
            person.ups, person.reads, person.later or 0))
    end
end
commands.swap = function() SK.ToggleSwap() end
commands.doors = function() SK.ToggleDoors() end
commands.door = commands.doors
commands.setup = function() SK.ShowSetup() end
commands.scan = function() SK.ScanAuctionScrolls() end
commands.plan = function() SK.TogglePlan() end
commands.about = function()
    SK.Print(L["version %s by generalwrex. Links are in Options > AddOns > Scrollkeeper > About."]:format(SK.version))
    print("  " .. L["In game: %s (PvE). Say hi!"]:format(SK.AUTHOR_CHARACTER or "Archmage Naage"))
    for _, link in ipairs(SK.LINKS or {}) do
        print(("  |cffffd100%s|r  %s"):format(L[link[1]], link[2]))
    end
end
commands.bug = function() SK.ShowBugReport() end
commands.backup = function() SK.ShowBackup() end
commands.restore = function() SK.ShowRestore() end
commands.config = commands.options

commands.help = function()
    SK.Print(L["commands: /sk, /sk simple, /sk advanced, /sk options, /sk plan, /sk log, /sk logchat, /sk net, /sk swap, /sk doors, /sk mail, /sk export, /sk backup, /sk restore, /sk bug, /sk scan, /sk setup, /sk about, /sk demo, /sk reset"])
end

------------------------------------------------------------------------
-- Dev commands: for whoever works on Scrollkeeper from a git clone. They
-- only run in a dev copy (SK.devCopy: the packager never filled in the TOC
-- version); in a CurseForge copy they just say so.
--
--   /sk dev    list the dev commands
--   /sk who    everyone heard: real name, race, faction, how and when
--              (to see why a whisper doesn't reach someone)
------------------------------------------------------------------------

local DEV_COMMANDS = {
    { "dev", "this list" },
    { "who", "everyone heard: real name, race, faction, source, last heard" },
    { "places", "Doorways towns: map ID, the zone name /who searches, and your faction's" },
    { "realms", "your realm, connected realms, and every player heard with their realm (copy box)" },
    { "scan", "dump game data to the saved file (Dev/Scan.lua)" },
    { "show", "show the latest scan to copy" },
    { "eventlog", "start or stop recording game events" },
    { "clear", "wipe the recorded scan data" },
}

local function DevOnly(run)
    return function(...)
        if not SK.devCopy then
            SK.Print("that's a dev command (only in a copy run from the git repo).")
            return
        end
        return run(...)
    end
end

commands.dev = DevOnly(function()
    SK.Print("dev commands (this copy runs from git):")
    for _, entry in ipairs(DEV_COMMANDS) do
        print(("  |cffffd100/sk %s|r  %s"):format(entry[1], entry[2]))
    end
end)

-- Every Doorways town with the zone name the game gives its map ID, so a
-- wrong map ID shows up (MISSING, or the wrong zone next to the town).
-- Realms: yours, the connected ones, and everyone heard, with whether
-- Fellow Mages counts them as reachable. In the copy box.
commands.realms = DevOnly(function()
    local lines = {}
    local function Add(text) lines[#lines + 1] = text end
    Add("Realm: " .. tostring(GetRealmName and GetRealmName()))
    Add("Normalized: " .. tostring(GetNormalizedRealmName and GetNormalizedRealmName()))
    Add("Faction: " .. tostring(UnitFactionGroup and UnitFactionGroup("player")))
    local connected = GetAutoCompleteRealms and { GetAutoCompleteRealms() } or {}
    local names = {}
    for _, value in ipairs(connected) do
        if type(value) == "table" then for _, name in ipairs(value) do names[#names + 1] = tostring(name) end
        else names[#names + 1] = tostring(value) end
    end
    Add("Connected realms (game): " .. (#names > 0 and table.concat(names, ", ") or "none listed"))
    Add("")
    Add("Players heard (" .. SK.version .. "):")
    local senders = {}
    for sender in pairs(SK.peers or {}) do senders[#senders + 1] = sender end
    table.sort(senders)
    for _, sender in ipairs(senders) do
        local peer = SK.peers[sender]
        local realm, race = "", "?"
        if peer.guid and GetPlayerInfoByGUID then
            local ok, _, _, _, englishRace, _, _, guidRealm = pcall(GetPlayerInfoByGUID, peer.guid)
            if ok then realm, race = tostring(guidRealm or ""), tostring(englishRace or "?") end
        end
        local anon = peer.anonymous
        Add(("%s | real: %s | realm: %s | %s %s | %s | %s%s%s"):format(anon and "anonymous player" or sender,
            anon and "hidden" or SK.ContactName(sender),
            realm ~= "" and realm or "(same as yours)", race, tostring(SK.FactionOfRace(race) or "?"),
            tostring(peer.class), SK.IsUnreachable(sender) and "UNREACHABLE" or "reachable",
            peer.anonymous and " (anonymous)" or "", peer.offline and " (offline)" or ""))
    end
    if #senders == 0 then Add("  nobody heard yet") end
    SK.ShowTextBox("Realms", table.concat(lines, "\n"))
end)

commands.places = DevOnly(function()
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    local lines = { "You: " .. tostring(mine), "" }
    for _, place in ipairs(SK.DOOR_PLACES or {}) do
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(place.map)
        local zone = info and info.name or "MISSING"
        local shown = (place.side == "both" or place.side == mine) and "" or "   (other faction, not listed)"
        lines[#lines + 1] = ("%-24s map %d -> %s  [%s]%s"):format(place.town, place.map, zone, place.side, shown)
    end
    SK.ShowTextBox("Doorways places", table.concat(lines, "\n"))
end)

commands.who = DevOnly(function()
    local myFaction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    print(("you: realm %q, normalized %q, %s"):format(tostring(GetRealmName and GetRealmName()),
        tostring(GetNormalizedRealmName and GetNormalizedRealmName()), myFaction))
    -- The public channel: are we in it, at which number, and how many
    -- players are in it with us (everyone running Scrollkeeper online now).
    local id = GetChannelName and GetChannelName(SK.Net.CHANNEL_NAME) or 0
    local members = id > 0 and GetNumChannelMembers and SK.Try(GetNumChannelMembers, id)
    print(("channel %s: %s, members %s, sharing %s, channel on %s"):format(SK.Net.CHANNEL_NAME,
        id > 0 and ("/" .. id) or "NOT JOINED", tostring(members or "?"), tostring(SK.db.sharing), tostring(SK.db.shareChannel)))
    -- What the network actually did since login (before any filtering).
    local stats = SK.Net.stats
    if stats then
        local senders = 0
        for _ in pairs(stats.senders) do senders = senders + 1 end
        local function List(t) local out = {} for k, v in pairs(t) do out[#out + 1] = k .. "=" .. v end table.sort(out) return table.concat(out, " ") end
        print(("net since %d min: received %d messages from %d players [%s] by [%s]"):format(
            math.floor((time() - stats.since) / 60), stats.received, senders, List(stats.kinds), List(stats.sources)))
        print(("sent %d ok, %d refused [%s]"):format(stats.sent, stats.refused, List(stats.results)))
    end
    local names = {}
    for sender in pairs(SK.peers or {}) do names[#names + 1] = sender end
    table.sort(names)
    if #names == 0 then SK.Print("nobody heard yet.") return end
    SK.Print(("%d heard (you're %s). Red = other server or faction: hidden from the lists."):format(#names, myFaction))
    for _, sender in ipairs(names) do
        local peer = SK.peers[sender]
        local real, race, faction = "?", "?", "?"
        if peer.guid and GetPlayerInfoByGUID then
            local ok, _, _, localRace, englishRace, _, name, realm = pcall(GetPlayerInfoByGUID, peer.guid)
            if ok and name then
                real = (realm and realm ~= "") and (name .. "-" .. realm) or name
                race = localRace or englishRace or "?"
                faction = SK.FactionOfRace(englishRace) or "?"
            else
                real = "not cached yet"
            end
        elseif not peer.guid then
            real = "no ID yet (heard before this /reload?)"
        end
        local color = (SK.IsUnreachable and SK.IsUnreachable(sender)) and "ff5555" or "ffffff"
        local ago = peer.seen and (time() - peer.seen) or -1
        -- Anonymous means anonymous, here too: no names.
        local shown = sender
        if peer.anonymous then shown, real = "anonymous player", "hidden" end
        print(("  |cff%s%s|r  real: %s  ·  %s %s  ·  %s %s, %ds ago  ·  v%s%s"):format(color, shown, real,
            race, faction, peer.class or "?", peer.source or "?", ago, peer.version or "?",
(peer.offline and "  |cff808080(offline)|r" or "")))
    end
end)

-- Dev/Scan.lua adds commands.scan, show, eventlog and clear (dev copies only:
-- that file isn't in the CurseForge package).
SK.commands = commands

SLASH_SCROLLKEEPER1 = "/sk"
SLASH_SCROLLKEEPER2 = "/scrollkeeper"
SlashCmdList["SCROLLKEEPER"] = function(input)
    local word, rest = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local run = commands[word] or commands.help
    SK.Safely("/sk " .. word, run, rest)
end
