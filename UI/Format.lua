-- Scrollkeeper: UI/Format.lua
-- Text formatting for the board (and anything else players write):
-- emojis as :name: and a little markdown, done when the text is shown.
-- What goes over the network stays plain text, so a Scrollkeeper without
-- this just shows ":fire:" and "**bold**" as typed.
--
--   :fire: :frost: :sheep: ...   game icons (the list below)
--   **bold**                     gold
--   *italic*                     light blue (the game can't do italics)
--   `code`                       green
--   ~~strike~~                   gray (the game can't strike through)
--   - at the start               a bullet
--   > at the start               a quote (gray)
--
-- Settings: textEmoji, textMarkdown (/sk options > Sharing).

local _, SK = ...

local MAX_EMOJI = 12   -- per text: any more stay as typed

local RAID = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local ICON = "Interface\\Icons\\"
local FACE = "Interface\\AddOns\\Scrollkeeper\\Media\\Emoji\\"
SK.EMOJI = {
    -- faces (our own pictures, in Media\Emoji)
    { "smile", FACE .. "smile", ":)" },
    { "grin", FACE .. "grin", ":D" },
    { "laugh", FACE .. "laugh", "XD" },
    { "wink", FACE .. "wink", ";)" },
    { "sad", FACE .. "sad", ":(" },
    { "cry", FACE .. "cry", ":'(" },
    { "angry", FACE .. "angry", ">:(" },
    { "surprised", FACE .. "surprised", ":O" },
    { "tongue", FACE .. "tongue", ":P" },
    { "cool", FACE .. "cool", "B)" },
    { "love", FACE .. "love" },
    { "neutral", FACE .. "neutral", ":|" },
    { "heart", FACE .. "heart", "<3" },
    -- game icons
    { "fire", ICON .. "Spell_Fire_FlameBolt" },
    { "frost", ICON .. "Spell_Frost_FrostBolt02" },
    { "arcane", ICON .. "Spell_Holy_MagicalSentry" },
    { "blink", ICON .. "Spell_Arcane_Blink" },
    { "sheep", ICON .. "Spell_Nature_Polymorph" },
    { "chicken", ICON .. "Spell_Magic_PolymorphChicken" },
    { "zzz", ICON .. "Spell_Nature_Sleep" },
    { "water", ICON .. "INV_Drink_18" },
    { "beer", ICON .. "INV_Drink_05" },
    { "gold", ICON .. "INV_Misc_Coin_01" },
    { "scroll", ICON .. "INV_Scroll_03" },
    { "book", ICON .. "INV_Misc_Book_09" },
    { "sword", ICON .. "INV_Sword_04" },
    { "shield", ICON .. "INV_Shield_06" },
    { "star", RAID .. "1" },
    { "circle", RAID .. "2" },
    { "diamond", RAID .. "3" },
    { "triangle", RAID .. "4" },
    { "moon", RAID .. "5" },
    { "square", RAID .. "6" },
    { "x", RAID .. "7" },
    { "skull", RAID .. "8" },
}
local byName = {}
local byText = { [":-)"] = "smile", [":-D"] = "grin", [":-("] = "sad", [":o"] = "surprised", [":p"] = "tongue", [";-)"] = "wink", ["xD"] = "laugh" }
for _, e in ipairs(SK.EMOJI) do
    byName[e[1]] = e[2]
    if e[3] then byText[e[3]] = e[1] end
end

function SK.EmojiTexture(name) return byName[name] end

local function On(key) return not (SK.db and SK.db[key] == false) end

-- Text ready to show: emojis and markdown, as the settings say.
--   size: emoji size in pixels (0 or nil: the text's own height)
function SK.FormatText(text, size)
    text = tostring(text or "")
    if On("textMarkdown") then
        text = text:gsub("^%- ", "• ")
        text = text:gsub("^> ?(.*)$", "|cff9a9a9a\"%1\"|r")
        text = text:gsub("~~([^~]+)~~", "|cff808080%1|r")
        text = text:gsub("%*%*([^%*]+)%*%*", "|cffffd100%1|r")
        text = text:gsub("%*([^%*]+)%*", "|cffa8d4ff%1|r")
        text = text:gsub("`([^`]+)`", "|cff7cff7c%1|r")
    end
    if On("textEmoji") then
        local n, px = 0, size or 0
        text = text:gsub(":(%w+):", function(name)
            local tex = byName[name:lower()]
            if not tex or n >= MAX_EMOJI then return nil end
            n = n + 1
            return ("|T%s:%d:%d|t"):format(tex, px, px)
        end)
        -- Text faces like :) and <3, as whole words only.
        text = text:gsub("%S+", function(word)
            local name = byText[word]
            if not name or n >= MAX_EMOJI then return nil end
            n = n + 1
            return ("|T%s:%d:%d|t"):format(byName[name], px, px)
        end)
    end
    return text
end

------------------------------------------------------------------------
-- The emoji picker: a small button that opens a grid of icons; clicking
-- one types its :name: into the edit box.
------------------------------------------------------------------------

local picker
local COLS, CELL = 6, 24

local function Picker()
    if picker then return picker end
    picker = CreateFrame("Frame", "ScrollkeeperEmojiPicker", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    picker:SetFrameStrata("DIALOG")
    picker:SetSize(COLS * CELL + 12, math.ceil(#SK.EMOJI / COLS) * CELL + 12)
    if picker.SetBackdrop then
        picker:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        picker:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    end
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    if picker.SetPropagateKeyboardInput then picker:SetPropagateKeyboardInput(true) end
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
            self:Hide()
        end
    end)
    picker:SetScript("OnShow", function(self)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
    end)
    for i, e in ipairs(SK.EMOJI) do
        local b = CreateFrame("Button", nil, picker)
        b:SetSize(CELL - 2, CELL - 2)
        b:SetPoint("TOPLEFT", 6 + ((i - 1) % COLS) * CELL, -6 - math.floor((i - 1) / COLS) * CELL)
        b:SetNormalTexture(e[2])
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnClick", function()
            local box = picker.editBox
            if box then
                box:SetFocus()
                box:Insert(":" .. e[1] .. ":")
            end
            picker:Hide()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(":" .. e[1] .. ":" .. (e[3] and ("  or  " .. e[3]) or ""))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    picker:Hide()
    return picker
end

-- A small smiley button for an edit box. Returns the button (place it).
function SK.EmojiButton(parent, editBox)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b:SetNormalTexture(ICON .. "Spell_Holy_MagicalSentry")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function(self)
        local p = Picker()
        if p:IsShown() and p.editBox == editBox then p:Hide() return end
        p.editBox = editBox
        p:ClearAllPoints()
        p:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 4)
        p:Show()
        if SK.Track then SK.Track("emoji.picker") end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(SK.L and SK.L["Emojis"] or "Emojis")
        GameTooltip:AddLine(SK.L and SK.L["Pick one, or type :name:. Also **bold**, *italic*, `code`, ~~strike~~, and - or > at the start for a bullet or a quote."]
            or "Pick one, or type :name:.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
