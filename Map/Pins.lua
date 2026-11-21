-- Scrollkeeper: Map/Pins.lua
-- Pins on the world map:
--   book icon     a library: the two known ones, plus any where Study
--                 worked for you or for other Scrollkeeper users
--   scroll icon   a spot where untranslated scrolls dropped, with the count
--   red book      a spot where books for the librarians were found
--
-- Uses the world map's own pin system, so pins zoom and scale like the
-- game's own. Turn them off in the settings.

local _, SK = ...
local L = SK.L

local TEMPLATE = "ScrollkeeperMapPinTemplate"
local ICON_LIBRARY = "Interface\\Icons\\INV_Misc_Book_09"
local ICON_SCROLL = "Interface\\Icons\\INV_Scroll_03"
local ICON_BOOK = "Interface\\Icons\\INV_Misc_Book_11"

------------------------------------------------------------------------
-- One pin (the frame comes from Map/Pins.xml). The world map calls these
-- methods itself: OnLoad, OnAcquired, OnMouseEnter, OnMouseLeave, OnClick.
------------------------------------------------------------------------

ScrollkeeperMapPinMixin = (CreateFromMixins and MapCanvasPinMixin)
    and CreateFromMixins(MapCanvasPinMixin) or {}

function ScrollkeeperMapPinMixin:OnLoad()
    if self.SetScalingLimits then self:SetScalingLimits(1, 1.0, 1.2) end
    if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI") end
end

function ScrollkeeperMapPinMixin:OnAcquired(data)
    self.data = data
    self:SetPosition(data.x, data.y)
    if data.kind == "library" then
        self.Icon:SetTexture(ICON_LIBRARY)
        self:SetSize(20, 20)
        self.Count:SetText("")
        self:SetAlpha(1)
    else
        local total = data.mine + data.others
        local book = data.kind == "book"
        -- A book is one book however often it was found: no number on it.
        local size = book and 18 or math.min(24, 12 + total * 2)
        self.Icon:SetTexture(book and ICON_BOOK or ICON_SCROLL)
        self:SetSize(size, size)
        self.Count:SetText((not book and total > 1) and total or "")
        -- Spots only others reported are a little faded.
        self:SetAlpha(data.mine > 0 and 1 or 0.75)
    end
end

function ScrollkeeperMapPinMixin:OnMouseEnter()
    local data = self.data
    if not data then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if data.kind == "library" then
        GameTooltip:SetText(data.name)
        GameTooltip:AddLine(L["Library: Study works here."], 1, 1, 1)
        GameTooltip:AddLine(L["Click for a waypoint."], 0.6, 0.6, 0.6)
        if data.mine then
            GameTooltip:AddLine(L["You've used Study here."], 0.25, 1, 0.25)
        end
        if (data.count or 0) > 0 then
            GameTooltip:AddLine(L["Shared by %d |4player:players;."]:format(data.count), 0.7, 0.7, 0.7)
        elseif data.known and not data.mine then
            GameTooltip:AddLine(L["Known library. Stand near the librarian."], 0.7, 0.7, 0.7)
        end
    elseif data.kind == "book" then
        GameTooltip:SetText(data.name or L["Book for the librarians."])
        GameTooltip:AddLine(L["A book for the librarians sits here."], 1, 1, 1)
        if data.mine > 0 then GameTooltip:AddLine(L["You found it here."], 0.25, 1, 0.25) end
        local found = data.mine + data.others
        if found > 1 then GameTooltip:AddLine(L["Found %d times."]:format(found), 0.7, 0.7, 0.7) end
    else
        GameTooltip:SetText(L["Untranslated scrolls"])
        if data.mine > 0 then GameTooltip:AddLine(L["You looted %d here."]:format(data.mine), 1, 1, 1) end
        if data.others > 0 then GameTooltip:AddLine(L["Others looted %d here."]:format(data.others), 0.7, 0.7, 0.7) end
    end
    if data.spots then GameTooltip:AddLine(L["All around this circle (%d spots)."]:format(data.spots), 1, 0.82, 0) end
    GameTooltip:AddLine(L["Scrollkeeper"], 0.41, 0.8, 0.94)
    GameTooltip:Show()
end

function ScrollkeeperMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

