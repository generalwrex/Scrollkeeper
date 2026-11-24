-- Scrollkeeper: Network/Usage.lua
-- Anonymous usage stats: which windows and buttons people use, and which
-- settings they change, so Scrollkeeper can get better where it matters.
--
-- What's counted: window opens, button uses, settings changed, slash
-- commands, and the settings that differ from the defaults. Just names
-- and numbers.
-- Never: names, realms, guilds, chat, gold, bags, where you are, or when
-- (beyond "this install has counted since ...").
--
-- Each install picks a random ID (not tied to any character) and shares its
-- counts every so often over the Scrollkeeper network, only with "Share
-- anonymous usage stats" on (asked in setup, and in /sk options > Sharing)
-- and Sharing not set to None. Only a dev copy (run from git) keeps what it
-- hears, by that random ID; the sender's name is never saved.
--
-- Network:  UZ|<install id>#<part>|key:count,key:count,set.key=value,...
-- Dev command: /sk usage  (yours, and everyone's added up)

local _, SK = ...
local Net = SK.Net

local SEND_EVERY = 30 * 60      -- seconds between shares
local MAX_COUNT = 100000        -- ignore anything bigger (broken or fake)

local function Store()
    if not SK.db then return nil end
    local usage = SK.db.usage
    if type(usage) ~= "table" then
        usage = { counts = {}, since = time() }
        SK.db.usage = usage
    end
    usage.counts = usage.counts or {}
    return usage
end

-- A random ID for this install (account), not tied to any character.
local function InstallID()
    if not SK.db.usageID then
        local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        local id = {}
        for i = 1, 10 do
            local n = math.random(1, #chars)
            id[i] = chars:sub(n, n)
        end
        SK.db.usageID = table.concat(id)
    end
    return SK.db.usageID
end

-- Count one thing: "open.bag", "bag.sell", "set.theme", "cmd.log"...
-- Names only use letters, digits, dots and dashes.
function SK.Track(name)
    local usage = Store()
    if not usage or type(name) ~= "string" then return end
    name = name:gsub("[^%w%.%-]", "")
    if name == "" then return end
    usage.counts[name] = (usage.counts[name] or 0) + 1
end

------------------------------------------------------------------------
-- Counting: wrap the functions that open windows and do things
------------------------------------------------------------------------

local function Wrap(fnName, event)
    local original = SK[fnName]
    if type(original) ~= "function" then return end
    SK[fnName] = function(...)
        SK.Track(event)
        return original(...)
    end
end

local wrapped = false
SK.Listen("READY", function()
    if wrapped then return end
    wrapped = true
    local wraps = {
        TogglePanel = "open.panel", ToggleScrollBag = "open.bag", ToggleGuide = "open.codex",
        TogglePlan = "open.plan", ToggleLog = "open.log", ToggleSwap = "open.swap",
        ToggleDoors = "open.doors", ToggleNetwork = "open.fellowmages", OpenOptions = "open.options",
        ToggleAltPanel = "open.alts", ShowPicks = "picks.open", TogglePin = "pin",
        UseBagPreset = "preset.use", SaveBagPreset = "preset.save", SetKeepAmount = "bag.keep",
        ScanAuctionScrolls = "ah.scan", ShowBackup = "backup", ShowSetup = "setup",
    }
    for fnName, event in pairs(wraps) do Wrap(fnName, event) end
    for action, run in pairs(SK.ScrollBagActions or {}) do
        SK.ScrollBagActions[action] = function(...)
            SK.Track("bag." .. action)
            return run(...)
        end
    end
    -- Slash commands: which ones people type.
    local slash = SlashCmdList and SlashCmdList.SCROLLKEEPER
    if slash then
        SlashCmdList.SCROLLKEEPER = function(input)
            local word = (input or ""):lower():match("^%s*(%S*)")
            SK.Track("cmd." .. (word ~= "" and word or "panel"))
            return slash(input)
        end
    end
end)

SK.Listen("DECIPHERED", function() SK.Track("decipher") end)
SK.Listen("THEME_CHANGED", function() SK.Track("theme." .. (SK.UI.ThemeName and SK.UI.ThemeName() or "?")) end)
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit == "player" and spellID == SK.SPELL_STUDY then SK.Track("study") end
end)

------------------------------------------------------------------------
-- Sharing (only with the setting on, and Sharing not None)
------------------------------------------------------------------------

-- Settings that differ from the defaults, as "set.key=value" (simple
-- values only: on/off, numbers, short words).
local function ChangedSettings()
    local list = {}
    for key, default in pairs(SK.DEFAULTS or {}) do
        local value = SK.db[key]
        local kind = type(value)
        if value ~= default and (kind == "boolean" or kind == "number" or (kind == "string" and value:match("^[%w%-]+$") and #value <= 12)) then
            list[#list + 1] = "set." .. key .. "=" .. tostring(value)
        end
    end
    table.sort(list)
    return list
end

function SK.UsageWanted()
    return SK.db and SK.db.shareUsage ~= false and SK.db.share and SK.db.sharing ~= "none"
end

local lastSent = 0
local function SendUsage(force)
    if not (Net and Net.SendList and SK.UsageWanted()) then return end
    if not force and time() - lastSent < SEND_EVERY then return end
    lastSent = time()
    local usage = Store()
    local items = {}
    local keys = {}
    for key in pairs(usage.counts) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do items[#items + 1] = key .. ":" .. usage.counts[key] end
    for _, setting in ipairs(ChangedSettings()) do items[#items + 1] = setting end
    items[#items + 1] = "class." .. (SK.isMage and "mage" or "other") .. ":1"
    items[#items + 1] = "version." .. tostring(SK.version):gsub("[^%w%.%-]", "") .. ":1"
    if #items > 0 then Net.SendList("UZ", InstallID(), items) end
end
SK.SendUsage = SendUsage

SK.Listen("NET_READY", function()
    C_Timer.After(90, function() SK.Safely("usage", SendUsage, true) end)
    if C_Timer.NewTicker then C_Timer.NewTicker(SEND_EVERY, function() SK.Safely("usage", SendUsage) end) end
end)

-- Only dev copies keep what they hear, by the random ID (never the sender).
if Net and Net.Handle then
    Net.Handle("UZ", function(_, f)
        if not (SK.devCopy and SK.db) then return end
        local id = (f[1] or ""):match("^([%w]+)#%d+$")
        if not id or #id > 16 then return end
        SK.db.usageHeard = SK.db.usageHeard or {}
        local entry = SK.db.usageHeard[id] or { counts = {}, settings = {} }
        entry.at = time()
        for item in (f[2] or ""):gmatch("[^,]+") do
            local key, count = item:match("^([%w%.%-]+):(%d+)$")
            if key then
                count = tonumber(count)
                if count and count <= MAX_COUNT then entry.counts[key] = count end
            else
                local setting, value = item:match("^set%.([%w]+)=([%w%.%-]+)$")
                if setting then entry.settings[setting] = value end
            end
        end
        SK.db.usageHeard[id] = entry
    end)
end

------------------------------------------------------------------------
-- The report (/sk usage, dev copies)
------------------------------------------------------------------------

function SK.UsageReport()
    local lines = {}
    local function Add(text) lines[#lines + 1] = text end
    local usage = Store() or { counts = {} }
    Add("Scrollkeeper usage " .. tostring(SK.version))
    Add("Sharing usage: " .. (SK.UsageWanted() and "on" or "off") .. ", install " .. InstallID())
    Add("")
    Add("== Everyone heard (installs that use it · total) ==")
    local totals, users, settings, installs = {}, {}, {}, 0
    local function Count(counts)
        for key, n in pairs(counts) do
            totals[key] = (totals[key] or 0) + n
            users[key] = (users[key] or 0) + 1
        end
    end
    local heard = SK.db.usageHeard or {}
    local seenMine = false
    for id, entry in pairs(heard) do
        installs = installs + 1
        if id == SK.db.usageID then seenMine = true end
        Count(entry.counts or {})
        for setting, value in pairs(entry.settings or {}) do
            local key = setting .. "=" .. value
            settings[key] = (settings[key] or 0) + 1
        end
    end
    if not seenMine then installs = installs + 1; Count(usage.counts) end
    local keys = {}
    for key in pairs(totals) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return users[a] > users[b] or (users[a] == users[b] and totals[a] > totals[b]) end)
    Add(installs .. " installs")
    for _, key in ipairs(keys) do Add(("%-28s %4d · %d"):format(key, users[key], totals[key])) end
    Add("")
    Add("== Settings changed from the defaults (installs) ==")
    local settingKeys = {}
    for key in pairs(settings) do settingKeys[#settingKeys + 1] = key end
    table.sort(settingKeys, function(a, b) return settings[a] > settings[b] end)
    for _, key in ipairs(settingKeys) do Add(("%-36s %d"):format(key, settings[key])) end
    if #settingKeys == 0 then Add("(none heard yet)") end
    Add("")
    Add("== Yours (since " .. (usage.since and date and date("%Y-%m-%d", usage.since) or "?") .. ") ==")
    local mine = {}
    for key in pairs(usage.counts) do mine[#mine + 1] = key end
    table.sort(mine, function(a, b) return usage.counts[a] > usage.counts[b] end)
    for _, key in ipairs(mine) do Add(("%-28s %d"):format(key, usage.counts[key])) end
    return table.concat(lines, "\n")
end
