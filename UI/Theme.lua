-- Scrollkeeper: UI/Theme.lua
-- How Scrollkeeper's windows look (/sk options > Panel > Theme):
--
--   classic         the game's own windows: gold and stone frames, bronze
--                   section bars (how it always looked)
--   dark            flat charcoal panels with thin gray borders and muted
--                   headers, no gold
--   dusk            "Darker classic": the game's window shapes, darkened,
--                   with gray borders and charcoal section bars
--   modern          flat slate panels, square buttons and boxes with thin
--                   borders, a blue accent
--
-- Every window, section bar, row stripe and pop-up asks for its colors
-- here, and is remembered, so switching themes changes everything at once.

local _, SK = ...
SK.UI = SK.UI or {}

local PALETTES = {
    classic = {
        background = { 0.05, 0.05, 0.06, 0.95 },
        stripe     = { 0.45, 0.32, 0.12, 0.18 },
        header     = { 0.35, 0.22, 0.08, 0.85 },
        nav        = { 0.35, 0.22, 0.08, 0.25 },
        border     = { 1, 0.82, 0, 1 },            -- pop-ups and pick rows
        box        = { 0.6, 0.5, 0.3, 1 },         -- dropdowns
        frameTint  = nil,                          -- the game's frame, untouched
        title      = { 1, 0.82, 0 },
    },
    dark = {
        background = { 0.07, 0.07, 0.08, 0.97 },
        stripe     = { 1, 1, 1, 0.04 },
        header     = { 0.16, 0.16, 0.18, 0.95 },
        nav        = { 0.12, 0.12, 0.14, 0.9 },
        border     = { 0.32, 0.32, 0.36, 1 },
        box        = { 0.3, 0.3, 0.34, 1 },
        flat       = true,                         -- no game frame at all
        title      = { 0.9, 0.9, 0.9 },
    },
    dusk = {
        background = { 0.04, 0.04, 0.05, 0.97 },
        stripe     = { 0.6, 0.6, 0.65, 0.07 },
        header     = { 0.2, 0.2, 0.22, 0.9 },
        nav        = { 0.18, 0.18, 0.2, 0.5 },
        border     = { 0.55, 0.55, 0.6, 1 },
        box        = { 0.4, 0.4, 0.44, 1 },
        frameTint  = { 0.42, 0.42, 0.46 },        -- the game's frame, grayed and darkened
        title      = { 0.85, 0.85, 0.88 },
    },
    modern = {
        background = { 0.08, 0.09, 0.11, 0.97 },
        stripe     = { 1, 1, 1, 0.035 },
        header     = { 0.13, 0.15, 0.19, 0.95 },
        nav        = { 0.11, 0.12, 0.15, 0.9 },
        border     = { 0.24, 0.27, 0.33, 1 },
        box        = { 0.26, 0.29, 0.35, 1 },
        flat       = true,
        title      = { 0.95, 0.96, 0.98 },
        headerTint = { 0.3, 0.38, 0.52 },          -- section bars: slate blue
        headerText = { 0.55, 0.75, 1 },
        square     = {                             -- square buttons and boxes
            button = { 0.15, 0.17, 0.21, 1 }, hover = { 0.21, 0.25, 0.32, 1 }, edge = { 0.3, 0.34, 0.41, 1 },
            accent = { 0.3, 0.62, 1, 1 }, text = { 0.93, 0.95, 0.98 }, input = { 0.05, 0.06, 0.08, 1 },
            selected = { 0.14, 0.3, 0.52, 1 },     -- the picked one of a row of buttons
        },
    },
}

SK.UI.THEMES = {
    { "classic", "Classic", "The game's own windows: gold and stone frames, bronze section bars." },
    { "dark", "Dark", "Flat charcoal panels with thin gray borders and muted headers. No gold." },
    { "dusk", "Darker classic", "The game's window shapes, darkened: gray borders and charcoal section bars." },
    { "modern", "Modern", "Flat slate panels, square buttons and boxes with thin borders, a blue accent." },
}

function SK.UI.ThemeName()
    local name = SK.db and SK.db.theme
    return PALETTES[name] and name or "classic"
end

function SK.UI.Palette() return PALETTES[SK.UI.ThemeName()] end

