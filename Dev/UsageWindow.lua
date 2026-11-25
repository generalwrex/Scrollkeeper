-- Scrollkeeper: Dev/UsageWindow.lua  (dev copies only, never packaged)
-- /sk usage: the usage stats, as a window.
--
--   Everyone / Yours   everything heard over the network, or just this install
--   tiles              installs, logins, errors, whether this install shares
--   Windows            how many installs open each window, how often, how long
--   Most used          buttons, actions and commands, by how many installs use them
--   Settings           what people change from the defaults
--   Who's playing      class, faction, language, skill, mages, view, addons
--   Errors             which parts of Scrollkeeper broke (never the message)
-- Copy as text: the old text report, to paste somewhere.

local _, SK = ...

local WIDTH = 470
local BAR_WIDTH = WIDTH - 40
local window, content, mode = nil, nil, "everyone"

local GREEN = { 0.25, 0.75, 0.4 }
local BLUE = { 0.3, 0.55, 1 }
local GOLD = { 0.85, 0.65, 0.2 }
local RED = { 0.85, 0.25, 0.25 }
local GRAY = { 0.5, 0.5, 0.55 }

-- Friendly names for the windows and the kinds of things counted.
local WINDOWS = {
    { "panel", "Panel" }, { "bag", "Scroll Bag" }, { "codex", "Codex" }, { "plan", "Farming Plan" },
    { "log", "Luck Log" }, { "swap", "Scroll Swap" }, { "doors", "Doorways" }, { "fellowmages", "Fellow Mages" },
    { "options", "Settings" }, { "alts", "Alts" }, { "mailhelper", "Mailbox helper" }, { "setup", "Setup" },
}
local PREFIXES = {
    { "panel.", "Panel: " }, { "bag.", "Scroll Bag: " }, { "doors.", "Doorways: " }, { "plan.", "Farming Plan: " },
    { "codex.", "Codex: " }, { "log.", "Luck Log: " }, { "fellowmages.", "Fellow Mages: " }, { "swap.", "Swap: " },
    { "mail.", "Mailbox: " }, { "cmd.", "/sk " }, { "toast.", "Pop-up: " }, { "key.", "Key: " },
    { "options.section.", "Settings page: " }, { "minimap.", "Minimap: " }, { "preset.", "Preset: " },
    { "picks.", "Picks: " }, { "tooltip.", "Tooltip: " }, { "theme.", "Theme: " }, { "set.", "Changed: " },
}
local INFO_GROUPS = {
    { "class", "Class" }, { "faction", "Faction" }, { "locale", "Game language" }, { "skill", "Comprehension" },
    { "mages", "Mages on the account" }, { "view", "Panel view" }, { "addon", "Other addons" }, { "version", "Version" },
}

