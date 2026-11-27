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
-- Doors use the Scroll of Liminal Passage icon.
local function ICON_DOOR()
    return (C_Item and SK.LIMINAL_PASSAGE and SK.Try(C_Item.GetItemIconByID, SK.LIMINAL_PASSAGE))
        or "Interface\\Icons\\Spell_Arcane_Blink"
end

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

-- The map sets every pin's layer again whenever it redraws, so inn pins
-- get lifted above the game's own inn icons each time, not just once.
function ScrollkeeperMapPinMixin:ApplyFrameLevel()
    if MapCanvasPinMixin and MapCanvasPinMixin.ApplyFrameLevel then MapCanvasPinMixin.ApplyFrameLevel(self) end
    if self.data and self.data.kind == "inn" and self.GetFrameLevel then
        self:SetFrameLevel(math.min(self:GetFrameLevel() + 100, 9000))
    end
end

function ScrollkeeperMapPinMixin:OnAcquired(data)
    self.data = data
    self:SetPosition(data.x, data.y)
    if self.Icon.SetDesaturated then self.Icon:SetDesaturated(false) end
    if data.kind == "library" then
        self.Icon:SetTexture(ICON_LIBRARY)
        self:SetSize(20, 20)
        self.Count:SetText("")
        self:SetAlpha(1)
    elseif data.kind == "door" then
        -- A Scrollkeeper user who's a door right now (Doorways).
        self.Icon:SetTexture(ICON_DOOR())
        self:SetSize(16 * (tonumber(SK.db and SK.db.mapPinScale) or 1), 16 * (tonumber(SK.db and SK.db.mapPinScale) or 1))
        self.Count:SetText("")
        self:SetAlpha(1)
    elseif data.kind == "inn" then
        -- A town with an inn (Doorways): rest here to be a door.
        self.Icon:SetTexture("Interface\\Minimap\\Tracking\\Innkeeper")
        local size = 14 * (tonumber(SK.db and SK.db.mapPinScale) or 1)
        self:SetSize(size, size)
        self.Count:SetText(data.doors > 0 and data.doors or "")
        self:SetAlpha(1)
        self:ApplyFrameLevel()
    elseif data.kind == "zone" then
        -- Continent map: one faint marker per zone with its scroll total.
        self.Icon:SetTexture((SK.db and SK.db.untranslatedIcon) or ICON_SCROLL)
        self:SetSize(11, 11)
        self.Count:SetText(data.total)
        self:SetAlpha(0.6)
    else
        local total = data.mine + data.others
        local book = data.kind == "book"
        -- A book is one book however often it was found: no number on it.
        -- Kept small so they don't cover the map.
        local size = (book and 13 or math.min(16, 10 + total)) * (tonumber(SK.db and SK.db.mapPinScale) or 1)
        -- Scrolls look like the untranslated scroll in your bags.
        self.Icon:SetTexture(book and ICON_BOOK or (SK.db and SK.db.untranslatedIcon) or ICON_SCROLL)
        self:SetSize(size, size)
        self.Count:SetText((not book and total > 1) and total or "")
        -- Spots only others reported are a little faded; a book found away
        -- from every known book spot (it may have moved) is grey.
        -- Books you've handed in fade out: you don't need them anymore.
        self:SetAlpha(data.handed and 0.45 or (data.mine > 0 or data.listed) and 1 or 0.75)
        if self.Icon.SetDesaturated then self.Icon:SetDesaturated((data.stale or data.outdated or data.handed) and true or false) end
    end
end