-- Everything themed, so a theme change reaches it: weak keys, so frames
-- that go away aren't kept.
local backgrounds = setmetatable({}, { __mode = "k" })
local stripes = setmetatable({}, { __mode = "k" })
local headerBgs = setmetatable({}, { __mode = "k" })
local navs = setmetatable({}, { __mode = "k" })
local headers = setmetatable({}, { __mode = "k" })
local windows = setmetatable({}, { __mode = "k" })
local boxes = setmetatable({}, { __mode = "k" })

local function Color(texture, color, alpha)
    if texture and texture.SetColorTexture then
        texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
    end
end

-- Tint (or untint) every texture in a frame: the game's window art.
local function Tint(frame, tint)
    if not (frame and frame.GetRegions) then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.SetVertexColor and region.GetObjectType and region:GetObjectType() == "Texture" then
            if region.SetDesaturated then region:SetDesaturated(tint and true or false) end
            region:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1)
        end
    end
end

-- A thin border for the Dark theme, in place of the game's frame.
local function FlatBorder(frame)
    if rawget(frame, "skFlatBorder") then return frame.skFlatBorder end
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetFrameLevel((frame:GetFrameLevel() or 1) + 1)
    if border.SetBackdrop then
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    end
    border:EnableMouse(false)
    frame.skFlatBorder = border
    return border
end

------------------------------------------------------------------------
-- Square buttons and boxes (Modern): the game's rounded button and edit
-- box art is hidden and a flat square with a thin border shows instead.
-- Every other theme shows the game's art again.
------------------------------------------------------------------------

