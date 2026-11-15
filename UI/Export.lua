-- Scrollkeeper: UI/Export.lua
-- Copyable text, for sharing outside the game:
--
--   /sk export   your scroll data: what your deciphers became, skill-ups
--                by color, where scrolls and books dropped, books learned,
--                library spots. No character or account names.
--   /sk bug      a bug report: versions, settings and the errors
--                Scrollkeeper caught.
--
-- Both open a window with the text selected: press Ctrl+C to copy, then
-- paste it into a GitHub issue (the issue forms say where).
--
-- Export format (one record per line, same fields as the network messages):
--   Scrollkeeper export 1
--   meta|version|client build|interface|class|level|skill|max|export id
--   T|tier|itemID:count,...          what deciphers of that tier became
--   U|tier|color:ups/tries,...       skill-ups by color at that tier
--   P|mapID|cell:count,...           untranslated scroll drops
--   K|mapID|cell:count,...           book drops
--   I|itemID,...                     items learned as books
--   N|itemID|name                    names of the item IDs above
--   W|instance|x|y|name              library spots (world position)
--   L|mapID|x|y|name                 library spots (older map position)
-- The export id is a random code made once per account, so the same
-- player's exports aren't counted twice. It says nothing about who you are.

local _, SK = ...

local window

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperExportFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperExportFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(460, 380)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    if window.SetDontSavePosition then window:SetDontSavePosition(true) end
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Scroll_03") end
    tinsert(UISpecialFrames, "ScrollkeeperExportFrame")   -- Escape closes it

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    window.hint = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.hint:SetPoint("TOPLEFT", 62, -32)
    window.hint:SetPoint("RIGHT", window, "RIGHT", -16, 0)
    window.hint:SetJustifyH("CENTER")

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -62)
    scroll:SetPoint("BOTTOMRIGHT", -36, 44)

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontSmall")
    box:SetWidth(400)
    box:SetScript("OnEscapePressed", function() window:Hide() end)
    -- Typing would only change the copy; put the real text back.
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput and window.text then
            self:SetText(window.text)
            self:HighlightText()
        end
    end)
    scroll:SetScrollChild(box)
    window.box = box

    window.note = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.note:SetPoint("BOTTOMLEFT", 18, 18)
    window.note:SetPoint("RIGHT", window, "RIGHT", -120, 0)
    window.note:SetJustifyH("LEFT")

    local select = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    select:SetSize(96, 22)
    select:SetPoint("BOTTOMRIGHT", -16, 14)
    select:SetText("Select all")
    select:SetScript("OnClick", function()
        box:SetFocus()
        box:HighlightText()
    end)
end

local function Show(title, hint, text, note)
    if not window then Build() end
    window:SetTitle(title)
    window.hint:SetText(hint)
    window.note:SetText(note or "")
    window.text = text
    window.box:SetText(text)
    window:Show()
    window.box:SetFocus()
    window.box:HighlightText()
end

------------------------------------------------------------------------
-- What goes in
------------------------------------------------------------------------

local function ExportID()
    if not SK.db.exportID then
        SK.db.exportID = ("%04x%04x"):format(math.random(0, 0xffff), math.random(0, 0xffff))
    end
    return SK.db.exportID
end

