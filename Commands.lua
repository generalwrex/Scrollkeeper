-- Scrollkeeper: Commands.lua
-- /sk            show or hide the panel
-- /sk log        what your deciphers have produced
-- /sk tooltips   turn the tooltip lines on or off
-- /sk announce   turn the "deciphered: ..." chat line on or off
-- /sk reset      move the panel back to the middle of the screen
-- /sk options    open the settings page
-- /sk simple     simple panel: buttons, bars and your scrolls
-- /sk advanced   advanced panel: everything
-- /sk net        the Network window: other Scrollkeeper users and community odds
-- /sk demo       fill the Network window, map and tooltips with made-up players
-- /sk export     copy your scroll data to share (GitHub issue "Share your data")
-- /sk about      version and links
-- /sk bug        copy a bug report (GitHub issue "Bug report")
-- /sk scan       developer data dump (see Dev/Scan.lua)

local _, SK = ...

local function OnOff(value) return value and "on" or "off" end

local commands = {}

commands[""] = function()
    if SK.isMage then
        SK.TogglePanel()
    elseif #SK.MyOtherMages() > 0 then
        SK.ToggleAltPanel()
    else
        SK.Print("log in on a mage once, and this character will show your mages' skill and Study timers.")
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
    SK.db.scale = 1
    if ScrollkeeperPanel then
        ScrollkeeperPanel:ClearAllPoints()
        ScrollkeeperPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        ScrollkeeperPanel:SetScale(1)
    end
    SK.Print("panel moved to the middle of the screen.")
end

commands.options = function() SK.OpenOptions() end
commands.simple = function() SK.db.viewMode = "compact"; SK.ApplyPanelSettings() end
commands.advanced = function() SK.db.viewMode = "full"; SK.ApplyPanelSettings() end
commands.net = function() SK.ToggleNetwork() end
commands.network = commands.net
commands.demo = function() SK.ToggleDemo() end
commands.export = function() SK.ShowExport() end
commands.about = function()
    SK.Print(("version %s by generalwrex. Links are in Options > AddOns > Scrollkeeper > About."):format(SK.version))
    for _, link in ipairs(SK.LINKS or {}) do
        print(("  |cffffd100%s|r  %s"):format(link[1], link[2]))
    end
end
commands.bug = function() SK.ShowBugReport() end
commands.config = commands.options

commands.help = function()
    SK.Print("commands: /sk, /sk simple, /sk advanced, /sk net, /sk options, /sk log, /sk export, /sk bug, /sk about, /sk demo, /sk reset")
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