-- Which controls get squared: text buttons (the game's panel buttons, in
-- whichever form this client's template has) and edit boxes. Not icon
-- buttons, check boxes, tabs or rows, which draw their own look.
local function Squarable(control)
    if rawget(control, "skNoSquare") or not control.GetObjectType then return false end
    local kind = control:GetObjectType()
    if kind == "EditBox" then return rawget(control, "skSquare") ~= nil or control:GetNumRegions() > 0 end
    if kind ~= "Button" then return false end
    if rawget(control, "LeftActive") or rawget(control, "LeftDisabled") or rawget(control, "Icon") or rawget(control, "icon") then return false end
    local text = control.GetFontString and control:GetFontString()
    return text ~= nil and (control.GetNormalTexture and control:GetNormalTexture() ~= nil
        or rawget(control, "Left") ~= nil or rawget(control, "Middle") ~= nil)
end

local squared = setmetatable({}, { __mode = "k" })

-- A squared button's resting look: blue when it's the picked one (the
-- game marks those with LockHighlight), plain otherwise.
local function Rest(control, parts)
    local sq = SK.UI.Palette().square
    if not (sq and squared[control]) then return end
    local picked = rawget(control, "skPicked")
    Color(parts.bg, picked and sq.selected or sq.button)
    local edge = picked and sq.accent or sq.edge
    parts.edge:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

local function SquareParts(control)
    local parts = rawget(control, "skSquare")
    if parts then return parts end
    -- The game's art: every texture the control has now (its normal,
    -- pushed, highlight and disabled art, or its left/middle/right pieces).
    local art = {}
    for _, region in ipairs({ control:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then art[#art + 1] = region end
    end
    local bg = control:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    local edge = CreateFrame("Frame", nil, control, "BackdropTemplate")
    edge:SetAllPoints()
    if edge.SetBackdrop then edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }) end
    edge:EnableMouse(false)
    parts = { bg = bg, edge = edge, art = art }
    control.skSquare = parts
    if control.HookScript and control:GetObjectType() == "Button" then
        control:HookScript("OnEnter", function(self)
            local sq = SK.UI.Palette().square
            if sq and squared[self] and (not self.IsEnabled or self:IsEnabled()) then
                Color(parts.bg, sq.hover); parts.edge:SetBackdropBorderColor(sq.accent[1], sq.accent[2], sq.accent[3], 1)
            end
        end)
        control:HookScript("OnLeave", function(self) Rest(self, parts) end)
        -- Picked / not picked (rows of choices: Panel view, Theme, sort...).
        if hooksecurefunc then
            hooksecurefunc(control, "LockHighlight", function(self) self.skPicked = true; Rest(self, parts) end)
            hooksecurefunc(control, "UnlockHighlight", function(self) self.skPicked = nil; Rest(self, parts) end)
        end
        -- Pressed: a touch darker.
        control:HookScript("OnMouseDown", function(self)
            local sq = SK.UI.Palette().square
            if sq and squared[self] then Color(parts.bg, sq.input) end
        end)
        control:HookScript("OnMouseUp", function(self)
            local sq = SK.UI.Palette().square
            if sq and squared[self] then
                if self:IsMouseOver() then Color(parts.bg, sq.hover) else Rest(self, parts) end
            end
        end)
    end
    return parts
end

local function SkinControl(control, sq)
    if not (sq or squared[control]) then return end    -- never squared: nothing to undo
    if not Squarable(control) then return end
    -- Secure buttons (Decipher, Study) can't be changed in combat: next time.
    if InCombatLockdown and InCombatLockdown() and control.IsProtected and control:IsProtected() then return end
    local parts = SquareParts(control)
    local isButton = control:GetObjectType() == "Button"
    -- The game's art is kept but hidden (alpha), so the game can keep
    -- swapping it for pressed and disabled as usual.
    for _, piece in ipairs(parts.art) do piece:SetAlpha(sq and 0 or 1) end
    if isButton then
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
            local texture = control[getter] and control[getter](control)
            if texture and texture.SetAlpha then texture:SetAlpha(sq and 0 or 1) end
        end
    end
    parts.bg:SetShown(sq and true or false)
    parts.edge:SetShown(sq and true or false)
    squared[control] = sq and true or nil
    if sq then
        Color(parts.bg, isButton and sq.button or sq.input)
        parts.edge:SetBackdropBorderColor(sq.edge[1], sq.edge[2], sq.edge[3], 1)
        if isButton then Rest(control, parts) end
    end
    if isButton and control.SetNormalFontObject then
        -- White text on the square buttons; the game's gold otherwise.
        if sq then
            if not rawget(control, "skFont") then control.skFont = control.GetNormalFontObject and control:GetNormalFontObject() or GameFontNormal end
            control:SetNormalFontObject(GameFontHighlight)
            if control.SetHighlightFontObject then control:SetHighlightFontObject(GameFontHighlight) end
        elseif rawget(control, "skFont") then
            control:SetNormalFontObject(control.skFont)
            if control.SetHighlightFontObject then control:SetHighlightFontObject(GameFontHighlight) end
        end
    end
end

-- Every button and edit box in a frame, all the way down.
local function SkinControls(frame, sq, depth)
    depth = depth or 0
    if depth > 8 or not (frame and frame.GetChildren) then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if type(child) == "table" then
            SkinControl(child, sq)
            SkinControls(child, sq, depth + 1)
        end
    end
end
SK.UI.SkinControls = function(frame) SK.Quietly("theme controls", SkinControls, frame, SK.UI.Palette().square) end

-- Windows build parts when they're first needed (a settings section, a
-- Doorways list), so while a square theme is on, open windows are looked
-- over again every second for new buttons.
local ticker
local function Sweep()
    local sq = SK.UI.Palette().square
    if not sq then
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    for frame in pairs(windows) do
        if frame.IsShown and frame:IsShown() then SkinControls(frame, sq) end
    end
    for frame in pairs(boxes) do
        if frame.IsShown and frame:IsShown() then SkinControls(frame, sq) end
    end
end
local function StartSweeping()
    if ticker or not SK.UI.Palette().square or not (C_Timer and C_Timer.NewTicker) then return end
    ticker = C_Timer.NewTicker(1, function() SK.Quietly("theme controls", Sweep) end)
end

