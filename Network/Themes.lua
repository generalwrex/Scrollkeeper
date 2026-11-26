-- Scrollkeeper: Network/Themes.lua
-- Holiday themes, sent by the dev team and signed with its key (see
-- Network/Board.lua), so new ones can come out without an update.
-- Every Scrollkeeper keeps the ones it got and passes them on.
--
--   BT|signature|key|name|months|colors|tip|at
--       key: a short name (letters), months: "10" or "1,2" ("0": withdrawn),
--       colors: 24 hex digits, background, bars, accent and title text
--       (rrggbb each), then 2 more for its order (which one "automatically"
--       picks when two share a month: lower first), tip: a few words

local _, SK = ...
local L = SK.L
local Net = SK.Net

local unpack = unpack or table.unpack

local function Now() return (GetServerTime and GetServerTime()) or time() end

local function Saved()
    SK.db.sharedThemes = type(SK.db.sharedThemes) == "table" and SK.db.sharedThemes or {}
    return SK.db.sharedThemes
end

local function Payload(t)
    return table.concat({ "SK1T", t.key, t.name, t.months, t.colors, t.tip, tostring(t.at) }, "|")
end

local function Plain(text, max)
    text = tostring(text or ""):gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > max then return nil end
    return text
end

-- A theme message as we'd keep it, or nil.
local function Valid(t)
    if type(t.key) ~= "string" or not t.key:match("^[a-z]+$") or #t.key > 16 then return nil end
    if t.key == "classic" or t.key == "modern" or t.key == "dark" or t.key == "darker" or t.key == "darkclassic" then return nil end
    t.name, t.tip = Plain(t.name, 32), Plain(t.tip, 80)
    if not (t.name and t.name ~= "" and t.tip) then return nil end
    if type(t.colors) ~= "string" or not t.colors:match("^%x+$") or (#t.colors ~= 24 and #t.colors ~= 26) then return nil end
    t.order = #t.colors == 26 and tonumber(t.colors:sub(25, 26), 16) or 50
    local months = {}
    for m in tostring(t.months or ""):gmatch("%d+") do
        m = tonumber(m)
        if m < 0 or m > 12 then return nil end
        if m > 0 then months[#months + 1] = m end
    end
    t.monthList = months
    if not (tonumber(t.at) and t.at < Now() + 600) then return nil end
    return t
end

local function Colors(hex)
    local out = {}
    for i = 1, 4 do
        local part = hex:sub(i * 6 - 5, i * 6)
        out[i] = { tonumber(part:sub(1, 2), 16) / 255, tonumber(part:sub(3, 4), 16) / 255, tonumber(part:sub(5, 6), 16) / 255 }
    end
    return out
end

local function Apply(t)
    if #t.monthList == 0 then
        SK.UI.RemoveHoliday(t.key)
    else
        local c = Colors(t.colors)
        SK.UI.AddHoliday(t.key, t.name, t.tip, t.monthList, c[1], c[2], c[3], c[4], tonumber(t.order))
    end
end

local function Keep(t)
    local saved = Saved()
    local have = saved[t.key]
    if have and (have.at or 0) >= t.at then return end
    saved[t.key] = { key = t.key, name = t.name, months = t.months, colors = t.colors, tip = t.tip, at = t.at, sig = t.sig }
    Apply(Valid(saved[t.key]))
    SK.Send("THEMES_CHANGED")
    if SK.UI.ApplyTheme then SK.UI.ApplyTheme() end
end

function SK.ThemesFromNetwork()
    if SK.RemoteOff and SK.RemoteOff("Themes") then return false end
    return SK.db and SK.db.share and SK.db.themesShared ~= false
end

Net.Handle("BT", function(_, f)
    if not SK.ThemesFromNetwork() then return end
    local t = { sig = f[1], key = f[2], name = f[3], months = f[4], colors = f[5], tip = f[6], at = tonumber(f[7]) }
    if not Valid(t) then return end
    local have = Saved()[t.key]
    if have and (have.at or 0) >= t.at then return end
    SK.VerifySigned(Payload(t), t.sig, function() Keep(t) end)
end)

local function Send(target, t)
    local fields = { t.sig, t.key, t.name, t.months, t.colors, t.tip, t.at }
    if target then Net.SendTo(target, "BT", unpack(fields)) else Net.Send("BT", unpack(fields)) end
end

-- Pass every theme we have on to one player (catching up).
function SK.PassOnThemes(target)
    if not SK.ThemesFromNetwork() then return end
    for _, t in pairs(Saved()) do Send(target, t) end
end

-- For the dev team (needs the signing key): put out a theme, or update
-- one. colors: 24 hex digits. Returns true, or nil and why.
function SK.ShareTheme(key, name, months, colors, tip)
    local t = { key = key, name = name, months = months, colors = colors, tip = tip or "", at = Now() }
    if not Valid(t) then return nil, L["that theme isn't right (key, name, months or colors)."] end
    t.sig = SK.SignForTeam and SK.SignForTeam(Payload(t))
    if not t.sig then return nil, L["only the dev team can share themes."] end
    Keep(t)
    Send(nil, t)
    return true
end

-- Resend them all (the team does now and then).
function SK.ResendThemes()
    for _, t in pairs(Saved()) do Send(nil, t) end
end

-- At login: the themes we kept.
SK.Listen("READY", function()
    for key, t in pairs(Saved()) do
        local ok = type(t) == "table" and Valid({ key = t.key, name = t.name, months = t.months, colors = t.colors, tip = t.tip, at = t.at })
        if ok then Apply(ok) else Saved()[key] = nil end
    end
    if SK.UI.ApplyTheme then SK.UI.ApplyTheme() end
end)
