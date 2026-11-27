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

-- Real emoji typed or pasted in (the game's font can't draw them: they
-- show as boxes): the ones we have pictures for become them, the rest go.
local UNICODE = {
    ["\240\159\152\128"] = "grin", ["\240\159\152\129"] = "grin", ["\240\159\152\131"] = "grin",
    ["\240\159\152\132"] = "grin", ["\240\159\153\130"] = "smile", ["\240\159\152\138"] = "smile",
    ["\240\159\152\134"] = "laugh", ["\240\159\152\130"] = "laugh", ["\240\159\164\163"] = "laugh",
    ["\240\159\152\137"] = "wink", ["\240\159\152\162"] = "cry", ["\240\159\152\173"] = "cry",
    ["\240\159\152\158"] = "sad", ["\240\159\153\129"] = "sad", ["\240\159\152\160"] = "angry",
    ["\240\159\152\161"] = "angry", ["\240\159\152\174"] = "surprised", ["\240\159\152\178"] = "surprised",
    ["\240\159\152\175"] = "surprised", ["\240\159\152\155"] = "tongue", ["\240\159\152\156"] = "tongue",
    ["\240\159\152\157"] = "tongue", ["\240\159\152\142"] = "cool", ["\240\159\152\141"] = "love",
    ["\240\159\165\176"] = "love", ["\240\159\152\144"] = "neutral", ["\240\159\152\145"] = "neutral",
    ["\226\157\164"] = "heart", ["\240\159\146\150"] = "heart", ["\240\159\146\149"] = "heart",
    ["\240\159\146\151"] = "heart", ["\240\159\148\165"] = "fire", ["\240\159\146\128"] = "skull",
    ["\226\152\160"] = "skull", ["\240\159\144\145"] = "sheep", ["\226\173\144"] = "star",
    ["\240\159\140\159"] = "star", ["\240\159\140\153"] = "moon", ["\240\159\146\167"] = "water",
    ["\240\159\141\186"] = "beer", ["\240\159\146\176"] = "gold", ["\240\159\147\156"] = "scroll",
    ["\240\159\147\150"] = "book", ["\240\159\148\180"] = "circle", ["\226\157\140"] = "x",
    ["\240\159\152\180"] = "zzz", ["\240\159\144\148"] = "chicken",
}

local function Unicode(text, px, budget)
    text = text:gsub("\239\184\143", "")   -- the "show as emoji" marker
    local n = 0
    local function Swap(seq)
        local name = UNICODE[seq]
        if not name then return "" end
        if n >= budget then return ":" .. name .. ":" end
        n = n + 1
        return ("|T%s:%d:%d|t"):format(byName[name], px, px)
    end
    text = text:gsub("\240[\144-\191][\128-\191][\128-\191]", Swap)   -- 4-byte emoji
    text = text:gsub("[\226][\152-\173][\128-\191]", function(seq)      -- symbols like heart, star
        if UNICODE[seq] then return Swap(seq) end
        return nil
    end)
    return text, n
end

local function On(key) return not (SK.db and SK.db[key] == false) end

------------------------------------------------------------------------
-- Links: item and spell links (shift-click) are sent as {i12345} and
-- {s12345} (the network can't carry the game's link codes), and shown
-- again with icon and color. Web addresses get colored.
------------------------------------------------------------------------

function SK.EncodeLinks(text)
    text = tostring(text or "")
    text = text:gsub("|c%x+|Hitem:(%d+)[^|]*|h%[[^%]]*%]|h|r", "{i%1}")
    text = text:gsub("|Hitem:(%d+)[^|]*|h%[[^%]]*%]|h", "{i%1}")
    text = text:gsub("|c%x+|Hspell:(%d+)[^|]*|h%[[^%]]*%]|h|r", "{s%1}")
    text = text:gsub("|Hspell:(%d+)[^|]*|h%[[^%]]*%]|h", "{s%1}")
    return text
end

local function ItemName(id)
    return C_Item and C_Item.GetItemNameByID and SK.Try(C_Item.GetItemNameByID, id) or nil