-- "k1:v1,k2:v2" from a table, sorted so exports are easy to compare.
local function Pairs(list)
    local keys = {}
    for key in pairs(list) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, key in ipairs(keys) do out[#out + 1] = key .. ":" .. list[key] end
    return table.concat(out, ",")
end

-- Names can't contain the separator.
local function Clean(text)
    return (tostring(text or ""):gsub("[|\n]", " "))
end

function SK.ExportText()
    local db = SK.db
    local lines = { "Scrollkeeper export 1" }
    local function Add(...) lines[#lines + 1] = table.concat({ ... }, "|") end

    local build, _, _, interface = GetBuildInfo()
    local _, class = UnitClass("player")
    local skill = SK.GetComprehension()
    Add("meta", SK.version, build or "?", interface or "?", class or "?", UnitLevel("player") or 0,
        skill.rank, skill.max, ExportID())

    local names = {}
    for tier, results in pairs(db.resultsByID or {}) do
        if next(results) then
            Add("T", tier, Pairs(results))
            for id in pairs(results) do names[id] = db.itemNames and db.itemNames[id] end
        end
    end

    local byTier = {}
    for key, seen in pairs(db.skillups or {}) do
        local tier, color = key:match("^(%d+) (%a+)$")
        if tier then
            byTier[tier] = byTier[tier] or {}
            byTier[tier][color] = seen.ups .. "/" .. seen.tries
        end
    end
    for tier, colors in pairs(byTier) do Add("U", tier, Pairs(colors)) end

    for mapID, cells in pairs(db.drops or {}) do
        if next(cells) then Add("P", mapID, Pairs(cells)) end
    end
    for mapID, cells in pairs(db.bookDrops or {}) do
        if next(cells) then Add("K", mapID, Pairs(cells)) end
    end

    local books = {}
    for id, name in pairs(db.bookIDs or {}) do
        books[#books + 1] = id
        if type(name) == "string" then names[id] = name end
    end
    table.sort(books)
    if #books > 0 then Add("I", table.concat(books, ",")) end

    for id, name in pairs(names) do
        if name then Add("N", id, Clean(name)) end
    end

    for _, pin in pairs(db.libraryPins or {}) do
        if pin.inst then
            Add("W", pin.inst, ("%.1f"):format(pin.x), ("%.1f"):format(pin.y), Clean(pin.name))
        elseif pin.mapID then
            Add("L", pin.mapID, ("%.3f"):format(pin.x), ("%.3f"):format(pin.y), Clean(pin.name))
        end
    end

    return table.concat(lines, "\n"), #lines - 2
end

function SK.BugReportText()
    local db = SK.db
    local lines = {}
    local function Line(label, value) lines[#lines + 1] = label .. ": " .. tostring(value) end

    local build, buildNumber, _, interface = GetBuildInfo()
    local _, class = UnitClass("player")
    local skill = SK.GetComprehension()
    lines[#lines + 1] = "Scrollkeeper bug report"
    Line("Scrollkeeper", SK.version)
    Line("Game", ("%s (%s), interface %s, %s"):format(build or "?", buildNumber or "?", interface or "?",
        GetLocale and GetLocale() or "?"))
    Line("Character", ("%s level %d, Comprehension %d/%d"):format(class or "?", UnitLevel("player") or 0,
        skill.rank, skill.max))
    Line("View", SK.ViewMode and SK.ViewMode() or "?")
    Line("Settings", ("panel %s, tooltips %s, sharing %s, channel %s, map pins %s, scale %s"):format(
        tostring(db.showPanel), tostring(db.showTooltips), tostring(db.share),
        tostring(db.shareChannel), tostring(db.mapPins), tostring(db.scale)))

    -- Other addons that are loaded (just a count and the names, to spot conflicts).
    local loaded = {}
    if C_AddOns and C_AddOns.GetNumAddOns then
        for i = 1, C_AddOns.GetNumAddOns() do
            local name = C_AddOns.GetAddOnInfo(i)
            if name and name ~= "Scrollkeeper" and C_AddOns.IsAddOnLoaded(i) then loaded[#loaded + 1] = name end
        end
    end
    Line("Other addons", #loaded > 0 and table.concat(loaded, ", ") or "none")

    lines[#lines + 1] = ""
    local errors = db.errors or {}
    if #errors == 0 then
        lines[#lines + 1] = "Errors: none caught"
    else
        lines[#lines + 1] = ("Errors (%d, newest last):"):format(#errors)
        for _, entry in ipairs(errors) do
            lines[#lines + 1] = ("[%s] %s: %s"):format(date("%Y-%m-%d %H:%M", entry.at or 0),
                tostring(entry.where), tostring(entry.error))
        end
    end
    return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------

function SK.ShowExport()
    local text, records = SK.ExportText()
    if records == 0 then
        SK.Print("nothing to export yet. Decipher some scrolls first.")
        return
    end
    Show("Scrollkeeper Export", "Ctrl+C to copy, then paste it in a GitHub issue", text,
        "Scroll data only. No character or account names.")
end

function SK.ShowBugReport()
    Show("Scrollkeeper Bug Report", "Ctrl+C to copy, then paste it in a GitHub issue", SK.BugReportText(),
        "Please also say what you were doing when it went wrong.")
end
