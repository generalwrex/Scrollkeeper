-- Scrollkeeper by generalwrex. Created 2026-11-21.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: UI/Renew.lua
-- Two key bindings (Key Bindings > AddOns > Scrollkeeper):
--   "Imbue your weapon"   uses your best imbue scroll on your main-hand weapon
--   "Summon a familiar"   uses your best familiar scroll
-- They work in combat too: each clicks a hidden secure button that is
-- pointed at your best scroll whenever you're out of combat (the game
-- doesn't let addons change it during a fight).

local _, SK = ...
local L = SK.L

local IMBUE_BINDING = "CLICK ScrollkeeperImbueKey:LeftButton"
local FAMILIAR_BINDING = "CLICK ScrollkeeperFamiliarKey:LeftButton"
BINDING_HEADER_SCROLLKEEPER = "Scrollkeeper"
_G["BINDING_NAME_" .. IMBUE_BINDING] = L["Imbue your weapon (best imbue scroll)"]
_G["BINDING_NAME_" .. FAMILIAR_BINDING] = L["Summon a familiar (best familiar scroll)"]

local function MakeButton(name, kind)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    button:Hide()
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:HookScript("OnClick", function(self, _, down)
        if down then return end
        SK.Track("key." .. kind)
        if not self.itemID then
            SK.Print(kind == "imbue" and L["you have no imbue scroll."] or L["you have no familiar scroll."])
        end
    end)
    return button
end

local imbueButton = MakeButton("ScrollkeeperImbueKey", "imbue")
local familiarButton = MakeButton("ScrollkeeperFamiliarKey", "familiar")

-- Point both buttons at your best scrolls (out of combat only).
local function Point()
    if SK.InCombat() or not (SK.SetScrollUse and SK.BestScroll) then return end
    local imbue = SK.isMage and SK.BestScroll("imbues") or nil
    local familiar = SK.isMage and SK.BestScroll("familiars") or nil
    local imbueID = type(imbue) == "table" and tonumber(imbue.itemID) or nil
    local familiarID = type(familiar) == "table" and tonumber(familiar.itemID) or nil
    imbueButton.itemID, familiarButton.itemID = imbueID or false, familiarID or false
    SK.SetScrollUse(imbueButton, imbueID, true)
    SK.SetScrollUse(familiarButton, familiarID, false)
end
SK.PointRenewButtons = Point

-- The key bound to one of them, for messages ("press F"). nil if none.
function SK.RenewKey(kind)
    if not GetBindingKey then return nil end
    return GetBindingKey(kind == "imbue" and IMBUE_BINDING or FAMILIAR_BINDING)
end

SK.Listen("READY", function() SK.Safely("renew keys", Point) end)
SK.Listen("BAGS_CHANGED", function() SK.Safely("renew keys", Point) end)
SK.Listen("REMINDERS_CHANGED", function() SK.Safely("renew keys", Point) end)
SK.On("PLAYER_REGEN_ENABLED", function() SK.Safely("renew keys", Point) end)
