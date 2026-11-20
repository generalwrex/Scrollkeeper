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
local SPEEDS, speedIndex, lastRefresh = { 0.5, 1, 2, 5 }, 2, 0   -- seconds between refreshes

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
    local function Header(text) Add("") Add(C(GOLD, ">> " .. text)) end

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

    -- Rulesets of everyone heard (yours in green).
    local rulesets = {}
    for sender in pairs(SK.peers or {}) do
        if not Net.IsMe(sender) then
            local r = SK.RulesetOf and SK.RulesetOf(sender) or "unknown"
            r = r or "unknown"
            rulesets[r] = (rulesets[r] or 0) + 1
        end
    end
    local mine = SK.ServerKind and SK.ServerKind()
    local rparts = {}
    for _, r in ipairs({ "PvE", "PvP", "RP", "RP-PvP", "Hardcore", "unknown" }) do
        if rulesets[r] then rparts[#rparts + 1] = C(r == mine and GREEN or (r == "unknown" and GREY or WHITE), r .. " x" .. rulesets[r]) end
    end
    Add(C(GREY, "rulesets: ") .. (#rparts > 0 and table.concat(rparts, C(GREY, "  \194\183  ")) or C(GREY, "nobody heard yet")))

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
    Add(Label("received", (stats.received or 0) .. " messages") .. C(GREY, " from ") .. C(WHITE, Count(stats.senders)) .. C(GREY, " other players"))
    Add(C(BLUE, ("your own echo: %d messages, last %s ago"):format(stats.echo or 0, Ago(stats.echoLast))) .. C(GREY, "  (left out of everything else)"))
    Add(C(GREY, "by kind: ") .. C(WHITE, Sorted(stats.kinds or {})))
    Add(C(GREY, "by source: ") .. C(WHITE, Sorted(stats.sources or {})))

    Header("Everyone heard (raw, before filtering)")
    local senders = {}
    for sender in pairs(Net.heard or {}) do senders[sender] = true end
    for sender in pairs(SK.peers or {}) do senders[sender] = true end
    for sender in pairs(senders) do if Net.IsMe(sender) then senders[sender] = nil end end
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
        Add(C(color, "* " .. name) .. "  " .. C(color, why))
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

------------------------------------------------------------------------
-- Graphs: the last 10 minutes in 10-second steps. Sampled all the time
-- (cheap), drawn while the window is open.
------------------------------------------------------------------------

local SAMPLES, STEP = 60, 10
local samples = {}                -- { inbound, outbound, refused, players }
local lastTotals = { received = 0, sent = 0, refused = 0 }

local function TakeSample()
    local stats = Net.stats or {}
    local players = 0
    for sender in pairs(Net.heard or {}) do if not Net.IsMe(sender) then players = players + 1 end end
    local function Delta(key)
        local now = stats[key] or 0
        local d = now - (lastTotals[key] or 0)
        lastTotals[key] = now
        return d < 0 and now or d   -- counters were reset
    end
    table.insert(samples, { inbound = Delta("received"), outbound = Delta("sent"), refused = Delta("refused"), players = players })
    if #samples > SAMPLES then table.remove(samples, 1) end
end

-- One graph: a dark box with SAMPLES columns of bars.
local function MakeGraph(parent, width, height, title)
    local graph = CreateFrame("Frame", nil, parent)
    graph:SetSize(width, height)
    local bg = graph:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    for i = 1, 3 do
        local line = graph:CreateTexture(nil, "BORDER")
        line:SetColorTexture(1, 1, 1, 0.06)
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", 0, height * i / 4)
        line:SetPoint("BOTTOMRIGHT", 0, height * i / 4)
    end
    graph.title = graph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    graph.title:SetPoint("TOPLEFT", 4, -3)
    graph.title:SetText(title)
    graph.peak = graph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    graph.peak:SetPoint("TOPRIGHT", -4, -3)
    graph.bars = {}
    local barWidth = width / SAMPLES
    for i = 1, SAMPLES do
        local column = {}
        for _, key in ipairs({ "a", "b", "c" }) do
            local bar = graph:CreateTexture(nil, "ARTWORK")
            bar:SetWidth(math.max(1, barWidth - 1))
            bar:SetPoint("BOTTOMLEFT", (i - 1) * barWidth, 0)
            bar:Hide()
            column[key] = bar
        end
        graph.bars[i] = column
    end
    graph.height, graph.width = height, width
    return graph
end

-- values: list of { a = n, b = n, c = n } (stacked a, b, c), colors for each.
local function DrawGraph(graph, values, colors, peakText)
    local max = 1
    for _, v in ipairs(values) do max = math.max(max, (v.a or 0) + (v.b or 0) + (v.c or 0)) end
    local offset = SAMPLES - #values
    for i = 1, SAMPLES do
        local v = values[i - offset]
        local column = graph.bars[i]
        local y = 0
        for _, key in ipairs({ "a", "b", "c" }) do
            local bar = column[key]
            local n = v and v[key] or 0
            if n > 0 then
                local h = math.max(1, n / max * (graph.height - 14))
                bar:ClearAllPoints()
                bar:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", (i - 1) * (graph.width / SAMPLES), y)
                bar:SetHeight(h)
                bar:SetColorTexture(colors[key][1], colors[key][2], colors[key][3], 0.9)
                bar:Show()
                y = y + h
            else
                bar:Hide()
            end
        end
    end
    graph.peak:SetText(peakText(max))
end

local function DrawGraphs()
    if not (window and window.messages) then return end
    local messages, players = {}, {}
    for i, sample in ipairs(samples) do
        messages[i] = { a = sample.inbound, b = sample.outbound, c = sample.refused }
        players[i] = { a = sample.players }
    end
    DrawGraph(window.messages, messages,
        { a = { 0.25, 1, 0.25 }, b = { 1, 0.6, 0.2 }, c = { 1, 0.3, 0.3 } },
        function(max) return ("|cff40ff40in|r / |cffff9933out|r / |cffff5555refused|r per 10s, peak %d"):format(max) end)
    local last = samples[#samples]
    DrawGraph(window.players, players, { a = { 0.4, 0.73, 1 } },
        function() return ("players heard: |cff66bbff%d|r"):format(last and last.players or 0) end)
end

local function Build()
    window = CreateFrame("Frame", "ScrollkeeperNetDevFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(760, 660)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    if type(window.TitleText) == "table" then window.TitleText:SetText("Scrollkeeper " .. SK.version .. ": Network (dev)") end
    tinsert(UISpecialFrames, "ScrollkeeperNetDevFrame")

    -- Graphs on top: messages (wide) and players heard.
    window.messages = MakeGraph(window, 470, 90, "Messages, last 10 min")
    window.messages:SetPoint("TOPLEFT", 12, -30)
    window.players = MakeGraph(window, 250, 90, "Players heard")
    window.players:SetPoint("TOPRIGHT", -12, -30)

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -130)
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
    -- Speed: how often the report redraws.
    local speed = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    speed:SetSize(60, 22)
    speed:SetPoint("BOTTOMRIGHT", -12, 12)
    local function SpeedLabel() speed:SetText(SPEEDS[speedIndex] .. "s") end
    SpeedLabel()
    speed:SetScript("OnClick", function() speedIndex = speedIndex % #SPEEDS + 1 SpeedLabel() end)
    window:Hide()
end

function SK.RefreshNetDev(force)
    if not (window and window:IsShown()) or (paused and not force) then return end
    local text = SK.NetReport()
    window.box:SetText(text)
    DrawGraphs()
end

SK.commands.netdev = function()
    if not SK.devCopy then SK.Print("that's a dev command (only in a copy run from the git repo).") return end
    if not window then Build() end
    window:SetShown(not window:IsShown())
    SK.RefreshNetDev(true)
end

SK.Listen("READY", function()
    if not C_Timer.NewTicker then return end
    C_Timer.NewTicker(0.25, function()
        if GetTime() - lastRefresh < SPEEDS[speedIndex] then return end
        lastRefresh = GetTime()
        SK.Safely("net dev", SK.RefreshNetDev)
    end)
    if SK.devCopy then C_Timer.NewTicker(STEP, function() SK.Safely("net dev sample", TakeSample) end) end
end)

SK.NetDevSample = function() TakeSample() DrawGraphs() end   -- for the test harness
