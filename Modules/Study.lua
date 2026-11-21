-- Scrollkeeper: Modules/Study.lua
-- Tracks the one-hour Study cooldown, and whether you are standing
-- somewhere Study works based on librarian world coordinates.

local _, SK = ...
local L = SK.L

-- How close to a librarian counts as "in the library", in yards.
-- (20 yards covers the library room.)
local YARD_THRESHOLD = 20

-- The two known libraries: the librarian's world position.
-- inst = instance (0 = Eastern Kingdoms). x and y are UnitPosition's
-- second and first values, in yards.
local KNOWN_LIBRARY_COORDS = {
    { inst = 0, x = 161.5, y = 1672.2, name = "Magic Quarter", side = "Horde", map = 1458,
      librarian = "Owen Thadd", city = "Undercity", firstBook = "Orgrimmar's Valley of Spirits",
      firstBookName = "The Lessons of Ta'zo", firstBookSpot = "38, 78" },
    { inst = 0, x = 868.5, y = -9004.5, name = "Wizard's Sanctum", side = "Alliance", map = 1453,
      librarian = "Garion Wendell", city = "Stormwind", firstBook = "Ironforge's Hall of Explorers",
      firstBookName = "Archmage Antonidas: The Unabridged Autobiography", firstBookSpot = "76, 10" },
}

-- Seconds until Study is ready. 0 means ready now.
function SK.StudySecondsLeft()
    local mage = SK.db and SK.MyMage and SK.MyMage()
    local readyAt = mage and mage.studyReadyAt or 0
    local left = readyAt - time()
    return left > 0 and left or 0
end

function SK.KnowsStudy()
    return C_SpellBook and SK.Try(C_SpellBook.IsSpellKnown, SK.SPELL_STUDY) or
        (IsPlayerSpell and SK.Try(IsPlayerSpell, SK.SPELL_STUDY)) or false
end

-- "42m", "3m 10s", "Ready"
function SK.FormatStudyTime(seconds)
    if seconds <= 0 then return L["Ready"] end
    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        if minutes >= 5 then return minutes .. "m" end
        return ("%dm %02ds"):format(minutes, seconds % 60)
    end
    return seconds .. "s"
end

-- The known libraries, for the map pins.
function SK.KnownLibraries()
    return KNOWN_LIBRARY_COORDS
end

-- Your faction's library (and its librarian).
function SK.MyLibrary()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local library = KNOWN_LIBRARY_COORDS[1]
    for _, entry in ipairs(KNOWN_LIBRARY_COORDS) do
        if entry.side == faction then library = entry end
    end
    return library
end

-- How to get Study, in one line: hand a library book to your librarian.
function SK.HowToLearnStudy()
    local library = SK.MyLibrary()
    return L["Learn Study: hand a library book to %s in %s (%s). One is always waiting in %s: %s (%s), click it to pick it up."]:format(
        L[library.librarian], L[library.city], L[library.name], L[library.firstBook], L[library.firstBookName], library.firstBookSpot)
end

