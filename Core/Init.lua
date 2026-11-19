-- Scrollkeeper: Core/Init.lua
-- Sets up the shared table every file uses (called `SK`), the saved settings,
-- a small event system, and safe-call helpers.

local ADDON_NAME, SK = ...

-- How much to share, as one choice:
--   full    everyone, with your name
--   anon    everyone, but your name isn't shown in other players' lists
--   simple  only your guild, group and friends
--   none    the network is off
-- It sets the older share / shareChannel / anonymous settings the rest of
-- the addon reads.
function SK.SetSharing(mode)
    local db = SK.db or ScrollkeeperDB
    if not db then return end
    if mode ~= "full" and mode ~= "anon" and mode ~= "simple" and mode ~= "none" then mode = "full" end
    db.sharing = mode
    db.share = mode ~= "none"
    db.shareChannel = mode == "full" or mode == "anon"
    db.anonymous = mode == "anon"
end

SK.name = ADDON_NAME
-- The packager fills in the real version from the git tag. A copy run
-- straight from the repo has no tag, so it reports the version below.
SK.version = "1.1.5"

-- Translations (see Core/Locale.lua and the Locales folder). Set up here,
-- in the first file, so every other file can use SK.L right away: any text
-- without a translation is simply shown in English.
SK.L = SK.L or setmetatable({}, {
    __index = function(_, key) return key end,
    __newindex = function(table, key, value)
        if value ~= nil and value ~= "" then rawset(table, key, value) end
    end,
})
SK.locale = SK.locale or (GetLocale and GetLocale()) or "enUS"
do
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local tagged = getMetadata and getMetadata(ADDON_NAME, "Version")
    if tagged and tagged:match("^v?%d") then SK.version = tagged:gsub("^v", "") end
end

------------------------------------------------------------------------
-- Chat output
------------------------------------------------------------------------

function SK.Print(message)
    print("|cff69ccf0Scrollkeeper:|r " .. tostring(message))
end

------------------------------------------------------------------------
-- Safe calls
-- The Forever client is new, so any game function might be missing or
-- might refuse to answer in combat. These helpers never throw.
------------------------------------------------------------------------

-- Call a game function that may not exist. Returns nil on any failure.
function SK.Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g end
    return nil
end