-- Click a library pin: set a waypoint there (Zygor's or TomTom's arrow
-- if you have one, otherwise the game's own map pin).
function ScrollkeeperMapPinMixin:OnClick(button)
    local data = self.data
    if button ~= "LeftButton" or not data or data.kind ~= "library" then return end
    if SK.SetWaypoint(self:GetMap():GetMapID(), data.x, data.y, data.name) then
        SK.Print(L["waypoint set: "] .. data.name)
    end
end

------------------------------------------------------------------------
-- Area circles: drop spots close together are drawn as one shaded
-- circle with a single pin (the total) in the middle.
------------------------------------------------------------------------

local AREA_TEMPLATE = "ScrollkeeperMapAreaTemplate"

ScrollkeeperMapAreaMixin = (CreateFromMixins and MapCanvasPinMixin)
    and CreateFromMixins(MapCanvasPinMixin) or {}

function ScrollkeeperMapAreaMixin:OnLoad()
    if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI") end
end

-- Keep the map's own scale, so the circle covers the same ground at any zoom.
function ScrollkeeperMapAreaMixin:ApplyCurrentScale() self:SetScale(1) end

function ScrollkeeperMapAreaMixin:OnAcquired(data)
    self:SetPosition(data.x, data.y)
    self:SetSize(data.size, data.size)
    self:SetScale(1)
    if self.EnableMouse then self:EnableMouse(false) end
    local c = data.color
    self.Fill:SetVertexColor(c[1], c[2], c[3], 0.22)
end

-- Spots no more than 2 cells (4% of the map) apart join one area.
local JOIN = 2
local function Clusters(cells)
    local list = {}
    for cell, counts in pairs(cells) do
        local gx, gy = cell:match("^(%d+)%.(%d+)$")
        if gx then list[#list + 1] = { gx = tonumber(gx), gy = tonumber(gy), cell = cell, counts = counts } end
    end
    local groups, done = {}, {}
    for i, start in ipairs(list) do
        if not done[i] then
            local group, queue = {}, { i }
            done[i] = true
            while #queue > 0 do
                local a = list[table.remove(queue)]
                group[#group + 1] = a
                for j, b in ipairs(list) do
                    if not done[j] and math.abs(a.gx - b.gx) <= JOIN and math.abs(a.gy - b.gy) <= JOIN then
                        done[j] = true
                        queue[#queue + 1] = j
                    end
                end
            end
            groups[#groups + 1] = group
        end
    end
    return groups
end

------------------------------------------------------------------------
-- The data provider: tells the map which pins to draw
------------------------------------------------------------------------

local provider

local function CreateProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
        self:GetMap():RemoveAllPinsByTemplate(AREA_TEMPLATE)
    end

    -- Drop spots: lone ones as pins, groups as a circle with one pin.
    function provider:DrawSpots(cells, kind, color, nameFor)
        local map = self:GetMap()
        local canvas = map.GetCanvas and map:GetCanvas()
        local width = canvas and canvas:GetWidth() or 0
        local height = canvas and canvas:GetHeight() or 0
        for _, group in ipairs(Clusters(cells)) do
            local mine, others = 0, 0
            local best, bestCount
            for _, spot in ipairs(group) do
                mine, others = mine + (spot.counts.mine or 0), others + (spot.counts.others or 0)
                local n = (spot.counts.mine or 0) + (spot.counts.others or 0)
                if not bestCount or n > bestCount then best, bestCount = spot, n end
            end
            -- Books for the librarians sit in one place in the world: spots
            -- close together are that same book (looted from a step away),
            -- so it's one pin where it was found most, no circle, no count.
            if kind == "book" then
                local x, y = SK.CellCenter(best.cell)
                if x then
                    map:AcquirePin(TEMPLATE, { kind = kind, x = x, y = y, mine = mine, others = others,
                        name = nameFor and nameFor(best.cell) })
                end
                group = {}
            end
            -- Middle weighted by count; radius reaches the farthest spot.
            local cx, cy, radius
            if #group > 1 and width > 0 and height > 0 then
                local sx, sy, total = 0, 0, 0
                for _, spot in ipairs(group) do
                    local x, y = SK.CellCenter(spot.cell)
                    local n = (spot.counts.mine or 0) + (spot.counts.others or 0)
                    sx, sy, total = sx + x * n, sy + y * n, total + n
                end
                cx, cy, radius = sx / math.max(1, total), sy / math.max(1, total), 0
                for _, spot in ipairs(group) do
                    local x, y = SK.CellCenter(spot.cell)
                    radius = math.max(radius, math.sqrt(((x - cx) * width) ^ 2 + ((y - cy) * height) ^ 2))
                end
                radius = radius + width / SK.DROP_GRID   -- room around the outer spots
                -- A chain of spots across half the zone isn't one area.
                if radius > width * 0.15 then radius = nil end
            end
            if not radius then
                for _, spot in ipairs(group) do
                    local x, y = SK.CellCenter(spot.cell)
                    if x then
                        map:AcquirePin(TEMPLATE, { kind = kind, x = x, y = y, mine = spot.counts.mine,
                            others = spot.counts.others, name = nameFor and nameFor(spot.cell) })
                    end
                end
            else
                map:AcquirePin(AREA_TEMPLATE, { x = cx, y = cy, size = radius * 2, color = color })
                map:AcquirePin(TEMPLATE, { kind = kind, x = cx, y = cy, mine = mine, others = others,
                    spots = #group, name = nameFor and nameFor(group[1].cell) })
            end
        end
    end

    function provider:RefreshAllData()
        -- The map asks for pins inside its own protected update. In combat,
        -- wait until it's over; and never let a pin problem break the map.
        if InCombatLockdown and InCombatLockdown() then
            self.redrawAfterCombat = true
            return
        end
        SK.Quietly("map pins", function() self:DrawPins() end)
    end

    function provider:DrawPins()
        self:RemoveAllData()
        if not SK.db.mapPins then return end
        local mapID = self:GetMap():GetMapID()
        if not mapID then return end

        self:DrawSpots(SK.DropCells(mapID), "drop", { 1, 0.82, 0 })
        self:DrawSpots(SK.DropCells(mapID, "books"), "book", { 1, 0.3, 0.3 }, function(cell)
            return SK.db.bookNames and SK.db.bookNames[mapID .. ":" .. cell]
        end)
        for _, library in ipairs(SK.LibraryPins(mapID)) do
            library.kind = "library"
            self:GetMap():AcquirePin(TEMPLATE, library)
        end
    end

    return provider
end

-- The world map is loaded only when first needed, so wait for it.
local function Attach()
    if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin) then return end
    SK.Safely("map pins", function()
        WorldMapFrame:AddDataProvider(CreateProvider())
    end)
end

SK.Listen("READY", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_WorldMap") then Attach() end
end)
SK.On("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" then Attach() end
end)

-- Draw the pins skipped during combat.
SK.On("PLAYER_REGEN_ENABLED", function()
    if provider and provider.redrawAfterCombat then
        provider.redrawAfterCombat = nil
        if WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
    end
end)

-- Redraw when the data or the setting changes.
SK.Listen("DROPS_CHANGED", function()
    if provider and WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end)
