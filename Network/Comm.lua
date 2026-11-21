-- Scrollkeeper: Network/Comm.lua
-- How copies of Scrollkeeper on different players' computers talk.
--
-- Messages are short lines of text sent as hidden "addon messages" to
-- your guild, your group and (optionally) a shared public channel.
-- Format:  KIND|field|field|...
--
-- Nothing is sent in combat: messages wait in a queue until it ends.
-- Turn sharing off in the settings and nothing is sent at all.

local _, SK = ...
local L = SK.L

SK.Net = {}
local Net = SK.Net

Net.PREFIX = "Scrollkeeper"
Net.PROTOCOL = 1                       -- bump if the message format changes
Net.CHANNEL_NAME = "ScrollkeeperNet"   -- the optional public channel
local SEND_INTERVAL = 0.25             -- how often the sender looks at the queue
-- The game gives each addon a small budget: a burst of about 10 messages,
-- then about 1 a second, and every destination (guild, channel...) costs
-- one. Past it, messages are silently dropped (result 3). So we keep our own
-- budget a little under that and only send when it allows.
local BUDGET_MAX, BUDGET_PER_SECOND = 8, 0.8
local budget, budgetAt = BUDGET_MAX, 0
-- Which messages go first. Who's online (hello, "who's there?", doors,
-- spares) must never wait behind bulk data (odds, drop spots...).
local PRIORITY = { Q = 1, H = 1, G = 2, S = 2, DA = 2, DY = 2, DN = 2 }
local nextSendAt = 0                   -- after a "throttled" answer, wait a little
local MAX_LENGTH = 250                 -- the game allows 255 bytes per message

local queue = {}
local handlers = {}

------------------------------------------------------------------------
-- Who am I, who sent this
------------------------------------------------------------------------

function Net.MyName()
    local name, realm = UnitFullName("player")
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

-- Short name for display: "Kaelith" for players on your realm.
function Net.ShortName(sender)
    if Ambiguate then return Ambiguate(sender, "short") end
    return (sender:gsub("%-.*$", ""))
end

-- Your own messages echo back to you through guild and group chat. The
-- sender name isn't reliable for spotting them (on Forever it can include
-- your title), so the hello carries your character's unique ID, and the
-- first echo of it tells us exactly how our own name comes back.
local mySenderNames = {}

function Net.RememberMyself(sender)
    if mySenderNames[sender] then return end
    mySenderNames[sender] = true
    -- Throw away anything saved from our own echo before we knew.
    SK.peers[sender] = nil
    if SK.db.community then SK.db.community[sender] = nil end
    for key, library in pairs(SK.db.sharedLibraries or {}) do
        library.from[sender] = nil
        if not next(library.from) then SK.db.sharedLibraries[key] = nil end
    end
    SK.Send("PEERS_CHANGED")
    SK.Send("COMMUNITY_CHANGED")
end

function Net.IsMe(sender)
    if mySenderNames[sender] then return true end
    -- (On Forever UnitName gives only the first name: check the full one too.)
    local mine = UnitName("player")
    local full = SK.PlayerFullName and SK.PlayerFullName()
    return sender == mine or sender == full or sender == Net.MyName()
end

------------------------------------------------------------------------
-- Receiving
-- Usage:  Net.Handle("H", function(sender, fields, source) ... end)
--         source is "GUILD", "PARTY", "RAID", "INSTANCE_CHAT", "CHANNEL" or "WHISPER"
------------------------------------------------------------------------

function Net.Handle(kind, fn)
    handlers[kind] = handlers[kind] or {}
    table.insert(handlers[kind], fn)
end

