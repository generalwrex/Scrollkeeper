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
    if mode == "simple" then mode = "anon" end   -- Simple is gone (1.2.2)
    if mode ~= "full" and mode ~= "anon" and mode ~= "none" then mode = "full" end
    db.sharing = mode
    db.share = mode ~= "none"
    db.shareChannel = mode == "full" or mode == "anon"
    db.anonymous = mode == "anon"
end

SK.name = ADDON_NAME
-- The packager fills in the real version from the git tag. A copy run
-- straight from the repo has no tag, so it reports the version below.
SK.version = "1.4.0"

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
    -- Running straight from the git repo (the packager never filled in the
    -- TOC version): other players aren't told about this copy's version, so
    -- a version bumped while working on it never says "update" to anyone.
    SK.devCopy = type(tagged) == "string" and tagged:find("project%-version") ~= nil
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
    if SK.Track then SK.Track("error." .. tostring(label)) end   -- which part broke (never the message)
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
    if SK.Track then SK.Track("error." .. tostring(label)) end   -- which part broke (never the message)
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

-- The game can hand addons "secret" values (in combat, instances and some
-- unit checks like UnitIsAFK) that we may not test or compare: doing so is
-- an error. SK.Known(value) gives the value, or nil when it's secret.
-- Wrap any unit check:  if SK.Known(UnitIsAFK("player")) then ...
function SK.Known(value)
    if issecretvalue and value ~= nil and issecretvalue(value) then return nil end
    return value
end

-- Features you can turn off (Options > Modules): "Bag", "Codex", "Plan",
-- "Log", "Swap", "Doors", "Network", "Board". On unless turned off.
function SK.ModuleOn(key)
    return not (key and SK.db and SK.db["module" .. key] == false)
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

-- Unit events can carry secret values (see SK.Known): handlers get nil in
-- their place, so a plain `unit ~= "player"` never errors.
local unpack = unpack or table.unpack
local function Unsecret(...)
    local count = select("#", ...)
    if count == 0 or not issecretvalue then return ... end
    local args = { ... }
    for i = 1, count do
        if args[i] ~= nil and issecretvalue(args[i]) then args[i] = nil end
    end
    return unpack(args, 1, count)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    if event:sub(1, 5) == "UNIT_" or event == "PARTY_INVITE_REQUEST" then
        for i = 1, #list do SK.Safely(event, list[i], Unsecret(...)) end
        return
    end
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

------------------------------------------------------------------------
-- This character's own layout (optional). With it on, these settings come
-- from ScrollkeeperCharDB (this character only) instead of the account:
-- swapped in at login, swapped back out at logout, so the rest of the
-- addon just uses SK.db as always.
------------------------------------------------------------------------

SK.LAYOUT_KEYS = { "showPanel", "viewMode", "scale", "panelPoint", "collapsed", "showScrollBar", "locked",
    "hideInCombat", "minimapButton", "minimapAngle", "scrollIcon", "iconPos", "toastPoint", "theme", "themeBefore", "themeHoliday" }

local accountLayout   -- the account's values while this character uses its own

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end

function SK.LoadCharacterLayout()
    ScrollkeeperCharDB = ScrollkeeperCharDB or {}
    SK.charDB = ScrollkeeperCharDB
    if not SK.charDB.own then return end
    SK.charDB.layout = SK.charDB.layout or {}
    accountLayout = {}
    for _, key in ipairs(SK.LAYOUT_KEYS) do
        accountLayout[key] = Copy(SK.db[key])
        if SK.charDB.layout[key] ~= nil then SK.db[key] = Copy(SK.charDB.layout[key]) end
    end
end

-- Logout: this character's layout goes to its own file, the account's back.
local function SaveCharacterLayout()
    if not (SK.charDB and SK.charDB.own and accountLayout) then return end
    SK.charDB.layout = {}
    for _, key in ipairs(SK.LAYOUT_KEYS) do
        SK.charDB.layout[key] = Copy(SK.db[key])
        SK.db[key] = accountLayout[key]
    end
end

-- The setting. On: starts from the layout you have now. Off: back to the
-- account's layout (fully after a /reload).
function SK.SetCharacterLayout(on)
    if not SK.charDB then return end
    if on and not SK.charDB.own then
        SK.charDB.own = true
        accountLayout = {}
        SK.charDB.layout = {}
        for _, key in ipairs(SK.LAYOUT_KEYS) do
            accountLayout[key] = Copy(SK.db[key])
            SK.charDB.layout[key] = Copy(SK.db[key])
        end
    elseif not on and SK.charDB.own then
        SK.charDB.own = false
        for _, key in ipairs(SK.LAYOUT_KEYS) do
            if accountLayout then SK.db[key] = accountLayout[key] end
        end
        accountLayout = nil
        if SK.ApplyPanelSettings then SK.ApplyPanelSettings() end
        if SK.RefreshIcon then SK.RefreshIcon() end
        if SK.RefreshMinimapButton then SK.RefreshMinimapButton() end
    end
end

