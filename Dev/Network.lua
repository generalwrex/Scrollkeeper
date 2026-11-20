-- Scrollkeeper: Dev/Network.lua  (dev copies only, never packaged)
-- /sk netdev: everything about the network, live.
--   channel, sending (budget, queue, results), receiving (kinds, sources),
--   every player heard (raw, before any filtering) with why they're shown
--   or hidden, what the lists end up with, and the last 100 messages.
-- Buttons: Pause, Reset counters, Select all (Ctrl+C), Export (saves the
-- report into ScrollkeeperDB.netReport: /reload writes it to disk).

local _, SK = ...
local Net = SK.Net

local window, paused

local function Ago(at)
    if not at then return "never" end
    local seconds = math.floor(GetTime() - at)
    if seconds < 60 then return seconds .. "s" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m" end
    return math.floor(seconds / 3600) .. "h"
end

local function Sorted(t)
    local out = {}
    for k, v in pairs(t) do out[#out + 1] = tostring(k) .. "=" .. tostring(v) end
    table.sort(out)
    return table.concat(out, "  ")
end

local function Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- Race and faction from a GUID (if the game knows them yet).
local function WhoIs(guid)
    if not (guid and GetPlayerInfoByGUID) then return "?", "?", "" end
    local ok, _, _, _, englishRace, _, _, realm = pcall(GetPlayerInfoByGUID, guid)
    if not ok then return "?", "?", "" end
    return englishRace or "?", SK.FactionOfRace and SK.FactionOfRace(englishRace) or "?", realm or ""
end

-- Colors for the window (the export strips them).
local GOLD, GREY, WHITE, GREEN, RED, BLUE, ORANGE = "ffd100", "9d9d9d", "ffffff", "40ff40", "ff5555", "66bbff", "ff9933"
local function C(color, text) return "|cff" .. color .. tostring(text) .. "|r" end
local function Label(text, value) return C(GREY, text .. ": ") .. C(WHITE, value) end

-- Newer first: "1.2.1" > "1.2.0" > "1.1.4"; "dev" last.
local function VersionValue(v)
    local a, b, c = tostring(v):match("(%d+)%.(%d+)%.?(%d*)")
    if not a then return -1 end
    return tonumber(a) * 10000 + tonumber(b) * 100 + (tonumber(c) or 0)
end

function SK.NetReport()
    local L = {}
    local function Add(text) L[#L + 1] = text end
    local function Header(text) Add("") Add(C(GOLD, "\226\150\140 " .. text)) end

    Add(C(GOLD, "Scrollkeeper " .. SK.version) .. C(GREY, "  network report  " .. date("%Y-%m-%d %H:%M:%S")))
    Add(Label("You", tostring(UnitName("player"))) .. "   " .. Label("realm", tostring(GetRealmName and GetRealmName()))
        .. "   " .. Label("ruleset", tostring(SK.ServerKind and SK.ServerKind())) .. "   "
        .. Label("faction", tostring(UnitFactionGroup and UnitFactionGroup("player"))))
    Add(Label("Sharing", tostring(SK.db.sharing)) .. "   " .. Label("public channel", tostring(SK.db.shareChannel)))

    Header("Channel")
    local id = GetChannelName and GetChannelName(Net.CHANNEL_NAME) or 0
    local members = id > 0 and GetNumChannelMembers and SK.Try(GetNumChannelMembers, id)
    Add(Label(Net.CHANNEL_NAME, id > 0 and ("/" .. id) or C(RED, "NOT JOINED")) .. "   " .. Label("members", tostring(members or "?"))
        .. "   " .. Label("guild", tostring(IsInGuild and IsInGuild())) .. "   " .. Label("group", tostring(IsInGroup and IsInGroup())))

    Header("Versions out there")
    local versions = {}
    for _, peer in pairs(SK.peers or {}) do
        local v = tostring(peer.version or "?")
        versions[v] = (versions[v] or 0) + 1
    end
    local order = {}
    for v in pairs(versions) do order[#order + 1] = v end
    table.sort(order, function(a, b) return VersionValue(a) > VersionValue(b) end)
    local parts = {}
    for _, v in ipairs(order) do
        local color = VersionValue(v) >= VersionValue(SK.version) and GREEN or (VersionValue(v) >= 10200 and WHITE or ORANGE)
        parts[#parts + 1] = C(color, v .. " x" .. versions[v])
    end
    Add(#parts > 0 and table.concat(parts, C(GREY, "  \194\183  ")) or C(GREY, "nobody heard yet"))

    Header("Sending")
    local inspect = Net.Inspect and Net.Inspect() or {}
    local dests = {}
    for _, d in ipairs(inspect.destinations or {}) do dests[#dests + 1] = d[1] .. (d[2] and ("/" .. d[2]) or "") end
    local budgetColor = (inspect.budget or 0) >= 2 and GREEN or ORANGE
    Add(Label("budget", C(budgetColor, ("%.1f"):format(inspect.budget or 0)) .. C(GREY, (" / %d, +%.1f a second"):format(inspect.budgetMax or 0, inspect.perSecond or 0)))
        .. "   " .. Label("backoff", ("%.1fs"):format(inspect.backoff or 0)) .. "   " .. Label("to", table.concat(dests, ", ")))
    local queue = inspect.queue or {}
    Add(Label("queue", #queue) .. (#queue > 0 and C(GREY, "  next: ") .. C(WHITE, table.concat(queue, " ")) or ""))
    local stats = Net.stats or {}
    Add(Label("since", math.floor((time() - (stats.since or time())) / 60) .. " min") .. "   "
        .. C(GREEN, (stats.sent or 0) .. " sent") .. "   " .. C((stats.refused or 0) > 0 and RED or GREY, (stats.refused or 0) .. " refused"))
    local results = {}
    for key, n in pairs(stats.results or {}) do
        local code = key:match(":(.+)$")
        results[#results + 1] = C((code == "0" or code == "true") and GREEN or RED, key .. "=" .. n)
    end
    table.sort(results)
    Add(C(GREY, "results: ") .. table.concat(results, "  "))
    Add(C(GREY, "codes: 0 sent \194\183 3 addon throttle \194\183 8 channel throttle \194\183 7 bad channel \194\183 5 not in group"))

    Header("Receiving")
    local others = 0
    for sender in pairs(stats.senders or {}) do if not Net.IsMe(sender) then others = others + 1 end end
    Add(Label("received", (stats.received or 0) .. " messages") .. C(GREY, " from ") .. C(WHITE, others) .. C(GREY, " other players (plus your own echo)"))
    Add(C(GREY, "by kind: ") .. C(WHITE, Sorted(stats.kinds or {})))
    Add(C(GREY, "by source: ") .. C(WHITE, Sorted(stats.sources or {})))

    Header("Everyone heard (raw, before filtering)")
    local senders = {}
    for sender in pairs(Net.heard or {}) do senders[sender] = true end
    for sender in pairs(SK.peers or {}) do senders[sender] = true end
    local list = {}
    for sender in pairs(senders) do list[#list + 1] = sender end
    table.sort(list)
    for _, sender in ipairs(list) do
        local heard = (Net.heard or {})[sender] or {}
        local peer = SK.peers[sender]
        local race, faction, realm = WhoIs(peer and peer.guid)
        local why, color
        if Net.IsMe(sender) then why, color = "YOU (your own echo)", BLUE
        elseif not peer then why, color = "no hello yet (only data)", ORANGE
        elseif peer.anonymous then why, color = "anonymous (counted, not named)", GREY
        elseif SK.IsUnreachable(sender) then why, color = "hidden: other ruleset or faction", RED
        elseif peer.class ~= "MAGE" and not peer.alt then why, color = "not a mage", GREY
        else why, color = "LISTED", GREEN end
        local name = peer and peer.anonymous and "anonymous" or sender
        local versionColor = peer and VersionValue(peer.version) >= VersionValue(SK.version) and GREEN or ORANGE
        Add(C(color, "\226\151\143 " .. name) .. "  " .. C(color, why))
        Add("     " .. C(GREY, ("%d msgs, last %s ago (%s via %s)"):format(heard.count or 0, Ago(heard.last), tostring(heard.kind), tostring(heard.source)))
            .. "   " .. C(versionColor, "v" .. tostring(peer and peer.version or "?"))
            .. "  " .. C(WHITE, ("%s lvl %s skill %s"):format(tostring(peer and peer.class), tostring(peer and peer.level), tostring(peer and peer.skill)))
            .. "  " .. C(GREY, ("ruleset %s  realm %s  %s %s"):format(tostring(peer and peer.ruleset or "-"), realm ~= "" and realm or "-", race, faction))
            .. (peer and peer.offline and C(GREY, "  (offline)") or "") .. (peer and peer.alt and C(BLUE, "  alt mage " .. peer.alt.name) or ""))
    end
    if #list == 0 then Add(C(GREY, "nobody")) end

    Header("What the lists show")
    Add(Label("Fellow Mages", #(SK.FreshMages and SK.FreshMages() or {})) .. "   " .. Label("peer list", #(SK.PeerList and SK.PeerList() or {}))
        .. "   " .. Label("anonymous", SK.AnonymousCount and SK.AnonymousCount() or 0) .. "   " .. Label("history", #(SK.MageHistory and SK.MageHistory() or {})))
    Add(Label("open doors", #(SK.OpenDoors and SK.OpenDoors() or {})) .. "   " .. Label("players with spares", Count(SK.spares))
        .. "   " .. Label("community data from", Count(SK.db.community) .. " players"))

    Header("Last messages (newest last)")
    for _, entry in ipairs(Net.log or {}) do
        local arrow = entry.dir == "in" and C(GREEN, "<<") or C(ORANGE, ">>")
        local result = ""
        if entry.result then
            result = "  " .. C((entry.result == "0" or entry.result == "true") and GREEN or RED, "result " .. entry.result)
        end
        Add(C(GREY, ("%5s ago "):format(Ago(entry.at))) .. arrow .. "  " .. C(WHITE, ("%-3s"):format(tostring(entry.kind)))
            .. C(GREY, (" %-8s "):format(tostring(entry.where))) .. C(Net.IsMe(entry.who or "") and BLUE or WHITE, tostring(entry.who or ""))
            .. C(GREY, ("  %db"):format(entry.size or 0)) .. result)
    end
    return table.concat(L, "\n")
end

-- The report without colors (for the export).
function SK.NetReportPlain()
    return (SK.NetReport():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Build()
    window = CreateFrame("Frame", "ScrollkeeperNetDevFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(760, 560)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    if window.TitleText then window.TitleText:SetText("Scrollkeeper " .. SK.version .. ": Network (dev)") end
    tinsert(UISpecialFrames, "ScrollkeeperNetDevFrame")

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetFontObject(GameFontHighlightSmall)
    box:SetSpacing(2)
    box:SetWidth(700)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(box)
    window.box = box

    local function Button(text, x, onClick)
        local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        b:SetSize(130, 22)
        b:SetPoint("BOTTOMLEFT", x, 12)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    window.pause = Button("Pause", 12, function(self)
        paused = not paused
        self:SetText(paused and "Resume" or "Pause")
    end)
    Button("Reset counters", 148, function() if Net.ResetStats then Net.ResetStats() end SK.RefreshNetDev(true) end)
    Button("Select all", 284, function() window.box:SetFocus() window.box:HighlightText() end)
    Button("Export", 420, function()
        SK.db.netReport = { at = time(), text = SK.NetReportPlain() }
        SK.Print("network report saved. /reload writes it to disk (ScrollkeeperDB.netReport).")
    end)
    Button("Ask who's there", 556, function() Net.Send("Q") SK.Print("sent \"who's there?\" (Q).") end)
    window:Hide()
end

function SK.RefreshNetDev(force)
    if not (window and window:IsShown()) or (paused and not force) then return end
    local text = SK.NetReport()
    window.box:SetText(text)
end

SK.commands.netdev = function()
    if not SK.devCopy then SK.Print("that's a dev command (only in a copy run from the git repo).") return end
    if not window then Build() end
    window:SetShown(not window:IsShown())
    SK.RefreshNetDev(true)
end

SK.Listen("READY", function()
    if C_Timer.NewTicker then C_Timer.NewTicker(2, function() SK.Safely("net dev", SK.RefreshNetDev) end) end
end)