-- Run one of our own functions. If it breaks, remember the error (so it
-- can be read from the saved file) and tell the player once.
local shownErrors = {}
-- Like SK.Safely, but only records the error (for /sk bug), with nothing
-- in chat. For things that should never bother the player, like map pins.
function SK.Quietly(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return true end
    if ScrollkeeperDB then
        ScrollkeeperDB.errors = ScrollkeeperDB.errors or {}
        local list = ScrollkeeperDB.errors
        list[#list + 1] = { at = time(), where = label, error = tostring(err) }
        while #list > 30 do table.remove(list, 1) end
    end
    return false
end

function SK.Safely(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return true end
    err = tostring(err)
    if ScrollkeeperDB then
        ScrollkeeperDB.errors = ScrollkeeperDB.errors or {}
        local list = ScrollkeeperDB.errors
        list[#list + 1] = { at = time(), where = label, error = err }
        while #list > 30 do table.remove(list, 1) end
    end
    if not shownErrors[err] then
        shownErrors[err] = true
        SK.Print("|cffff5555error in " .. label .. ":|r " .. err)
    end
    return false
end

function SK.InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

------------------------------------------------------------------------
-- Events
-- Usage:  SK.On("BAG_UPDATE_DELAYED", function(...) ... end)
------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

function SK.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        SK.Safely(event, list[i], ...)
    end
end)

------------------------------------------------------------------------
-- Internal messages between our own files
-- Usage:  SK.Listen("BAGS_CHANGED", fn)   SK.Send("BAGS_CHANGED")
------------------------------------------------------------------------

local listeners = {}

function SK.Listen(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function SK.Send(message, ...)
    local list = listeners[message]
    if not list then return end
    for i = 1, #list do
        SK.Safely(message, list[i], ...)
    end
end

------------------------------------------------------------------------
-- Saved settings
------------------------------------------------------------------------

local DEFAULTS = {
    showPanel = true,        -- show the panel on mages
    showTooltips = true,     -- add a line to scroll tooltips
    announce = true,         -- print what each decipher produced
    hideInCombat = true,     -- hide the panel while in combat, show it again after
    mailHelper = true,       -- at the mailbox: who could use your scrolls
    mailIncludeMine = false, -- ...also offer the scrolls you'd still level from yourself
    oddsStandard = false,    -- community odds: list standard scrolls one by one (off: one merged row)    guildBankMarks = true,   -- dots on guild bank scrolls someone levels from
    ahScanButton = true,     -- "Scan scrolls" button on the auction house
    chatHelper = true,       -- "who needs this? [scroll]" notes in chat
    scrollIcon = false,      -- small icon with the number of scrolls ready
    minimapButton = true,    -- the round button on the minimap's edge
    reminderToast = true,    -- pop-up when your imbue or familiar drops off (UI/Toast.lua)
    language = "auto",       -- "auto" (the game's language) or enUS, deDE, esES, frFR
    showScrollBar = true,    -- show your usable scrolls as buttons in the panel
    share = true,            -- talk to other Scrollkeeper users in your guild and group
    shareChannel = true,     -- also use the public Scrollkeeper channel
    anonymous = false,       -- share without showing your name in other players' lists
    mapPins = true,          -- show libraries and scroll drop spots on the world map
    locked = false,          -- stop the panel from being dragged
    viewMode = nil,          -- "full" (Advanced), "compact" (Simple) or "mini" (title only)
    scale = 1,               -- panel size
    panelPoint = nil,        -- saved panel position
    mages = {},              -- your mages across the account (Modules/Alts.lua), incl. Study timers
    results = {},            -- luck log: results[tier][scroll name] = count
    deciphered = 0,          -- total scrolls deciphered
    errors = {},
}

SK.On("ADDON_LOADED", function(loaded)
    if loaded ~= ADDON_NAME then return end
    ScrollkeeperDB = ScrollkeeperDB or {}
    for key, value in pairs(DEFAULTS) do
        if ScrollkeeperDB[key] == nil then
            ScrollkeeperDB[key] = type(value) == "table" and {} or value
        end
    end
    SK.db = ScrollkeeperDB
    if SK.ApplyLanguage then SK.ApplyLanguage() end

    -- Hide in combat became the default in 1.0.0; switch it on once for
    -- everyone (after that, your own choice in the settings sticks).
    if not ScrollkeeperDB.hideInCombatDefaulted then
        ScrollkeeperDB.hideInCombat = true
        ScrollkeeperDB.hideInCombatDefaulted = true
    end

    -- The public channel became the default in 1.1.0; switch it on once.
    if not ScrollkeeperDB.shareChannelDefaulted then
        ScrollkeeperDB.shareChannel = true
        ScrollkeeperDB.shareChannelDefaulted = true
    end

    -- 1.1.4: sharing is one choice now (full, anon, simple or none).
    if ScrollkeeperDB.sharing == nil then
        if ScrollkeeperDB.share == false then ScrollkeeperDB.sharing = "none"
        elseif ScrollkeeperDB.shareChannel == false then ScrollkeeperDB.sharing = "simple"
        else ScrollkeeperDB.sharing = "full" end
    end
    SK.SetSharing(ScrollkeeperDB.sharing)

    -- Early 1.1.0 test builds saved ordinary scroll prices too; start clean.
    -- 1.1.4 test builds counted bid-only auctions and got counts/averages
    -- wrong; start clean again. The old auto-scan setting is gone too.
    if (ScrollkeeperDB.ahPricesCleaned or 0) < 3 then
        ScrollkeeperDB.ahPrices = nil
        ScrollkeeperDB.ahLastScan = nil
        ScrollkeeperDB.ahAutoScan = nil
        ScrollkeeperDB.ahPricesCleaned = 3
    end

    -- Errors from an older version are no longer useful.
    if ScrollkeeperDB.version ~= SK.version then
        ScrollkeeperDB.errors = {}
        ScrollkeeperDB.version = SK.version
    end

    local _, class = UnitClass("player")
    SK.isMage = (class == "MAGE")
    SK.Send("READY")
end)