local function SkinWindow(frame)
    local p = SK.UI.Palette()
    local art = { rawget(frame, "NineSlice"), rawget(frame, "TopTileStreaks"), rawget(frame, "Bg") }
    local portrait = rawget(frame, "PortraitContainer") or rawget(frame, "portrait")
    for _, piece in ipairs(art) do
        if type(piece) == "table" then
            if piece.SetShown then piece:SetShown(not p.flat) end
            if piece.GetRegions then Tint(piece, p.frameTint) end
            if piece.SetVertexColor and piece.GetObjectType and piece:GetObjectType() == "Texture" then
                if piece.SetDesaturated then piece:SetDesaturated(p.frameTint and true or false) end
                local t = p.frameTint
                piece:SetVertexColor(t and t[1] or 1, t and t[2] or 1, t and t[3] or 1)
            end
        end
    end
    if type(portrait) == "table" and portrait.SetDesaturated then portrait:SetDesaturated(false) end
    local border = FlatBorder(frame)
    border:SetShown(p.flat and true or false)
    if border.SetBackdropBorderColor then border:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1) end
    local container = rawget(frame, "TitleContainer")
    local title = (type(container) == "table" and rawget(container, "TitleText")) or rawget(frame, "TitleText")
    if type(title) == "table" and title.SetTextColor then title:SetTextColor(p.title[1], p.title[2], p.title[3]) end
    -- Buttons and boxes: now, and again each time it opens (parts of a
    -- window are made when first needed).
    SkinControls(frame, p.square)
    if frame.HookScript and not rawget(frame, "skControlsHooked") then
        frame.skControlsHooked = true
        frame:HookScript("OnShow", function(self) SK.Quietly("theme controls", SkinControls, self, SK.UI.Palette().square) end)
    end
end

SK.Listen("READY", function() StartSweeping() end)

-- A window's dark background (and the window itself, for the frame art).
function SK.UI.Background(texture, frame)
    backgrounds[texture] = true
    Color(texture, SK.UI.Palette().background)
    frame = frame or (texture.GetParent and texture:GetParent())
    if frame then
        windows[frame] = true
        SK.Quietly("theme window", SkinWindow, frame)
    end
end

-- A striped row's stripe: shown (on) or not.
function SK.UI.Stripe(texture, on)
    if on == nil then on = true end
    stripes[texture] = on and true or false
    local p = SK.UI.Palette()
    Color(texture, p.stripe, on and p.stripe[4] or 0)
end

-- A section bar's plain background (when the game's template is missing).
function SK.UI.HeaderBg(texture)
    headerBgs[texture] = true
    Color(texture, SK.UI.Palette().header)
end

-- The settings window's section list background.
function SK.UI.NavBg(texture)
    navs[texture] = true
    Color(texture, SK.UI.Palette().nav)
end

-- A section bar made from the game's character-window template: its own
-- bronze art, tinted for the darker themes.
function SK.UI.SkinHeader(header)
    headers[header] = true
    local p = SK.UI.Palette()
    local tint = p.headerTint or (p.flat and { 0.35, 0.35, 0.38 }) or p.frameTint
    SK.Quietly("theme header", Tint, header, tint)
    local title = rawget(header, "Title")
    local color = p.headerText or p.title
    if type(title) == "table" and title.SetTextColor then title:SetTextColor(color[1], color[2], color[3]) end
end

-- A pop-up or dropdown with a backdrop: kind "accent" (pop-ups, pick
-- rows: gold in Classic) or "box" (dropdowns).
function SK.UI.SkinBox(frame, kind)
    boxes[frame] = kind or "accent"
    local p = SK.UI.Palette()
    -- "dialog": the game's dialog border, untouched in Classic.
    local c = kind == "box" and p.box or (kind == "dialog" and p.frameTint == nil and not p.flat and { 1, 1, 1 }) or p.border
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
    SK.Quietly("theme controls", SkinControls, frame, p.square)
end

-- Switch themes: everything remembered gets the new colors.
function SK.UI.ApplyTheme()
    local p = SK.UI.Palette()
    for texture in pairs(backgrounds) do Color(texture, p.background) end
    for texture, on in pairs(stripes) do Color(texture, p.stripe, on and p.stripe[4] or 0) end
    for texture in pairs(headerBgs) do Color(texture, p.header) end
    for texture in pairs(navs) do Color(texture, p.nav) end
    for header in pairs(headers) do SK.UI.SkinHeader(header) end
    for frame, kind in pairs(boxes) do SK.UI.SkinBox(frame, kind) end
    for frame in pairs(windows) do SK.Quietly("theme window", SkinWindow, frame) end
    StartSweeping()
    SK.Send("THEME_CHANGED")
end