end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return SK.Try(C_Spell.GetSpellName, id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end
local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return SK.Try(C_Spell.GetSpellTexture, id) end
    return GetSpellTexture and GetSpellTexture(id) or nil
end

-- Fuzzy matching for search boxes: how well query fits text (nil = not
-- at all). Ignores case, spaces and punctuation ("rogmar" finds Rog'mar);
-- letters in order count too ("gdgz"), and word initials ("stv").
local function Plain(text) return tostring(text or ""):lower():gsub("[^%w]", "") end
function SK.FuzzyScore(query, text)
    local q, t = Plain(query), Plain(text)
    if q == "" then return 0 end
    local at = t:find(q, 1, true)
    if at then return 200 - at end
    local initials = tostring(text or ""):lower():gsub("(%w)%w*[^%w]*", "%1")
    if initials:find(q, 1, true) then return 150 end
    local pos, gaps = 0, 0
    for i = 1, #q do
        local found = t:find(q:sub(i, i), pos + 1, true)
        if not found then return nil end
        gaps = gaps + (found - pos - 1)
        pos = found
    end
    return 100 - math.min(gaps, 90)
end

-- The item IDs in a text, in order (for the item buttons under a post).
function SK.LinkedItems(text)
    local ids, seen = {}, {}
    for id in tostring(text or ""):gmatch("{i(%d+)}") do
        id = tonumber(id)
        if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    return ids
end

local function ShowLinks(text)
    text = text:gsub("{i(%d+)}", function(id)
        id = tonumber(id)
        local name = ItemName(id)
        return SK.UI and SK.UI.ItemLabel and SK.UI.ItemLabel(id, "[" .. (name or ("item " .. id)) .. "]") or ("[" .. (name or id) .. "]")
    end)
    text = text:gsub("{s(%d+)}", function(id)
        id = tonumber(id)
        local icon = SpellIcon(id)
        return (icon and ("|T" .. icon .. ":14:14:0:0|t ") or "") .. "|cff71d5ff[" .. (SpellName(id) or ("spell " .. id)) .. "]|r"
    end)
    return text
end

local URL_PATTERNS = { "https?://[%w%-%._~:/%?#@!%$&'%(%)%+,;=%%]+", "www%.[%w%-%._~:/%?#@!%$&'%(%)%+,;=%%]+" }

-- The text with links as plain words, for copying.
function SK.PlainText(text)
    text = tostring(text or ""):gsub("{i(%d+)}", function(id) return "[" .. (ItemName(tonumber(id)) or ("item " .. id)) .. "]" end)
    text = text:gsub("{s(%d+)}", function(id) return "[" .. (SpellName(tonumber(id)) or ("spell " .. id)) .. "]" end)
    return text
end

-- Our edit boxes take shift-clicked links (the game only fills its chat
-- box): SK.UI.LinkTarget(editBox).
local linkTargets = {}
function SK.UI_LinkTarget(box) linkTargets[#linkTargets + 1] = box end
if hooksecurefunc and ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if type(link) ~= "string" then return end
        for _, box in ipairs(linkTargets) do
            if box:IsVisible() and box:HasFocus() then box:Insert(link) return end
        end
    end)
end

-- Text ready to show: emojis and markdown, as the settings say.
--   size: emoji size in pixels (0 or nil: the text's own height)
-- Optional word filter (setting boardWordFilter): swear words as ****.
local SWEARS = { "fuck", "shit", "bitch", "cunt", "dick", "cock", "pussy", "asshole", "bastard", "slut", "whore", "fag", "nigg", "retard" }
function SK.FilterWords(text)
    if not (SK.db and SK.db.boardWordFilter) then return text end
    local lower = text:lower()
    for _, word in ipairs(SWEARS) do
        local from = 1
        while true do
            local a, b = lower:find(word, from, true)
            if not a then break end
            text = text:sub(1, a - 1) .. string.rep("*", b - a + 1) .. text:sub(b + 1)
            from = b + 1
        end
    end
    return text
end

function SK.FormatText(text, size)
    text = SK.FilterWords(tostring(text or ""))
    -- Web addresses: kept out of the markdown (they can have * and _ in
    -- them), colored at the end.
    local urls = {}
    for _, pattern in ipairs(URL_PATTERNS) do
        text = text:gsub(pattern, function(url)
            urls[#urls + 1] = url
            return "\1" .. #urls .. "\1"
        end)
    end
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
        text, n = Unicode(text, px, MAX_EMOJI)
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
    text = ShowLinks(text)
    -- @Name: gold (brighter when it's you).
    text = text:gsub("(%f[%w@]@)([%a][%w]+)", function(at, name)
        local me = SK.BoardMentionsMe and SK.BoardMentionsMe("@" .. name)
        return (me and "|cffffff00" or "|cffffd100") .. at .. name .. "|r"
    end)
    text = text:gsub("\1(%d+)\1", function(n) return "|cff4fc3f7" .. (urls[tonumber(n)] or "") .. "|r" end)
    return text
end

------------------------------------------------------------------------
-- Pop-up menus (emoji picker, reactions, •••): close when you click
-- anywhere else, press Escape, or close the window they belong to.
--   SK.UI_AutoClose(frame)            once, when it's made (frame needs a name)
--   SK.UI_PopupFrom(frame, button)    when it opens: clicks on that button don't count
--   SK.UI_CloseMenus()                close them all
------------------------------------------------------------------------

local popups, popupFrom, popupOpened = {}, setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
function SK.UI_AutoClose(frame)
    popups[#popups + 1] = frame
    if frame:GetName() and UISpecialFrames then tinsert(UISpecialFrames, frame:GetName()) end
    frame:HookScript("OnShow", function(self) popupOpened[self] = GetTime() end)
    frame:HookScript("OnUpdate", function(self)
        if not (IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))) then return end
        if GetTime() - (popupOpened[self] or 0) < 0.15 then return end
        if self:IsMouseOver() then return end
        local from = popupFrom[self]
        if from and from.IsMouseOver and from:IsMouseOver() then return end
        self:Hide()
    end)
end
function SK.UI_PopupFrom(frame, button) popupFrom[frame] = button end
function SK.UI_CloseMenus()
    for _, frame in ipairs(popups) do if frame:IsShown() then frame:Hide() end end
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
    SK.UI_AutoClose(picker)
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
        SK.UI_PopupFrom(p, self)
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
