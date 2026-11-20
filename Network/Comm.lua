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
local SEND_INTERVAL = 0.4              -- seconds between messages (the game limits bursts)
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
    local mine = UnitName("player")
    return sender == mine or sender == Net.MyName()
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

SK.On("CHAT_MSG_ADDON", function(prefix, text, source, sender)
    if prefix ~= Net.PREFIX or type(text) ~= "string" then return end
    local stats = Net.stats
    stats.received = stats.received + 1
    if type(sender) == "string" then stats.senders[sender] = true end
    if type(source) == "string" then stats.sources[source] = (stats.sources[source] or 0) + 1 end
    if not (SK.db and SK.db.share) then return end
    local fields = Split(text)
    local kind = table.remove(fields, 1)
    if kind then stats.kinds[kind] = (stats.kinds[kind] or 0) + 1 end
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
    local key = kind .. "|" .. tostring((select(1, ...)) or "")
    for i, queued in ipairs(queue) do
        if queued.key == key then queue[i] = { key = key, text = text } return end
    end
    queue[#queue + 1] = { key = key, text = text }
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
    pcall(C_ChatInfo.SendAddonMessage, Net.PREFIX, text, "WHISPER", target)
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

local function SendNext()
    if #queue == 0 or SK.InCombat() then return end
    local message = table.remove(queue, 1)
    for _, destination in ipairs(Destinations()) do
        local ok, result = pcall(C_ChatInfo.SendAddonMessage, Net.PREFIX, message.text, destination[1], destination[2])
        -- The game answers with a result code: 0 (or true) is sent; anything
        -- else (throttled, not in channel...) means it never left.
        local stats = Net.stats
        local key = destination[1] .. ":" .. tostring(ok and result)
        stats.results[key] = (stats.results[key] or 0) + 1
        if ok and (result == nil or result == true or result == 0) then stats.sent = stats.sent + 1
        else stats.refused = stats.refused + 1 end
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
