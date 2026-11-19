-- Scrollkeeper: Commands.lua
-- /sk            show or hide the panel
-- /sk log        the Luck Log window: what your deciphers have produced
-- /sk logchat    the same, printed in chat
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
local L = SK.L

local function OnOff(value) return value and L["on"] or L["off"] end

local commands = {}

commands[""] = function()
    if SK.isMage then
        SK.TogglePanel()
    elseif #SK.MyOtherMages() > 0 then
        SK.ToggleAltPanel()
    else
        SK.Print(L["log in on a mage once, and this character will show your mages' skill and Study timers."])
    end
end

commands.log = function() SK.ToggleLog() end
commands.logchat = function() SK.PrintLog() end

commands.tooltips = function()
    SK.db.showTooltips = not SK.db.showTooltips
    SK.Print(L["tooltip lines "] .. OnOff(SK.db.showTooltips))
end

commands.announce = function()
    SK.db.announce = not SK.db.announce
    SK.Print(L["decipher messages "] .. OnOff(SK.db.announce))
end

commands.reset = function()
    if SK.InCombat() then SK.Print(L["not in combat."]) return end
    SK.db.panelPoint = nil
    SK.db.scale = 1
    if ScrollkeeperPanel then
        ScrollkeeperPanel:ClearAllPoints()
        ScrollkeeperPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        ScrollkeeperPanel:SetScale(1)
    end
    SK.Print(L["panel moved to the middle of the screen."])
    -- The scroll icon too, if it's in use (it can get lost off screen).
    if SK.db.scrollIcon and SK.ResetIconPosition then SK.ResetIconPosition() end
end

commands.options = function() SK.OpenOptions() end
commands.simple = function() SK.db.viewMode = "compact"; SK.ApplyPanelSettings() end
commands.advanced = function() SK.db.viewMode = "full"; SK.ApplyPanelSettings() end
commands.net = function() SK.ToggleNetwork() end
commands.network = commands.net
commands.demo = function() SK.ToggleDemo() end
commands.export = function() SK.ShowExport() end
-- /sk mail: who could use your spare scrolls (same list as the mailbox).
commands.mail = function()
    local plan = SK.MailPlan and SK.MailPlan() or {}
    local spare = #(SK.bags.untranslated or {})
    if #plan == 0 then
        SK.Print(L["mail list is empty. You're carrying %d untranslated |4scroll:scrolls;; "]:format(spare)
            .. L["nobody known (your other mages, or Scrollkeeper users online) can use the spare ones."])
        return
    end
    SK.Print(L["who could use your scrolls:"])
    for _, person in ipairs(plan) do
        print(L["  %s (%s): %d skill-up, %d they can read, %d for later"]:format(person.name, person.kind,
            person.ups, person.reads, person.later or 0))
    end
end
commands.swap = function() SK.ToggleSwap() end
commands.setup = function() SK.ShowSetup() end
commands.scan = function() SK.ScanAuctionScrolls() end
commands.plan = function() SK.TogglePlan() end
commands.about = function()
    SK.Print(L["version %s by generalwrex. Links are in Options > AddOns > Scrollkeeper > About."]:format(SK.version))
    print("  " .. L["In game: %s (PvE). Say hi!"]:format(SK.AUTHOR_CHARACTER or "Archmage Naage"))
    for _, link in ipairs(SK.LINKS or {}) do
        print(("  |cffffd100%s|r  %s"):format(link[1], link[2]))
    end
end
commands.bug = function() SK.ShowBugReport() end
commands.backup = function() SK.ShowBackup() end
commands.restore = function() SK.ShowRestore() end
commands.config = commands.options

commands.help = function()
    SK.Print(L["commands: /sk, /sk simple, /sk advanced, /sk net, /sk options, /sk log, /sk export, /sk bug, /sk mail, /sk swap, /sk scan, /sk plan, /sk setup, /sk about, /sk demo, /sk reset"])
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
