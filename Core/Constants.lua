-- Scrollkeeper: Core/Constants.lua
-- IDs read from the live game with /sk scan (build 1.60.1.70938).

local _, SK = ...

SK.SKILL_LINE_COMPREHENSION = 3012

SK.SPELL_COMPREHEND_SCROLL = 1296017   -- the spellbook spell: instant, 5 yard range, targets a scroll in your bags
SK.SPELL_COMPREHEND_CAST = 1309973     -- the 4 second cast it starts; when this finishes, the scroll is read
SK.SPELL_STUDY = 1302508               -- 6 second cast, needs a library, makes a Bundle of Scrolls

SK.ITEM_LIGHT_FEATHER = 17056          -- Study uses one

SK.STUDY_COOLDOWN_SECONDS = 3600

-- Item class 0 (Consumable), subclass 4 (Scrolls): every mage scroll uses this.
SK.ITEM_CLASS_CONSUMABLE = 0
SK.ITEM_SUBCLASS_SCROLL = 4

-- The skill cap goes up 5 points per character level (57/100 seen at level 20).
SK.SKILL_CAP_PER_LEVEL = 5
