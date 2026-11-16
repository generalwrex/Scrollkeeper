-- Scrollkeeper: Core/Init.lua
-- Sets up the shared table every file uses (called `SK`), the saved settings,
-- a small event system, and safe-call helpers.

local ADDON_NAME, SK = ...

SK.name = ADDON_NAME
-- The packager fills in the real version from the git tag. A copy run
-- straight from the repo has no tag, so it reports the version below.
SK.version = "0.5.0"
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
    hideInCombat = false,    -- hide the panel while in combat, show it again after
    showScrollBar = true,    -- show your usable scrolls as buttons in the panel
    share = true,            -- talk to other Scrollkeeper users in your guild and group
    shareChannel = false,    -- also use the public Scrollkeeper channel (experimental)
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

    -- Errors from an older version are no longer useful.
    if ScrollkeeperDB.version ~= SK.version then
        ScrollkeeperDB.errors = {}
        ScrollkeeperDB.version = SK.version
    end

    local _, class = UnitClass("player")
    SK.isMage = (class == "MAGE")
    SK.Send("READY")
end)
