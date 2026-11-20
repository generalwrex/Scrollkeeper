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

function SK.NetReport()
    local L = {}
    local function Add(text) L[#L + 1] = text end
    local function Header(text) Add("") Add("== " .. text .. " ==") end

    Add(("Scrollkeeper %s network report, %s"):format(SK.version, date("%Y-%m-%d %H:%M:%S")))
    Add(("You: %s, realm %q (ruleset %s), %s, sharing %s, public channel %s"):format(
        tostring(UnitName("player")), tostring(GetRealmName and GetRealmName()), tostring(SK.ServerKind and SK.ServerKind()),
        tostring(UnitFactionGroup and UnitFactionGroup("player")), tostring(SK.db.sharing), tostring(SK.db.shareChannel)))

    Header("Channel")
    local id = GetChannelName and GetChannelName(Net.CHANNEL_NAME) or 0
    local members = id > 0 and GetNumChannelMembers and SK.Try(GetNumChannelMembers, id)
    Add(("%s: %s, members %s, in guild %s, in group %s"):format(Net.CHANNEL_NAME, id > 0 and ("/" .. id) or "NOT JOINED",
        tostring(members or "?"), tostring(IsInGuild and IsInGuild()), tostring(IsInGroup and IsInGroup())))

    Header("Sending")
    local inspect = Net.Inspect and Net.Inspect() or {}
    local dests = {}
    for _, d in ipairs(inspect.destinations or {}) do dests[#dests + 1] = d[1] .. (d[2] and ("/" .. d[2]) or "") end
    Add(("budget %.1f / %d (+%.1f a second), backoff %.1fs, destinations: %s"):format(inspect.budget or 0,
        inspect.budgetMax or 0, inspect.perSecond or 0, inspect.backoff or 0, table.concat(dests, ", ")))
    Add(("queue (%d, next first): %s"):format(#(inspect.queue or {}), table.concat(inspect.queue or {}, " ")))
    local stats = Net.stats or {}
    Add(("since %d min: sent %d ok, %d refused"):format(math.floor((time() - (stats.since or time())) / 60), stats.sent or 0, stats.refused or 0))
    Add("results (where:code): " .. Sorted(stats.results or {}))
    Add("codes: 0 sent, 3 addon throttle, 8 channel throttle, 7 bad channel, 5 not in group")

    Header("Receiving")
    Add(("received %d messages from %d players"):format(stats.received or 0, Count(stats.senders)))
    Add("by kind: " .. Sorted(stats.kinds or {}))
    Add("by source: " .. Sorted(stats.sources or {}))

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
        local why
        if not peer then why = "no hello yet (only data heard)"
        elseif peer.anonymous then why = "anonymous (counted, not named)"
        elseif SK.IsUnreachable(sender) then why = "HIDDEN: other ruleset or faction"
        elseif peer.class ~= "MAGE" and not peer.alt then why = "not a mage (no mage on account)"
        else why = "listed" end
        Add(("%s | %d msgs, last %s ago (%s via %s) | v%s %s lvl %s skill %s | ruleset %s realm %s | %s %s | %s%s%s"):format(
            peer and peer.anonymous and "anonymous" or sender, heard.count or 0, Ago(heard.last), tostring(heard.kind),
            tostring(heard.source), tostring(peer and peer.version), tostring(peer and peer.class), tostring(peer and peer.level),
            tostring(peer and peer.skill), tostring(peer and peer.ruleset or "-"), realm ~= "" and realm or "-", race, faction,
            why, peer and peer.offline and " (offline)" or "", peer and peer.alt and (" alt mage " .. peer.alt.name) or ""))
    end
    if #list == 0 then Add("nobody") end

    Header("What the lists show")
    Add(("Fellow Mages (fresh, reachable): %d   whole peer list: %d   anonymous: %d   history: %d"):format(
        #(SK.FreshMages and SK.FreshMages() or {}), #(SK.PeerList and SK.PeerList() or {}),
        SK.AnonymousCount and SK.AnonymousCount() or 0, #(SK.MageHistory and SK.MageHistory() or {})))
    Add(("open doors: %d   players with spares: %d   community data from: %d players"):format(
        #(SK.OpenDoors and SK.OpenDoors() or {}), Count(SK.spares), Count(SK.db.community)))

    Header("Last messages (newest last)")
    for _, entry in ipairs(Net.log or {}) do
        Add(("%s ago  %s  %-3s %-8s %s  %db%s"):format(Ago(entry.at), entry.dir == "in" and "<<" or ">>", tostring(entry.kind),
            tostring(entry.where), tostring(entry.who or ""), entry.size or 0, entry.result and ("  result " .. entry.result) or ""))
    end
    return table.concat(L, "\n")
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
    if window.TitleText then window.TitleText:SetText("Scrollkeeper: Network (dev)") end
    tinsert(UISpecialFrames, "ScrollkeeperNetDevFrame")

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetFontObject(GameFontHighlightSmall)
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
        SK.db.netReport = { at = time(), text = SK.NetReport() }
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
