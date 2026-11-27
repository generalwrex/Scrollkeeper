-- Scrollkeeper by generalwrex. Created 2026-11-19.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: UI/Unlock.lua
-- Scroll of Khadgar's Unlocking on locked chests.
--
-- An addon can't open a chest by itself: the game wants a real key press
-- or click to use an item, and only you can pick which chest. So:
--   key binding   "Use Khadgar's Unlocking" (Key Bindings > AddOns >
--                 Scrollkeeper) uses the scroll; then click the chest.
--   tooltip       mouse over a locked chest and the tooltip says how many
--                 scrolls you have and which key to press.

local _, SK = ...
local L = SK.L

SK.KHADGARS_UNLOCKING = 277492
local BINDING = "CLICK ScrollkeeperUnlockButton:LeftButton"

-- Names in the Key Bindings window.
BINDING_HEADER_SCROLLKEEPER = "Scrollkeeper"
_G["BINDING_NAME_" .. BINDING] = L["Use Khadgar's Unlocking (then click the chest)"]

function SK.UnlockingCount()
    local count = SK.Try(C_Item and C_Item.GetItemCount, SK.KHADGARS_UNLOCKING) or SK.Try(GetItemCount, SK.KHADGARS_UNLOCKING)
    return tonumber(count) or 0
end

-- The hidden secure button the key binding clicks. Made at load, outside
-- combat, so the binding works from the first key press.
local button = CreateFrame("Button", "ScrollkeeperUnlockButton", UIParent, "SecureActionButtonTemplate")
button:Hide()
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type", "item")
button:SetAttribute("item", "item:" .. SK.KHADGARS_UNLOCKING)
-- Without the scroll the game would just say so; say it nicer.
button:HookScript("OnClick", function(_, _, down)
    if down then return end
    SK.Track("key.unlock")
    if SK.UnlockingCount() == 0 then SK.Print(L["you have no Scroll of Khadgar's Unlocking."]) end
end)

------------------------------------------------------------------------
-- The tooltip on locked chests
------------------------------------------------------------------------

-- The game's "Locked" line, in your language.
local function LockedWord()
    return type(LOCKED) == "string" and LOCKED or "Locked"
end

local function IsLockedObject(tooltip)
    -- Items and units have their own tooltips; this is for things in the world.
    if tooltip.GetItem and select(2, tooltip:GetItem()) then return false end
    if tooltip.GetUnit and select(2, tooltip:GetUnit()) then return false end
    local name = tooltip:GetName()
    local word = LockedWord()
    for i = 2, math.min(tooltip:NumLines() or 0, 6) do
        local line = _G[name .. "TextLeft" .. i]
        local text = line and SK.Known(line:GetText())
        if type(text) == "string" and (text == word or text:find(word, 1, true) == 1) then return true end
    end
    return false
end

local function AddHint(tooltip)
    if not (SK.isMage and SK.db and SK.db.showTooltips) or tooltip.scrollkeeperUnlock then return end
    local count = SK.UnlockingCount()
    if count == 0 or not IsLockedObject(tooltip) then return end
    tooltip.scrollkeeperUnlock = true
    local key = GetBindingKey and GetBindingKey(BINDING)
    tooltip:AddLine(L["Scrollkeeper: %d Scroll of Khadgar's Unlocking"]:format(count), 0.41, 0.8, 0.94)
    if key then
        tooltip:AddLine(L["Press %s, then click the chest."]:format(GetBindingText and GetBindingText(key) or key), 1, 1, 1)
    else
        tooltip:AddLine(L["Set a key for it in Key Bindings > AddOns > Scrollkeeper, or click the scroll in the panel, then click the chest."], 1, 1, 1, true)
    end
    tooltip:Show()
end

SK.UnlockHint = AddHint   -- for the test harness

if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnShow", function(self)
        SK.Quietly("unlock tooltip", AddHint, self)
        -- World object tooltips can fill in a moment after showing: look once more.
        C_Timer.After(0.1, function()
            if self:IsShown() and not self.scrollkeeperUnlock then SK.Quietly("unlock tooltip", AddHint, self) end
        end)
    end)
    GameTooltip:HookScript("OnHide", function(self) self.scrollkeeperUnlock = nil end)
end
