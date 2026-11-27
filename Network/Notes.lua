-- Scrollkeeper: Network/Notes.lua
-- Notes from the Scrollkeeper team, signed with its key (see
-- Network/Board.lua), so they can't come from anyone else:
--   news   a line of news, shown once in chat (between updates too)
--   off    a feature switched off for everyone until a fix is out
--          (value "1" off, "0" back on), with why
--   ver    the latest released version (key "latest", value "1.4.0"):
--          an older Scrollkeeper says once that it's out
-- Only text and on/off: never code.
--
--   BN|signature|kind|key|value|why|at
--   news: key = an id, value = the text, why = ""
--   off:  key = a module ("Bag", "Board", "Doors"...), value = "1" or "0"

local _, SK = ...
local L = SK.L
local Net = SK.Net

local NEWS_DAYS = 14     -- news older than this isn't shown any more
local unpack = unpack or table.unpack

local function Now() return (GetServerTime and GetServerTime()) or time() end

local function Saved()
    local db = SK.db
    db.teamNotes = type(db.teamNotes) == "table" and db.teamNotes or {}
    db.teamNewsSeen = type(db.teamNewsSeen) == "table" and db.teamNewsSeen or {}
    return db.teamNotes
end

local function Payload(n)
    return table.concat({ "SK1N", n.kind, n.key, n.value, n.why, tostring(n.at) }, "|")
end

local function Plain(text, max)
    text = tostring(text or ""):gsub("[%c|]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > max then text = text:sub(1, max):gsub("[\192-\255][\128-\191]*$", "") end
    return text
end

local function Valid(n)
    if n.kind ~= "news" and n.kind ~= "off" and n.kind ~= "ver" then return nil end
    n.key = Plain(n.key, 24)
    if n.key == "" or not n.key:match("^[%w%-_]+$") then return nil end
    n.value, n.why = Plain(n.value, 150), Plain(n.why, 80)
    if n.kind == "off" and n.value ~= "1" and n.value ~= "0" then return nil end
    if n.kind == "news" and n.value == "" then return nil end
    if n.kind == "ver" and not (n.key == "latest" and n.value:match("^%d+%.%d+%.?%d*$")) then return nil end
    if not (tonumber(n.at) and n.at < Now() + 600 and n.at > Now() - 60 * 86400) then return nil end
    return n
end

------------------------------------------------------------------------
-- Switched off
------------------------------------------------------------------------

-- Has the Scrollkeeper team switched this feature off for now?
function SK.RemoteOff(key)
    local db = SK.db
    local n = db and type(db.teamNotes) == "table" and db.teamNotes["off:" .. tostring(key)]
    return n and n.value == "1" or false, n and n.why
end

------------------------------------------------------------------------
-- Showing a note
------------------------------------------------------------------------

local function ShowNews(n)
    local seen = SK.db.teamNewsSeen
    if seen[n.key] or (n.at or 0) < Now() - NEWS_DAYS * 86400 then return end
    seen[n.key] = Now()
    print("|TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t |cffffe14d" .. L["Scrollkeeper news:"] .. "|r |cffffffff" .. n.value .. "|r")
end

local function Apply(n, quiet)
    if n.kind == "ver" then
        -- The same notice as hearing a newer version from a player (once a session).
        if SK.NoteVersion then SK.NoteVersion(n.value) end
    elseif n.kind == "news" then
        if not quiet then ShowNews(n) end
    elseif n.kind == "off" and not quiet then
        if n.value == "1" then
            SK.Print(L["the Scrollkeeper team switched off %s for now%s. It comes back by itself when it's fixed."]:format(
                n.key, n.why ~= "" and (": " .. n.why) or ""))
        else
            SK.Print(L["%s is back on."]:format(n.key))
        end
        if SK.ApplyPanelSettings then SK.Safely("panel", SK.ApplyPanelSettings) end
        SK.Send("REMOTE_SWITCHED")
    end
end

local function Keep(n)
    local saved = Saved()
    local id = n.kind .. ":" .. n.key
    local have = saved[id]
    if have and (have.at or 0) >= n.at then return end
    saved[id] = { kind = n.kind, key = n.key, value = n.value, why = n.why, at = n.at, sig = n.sig }
    -- Already in this state (a resend): say nothing.
    Apply(saved[id], have and have.value == n.value)
end

Net.Handle("BN", function(_, f)
    local n = Valid({ sig = f[1], kind = f[2], key = f[3], value = f[4], why = f[5], at = tonumber(f[6]) })
    if not n then return end
    local have = Saved()[n.kind .. ":" .. n.key]
    if have and (have.at or 0) >= n.at then return end
    SK.VerifySigned(Payload(n), n.sig, function() Keep(n) end)
end)

local function Send(target, n)
    local fields = { n.sig, n.kind, n.key, n.value, n.why, n.at }
    if target then Net.SendTo(target, "BN", unpack(fields)) else Net.Send("BN", unpack(fields)) end
end

-- Pass every note we have on to one player (catching up).
function SK.PassOnNotes(target)
    for _, n in pairs(Saved()) do Send(target, n) end
end

-- For the Scrollkeeper team (needs the signing key). Returns true, or nil and why.
function SK.SendTeamNote(kind, key, value, why)
    local n = Valid({ kind = kind, key = key, value = value, why = why or "", at = Now() })
    if not n then return nil, L["that note isn't right."] end
    -- Always newer than the last one about the same thing (two in one second).
    local have = Saved()[n.kind .. ":" .. n.key]
    if have and (have.at or 0) >= n.at then n.at = have.at + 1 end
    n.sig = SK.SignForTeam and SK.SignForTeam(Payload(n))
    if not n.sig then return nil, L["only the Scrollkeeper team can send that."] end
    Keep(n)
    Send(nil, n)
    return true
end

function SK.ResendTeamNotes()
    for _, n in pairs(Saved()) do Send(nil, n) end
end

function SK.TeamNotes() return Saved() end

-- Old news goes; at login, news you haven't seen yet shows.
SK.Listen("READY", function()
    local saved = Saved()
    for id, n in pairs(saved) do
        if type(n) ~= "table" or (n.kind == "news" and (n.at or 0) < Now() - NEWS_DAYS * 86400) then saved[id] = nil end
    end
    C_Timer.After(8, function()
        for _, n in pairs(Saved()) do
            if n.kind == "news" then SK.Safely("team news", ShowNews, n) end
            if n.kind == "ver" and SK.NoteVersion then SK.Safely("team version", SK.NoteVersion, n.value) end
        end
    end)
end)