local function Split(text)
    local fields = {}
    for field in (text .. "|"):gmatch("(.-)|") do fields[#fields + 1] = field end
    return fields
end

-- Counts for /sk who: what actually arrives and leaves, before any
-- filtering, to find out where messages get lost.
Net.stats = { since = time(), received = 0, senders = {}, kinds = {}, sources = {}, sent = 0, refused = 0, results = {} }

-- The last messages in and out, for the dev network window (Dev/Network.lua).
-- Each: { at, dir = "in"/"out", kind, where, who, size, result }.
Net.log = {}
local LOG_MAX = 100
function Net.Log(entry)
    entry.at = GetTime()
    table.insert(Net.log, entry)
    if #Net.log > LOG_MAX then table.remove(Net.log, 1) end
end

-- Per player heard: { count, last = GetTime(), kind, source } (before filtering).
Net.heard = {}

function Net.ResetStats()
    Net.stats = { since = time(), received = 0, senders = {}, kinds = {}, sources = {}, sent = 0, refused = 0, results = {} }
    Net.log, Net.heard = {}, {}
end

SK.On("CHAT_MSG_ADDON", function(prefix, text, source, sender)
    if prefix ~= Net.PREFIX or type(text) ~= "string" then return end
    local stats = Net.stats
    local fields = Split(text)
    local kind = table.remove(fields, 1)
    -- Our own messages echo back: counted on their own, not with everyone's.
    if kind == "H" and fields[9] and fields[9] == UnitGUID("player") then Net.RememberMyself(sender) end
    if Net.IsMe(sender) then
        stats.echo, stats.echoLast = (stats.echo or 0) + 1, GetTime()
    else
        stats.received = stats.received + 1
        if type(sender) == "string" then stats.senders[sender] = true end
        if type(source) == "string" then stats.sources[source] = (stats.sources[source] or 0) + 1 end
        if kind then stats.kinds[kind] = (stats.kinds[kind] or 0) + 1 end
        if type(sender) == "string" then
            local who = Net.heard[sender] or { count = 0 }
            who.count, who.last, who.kind, who.source = who.count + 1, GetTime(), kind, source
            Net.heard[sender] = who
        end
        Net.Log({ dir = "in", kind = kind, where = source, who = sender, size = #text })
    end
    if not (SK.db and SK.db.share) then
        -- Sharing off: nothing else is read, but a newer version is still
        -- worth knowing about (from guild and group hellos).
        if kind == "H" and tonumber(fields[1]) == Net.PROTOCOL and not Net.IsMe(sender) and SK.NoteVersion then
            SK.Safely("version", SK.NoteVersion, fields[2])
        end
        return
    end
    if kind == "H" and fields[9] and fields[9] == UnitGUID("player") then
        Net.RememberMyself(sender)
        return
    end
    if Net.IsMe(sender) then return end
    for _, fn in ipairs(handlers[kind] or {}) do
        SK.Safely("message " .. kind, fn, sender, fields, source)
    end
end)

------------------------------------------------------------------------
-- Sending
------------------------------------------------------------------------

-- Where to send: every channel we're part of right now.
local function Destinations()
    local list = {}
    if IsInGuild and IsInGuild() then list[#list + 1] = { "GUILD" } end
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        list[#list + 1] = { "INSTANCE_CHAT" }
    elseif IsInRaid and IsInRaid() then
        list[#list + 1] = { "RAID" }
    elseif IsInGroup and IsInGroup() then
        list[#list + 1] = { "PARTY" }
    end
    if SK.db.shareChannel and GetChannelName then
        local id = GetChannelName(Net.CHANNEL_NAME)
        if id and id > 0 then list[#list + 1] = { "CHANNEL", id } end
    end
    return list
end

-- Queue a message. `fields` are joined with "|". Fields must not contain "|".
function Net.Send(kind, ...)
    if not (SK.db and SK.db.share) then return end
    local parts = { kind }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)) or ""):gsub("|", "/")
    end
    local text = table.concat(parts, "|")
    if #text > MAX_LENGTH then
        SK.Print(L["internal: message too long, not sent ("] .. kind .. ")")
        return
    end
    -- Replace an older queued message of the same kind and first field,
    -- so a burst of updates becomes one message.
    -- Net.onlyTo (set around a call) sends just to one place, e.g. "GUILD".
    local only = Net.onlyTo and { { Net.onlyTo } } or nil
    local key = kind .. "|" .. tostring((select(1, ...)) or "") .. (Net.onlyTo and ("@" .. Net.onlyTo) or "")
    local priority = PRIORITY[kind] or 3
    for i, queued in ipairs(queue) do
        if queued.key == key then queue[i] = { key = key, text = text, priority = priority, only = only } return end
    end
    -- Behind everything of the same or higher priority, ahead of the rest.
    local at = #queue + 1
    for i, queued in ipairs(queue) do
        if queued.priority > priority then at = i break end
    end
    table.insert(queue, at, { key = key, text = text, priority = priority, only = only })
end

-- How many messages are waiting (for /sk who).
function Net.QueueLength() return #queue end

-- For the dev network window: the queue, the budget and the backoff.
function Net.Inspect()
    local kinds = {}
    for i, message in ipairs(queue) do kinds[i] = message.key:match("^[^|]+") .. (message.tries and ("x" .. message.tries) or "") end
    return { queue = kinds, budget = budget, budgetMax = BUDGET_MAX, perSecond = BUDGET_PER_SECOND,
        backoff = math.max(0, nextSendAt - GetTime()), destinations = Destinations() }
end

-- Send one message straight to one player (used to find friends who run
-- Scrollkeeper). Goes out right away, not through the queue.
function Net.Whisper(target, kind, ...)
    if not (SK.db and SK.db.share and target and C_ChatInfo) or SK.InCombat() then return end
    local parts = { kind }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)) or ""):gsub("|", "/")
    end
    local text = table.concat(parts, "|")
    if #text > MAX_LENGTH then return end
    budget = budget - 1   -- whispers spend the same budget
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, Net.PREFIX, text, "WHISPER", target)
    Net.Log({ dir = "out", kind = kind, where = "WHISPER", who = target, size = #text, result = tostring(ok and result) })
end

-- Send a list of "a:b" items as several messages that each fit.
-- Each message is  KIND|head|item,item,item
function Net.SendList(kind, head, items)
    local chunk, length = {}, #kind + #tostring(head) + 4
    local part = 0
    local function Flush()
        if #chunk == 0 then return end
        part = part + 1
        Net.Send(kind, head .. "#" .. part, table.concat(chunk, ","))
        chunk, length = {}, #kind + #tostring(head) + 8
    end
    for _, item in ipairs(items) do
        if length + #item + 1 > MAX_LENGTH then Flush() end
        chunk[#chunk + 1] = item
        length = length + #item + 1
    end
    Flush()
end

-- The game's answer to a send: 0 (or true, on older clients) is sent;
-- 3 and 8 mean throttled (try again later); anything else won't ever work.
local THROTTLED = { [3] = true, [8] = true }

local function SendNext()
    if #queue == 0 or SK.InCombat() or GetTime() < nextSendAt then return end
    -- Refill the budget, then send only if it covers every destination.
    local now = GetTime()
    budget = math.min(BUDGET_MAX, budget + (now - budgetAt) * BUDGET_PER_SECOND)
    budgetAt = now
    local destinations = queue[1].only or Destinations()
    if budget < #destinations then return end
    budget = budget - #destinations
    local message = table.remove(queue, 1)
    local retry = {}
    for _, destination in ipairs(destinations) do
        local ok, result = pcall(C_ChatInfo.SendAddonMessage, Net.PREFIX, message.text, destination[1], destination[2])
        local stats = Net.stats
        Net.Log({ dir = "out", kind = message.key:match("^[^|]+"), where = destination[1], size = #message.text,
            result = tostring(ok and result) })
        local key = destination[1] .. ":" .. tostring(ok and result)
        stats.results[key] = (stats.results[key] or 0) + 1
        if ok and (result == nil or result == true or result == 0) then
            stats.sent = stats.sent + 1
        else
            stats.refused = stats.refused + 1
            if ok and THROTTLED[result] then retry[#retry + 1] = destination end
        end
    end
    -- Throttled somewhere: back off a few seconds and try just those again
    -- (at most 3 times), instead of losing the message.
    if #retry > 0 then
        nextSendAt = GetTime() + 3
        message.tries = (message.tries or 0) + 1
        if message.tries <= 3 then
            message.only = retry
            table.insert(queue, 1, message)
        end
    end
end

------------------------------------------------------------------------
-- Start up
------------------------------------------------------------------------

-- Join the public channel without showing it in any chat window.
-- Your chat channels as { id, name } in order (/1 General, /2 Trade...).
local function ChannelList()
    local list, raw = {}, GetChannelList and { GetChannelList() } or {}
    for i = 1, #raw, 3 do
        if type(raw[i]) == "number" and type(raw[i + 1]) == "string" then
            list[#list + 1] = { id = raw[i], name = raw[i + 1] }
        end
    end
    return list
end

-- Our channel must never take /1 (General) or any number before the game's
-- own channels: move it to the end, one swap at a time, so the others keep
-- their order.
local function MoveChannelLast()
    local swap = C_ChatInfo and C_ChatInfo.SwapChatChannelsByChannelIndex
    if not swap then return end
    for _ = 1, 10 do
        local list, mine = ChannelList(), nil
        for i, channel in ipairs(list) do
            if channel.name:lower() == Net.CHANNEL_NAME:lower() then mine = i end
        end
        if not mine or mine == #list then return end
        if not SK.Try(swap, list[mine].id, list[mine + 1].id) then return end
    end
end
Net.MoveChannelLast = MoveChannelLast

-- Have the game's own channels (General...) been joined yet?
local function GameChannelsReady()
    for _, channel in ipairs(ChannelList()) do
        if channel.name:lower() ~= Net.CHANNEL_NAME:lower() then return true end
    end
    return false
end

local waitedForChannels = 0
function Net.UpdateChannel()
    if not (JoinTemporaryChannel and GetChannelName) then return end
    local joined = GetChannelName(Net.CHANNEL_NAME) > 0
    if joined then MoveChannelLast() end
    if SK.db.share and SK.db.shareChannel and not joined then
        -- Join after General and the rest, so ours gets the last number.
        -- (Give up waiting after a minute: some places have no channels.)
        if not GameChannelsReady() and waitedForChannels < 60 then
            waitedForChannels = waitedForChannels + 5
            C_Timer.After(5, Net.UpdateChannel)
            return
        end
        JoinTemporaryChannel(Net.CHANNEL_NAME)
        C_Timer.After(2, MoveChannelLast)
        C_Timer.After(1, function()
            for i = 1, NUM_CHAT_WINDOWS or 10 do
                local frame = _G["ChatFrame" .. i]
                if frame and ChatFrame_RemoveChannel then ChatFrame_RemoveChannel(frame, Net.CHANNEL_NAME) end
            end
        end)
    elseif joined and not (SK.db.share and SK.db.shareChannel) then
        LeaveChannelByName(Net.CHANNEL_NAME)
    end
end

SK.Listen("READY", function()
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
    C_ChatInfo.RegisterAddonMessagePrefix(Net.PREFIX)
    C_Timer.NewTicker(SEND_INTERVAL, function() SK.Safely("send", SendNext) end)
    -- Wait a little after login: guild and channels aren't ready at once.
    C_Timer.After(8, function()
        Net.UpdateChannel()
        SK.Send("NET_READY")
    end)
end)
