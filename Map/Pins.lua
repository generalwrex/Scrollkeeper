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
        local size = math.min(24, 12 + total * 2)
        self.Icon:SetTexture(data.kind == "book" and ICON_BOOK or ICON_SCROLL)
        self:SetSize(size, size)
        self.Count:SetText(total > 1 and total or "")
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
        GameTooltip:AddLine("Library: Study works here.", 1, 1, 1)
        GameTooltip:AddLine("Click for a waypoint.", 0.6, 0.6, 0.6)
        if data.mine then
            GameTooltip:AddLine("You've used Study here.", 0.25, 1, 0.25)
        end
        if (data.count or 0) > 0 then
            GameTooltip:AddLine(("Shared by %d |4player:players;."):format(data.count), 0.7, 0.7, 0.7)
        elseif data.known and not data.mine then
            GameTooltip:AddLine("Known library. Stand near the librarian.", 0.7, 0.7, 0.7)
        end
    elseif data.kind == "book" then
        GameTooltip:SetText(data.name or "Books")
        GameTooltip:AddLine("Book for the librarians.", 1, 1, 1)
        if data.mine > 0 then GameTooltip:AddLine(("You found %d here."):format(data.mine), 1, 1, 1) end
        if data.others > 0 then GameTooltip:AddLine(("Others found %d here."):format(data.others), 0.7, 0.7, 0.7) end
    else
        GameTooltip:SetText("Untranslated scrolls")
        if data.mine > 0 then GameTooltip:AddLine(("You looted %d here."):format(data.mine), 1, 1, 1) end
        if data.others > 0 then GameTooltip:AddLine(("Others looted %d here."):format(data.others), 0.7, 0.7, 0.7) end
    end
    GameTooltip:AddLine("Scrollkeeper", 0.41, 0.8, 0.94)
    GameTooltip:Show()
end

function ScrollkeeperMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

-- Click a library pin: set a waypoint there (TomTom if you have it,
-- otherwise the game's own map pin).
function ScrollkeeperMapPinMixin:OnClick(button)
    local data = self.data
    if button ~= "LeftButton" or not data or data.kind ~= "library" then return end
    local mapID = self:GetMap():GetMapID()
    if _G.TomTom and TomTom.AddWaypoint then
        TomTom:AddWaypoint(mapID, data.x, data.y, { title = data.name, from = "Scrollkeeper" })
    elseif C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) and UiMapPoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, data.x, data.y))
        if C_SuperTrack then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
    SK.Print("waypoint set: " .. data.name)
end

------------------------------------------------------------------------
-- The data provider: tells the map which pins to draw
------------------------------------------------------------------------

local provider

local function CreateProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
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

        for cell, counts in pairs(SK.DropCells(mapID)) do
            local x, y = SK.CellCenter(cell)
            if x then
                self:GetMap():AcquirePin(TEMPLATE, {
                    kind = "drop", x = x, y = y, mine = counts.mine, others = counts.others,
                })
            end
        end
        for cell, counts in pairs(SK.DropCells(mapID, "books")) do
            local x, y = SK.CellCenter(cell)
            if x then
                local name = SK.db.bookNames and SK.db.bookNames[mapID .. ":" .. cell]
                self:GetMap():AcquirePin(TEMPLATE, {
                    kind = "book", x = x, y = y, mine = counts.mine, others = counts.others, name = name,
                })
            end
        end
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
