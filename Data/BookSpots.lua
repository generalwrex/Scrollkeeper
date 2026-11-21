-- Scrollkeeper: Data/BookSpots.lua
-- Where every book for the librarians sits in the world.
--
-- Source: Wowhead's "Collecting Library Books: Locations and Rewards"
-- guide for WoW Forever (updated 2026-11-13, after the books moved).
-- map = the zone's map ID, x and y = its /way coordinates (0 to 100).
-- Names are the books' English names.

local _, SK = ...

SK.BOOK_SPOTS = {
    { name = "Defensive Magics 101", map = 1416, x = 48.4, y = 57.6 },                       -- Alterac Mountains
    { name = "A Web of Lies: Debunking Myths and Legends", map = 1417, x = 73.6, y = 65.2 }, -- Arathi Highlands
    { name = "Everyday Etiquette", map = 1447, x = 20.7, y = 62.0 },                         -- Azshara
    { name = "Mummies: A Guide to the Unsavory Undead", map = 1418, x = 56.7, y = 39.9 },    -- Badlands
    { name = "Arcanic Systems Manual", map = 1413, x = 56.3, y = 8.8 },                      -- The Barrens
    { name = "Baxtan: On Destructive Magics", map = 1413, x = 62.7, y = 36.3 },              -- The Barrens
    { name = "Secrets of the Dreamers", map = 1413, x = 46.0, y = 36.5 },                    -- The Barrens
    { name = "Conjurer's Codex", map = 1419, x = 55.4, y = 32.2 },                           -- Blasted Lands
    { name = "Stonewrought Design", map = 1428, x = 29.0, y = 28.9 },                        -- Burning Steppes
    { name = "Magma or Lava?", map = 1428, x = 29.6, y = 28.2 },                             -- Burning Steppes
    { name = "Nar'thalas Almanac, Vol. 74", map = 1439, x = 59.6, y = 22.2 },                -- Darkshore
    { name = "Demons and You", map = 1443, x = 55.1, y = 26.2 },                             -- Desolace
    { name = "Crimes Against Anatomy", map = 1431, x = 16.6, y = 28.5 },                     -- Duskwood
    { name = "RwlRwlRwlRwl!", map = 1445, x = 57.2, y = 20.8 },                              -- Dustwallow Marsh
    { name = "A Study of the Light", map = 1423, x = 71.8, y = 48.2 },                       -- Eastern Plaguelands
    { name = "Scourge: Undead Menace or Misunderstood?", map = 1423, x = 31.3, y = 21.0 },   -- Eastern Plaguelands
    { name = "The Knight and the Lady", map = 1423, x = 47.3, y = 42.3 },                    -- Eastern Plaguelands
    { name = "Archmage Theocritus' Research Journal", map = 1429, x = 65.4, y = 70.1 },       -- Elwynn Forest
    { name = "Northern Kalimdor - A Comprehensive Guide", map = 1448, x = 65.2, y = 3.3,
      note = "inside Timbermaw Hold" },                                                      -- Felwood
    { name = "The Liminal and the Arcane", map = 1444, x = 50.6, y = 15.7 },                 -- Feralas
    { name = "Venomous Journeys", map = 1425, x = 36.0, y = 72.8 },                          -- The Hinterlands
    { name = "Archmage Antonidas: The Unabridged Autobiography", map = 1455, x = 75.7, y = 10.5 }, -- Ironforge
    { name = "Runes of the Sorcerer-Kings", map = 1432, x = 77.4, y = 14.0 },                -- Loch Modan
    { name = "The Lessons of Ta'zo", map = 1454, x = 38.7, y = 78.4 },                       -- Orgrimmar
    { name = "A Mind of Metal", map = 1427, x = 37.8, y = 49.3 },                            -- Searing Gorge
    { name = "Ataeric: On Arcane Curiosities", map = 1421, x = 43.4, y = 41.2 },             -- Silverpine Forest
    { name = "The Dalaran Digest, Vol. 23", map = 1421, x = 63.5, y = 63.1 },                -- Silverpine Forest
    { name = "Fury of the Land", map = 1442, x = 74.4, y = 85.7 },                           -- Stonetalon Mountains
    { name = "Basilisks: Should Petrification be Feared?", map = 1434, x = 41.4, y = 50.9 }, -- Stranglethorn Vale
    { name = "A Luddite's Guide to Caring for Your Demonic Pet", map = 1435, x = 61.4, y = 22.4 }, -- Swamp of Sorrows
    { name = "Sanguine Sorcery", map = 1435, x = 70.0, y = 51.0 },                           -- Swamp of Sorrows
    { name = "Legends of the Tidesages", map = 1446, x = 72.7, y = 47.8 },                   -- Tanaris
    { name = "Geomancy: The Stone-Cold Truth", map = 1441, x = 34.4, y = 40.1 },             -- Thousand Needles
    { name = "The Apothecary's Metaphysical Primer", map = 1420, x = 59.4, y = 52.3 },       -- Tirisfal Glades
    { name = "Necromancy 101", map = 1422, x = 69.4, y = 72.8 },                             -- Western Plaguelands
    { name = "Undead Potatoes", map = 1422, x = 38.3, y = 54.6 },                            -- Western Plaguelands
    { name = "Bewitchments and Glamours", map = 1436, x = 45.4, y = 70.5 },                  -- Westfall
    { name = "Rumi of Gnomeregan: The Collected Works", map = 1436, x = 52.7, y = 53.8 },    -- Westfall
    { name = "Goaz Scrolls", map = 1437, x = 33.6, y = 47.9 },                               -- Wetlands
    { name = "Ka-Boom!", map = 1452, x = 60.7, y = 37.7 },                                   -- Winterspring
}