local function Pretty(key)
    for _, p in ipairs(PREFIXES) do
        if key:sub(1, #p[1]) == p[1] then return p[2] .. key:sub(#p[1] + 1):gsub("%.", " ") end
    end
    return key
end

local function Minutes(seconds)
    if seconds < 60 then return ("%ds"):format(seconds) end
    if seconds < 3600 then return ("%dm"):format(math.floor(seconds / 60 + 0.5)) end
    return ("%.1fh"):format(seconds / 3600)
end

local function Sorted(list, value)
    table.sort(list, function(a, b)
        local va, vb = value(a), value(b)
        if va ~= vb then return va > vb end
        return a < b
    end)
    return list
end

------------------------------------------------------------------------
-- Building blocks, reused each time the window is filled
------------------------------------------------------------------------

local pools = { bars = {}, headers = {}, notes = {}, tiles = {} }
local used = { bars = 0, headers = 0, notes = 0, tiles = 0 }
local y = 0

local function Reset()
    for kind, list in pairs(pools) do
        for _, item in ipairs(list) do item:Hide() end
        used[kind] = 0
    end
    y = 0
end

local function Header(text)
    used.headers = used.headers + 1
    local header = pools.headers[used.headers]
    if not header then
        header = SK.UI.CreateHeader(content, text, BAR_WIDTH + 10)
        pools.headers[used.headers] = header
    end
    header.Title:SetText(text)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", 0, -y - 6)
    header:Show()
    y = y + 34
end

local function Note(text, color)
    used.notes = used.notes + 1
    local note = pools.notes[used.notes]
    if not note then
        note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        note:SetJustifyH("LEFT")
        note:SetWidth(BAR_WIDTH)
        pools.notes[used.notes] = note
    end
    note:SetText(text)
    note:SetTextColor(color and color[1] or 0.7, color and color[2] or 0.7, color and color[3] or 0.7)
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", 6, -y)
    note:Show()
    y = y + (note:GetStringHeight() or 12) + 6
end

-- One bar: a label on the left, numbers on the right, filled value/max.
local function Bar(label, right, value, max, color, tip)
    used.bars = used.bars + 1
    local bar = pools.bars[used.bars]
    if not bar then
        bar = SK.UI.CreateBar(content, BAR_WIDTH, 16)
        bar:EnableMouse(true)
        bar:SetScript("OnEnter", function(self)
            if not self.tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.tipTitle or "", 1, 0.82, 0)
            GameTooltip:AddLine(self.tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pools.bars[used.bars] = bar
    end
    bar:SetProgress(value, max)
    bar:SetBarColor(color or BLUE)
    bar:SetLabel(label, right)
    bar.tip, bar.tipTitle = tip, label
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", 6, -y)
    bar:Show()
    y = y + 20
end

-- A tile: a big number and a small label under it.
local function Tiles(list)
    local width = (BAR_WIDTH - (#list - 1) * 8) / #list
    for i, item in ipairs(list) do
        used.tiles = used.tiles + 1
        local tile = pools.tiles[used.tiles]
        if not tile then
            tile = CreateFrame("Frame", nil, content, "BackdropTemplate")
            tile:SetHeight(52)
            if tile.SetBackdrop then
                tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            end
            tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            tile.value:SetPoint("TOP", 0, -8)
            tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            tile.label:SetPoint("BOTTOM", 0, 8)
            pools.tiles[used.tiles] = tile
        end
        tile:SetWidth(width)
        if tile.SetBackdropColor then
            tile:SetBackdropColor(1, 1, 1, 0.04)
            tile:SetBackdropBorderColor(1, 1, 1, 0.12)
        end
        local color = item[3] or { 1, 1, 1 }
        tile.value:SetText(item[1])
        tile.value:SetTextColor(color[1], color[2], color[3])
        tile.label:SetText(item[2])
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", 6 + (i - 1) * (width + 8), -y)
        tile:Show()
    end
    y = y + 60
end

------------------------------------------------------------------------
-- Filling it
------------------------------------------------------------------------

local function Fill()
    Reset()
    local mine = mode == "mine"
    local data = SK.UsageData(mine)
    local installs = math.max(1, data.installs)
    local totals, users = data.totals, data.users
    local function Users(key) return users[key] or 0 end
    local function Total(key) return totals[key] or 0 end
    -- "Yours": bars against your own biggest count; "Everyone": against installs.
    local function Scale(keys)
        local max = 0
        for _, key in ipairs(keys) do max = math.max(max, mine and Total(key) or Users(key)) end
        return math.max(1, max)
    end

    local errors, logins = 0, Total("session")
    for key, n in pairs(totals) do if key:match("^error%.") then errors = errors + n end end
    Tiles({
        { mine and "1" or tostring(data.installs), mine and "this install" or "installs heard", BLUE },
        { tostring(logins), "logins", GREEN },
        { tostring(errors), "errors", errors > 0 and RED or GREEN },
        { SK.UsageWanted() and "On" or "Off", "you share", SK.UsageWanted() and GREEN or GRAY },
    })
    if not mine and data.installs <= 1 then
        Note("Nobody else heard yet. Other installs share every 30 minutes, if they picked Yes in setup.")
    end

    -- Windows: who opens them, how often, how long they stay open.
    Header("Windows")
    local windowKeys = {}
    for _, w in ipairs(WINDOWS) do windowKeys[#windowKeys + 1] = "open." .. w[1] end
    Sorted(windowKeys, function(key) return mine and Total(key) or Users(key) * 100000 + Total(key) end)
    local names = {}
    for _, w in ipairs(WINDOWS) do names["open." .. w[1]] = w end
    local shown = 0
    local max = Scale(windowKeys)
    for _, key in ipairs(windowKeys) do
        local w = names[key]
        local opens, secs = Total(key), Total("secs." .. w[1])
        if opens > 0 or secs > 0 then
            shown = shown + 1
            local per = Users(key) > 0 and secs / Users(key) or secs
            local right = mine and ("%d opens · %s open"):format(opens, Minutes(secs))
                or ("%d of %d · %d opens · %s each"):format(Users(key), installs, opens, Minutes(per))
            Bar(w[2], right, mine and opens or Users(key), mine and max or installs, BLUE,
                ("Opened %d times. Open for %s in all."):format(opens, Minutes(secs)))
        end
    end
    if shown == 0 then Note("No windows opened yet.") end

    -- Most used: buttons, actions and commands.
    Header("Most used")
    local actions = {}
    for key in pairs(totals) do
        if not (key:match("^open%.") or key:match("^secs%.") or key:match("^info%.") or key:match("^error%.")
            or key:match("^set%.") or key == "session") then
            actions[#actions + 1] = key
        end
    end
    Sorted(actions, function(key) return mine and Total(key) or Users(key) * 100000 + Total(key) end)
    max = Scale(actions)
    for i = 1, math.min(#actions, 30) do
        local key = actions[i]
        local right = mine and tostring(Total(key)) or ("%d of %d · %d"):format(Users(key), installs, Total(key))
        Bar(Pretty(key), right, mine and Total(key) or Users(key), mine and max or installs, GREEN, key)
    end
    if #actions == 0 then Note("Nothing clicked yet.") end
    if #actions > 30 then Note(("+ %d more (Copy as text has them all)"):format(#actions - 30)) end

    -- Settings: changed from the defaults, and clicked in the settings window.
    Header("Settings people change")
    local settingKeys = {}
    for key in pairs(data.settings) do settingKeys[#settingKeys + 1] = key end
    Sorted(settingKeys, function(key) return data.settings[key] end)
    for i = 1, math.min(#settingKeys, 20) do
        local key = settingKeys[i]
        local name, value = key:match("^(.-)=(.*)$")
        Bar((name or key) .. " |cff999999= " .. (value or "") .. "|r",
            mine and "" or ("%d of %d"):format(data.settings[key], installs),
            data.settings[key], installs, GOLD, "Different from the default on " .. data.settings[key] .. " install(s).")
    end
    if #settingKeys == 0 then Note("Everyone's on the defaults so far.") end

    -- Who's playing (everyone only: yours is just you).
    if not mine then
        Header("Who's playing")
        local any = false
        for _, group in ipairs(INFO_GROUPS) do
            local prefix = "info." .. group[1] .. "."
            local values = {}
            for key in pairs(users) do
                if key:sub(1, #prefix) == prefix then values[#values + 1] = key end
            end
            if #values > 0 then
                any = true
                Note(group[2], { 1, 0.82, 0 })
                Sorted(values, function(key) return Users(key) end)
                for _, key in ipairs(values) do
                    Bar(key:sub(#prefix + 1):gsub("%-", "."), ("%d of %d"):format(Users(key), installs), Users(key), installs, BLUE)
                end
            end
        end
        if not any then Note("Nothing heard yet.") end
    end

    -- Errors: which parts broke.
    Header("Errors")
    local errorKeys = {}
    for key in pairs(totals) do if key:match("^error%.") then errorKeys[#errorKeys + 1] = key end end
    Sorted(errorKeys, function(key) return Total(key) end)
    max = Scale(errorKeys)
    for _, key in ipairs(errorKeys) do
        Bar(key:sub(7), mine and tostring(Total(key)) or ("%d of %d · %d"):format(Users(key), installs, Total(key)),
            mine and Total(key) or Users(key), mine and max or installs, RED, "Where it broke. /sk errors has the messages (yours only).")
    end
    if #errorKeys == 0 then Note("None. Nice.", GREEN) end

    content:SetHeight(y + 10)
    window.since:SetText(data.since and date and ("counting since " .. date("%b %d", data.since)) or "")
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperUsageFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperUsageFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH + 30, 600)
    window:SetPoint("CENTER")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetTitle("Scrollkeeper: Usage stats")
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Note_05") end
    tinsert(UISpecialFrames, "ScrollkeeperUsageFrame")

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)

    -- Everyone / Yours
    local function ModeButton(key, text, x)
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetSize(90, 22)
        button:SetPoint("TOPLEFT", x, -32)
        button:SetText(text)
        button:SetScript("OnClick", function() mode = key; window:Refresh() end)
        return button
    end
    window.everyone = ModeButton("everyone", "Everyone", 70)
    window.mine = ModeButton("mine", "Yours", 164)
    window.since = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.since:SetPoint("LEFT", window.mine, "RIGHT", 10, 0)

    local copy = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    copy:SetSize(100, 22)
    copy:SetPoint("BOTTOMRIGHT", -12, 10)
    copy:SetText("Copy as text")
    copy:SetScript("OnClick", function() SK.ShowTextBox("Usage stats", SK.UsageReport()) end)
    local share = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    share:SetSize(100, 22)
    share:SetPoint("RIGHT", copy, "LEFT", -6, 0)
    share:SetText("Share now")
    share:SetScript("OnClick", function()
        if SK.SendUsage then SK.SendUsage(true) end
        SK.Print(SK.UsageWanted() and "usage shared." or "you're not sharing usage (Options > Sharing).")
    end)

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -62)
    scroll:SetPoint("BOTTOMRIGHT", -32, 40)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH, 10)
    scroll:SetScrollChild(content)

    function window:Refresh()
        self.everyone:SetEnabled(mode ~= "everyone")
        self.mine:SetEnabled(mode ~= "mine")
        SK.Quietly("usage window", Fill)
    end
    window:SetScript("OnShow", function(self) self:Refresh() end)
    window:Hide()
end

function SK.ToggleUsageWindow()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

SK.commands.usage = function(arg)
    if arg == "text" then SK.ShowTextBox("Usage stats", SK.UsageReport()) return end
    SK.ToggleUsageWindow()
end
