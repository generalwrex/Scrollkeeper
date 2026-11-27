-- Scrollkeeper by generalwrex. Created 2026-11-18.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: UI/Backup.lua
-- A full backup of everything Scrollkeeper saved (settings, luck log,
-- drops, books, alts, prices, what you heard from others), as one piece
-- of text you can keep somewhere safe, and put back if WTF gets wiped.
--
--   /sk backup    shows the backup text to copy
--   /sk restore   paste a backup, it asks first, then replaces your data and reloads
--
-- The text is read back with our own little reader, never run as code,
-- so pasting something odd can't do anything. When the game has its
-- compression functions (C_EncodingUtil) the text is compressed too.

local _, SK = ...
local L = SK.L

local PLAIN = "SKBACKUP1:"        -- then the data as plain text
local PACKED = "SKBACKUP1Z:"      -- then compressed + base64
local SKIP = { errors = true, lastExport = true, lastExportTitle = true, lastExportAt = true }

------------------------------------------------------------------------
-- Writing and reading the data
--   s<length>:<text>   n<number>;   t   f   { key value key value ... }
------------------------------------------------------------------------

local function Write(value, out)
    local kind = type(value)
    if kind == "string" then
        out[#out + 1] = "s" .. #value .. ":" .. value
    elseif kind == "number" then
        out[#out + 1] = "n" .. string.format("%.17g", value) .. ";"
    elseif kind == "boolean" then
        out[#out + 1] = value and "t" or "f"
    elseif kind == "table" then
        out[#out + 1] = "{"
        for key, inner in pairs(value) do
            local keyKind = type(key)
            if (keyKind == "string" or keyKind == "number") and type(inner) ~= "function" and type(inner) ~= "userdata" then
                Write(key, out)
                Write(inner, out)
            end
        end
        out[#out + 1] = "}"
    else
        out[#out + 1] = "f"   -- anything else can't be saved anyway
    end
end

-- Returns the value and the position after it, or nil on bad text.
local function Read(text, pos, depth)
    if depth > 40 then return nil end
    local tag = text:sub(pos, pos)
    if tag == "s" then
        local length, after = text:match("^(%d+):()", pos + 1)
        if not length then return nil end
        length = tonumber(length)
        if after + length - 1 > #text then return nil end
        return text:sub(after, after + length - 1), after + length
    elseif tag == "n" then
        local number, after = text:match("^([^;]+);()", pos + 1)
        number = tonumber(number)
        if not number then return nil end
        return number, after
    elseif tag == "t" then
        return true, pos + 1
    elseif tag == "f" then
        return false, pos + 1
    elseif tag == "{" then
        local result = {}
        pos = pos + 1
        while text:sub(pos, pos) ~= "}" do
            if pos > #text then return nil end
            local key, value
            key, pos = Read(text, pos, depth + 1)
            if key == nil then return nil end
            value, pos = Read(text, pos, depth + 1)
            if value == nil then return nil end
            result[key] = value
        end
        return result, pos + 1
    end
    return nil
end

local function Encoding()
    local util = C_EncodingUtil
    if util and util.CompressString and util.DecompressString and util.EncodeBase64 and util.DecodeBase64 then
        return util
    end
end

-- The backup text for your current data.
function SK.BackupText()
    local data = {}
    for key, value in pairs(ScrollkeeperDB or {}) do
        if not SKIP[key] then data[key] = value end
    end
    data.backupOf = { version = SK.version, at = time() }
    local out = {}
    Write(data, out)
    local plain = table.concat(out)
    local util = Encoding()
    if util then
        local ok, packed = pcall(function() return util.EncodeBase64(util.CompressString(plain)) end)
        if ok and type(packed) == "string" and packed ~= "" then return PACKED .. packed end
    end
    return PLAIN .. plain
end

-- A backup text back into a table, or nil and why not.
function SK.ReadBackup(text)
    if type(text) ~= "string" then return nil, L["That isn't a Scrollkeeper backup."] end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    local body
    if text:sub(1, #PACKED) == PACKED then
        local util = Encoding()
        if not util then return nil, L["This backup is compressed, and your game can't unpack it."] end
        local ok, plain = pcall(function() return util.DecompressString(util.DecodeBase64((text:sub(#PACKED + 1):gsub("%s", "")))) end)
        if not ok or type(plain) ~= "string" then return nil, L["That backup is damaged (part of it may be missing)."] end
        body = plain
    elseif text:sub(1, #PLAIN) == PLAIN then
        body = text:sub(#PLAIN + 1)
    else
        return nil, L["That isn't a Scrollkeeper backup."]
    end
    local data, after = Read(body, 1, 0)
    if type(data) ~= "table" or after ~= #body + 1 or type(data.backupOf) ~= "table" then
        return nil, L["That backup is damaged (part of it may be missing)."]
    end
    return data
end

------------------------------------------------------------------------
-- The windows
------------------------------------------------------------------------

local window

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperBackupFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperBackupFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(460, 380)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Scroll_03") end
    tinsert(UISpecialFrames, "ScrollkeeperBackupFrame")   -- Escape closes it

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)
    SK.UI.AddHelp(window, "backup")

    window.hint = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.hint:SetPoint("TOPLEFT", 62, -32)
    window.hint:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    window.hint:SetJustifyH("CENTER")

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -64)
    scroll:SetPoint("BOTTOMRIGHT", -36, 44)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontSmall")
    box:SetWidth(400)
    box:SetMaxLetters(0)
    box:SetScript("OnEscapePressed", function() window:Hide() end)
    -- Backup mode: typing would only change the copy, so put the real text back.
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput and window.mode == "backup" and window.text then
            self:SetText(window.text)
            self:HighlightText()
        end
    end)
    scroll:SetScrollChild(box)
    window.box = box

    window.note = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.note:SetPoint("BOTTOMLEFT", 18, 18)
    window.note:SetPoint("RIGHT", window, "RIGHT", -120, 0)
    window.note:SetJustifyH("LEFT")

    local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    button:SetSize(96, 22)
    button:SetPoint("BOTTOMRIGHT", -16, 14)
    button:SetScript("OnClick", function()
        if window.mode == "backup" then
            box:SetFocus()
            box:HighlightText()
            return
        end
        local data, why = SK.ReadBackup(box:GetText())
        if not data then
            window.note:SetText("|cffff6666" .. why .. "|r")
            return
        end
        window.pending = data
        if StaticPopup_Show then StaticPopup_Show("SCROLLKEEPER_RESTORE") end
    end)
    window.button = button
    window:Hide()   -- new frames start shown
end

local function Open(mode)
    if not window then Build() end
    window.mode = mode
    window.pending = nil
    if mode == "backup" then
        window:SetTitle(L["Scrollkeeper: Backup"])
        window.hint:SetText(L["Copy all of this and keep it somewhere safe"])
        window.text = SK.BackupText()
        window.box:SetText(window.text)
        window.note:SetText(L["Put it back any time with /sk restore."])
        window.button:SetText(L["Select all"])
        window:Show()
        window.box:SetFocus()
        window.box:HighlightText()
    else
        window:SetTitle(L["Scrollkeeper: Restore"])
        window.hint:SetText(L["Paste a backup from /sk backup here"])
        window.text = nil
        window.box:SetText("")
        window.note:SetText(L["This replaces all your Scrollkeeper data. It asks first."])
        window.button:SetText(L["Restore"])
        window:Show()
        window.box:SetFocus()
    end
end

function SK.ShowBackup() Open("backup") end
function SK.ShowRestore() Open("restore") end

-- Swap the backup in for everything saved now, then reload so it all loads fresh.
local function Restore(data)
    if type(data) ~= "table" or not ScrollkeeperDB then return end
    for key in pairs(ScrollkeeperDB) do ScrollkeeperDB[key] = nil end
    for key, value in pairs(data) do
        if key ~= "backupOf" then ScrollkeeperDB[key] = value end
    end
    ScrollkeeperDB.errors = {}
    if ReloadUI then ReloadUI() end
end
SK.RestoreBackupData = Restore

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_RESTORE"] = {
        text = L["Scrollkeeper: replace all your Scrollkeeper data with this backup? Your UI reloads after."],
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        OnAccept = function()
            if window and window.pending then SK.Safely("restore", Restore, window.pending) end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end
