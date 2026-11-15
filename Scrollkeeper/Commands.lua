-- Scrollkeeper: Commands.lua
-- /sk            show or hide the panel
-- /sk log        what your deciphers have produced
-- /sk tooltips   turn the tooltip lines on or off
-- /sk announce   turn the "deciphered: ..." chat line on or off
-- /sk reset      move the panel back to the middle of the screen
-- /sk scan       developer data dump (see Dev/Scan.lua)

local _, SK = ...

local function OnOff(value) return value and "on" or "off" end

local commands = {}

commands[""] = function()
    if SK.isMage then
        SK.TogglePanel()
    else
        SK.Print("the panel is for mages. On other classes Scrollkeeper adds tooltips to mage scrolls.")
    end
end

commands.log = function() SK.PrintLog() end

commands.tooltips = function()
    SK.db.showTooltips = not SK.db.showTooltips
    SK.Print("tooltip lines " .. OnOff(SK.db.showTooltips))
end

commands.announce = function()
    SK.db.announce = not SK.db.announce
    SK.Print("decipher messages " .. OnOff(SK.db.announce))
end

commands.reset = function()
    if SK.InCombat() then SK.Print("not in combat.") return end
    SK.db.panelPoint = nil
    if ScrollkeeperPanel then
        ScrollkeeperPanel:ClearAllPoints()
        ScrollkeeperPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    SK.Print("panel moved to the middle of the screen.")
end

commands.help = function()
    SK.Print("commands: /sk, /sk log, /sk tooltips, /sk announce, /sk reset")
end

-- Dev/Scan.lua adds commands.scan, commands.show and commands.clear.
SK.commands = commands

SLASH_SCROLLKEEPER1 = "/sk"
SLASH_SCROLLKEEPER2 = "/scrollkeeper"
SlashCmdList["SCROLLKEEPER"] = function(input)
    local word, rest = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local run = commands[word] or commands.help
    SK.Safely("/sk " .. word, run, rest)
end
