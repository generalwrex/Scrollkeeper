-- Scrollkeeper: Core/Locale.lua
-- Translations. Every piece of text the player sees goes through SK.L:
--
--   L["Study ready"]            -> the translation, or the English text
--   L["%d scrolls"]:format(n)   -> works the same with formats
--
-- English is the text itself, so there's no English file. Other languages
-- live in Locales\<locale>.lua and only fill in what they translate.
-- (Every language but English was drafted with AI and needs a native
-- speaker to check it. Fixes are very welcome on GitHub.)

local _, SK = ...

-- SK.L itself is created in Core/Init.lua (the first file), so it exists
-- even before this file loads.
SK.locale = SK.locale or (GetLocale and GetLocale()) or "enUS"

-- The languages you can pick in the settings ("auto" follows the game).
SK.LANGUAGES = {
    { "auto", "Auto (game language)" },
    { "enUS", "English" },
    { "deDE", "Deutsch" },
    { "esES", "Español" },
    { "frFR", "Français" },
}

-- Chinese only on Chinese game clients: the fonts other clients use have
-- no Chinese characters, so picking it there would show empty boxes.
if SK.locale == "zhCN" or SK.locale == "zhTW" then
    table.insert(SK.LANGUAGES, { "zhCN", "简体中文" })
    table.insert(SK.LANGUAGES, { "zhTW", "繁體中文" })
end

-- Fill SK.L with the chosen language. Called once your settings load;
-- changing the setting takes effect after a /reload.
function SK.ApplyLanguage()
    local choice = SK.db and SK.db.language or "auto"
    local code = choice ~= "auto" and choice or SK.locale
    if code == "esMX" then code = "esES" end
    SK.languageInUse = code
    local translation = SK.TRANSLATIONS and SK.TRANSLATIONS[code]
    if not translation then return end
    for key, value in pairs(translation) do
        if value ~= "" then rawset(SK.L, key, value) end
    end
end