local DEFAULTS = {
    showPanel = true,        -- show the panel on mages
    showTooltips = true,     -- add a line to scroll tooltips
    announce = true,         -- print what each decipher produced
    hideInCombat = true,     -- hide the panel while in combat, show it again after
    mailHelper = true,       -- at the mailbox: who could use your scrolls
    mailIncludeMine = false, -- ...also offer the scrolls you'd still level from yourself
    updateNotice = true,     -- say in chat when someone has a newer Scrollkeeper
    offlineMinutes = 5,      -- Fellow Mages: how long someone found offline stays listed
    oddsStandard = false,    -- community odds: list standard scrolls one by one (off: one merged row)
    guildBankMarks = true,   -- dots on guild bank scrolls someone levels from
    liminalDoor = false,     -- Doorways: offer to be a door while resting (UI/Doors.lua)
    doorAutoInvite = false,  -- ...and invite whoever asks, without a pop-up
    ahScanButton = true,     -- "Scan scrolls" button on the auction house
    chatHelper = true,       -- "who needs this? [scroll]" notes in chat
    scrollIcon = false,      -- small icon with the number of scrolls ready
    minimapButton = true,    -- the round button on the minimap's edge
    reminderToast = true,    -- pop-up when your imbue or familiar drops off (UI/Icon.lua)
    expiringReminder = true, -- ...and when one is about to run out
    reminderInCombat = false, -- ...also during a fight
    familiarAnywhere = false, -- familiar pop-ups outside dungeons/raids too
    imbueByUse = false,      -- imbue pick: the one you use most before your spec's
    expiringMinutes = 5,     -- ...this many minutes before
    moduleBag = true,        -- Modules: the Scroll Bag and everything it adds (marks, tooltip and chat notes)
    moduleCodex = true,      -- ...the Codex
    modulePlan = true,       -- ...the Farming Plan
    moduleLog = true,        -- ...the Luck Log
    moduleSwap = true,       -- ...the Scroll Swap board
    moduleDoors = true,      -- ...Doorways (and the Liminal Passage warning)
    moduleNetwork = true,    -- ...the Fellow Mages window
    bagCountBank = true,     -- Scroll Bag: count what's in your bank (remembered from your last visit)
    bagCountMail = true,     -- ...and in your mailbox
    bagSetAside = true,      -- ...imbues for a weapon you don't own are "set aside", not extra
    bagWeaponAlert = true,   -- ...new weapon: say which imbues for it wait in your bank or mail
    bagChatStatus = true,    -- ...the "deciphered:" chat line says keep, extra or set aside
    bagTooltip = true,       -- ...a keep/extra line on deciphered scroll tooltips
    bagConfirm = true,       -- ...ask before selling extras
    bagAutoSyncBank = false, -- ...Sync bank extras on its own when the bank opens (also a check on the Scroll Bag)
    bagAutoSyncMail = false, -- ...Sync mail extras on its own once the mail comes in
    bagHideErrors = true,    -- ...hide the game's red "Couldn't split those items" while Scrollkeeper moves scrolls
    bagAllowDelete = false,  -- ...show the Delete extras button
    bagMarks = true,         -- ...colored corner marks on scrolls in your bags (and bag addons)
    bagJunk = false,         -- ...extras count as junk in bag addons with a junk list
    bagMailTo = "",          -- ...who Mail extras fills in when the To box is empty
    liminalLow = 2,          -- warn when you carry this many Scroll of Liminal Passage or fewer (0 = off)
    liminalLowChat = true,   -- ...also say it in chat when it drops that low
    language = "auto",       -- "auto" (the game's language) or enUS, deDE, esES, frFR
    showScrollBar = true,    -- show your usable scrolls as buttons in the panel
    share = true,            -- talk to other Scrollkeeper users in your guild and group
    shareChannel = true,     -- also use the public Scrollkeeper channel
    anonymous = false,       -- share without showing your name in other players' lists
    helpButtons = true,      -- the red "?" on every window (UI/Help.lua)
    shareUsage = false,      -- opt in: share anonymous usage counts (which windows and buttons get used) (Network/Usage.lua)
    mapPins = true,          -- show libraries and scroll drop spots on the world map
    mapPinScale = 1,         -- size of the scroll and book spots on the map
    locked = false,          -- stop the panel from being dragged
    viewMode = nil,          -- "full" (Advanced), "compact" (Simple) or "mini" (title only)
    scale = 1,               -- panel size
    boardOn = true,          -- the Fellow Mages board (Network/Board.lua, /sk board)
    boardNotify = true,      -- ...say once a session when there are new posts
    boardRulesets = "all",   -- ...General posts and notices: "all" rulesets or "mine"
    themeHoliday = false,
    themesShared = true,     -- holiday themes from the network (Network/Themes.lua)    -- wear the holiday theme on its own during holidays (UI/Theme.lua)
    theme = "classic",       -- how the windows look: "classic", "dark" or "dusk" (Darker classic) (UI/Theme.lua)
    panelPoint = nil,        -- saved panel position
    mages = {},              -- your mages across the account (Modules/Alts.lua), incl. Study timers
    results = {},            -- luck log: results[tier][scroll name] = count
    deciphered = 0,          -- total scrolls deciphered
    errors = {},
}

SK.DEFAULTS = DEFAULTS

SK.On("ADDON_LOADED", function(loaded)
    if loaded ~= ADDON_NAME then return end
    ScrollkeeperDB = ScrollkeeperDB or {}
    for key, value in pairs(DEFAULTS) do
        if ScrollkeeperDB[key] == nil then
            ScrollkeeperDB[key] = type(value) == "table" and {} or value
        end
    end
    SK.db = ScrollkeeperDB
    SK.LoadCharacterLayout()
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
        elseif ScrollkeeperDB.shareChannel == false then ScrollkeeperDB.sharing = "anon"
        else ScrollkeeperDB.sharing = "full" end
    end
    -- 1.2.2: Simple (guild and friends only) is gone; it became Anonymous.
    if ScrollkeeperDB.sharing == "simple" then ScrollkeeperDB.sharing = "anon" end
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

SK.On("PLAYER_LOGOUT", function() SaveCharacterLayout() end)
