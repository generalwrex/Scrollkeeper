-- Scrollkeeper: UI/Theme.lua
-- How Scrollkeeper's windows look (/sk options > Panel > Theme):
--
--   classic         the game's own windows: gold and stone frames, bronze
--                   section bars (how it always looked)
--   dark            flat charcoal panels with thin gray borders and muted
--                   headers, no gold
--   dusk            "Darker classic": the game's window shapes, darkened,
--                   with gray borders and charcoal section bars
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
}

SK.UI.THEMES = {
    { "classic", "Classic", "The game's own windows: gold and stone frames, bronze section bars." },
    { "dark", "Dark", "Flat charcoal panels with thin gray borders and muted headers. No gold." },
    { "dusk", "Darker classic", "The game's window shapes, darkened: gray borders and charcoal section bars." },
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
end

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
    local tint = p.flat and { 0.35, 0.35, 0.38 } or p.frameTint
    SK.Quietly("theme header", Tint, header, tint)
    local title = rawget(header, "Title")
    if type(title) == "table" and title.SetTextColor then title:SetTextColor(p.title[1], p.title[2], p.title[3]) end
end

-- A pop-up or dropdown with a backdrop: kind "accent" (pop-ups, pick
-- rows: gold in Classic) or "box" (dropdowns).
function SK.UI.SkinBox(frame, kind)
    boxes[frame] = kind or "accent"
    local p = SK.UI.Palette()
    -- "dialog": the game's dialog border, untouched in Classic.
    local c = kind == "box" and p.box or (kind == "dialog" and p.frameTint == nil and not p.flat and { 1, 1, 1 }) or p.border
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
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
    SK.Send("THEME_CHANGED")
end
