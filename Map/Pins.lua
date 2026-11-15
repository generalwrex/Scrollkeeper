-- Scrollkeeper: Map/Pins.lua
-- Pins on the world map:
--   book icon     a library where Study worked (yours, or shared by others)
--   scroll icon   a spot where untranslated scrolls dropped, with the count
--
-- Uses the world map's own pin system, so pins zoom and scale like the
-- game's own. Turn them off in the settings.

local _, SK = ...

local TEMPLATE = "ScrollkeeperMapPinTemplate"
local ICON_LIBRARY = "Interface\\Icons\\INV_Misc_Book_09"
local ICON_SCROLL = "Interface\\Icons\\INV_Scroll_03"

------------------------------------------------------------------------
-- One pin (the frame comes from Map/Pins.xml)
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
        self.Icon:SetTexture(ICON_SCROLL)
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
        if data.mine then
            GameTooltip:AddLine("You've used Study here.", 0.25, 1, 0.25)
        else
            GameTooltip:AddLine(("Shared by %d |4player:players;."):format(data.count or 1), 0.7, 0.7, 0.7)
        end
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

-- Redraw when the data or the setting changes.
SK.Listen("DROPS_CHANGED", function()
    if provider and WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end)