-- One pin's lines. The first pin's title is the tooltip's title; the
-- others (pins under the mouse too) get a gap and a gold title.
local function AddPinLines(data, first)
    local function Title(text)
        if first then GameTooltip:SetText(text) else GameTooltip:AddLine(" ") GameTooltip:AddLine(text, 1, 0.82, 0) end
    end
    if data.kind == "library" then
        Title(data.name)
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
    elseif data.kind == "door" then
        Title(data.short)
        GameTooltip:AddLine(L["A door: resting in %s."]:format(data.place or "?"), 1, 1, 1, true)
        GameTooltip:AddLine(data.auto and L["Invites you by itself."] or L["Gets a pop-up to invite you."], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["Click to open Doorways on them."], 0.6, 0.6, 0.6)
    elseif data.kind == "inn" then
        Title(data.town)
        GameTooltip:AddLine(L["An inn: rest here to be a door, or come here with Liminal Passage."], 1, 1, 1, true)
        if data.doors > 0 then
            GameTooltip:AddLine(L["%d |4door:doors; open here right now."]:format(data.doors), 0.25, 1, 0.25)
        end
        GameTooltip:AddLine(L["Click to open Doorways on this town."], 0.6, 0.6, 0.6)
    elseif data.kind == "zone" then
        Title(data.name or L["Untranslated scrolls"])
        GameTooltip:AddLine(L["%d untranslated scrolls found here."]:format(data.total), 1, 1, 1)
        if data.tiers then
            local parts = {}
            for _, tier in ipairs(SK.TIERS) do
                if data.tiers[tier] then parts[#parts + 1] = L["Tier %d: %d"]:format(tier, data.tiers[tier]) end
            end
            if #parts > 0 then GameTooltip:AddLine(table.concat(parts, "   "), 0.4, 0.73, 1) end
        end
        GameTooltip:AddLine(L["Open the zone's map for the spots."], 0.6, 0.6, 0.6)
    elseif data.kind == "book" then
        Title(data.name or L["Book for the librarians."])
        GameTooltip:AddLine(L["A book for the librarians sits here."], 1, 1, 1)
        if data.handed then GameTooltip:AddLine(L["You've handed this one in."], 0.25, 1, 0.25) end
        -- Your other characters who handed it in.
        local by = SK.BookHandedBy and SK.BookHandedBy(data.listedName or data.name) or {}
        if #by > 0 and not (data.handed and #by == 1) then
            GameTooltip:AddLine(L["Handed in by: %s"]:format(table.concat(by, ", ")), 0.6, 0.85, 0.6, true)
        end
        if data.note then GameTooltip:AddLine(L[data.note], 1, 1, 1) end
        if data.mine > 0 then GameTooltip:AddLine(L["You found it here."], 0.25, 1, 0.25) end
        local found = data.mine + data.others
        if found > 1 then GameTooltip:AddLine(L["Found %d times."]:format(found), 0.7, 0.7, 0.7) end
        if data.outdated then
            GameTooltip:AddLine(L["Players find this book somewhere else more often: it has probably moved."], 0.6, 0.6, 0.6, true)
        end
        if data.movedHere then
            GameTooltip:AddLine(L["Players find it here more often than at its listed spot: it probably moved here."], 1, 0.82, 0, true)
        end
        if data.stale then
            GameTooltip:AddLine(L["Found by players, but not on the list of book spots: it may have moved."], 0.6, 0.6, 0.6, true)
        end
        GameTooltip:AddLine(L["Click for a waypoint."], 0.6, 0.6, 0.6)
    else
        Title(L["Untranslated scrolls"])
        if data.mine > 0 then GameTooltip:AddLine(L["You looted %d here."]:format(data.mine), 1, 1, 1) end
        if data.others > 0 then GameTooltip:AddLine(L["Others looted %d here."]:format(data.others), 0.7, 0.7, 0.7) end
        -- Which tiers: at these spots if anyone recorded it, else the zone's mix.
        local function TierText(tiers)
            local parts = {}
            for _, tier in ipairs(SK.TIERS) do
                if tiers[tier] then parts[#parts + 1] = L["Tier %d: %d"]:format(tier, tiers[tier]) end
            end
            return table.concat(parts, "   ")
        end
        local here = data.mapID and data.cells and SK.TiersAt and SK.TiersAt(data.mapID, data.cells)
        local zone = not here and data.mapID and SK.TiersInZone and SK.TiersInZone(data.mapID)
        if here then
            GameTooltip:AddLine(TierText(here), 0.4, 0.73, 1)
        elseif zone then
            GameTooltip:AddLine(L["In this zone:"] .. " " .. TierText(zone), 0.4, 0.73, 1, true)
        end
    end
    if data.spots then GameTooltip:AddLine(L["All around this circle (%d spots)."]:format(data.spots), 1, 0.82, 0) end
end

-- Other Scrollkeeper pins drawn over this one (their centers closer than
-- the two pins' half sizes), libraries first, then books, then scrolls.
local KIND_ORDER = { door = 0, inn = 1, library = 2, book = 3, drop = 4 }
local function StackedWith(pin)
    local list = {}
    local map = pin.GetMap and pin:GetMap()
    if not (map and map.EnumeratePinsByTemplate) then return list end
    local x, y = pin:GetCenter()
    local scale = pin:GetEffectiveScale()
    if not (x and scale) then return list end
    x, y = x * scale, y * scale
    local reach = pin:GetWidth() * scale / 2
    for other in map:EnumeratePinsByTemplate("ScrollkeeperMapPinTemplate") do
        if other ~= pin and other.data and other:IsShown() then
            local ox, oy = other:GetCenter()
            local oscale = other:GetEffectiveScale()
            if ox and oscale then
                local distance = math.sqrt((ox * oscale - x) ^ 2 + (oy * oscale - y) ^ 2)
                if distance <= reach + other:GetWidth() * oscale / 2 then list[#list + 1] = other.data end
            end
        end
    end
    table.sort(list, function(a, b) return (KIND_ORDER[a.kind] or 9) < (KIND_ORDER[b.kind] or 9) end)
    return list
end

function ScrollkeeperMapPinMixin:OnMouseEnter()
    local data = self.data
    if not data then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    AddPinLines(data, true)
    -- Pins stacked on this one: all in the same tooltip.
    local ok, stacked = pcall(StackedWith, self)
    for _, other in ipairs(ok and stacked or {}) do AddPinLines(other, false) end
    GameTooltip:AddLine(L["Scrollkeeper"], 0.41, 0.8, 0.94)
    GameTooltip:Show()
end

function ScrollkeeperMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

-- Click a library or a book: set a waypoint there (Zygor's or TomTom's
-- arrow if you have one, otherwise the game's own map pin).
local WAYPOINT_KINDS = { library = true, book = true }
function ScrollkeeperMapPinMixin:OnClick(button)
    local data = self.data
    if button ~= "LeftButton" or not data then return end
    if data.kind == "door" then
        if SK.ShowDoor then SK.ShowDoor(data.sender) end
        return
    end
    if data.kind == "inn" then
        if SK.ShowDoorTown then SK.ShowDoorTown(data.town) end
        return
    end
    if data.kind == "zone" then
        local map = self:GetMap()
        if map and map.SetMapID and data.mapID then map:SetMapID(data.mapID) end
        return
    end
    -- A library or book under a scroll pin still gets its waypoint.
    if not WAYPOINT_KINDS[data.kind] then
        local ok, stacked = pcall(StackedWith, self)
        data = nil
        for _, other in ipairs(ok and stacked or {}) do
            if WAYPOINT_KINDS[other.kind] then data = other break end
        end
        if not data then return end
    end
    local title = data.name or L["Book for the librarians."]
    if SK.SetWaypoint(self:GetMap():GetMapID(), data.x, data.y, title) then
        SK.Print(L["waypoint set: "] .. title)
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
    self.Fill:SetVertexColor(c[1], c[2], c[3], data.alpha or 0.22)
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

local provider, FilteredCells
local waitingBooks = {}

------------------------------------------------------------------------
-- Tier filter: which scroll spots the map shows.
--   SK.db.mapTiers = "all", "mine" (tiers you still level from) or a tier
------------------------------------------------------------------------

local FILTERS = { "all", "mine", 1, 15, 50, 175, "none" }

-- The tiers to show, as a set, or nil for all.
local function WantedTiers()
    local filter = SK.db and SK.db.mapTiers or "all"
    if filter == "all" then return nil end
    if filter == "none" then return {} end
    if type(filter) == "number" then return { [filter] = true } end
    -- "mine": tiers that still give you skill-ups (on a mage).
    if not SK.isMage then return nil end
    local skill = SK.GetComprehension()
    local wanted = {}
    for _, tier in ipairs(SK.TIERS) do
        local chance = SK.SkillUpChance(tier, skill.rank)
        if skill.effective >= tier and chance and chance.gives then wanted[tier] = true end
    end
    if not skill.known then wanted[1] = true end
    return wanted
end

-- Only the spots whose tiers are wanted. A spot without its own tiers goes
-- by its zone's mix.
FilteredCells = function(mapID, cells)
    local wanted = WantedTiers()
    if not wanted then return cells end
    local zone = SK.TiersInZone and SK.TiersInZone(mapID) or {}
    local kept = {}
    for cell, counts in pairs(cells) do
        local tiers = SK.TiersAt and SK.TiersAt(mapID, { cell }) or zone
        for tier in pairs(tiers) do
            if wanted[tier] then kept[cell] = counts break end
        end
    end
    return kept
end

local function FilterLabel()
    local filter = SK.db and SK.db.mapTiers or "all"
    if filter == "all" then return L["Scrolls: all"] end
    if filter == "mine" then return L["Scrolls: my tiers"] end
    if filter == "none" then return L["Scrolls: none"] end
    return L["Scrolls: tier %d"]:format(filter)
end

local filterButton
local function MakeFilterButton()
    if filterButton or type(WorldMapFrame) ~= "table" or not WorldMapFrame.GetFrameLevel then return end
    local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
    filterButton = CreateFrame("Button", "ScrollkeeperMapFilter", parent, "UIPanelButtonTemplate")
    filterButton:SetSize(118, 20)
    filterButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -6)
    filterButton:SetFrameLevel(parent:GetFrameLevel() + 20)
    if filterButton.GetFontString and filterButton:GetFontString() then filterButton:GetFontString():SetFontObject(GameFontHighlightSmall) end
    filterButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    filterButton:SetScript("OnClick", function(self, button)
        local now = SK.db.mapTiers or "all"
        local at = 1
        for i, value in ipairs(FILTERS) do if value == now then at = i end end
        at = button == "RightButton" and (at - 2) % #FILTERS + 1 or at % #FILTERS + 1
        SK.db.mapTiers = FILTERS[at]
        self:SetText(FilterLabel())
        if provider then provider:RefreshAllData() end
    end)
    filterButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(L["Scrollkeeper: which scroll spots to show"])
        GameTooltip:AddLine(L["Click: next. Right-click: back. My tiers = the ones you still get skill-ups from. None = no scroll spots, just doors and inns."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    filterButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Toggles next to it: open doors, and our inn pins (Doorways).
    local function Toggle(name, key, default, label, tip)
        local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        b:SetSize(64, 20)
        b:SetFrameLevel(parent:GetFrameLevel() + 20)
        if b.GetFontString and b:GetFontString() then b:GetFontString():SetFontObject(GameFontHighlightSmall) end
        b.Update = function(self)
            local on = SK.db[key]
            if on == nil then on = default end
            self:SetText((on and "|cff40ff40" or "|cff808080") .. label .. "|r")
            self:SetShown(SK.db.mapPins and SK.ModuleOn("Doors") and true or false)
        end
        b:SetScript("OnClick", function(self)
            local on = SK.db[key]
            if on == nil then on = default end
            SK.db[key] = not on
            self:Update()
            if provider then provider:RefreshAllData() end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
            GameTooltip:AddLine(label)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    filterButton.doors = Toggle("ScrollkeeperMapDoors", "mapDoors", true, L["Doors"],
        L["Scrollkeeper mages who are a door right now (Doorways). Click a door to open Doorways on them."])
    filterButton.doors:SetPoint("RIGHT", filterButton, "LEFT", -4, 0)
    filterButton.inns = Toggle("ScrollkeeperMapInns", "mapInns", true, L["Inns"],
        L["Our pin on each inn, with how many doors are open there; click one to open Doorways on that town. They sit on top of the game's own inn icons."])
    filterButton.inns:SetPoint("RIGHT", filterButton.doors, "LEFT", -4, 0)
end

local function UpdateFilterButton()
    if not filterButton then return end
    filterButton:SetText(FilterLabel())
    filterButton:SetShown(SK.db.mapPins and true or false)
    if filterButton.doors then filterButton.doors:Update() end
    if filterButton.inns then filterButton.inns:Update() end
end   -- book item IDs whose names the game is still loading

-- Is this one of the books on the list (Data/BookSpots.lua)? Its spot, or nil.
local listedNames
local function ListedName(name)
    if not listedNames then
        listedNames = {}
        for _, spot in ipairs(SK.BOOK_SPOTS or {}) do listedNames[spot.name:lower()] = spot end
    end
    return type(name) == "string" and listedNames[name:lower()] or nil
end

-- How often players found a book at (or right next to) its listed spot.
local function FoundAtListed(spot)
    local total = 0
    for cell, counts in pairs(SK.DropCells(spot.map, "books") or {}) do
        local x, y = SK.CellCenter(cell)
        if x and math.abs(x - spot.x / 100) <= 0.03 and math.abs(y - spot.y / 100) <= 0.03 then
            total = total + (counts.mine or 0) + (counts.others or 0)
        end
    end
    return total
end

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
                -- Its name from whichever spot of the group knows it.
                local name = nameFor and nameFor(best.cell)
                for _, spot in ipairs(group) do
                    if name then break end
                    name = nameFor and nameFor(spot.cell)
                end
                -- Next to a known book spot: it's that book (counted there).
                local known
                for _, listed in ipairs(self.listedBooks or {}) do
                    if x and math.abs(listed.x - x) <= 0.03 and math.abs(listed.y - y) <= 0.03 then known = listed break end
                end
                -- Named after a book on the list but far from its spot: that
                -- report is wrong (the book is where the list says), so skip
                -- it. Unless players found it here more often than at the
                -- listed spot: then the list is probably out of date.
                local listedSpot = not known and name and ListedName(name)
                local foundHereMore = listedSpot and (mine + others) > FoundAtListed(listedSpot)
                if known then
                    known.mine, known.others = known.mine + mine, known.others + others
                    known.foundName = known.foundName or name
                elseif x and (not listedSpot or foundHereMore) then
                    if foundHereMore then self.movedNames[listedSpot.name:lower()] = true end
                    map:AcquirePin(TEMPLATE, { kind = kind, x = x, y = y, mine = mine, others = others, name = name,
                        stale = SK.BOOK_SPOTS ~= nil and not foundHereMore, movedHere = foundHereMore or nil })
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
                            others = spot.counts.others, name = nameFor and nameFor(spot.cell),
                            mapID = self.mapID, cells = { spot.cell } })
                    end
                end
            else
                -- Heat: the more found here, the stronger the circle.
                local heat = 0.12 + math.min(0.33, (mine + others) / 40)
                map:AcquirePin(AREA_TEMPLATE, { x = cx, y = cy, size = radius * 2, color = color, alpha = heat })
                local groupCells = {}
                for _, spot in ipairs(group) do groupCells[#groupCells + 1] = spot.cell end
                map:AcquirePin(TEMPLATE, { kind = kind, x = cx, y = cy, mine = mine, others = others,
                    spots = #group, name = nameFor and nameFor(group[1].cell), mapID = self.mapID, cells = groupCells })
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
        self.mapID = mapID

        -- Continent (or world) map: one faint marker per zone instead.
        local info = C_Map and C_Map.GetMapInfo and SK.Try(C_Map.GetMapInfo, mapID)
        local mapType = type(info) == "table" and info.mapType
        if mapType and mapType <= 2 then
            self:DrawZones(mapID)
            return
        end

        self:DrawSpots(FilteredCells(mapID, SK.DropCells(mapID)), "drop", { 1, 0.82, 0 })
        -- Every known book spot in this zone (Data/BookSpots.lua). Player
        -- finds next to one are added to it.
        self.listedBooks, self.movedNames = {}, {}
        for _, spot in ipairs(SK.BOOK_SPOTS or {}) do
            if spot.map == mapID then
                self.listedBooks[#self.listedBooks + 1] = { kind = "book", listed = true, x = spot.x / 100, y = spot.y / 100,
                    name = spot.name, note = spot.note, mine = 0, others = 0 }
            end
        end
        self:DrawSpots(SK.DropCells(mapID, "books"), "book", { 1, 0.3, 0.3 }, function(cell)
            -- Which book: by its item ID (anyone's find, in your language),
            -- else the name you saw when you looted it.
            local itemID = SK.BookAt and SK.BookAt(mapID, cell)
            local name = itemID and C_Item and SK.Try(C_Item.GetItemNameByID, itemID)
            if itemID and not name and C_Item and C_Item.RequestLoadItemDataByID then
                waitingBooks[itemID] = true
                SK.Try(C_Item.RequestLoadItemDataByID, itemID)
            end
            return name or (SK.db.bookNames and SK.db.bookNames[mapID .. ":" .. cell])
        end)
        for _, book in ipairs(self.listedBooks) do
            -- A player's find names it in your language when it can.
            -- Players find this book somewhere else more often: our data
            -- beats the list, so its listed spot goes grey.
            book.outdated = self.movedNames[book.name:lower()] or nil
            book.handed = SK.BookHanded and SK.BookHanded(book.name) or nil
            book.listedName = book.name
            book.name = book.foundName or book.name
            self:GetMap():AcquirePin(TEMPLATE, book)
        end
        for _, library in ipairs(SK.LibraryPins(mapID)) do
            library.kind = "library"
            self:GetMap():AcquirePin(TEMPLATE, library)
        end
        -- Inns (Doorways): where to rest to be a door (setting mapInns).
        if SK.db.mapInns ~= false and SK.InnPins and SK.ModuleOn("Doors") then
            for _, inn in ipairs(SK.InnPins(mapID)) do
                inn.kind = "inn"
                self:GetMap():AcquirePin(TEMPLATE, inn)
            end
        end
        -- Open doors (Doorways): Scrollkeeper users resting here right now.
        for _, door in ipairs(SK.db.mapDoors ~= false and SK.OpenDoors and SK.OpenDoors() or {}) do
            if door.map == mapID and door.x and door.y then
                self:GetMap():AcquirePin(TEMPLATE, { kind = "door", x = door.x / 100, y = door.y / 100,
                    sender = door.sender, short = door.short, place = door.place, auto = door.auto })
            end
        end
    end

    -- A continent: each zone with scroll drops gets one small marker at
    -- its middle, with the total (nothing else, to keep it quiet).
    function provider:DrawZones(continentID)
        if not (C_Map and C_Map.GetMapRectOnMap) then return end
        for zoneID in pairs(SK.DropZones and SK.DropZones() or {}) do
            local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, zoneID, continentID)
            if ok and left and right and top and bottom and right > left then
                local total = 0
                for _, counts in pairs(SK.DropCells(zoneID) or {}) do
                    total = total + (counts.mine or 0) + (counts.others or 0)
                end
                if total > 0 and SK.db.mapTiers ~= "none" then
                    local zoneInfo = SK.Try(C_Map.GetMapInfo, zoneID)
                    self:GetMap():AcquirePin(TEMPLATE, { kind = "zone", x = (left + right) / 2, y = (top + bottom) / 2,
                        total = total, mapID = zoneID, name = type(zoneInfo) == "table" and zoneInfo.name or nil,
                        tiers = SK.TiersInZone and SK.TiersInZone(zoneID) })
                end
            end
        end
    end

    return provider
end

-- The world map is loaded only when first needed, so wait for it.
local function Attach()
    if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin) then return end
    SK.Safely("map pins", function()
        WorldMapFrame:AddDataProvider(CreateProvider())
        MakeFilterButton()
        UpdateFilterButton()
        if WorldMapFrame.HookScript then WorldMapFrame:HookScript("OnShow", UpdateFilterButton) end
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

-- A book's name finished loading: redraw so its pin says which book.
SK.On("GET_ITEM_INFO_RECEIVED", function(itemID)
    if not (itemID and waitingBooks[itemID]) then return end
    waitingBooks[itemID] = nil
    if provider and WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end)

-- Doors come and go: redraw while the map is open.
SK.Listen("DOORS_CHANGED", function()
    if provider and WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end)
