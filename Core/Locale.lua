-- Scrollkeeper: Core/Locale.lua
-- Translations. Every piece of text the player sees goes through SK.L:
--
--   L["Study ready"]            -> the translation, or the English text
--   L["%d scrolls"]:format(n)   -> works the same with formats
--
-- English is the text itself, so there's no English file. Other languages
-- live in Locales\<locale>.lua and only fill in what they translate.
-- (The Spanish, French and German files were drafted with AI and need a
-- native speaker to check them. Fixes are very welcome on GitHub.)

local _, SK = ...

-- SK.L itself is created in Core/Init.lua (the first file), so it exists
-- even before this file loads.
SK.locale = SK.locale or (GetLocale and GetLocale()) or "enUS"