-- A waypoint with an arrow: Zygor's if you have it, then TomTom's, else
-- the game's own map pin. x and y are 0 to 1. True if one was set.
function SK.SetWaypoint(mapID, x, y, title)
    if not (mapID and x and y) then return false end
    local zygor = _G.ZygorGuidesViewer
    local pointer = type(zygor) == "table" and type(zygor.Pointer) == "table" and zygor.Pointer
    if pointer and type(pointer.SetWaypoint) == "function" then
        local ok, way = pcall(pointer.SetWaypoint, pointer, mapID, x, y, {
            title = title, type = "manual", cleartype = true, onminimap = "always",
            overworld = true, showonedge = true, findpath = true,
        })
        if ok and way then return true end
    end
    if _G.TomTom and TomTom.AddWaypoint then
        local ok = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y, { title = title, from = "Scrollkeeper" })
        if ok then return true end
    end
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint then
        if C_Map.CanSetUserWaypointOnMap and not SK.Try(C_Map.CanSetUserWaypointOnMap, mapID) then return false end
        SK.Try(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
        if C_SuperTrack then SK.Try(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
        return true
    end
    return false
end

-- Not in a library? Open the world map on your faction's library and put
-- a waypoint on it (Zygor or TomTom if you have one, else the game's pin).
function SK.ShowLibraryOnMap()
    local library = SK.MyLibrary()
    local x, y = SK.WorldToMap(library.inst, library.x, library.y, library.map)
    if OpenWorldMap then
        SK.Try(OpenWorldMap, library.map)
    elseif WorldMapFrame then
        if ShowUIPanel then ShowUIPanel(WorldMapFrame) end
        if WorldMapFrame.SetMapID then SK.Try(WorldMapFrame.SetMapID, WorldMapFrame, library.map) end
    end
    if x and y then SK.SetWaypoint(library.map, x, y, L[library.name]) end
    if SK.KnowsStudy and not SK.KnowsStudy() then
        SK.Print(SK.HowToLearnStudy() .. " " .. L["It's on your map."])
    else
        SK.Print(L["Study works in a library. Yours is the %s: it's on your map."]:format(L[library.name]))
    end
end

-- Where the player is on the zone map: mapID, x, y (0 to 1), or nil.
-- Used for logging where scrolls drop.
function SK.PlayerMapPosition()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return nil end
    local x, y = position:GetXY()
    if not x or (x == 0 and y == 0) then return nil end
    return mapID, x, y
end

-- A world position (as stored above) on a given map: x, y (0 to 1), or
-- nil when it isn't on that map. Works for the city, zone and continent maps.
function SK.WorldToMap(inst, x, y, mapID)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    -- UnitPosition gives (y, x); the game's conversion wants them in that order.
    local ok, _, position = pcall(C_Map.GetMapPosFromWorldPos, inst, CreateVector2D(y, x), mapID)
    if not ok or not position then return nil end
    local mx, my = position:GetXY()
    if not mx or mx < 0 or mx > 1 or my < 0 or my > 1 then return nil end
    return mx, my
end

-- World position in yards: instanceID, x, y, or nil.
function SK.PlayerWorldPosition()
    if not UnitPosition then return nil end
    local y, x, _, instanceID = UnitPosition("player")
    if not x or not y or not instanceID then return nil end
    return instanceID, x, y
end

-- Helper to check if (inst, px, py) is within YARD_THRESHOLD of a target point
local function IsNearPoint(inst, px, py, target)
    if not target or target.inst ~= inst or not target.x or not target.y then
        return false
    end
    local dx = px - target.x
    local dy = py - target.y
    return math.sqrt(dx * dx + dy * dy) <= YARD_THRESHOLD
end

-- true if you are within range of a librarian or learned library coordinate.
function SK.InLibrary()
    local inst, px, py = SK.PlayerWorldPosition()
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local fallbackName = sub ~= "" and sub or (zone ~= "" and zone or "Unknown")

    if not inst then
        return false, fallbackName
    end

    -- 1. Check librarian coordinate list
    for _, loc in ipairs(KNOWN_LIBRARY_COORDS) do
        if IsNearPoint(inst, px, py, loc) then
            return true, loc.name or fallbackName
        end
    end

    -- 2. Check dynamically learned & saved library pins
    if SK.db and SK.db.libraryPins then
        for _, pin in pairs(SK.db.libraryPins) do
            if IsNearPoint(inst, px, py, pin) then
                return true, pin.name or fallbackName
            end
        end
    end

    return false, fallbackName
end

-- Single unified event handler for successful spellcasts
SK.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or spellID ~= SK.SPELL_STUDY then return end

    -- 1. Handle Cooldown
    local mage = SK.MyMage()
    if mage then mage.studyReadyAt = time() + SK.STUDY_COOLDOWN_SECONDS end
    SK.Send("STUDY_CHANGED")

    -- 2. Save coordinates if this spot isn't already known or learned
    local inst, x, y = SK.PlayerWorldPosition()
    if not inst then return end

    SK.db.libraryPins = SK.db.libraryPins or {}

    local alreadyKnown = false
    for _, loc in ipairs(KNOWN_LIBRARY_COORDS) do
        if IsNearPoint(inst, x, y, loc) then
            alreadyKnown = true
            break
        end
    end

    if not alreadyKnown then
        for _, pin in pairs(SK.db.libraryPins) do
            if IsNearPoint(inst, x, y, pin) then
                alreadyKnown = true
                break
            end
        end
    end

    if not alreadyKnown then
        local sub = GetSubZoneText and GetSubZoneText() or ""
        local zone = GetRealZoneText and GetRealZoneText() or "Library"
        local placeName = sub ~= "" and sub or zone
        local key = ("%d_%.1f_%.1f"):format(inst, x, y)

        SK.db.libraryPins[key] = {
            inst = inst,
            x = x,
            y = y,
            name = placeName,
        }
        SK.Print(L["Learned new library spot: "] .. placeName)
        SK.Send("MY_DATA_CHANGED")
    end

    SK.Send("PLACE_CHANGED")
end)

-- Poll movement every 0.5s so the UI updates when walking into/out of library coordinates
local lastInLibrary, lastPlaceName
local function CheckPositionChange()
    local inLib, placeName = SK.InLibrary()
    if inLib ~= lastInLibrary or placeName ~= lastPlaceName then
        lastInLibrary = inLib
        lastPlaceName = placeName
        SK.Send("PLACE_CHANGED")
    end
end

local pollFrame = CreateFrame("Frame")
local elapsedTotal = 0
pollFrame:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal >= 0.5 then
        elapsedTotal = 0
        CheckPositionChange()
    end
end)

SK.On("ZONE_CHANGED", CheckPositionChange)
SK.On("ZONE_CHANGED_INDOORS", CheckPositionChange)
SK.On("ZONE_CHANGED_NEW_AREA", CheckPositionChange)
