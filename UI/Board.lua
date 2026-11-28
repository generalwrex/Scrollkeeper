-- Scrollkeeper by generalwrex. Created 2026-11-26.
-- Read the LICENSE file before using any of this code.
-- Scrollkeeper: UI/Board.lua
-- The Fellow Mages board window (/sk board): categories on the left, the
-- posts in the middle, the picked post with its replies on the right.
-- Network/Board.lua keeps the posts and talks to other players.

local _, SK = ...
local L = SK.L

local WIDTH, HEIGHT = 780, 520
local CAT_W, LIST_W, DETAIL_W = 150, 290, 300
local LIST_ROWS = 8         -- three-line rows (title, who, reactions)
local TOP = -62

local window
local picked = { cat = nil, post = nil }   -- category key (nil = all), post id
local state = {}   -- readBefore, mineCount, current post, ticker
local selectTex = setmetatable({}, { __mode = "k" })

local function Now() return (GetServerTime and GetServerTime()) or time() end

-- "40m", "3h", "2d"
local function Ago(at)
    local s = math.max(0, Now() - (at or 0))
    if s < 3600 then return L["%dm"]:format(math.max(1, math.floor(s / 60))) end
    if s < 86400 then return L["%dh"]:format(math.floor(s / 3600)) end
    return L["%dd"]:format(math.floor(s / 86400))
end

-- "Horde" / "Alliance", in the game's language.
local function MyFactionName()
    local _, name = UnitFactionGroup and UnitFactionGroup("player")
    return name or ""
end

local MAGE = "|cff69ccf0"
-- short: just the name (and [dev]), for the post list; tier and ruleset
-- are on its tooltip.
-- Online now: heard from them (Fellow Mages) in the last 10 minutes.
local function IsOnline(guid)
    if not guid or guid == "" then return false end
    if SK.BoardIsMine and SK.BoardIsMine({ guid = guid }) then return true end
    for _, peer in pairs(SK.peers or {}) do
        if peer.guid == guid and not peer.demo and time() - (peer.seen or 0) < 600 and not peer.offline then return true end
    end
    return false
end
SK.BoardAuthorOnline = IsOnline

local function AuthorText(p, short)
    local name = p.author ~= "" and p.author or L["a Fellow Mage"]
    if SK.db.boardShowOnline ~= false and IsOnline(p.guid) then name = "|TInterface\\FriendsFrame\\StatusIcon-Online:12:12|t" .. name end
    local dev = p.team or SK.BoardIsDev(p.guid)
    -- Their class color (any class can post: alts use the board too).
    local classColor = p.class and SK.db.boardClassColors ~= false and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
    local color = dev and "|cffff7aa8" or (classColor and ("|c" .. (classColor.colorStr or "ffffffff"))) or MAGE
    local parts = { color .. name .. "|r" }
    if dev then parts[#parts + 1] = "|cffff7aa8" .. L["[dev]"] .. "|r" end
    if short then return table.concat(parts, " ") end
    if (p.tier or 0) > 0 then parts[#parts + 1] = "|cffaaaaaa[" .. p.tier .. "]|r" end
    -- Their ruleset, always: gold when it isn't yours, gray when it is.
    local mine = SK.ServerKind and SK.ServerKind()
    if p.ruleset and p.ruleset ~= "" then
        parts[#parts + 1] = (p.ruleset ~= mine and "|cffffd27a" or "|cff9a9a9a") .. "[" .. p.ruleset .. "]|r"
    end
    return table.concat(parts, " ")
end

local function Button(parent, text, width, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    if b.GetFontString and b:GetFontString() then b:GetFontString():SetFontObject("GameFontNormalSmall") end
    b:SetScript("OnClick", onClick)
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(text)
            GameTooltip:AddLine(type(tip) == "function" and tip() or tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

local function Box(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if box.SetBackdrop then
        box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        box:SetBackdropColor(0, 0, 0, 0.6)
        box:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    end
    SK.UI.SkinBox(box, "box")
    return box
end

------------------------------------------------------------------------
-- Writing a post
------------------------------------------------------------------------

local function BuildCompose()
    local c = CreateFrame("Frame", nil, window, "BackdropTemplate")
    c:SetSize(420, 262)
    c:SetPoint("CENTER", 0, -10)
    c:SetFrameLevel(window:GetFrameLevel() + 20)
    c:EnableMouse(true)
    if c.SetBackdrop then
        c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        c:SetBackdropColor(0.05, 0.05, 0.06, 0.98)
    end
    SK.UI.SkinBox(c, "accent")

    local heading = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 18, -16)
    heading:SetText(L["New post"])

    -- Category buttons, in rows (the dev team can add categories, so
    -- they're laid out again each time).
    c.cats = {}

    local titleLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleLabel:SetPoint("TOPLEFT", 18, -98)
    c.titleLabel = titleLabel
    titleLabel:SetText(L["Title"])
    c.title = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
    c.title:SetSize(330, 20)
    c.title:SetPoint("LEFT", titleLabel, "RIGHT", 12, 0)
    c.title:SetAutoFocus(false)
    c.title:SetMaxBytes(41)
    if SK.UI_LinkTarget then SK.UI_LinkTarget(c.title) end
    c.title:SetScript("OnTextChanged", function() c:Refresh() end)
    c.title:SetScript("OnEscapePressed", function() c:Hide() end)

    local bodyBox = Box(c)
    bodyBox:SetPoint("TOPLEFT", 16, -122)
    bodyBox:SetSize(388, 76)
    c.bodyBox = bodyBox
    c.body = CreateFrame("EditBox", nil, bodyBox)
    c.body:SetPoint("TOPLEFT", 8, -6)
    c.body:SetPoint("BOTTOMRIGHT", -8, 6)
    c.body:SetMultiLine(true)
    c.body:SetAutoFocus(false)
    c.body:SetFontObject("ChatFontNormal")
    if SK.UI_LinkTarget then SK.UI_LinkTarget(c.body) end
    c.body:SetScript("OnTextChanged", function() c:Refresh() end)
    c.body:SetScript("OnEscapePressed", function() c:Hide() end)
    bodyBox:EnableMouse(true)
    bodyBox:SetScript("OnMouseDown", function() c.body:SetFocus() end)

    c.left = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.left:SetPoint("TOPRIGHT", bodyBox, "BOTTOMRIGHT", -4, -4)

    c.note = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.note:SetPoint("TOPLEFT", bodyBox, "BOTTOMLEFT", 26, -4)
    c.emoji = SK.EmojiButton(c, c.body)
    c.emoji:SetPoint("TOPLEFT", bodyBox, "BOTTOMLEFT", 2, -2)
    -- Wanted / spare posts: write it from your bags.
    c.fromBags = Button(c, L["From my bags"], 96, function()
        local text = state.FromBags and state.FromBags(c.cat)
        if text and text ~= "" then c.body:SetText(text); c:Refresh() end
    end, L["Write which scroll tiers you need (Scrolls wanted) or have spare (Spare scrolls), from your bags."])
    c.fromBags:SetPoint("BOTTOMRIGHT", bodyBox, "TOPRIGHT", 0, 4)
    c.note:SetPoint("RIGHT", c.left, "LEFT", -8, 0)
    c.note:SetJustifyH("LEFT")

    c.post = Button(c, L["Post"], 90, function()
        local p, why
        if c.editing then
            p, why = SK.BoardEdit(c.editing.id, c.title:GetText(), c.body:GetText())
        else
            p, why = SK.BoardPost(c.cat, c.title:GetText(), c.body:GetText())
        end
        if not p then c.error = why; c:Refresh() return end
        if not c.editing then picked.cat = nil end
        picked.post = p.id
        c:Hide()
        SK.RefreshBoard()
    end)
    c.post:SetPoint("BOTTOMRIGHT", -16, 16)
    local cancel = Button(c, CANCEL or L["Cancel"], 80, function() c:Hide() end)
    cancel:SetPoint("RIGHT", c.post, "LEFT", -6, 0)

    function c:LayoutCats()
        local x, y, n = 18, -38, 0
        for _, b in ipairs(self.cats) do b:Hide() end
        for _, cat in ipairs(SK.BOARD_CATEGORIES) do
            -- Editing: the category stays what it was.
            local allowed = self.editing and cat.key == self.cat or (not self.editing and SK.BoardCanPostIn(cat.key))
            if allowed then
                n = n + 1
                local b = self.cats[n]
                if not b then
                    b = Button(self, "", 0, function(btn) self.cat = btn.key; self:Refresh() end)
                    b:SetScript("OnClick", function(btn) self.cat = btn.key; self:Refresh() end)
                    self.cats[n] = b
                end
                b.key = cat.key
                b:SetText(L[cat.name])
                local width = math.max(70, ((b:GetFontString() and b:GetFontString():GetStringWidth()) or 60) + 20)
                b:SetWidth(width)
                if x + width > 400 then x, y = 18, y - 26 end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", x, y)
                x = x + width + 4
                b:Show()
            end
        end
        -- More than two rows: push the rest down.
        local extra = math.max(0, (-38 - y) - 26)
        self.titleLabel:SetPoint("TOPLEFT", 18, -98 - extra)
        self.bodyBox:SetPoint("TOPLEFT", 16, -122 - extra)
        self:SetHeight(262 + extra)
    end

    function c:Refresh()
        self:LayoutCats()
        for _, b in ipairs(self.cats) do
            if b.key == self.cat then b:LockHighlight() else b:UnlockHighlight() end
        end
        local cat = SK.BoardCategory(self.cat)
        local room = SK.BoardRoom(self.title:GetText()) - #(self.body:GetText() or "")
        self.left:SetText(room >= 0 and L["%d left"]:format(room) or ("|cffff6666" .. L["%d too long"]:format(-room) .. "|r"))
        if self.error then
            self.note:SetText("|cffff6666" .. self.error .. "|r")
        elseif cat and cat.mine then
            self.note:SetText(L["Only %s mages on your ruleset see this."]:format(MyFactionName()))
        else
            self.note:SetText(L["%s mages on every ruleset can see this."]:format(MyFactionName()))
        end
        self.fromBags:SetShown((self.cat == "wanted" or self.cat == "spare") and SK.isMage and true or false)
        local ready = cat and room >= 0 and (self.title:GetText() or "") ~= "" and (self.body:GetText() or "") ~= ""
        self.post:SetEnabled(ready and true or false)
    end

    c:HookScript("OnHide", function() SK.UI_CloseMenus() end)
    c:SetScript("OnShow", function(self)
        self.error = nil
        local e = state.editPost
        state.editPost = nil
        self.editing = e
        heading:SetText(e and L["Edit your post"] or L["New post"])
        self.post:SetText(e and L["Save"] or L["Post"])
        self.title:SetText(e and e.title or "")
        self.body:SetText(e and e.body or "")
        local start = e and e.cat or picked.cat
        if not e and not (start and SK.BoardCanPostIn(start)) then start = "general" end
        self.cat = start
        self:Refresh()
        self.title:SetFocus()
    end)
    c:Hide()
    return c
end

------------------------------------------------------------------------
-- Filters and sorting (SK.db.boardFilter: show = { key = true }, age, sort)
------------------------------------------------------------------------

local SHOW = {
    { "new", "New since I last looked" },
    { "unanswered", "No replies yet" },
    { "answered", "Has replies" },
    { "dev", "From the dev team" },
    { "mine", "On my ruleset only" },
}
local AGES = { { 0, "Any time" }, { 1, "Last day" }, { 3, "Last 3 days" } }
local SORTS = {
    { "new", "Newest post first" },
    { "active", "Latest reply first" },
    { "replies", "Most replies first" },
}

local function Filter()
    SK.db.boardFilter = type(SK.db.boardFilter) == "table" and SK.db.boardFilter or {}
    local f = SK.db.boardFilter
    f.show = type(f.show) == "table" and f.show or {}
    f.age = tonumber(f.age) or 0
    f.sort = f.sort or "new"
    return f
end

-- How many filters are on (for the button's label).
local function FiltersOn()
    local f, n = Filter(), 0
    for _, on in pairs(f.show) do if on then n = n + 1 end end
    if f.age > 0 then n = n + 1 end
    return n
end

local function ApplyFilter(posts, replies)
    local f = Filter()
    local now, mine = Now(), SK.ServerKind and SK.ServerKind()
    local out = {}
    for _, p in ipairs(posts) do
        local list = replies[p.id]
        local n = list and #list or 0
        local last = (list and list[#list] and list[#list].at) or p.at
        local ok = not (SK.db.boardHideDone and SK.BoardIsDone(p) and not SK.BoardIsMine(p))
        if f.show.new and not ((last or 0) > (state.readBefore or 0) and not SK.BoardIsMine(p)) then ok = false end
        if f.show.unanswered and n > 0 then ok = false end
        if f.show.answered and n == 0 then ok = false end
        if f.show.dev and not (p.team or SK.BoardIsDev(p.guid)) then ok = false end
        if f.show.mine and mine and p.ruleset ~= "" and p.ruleset ~= mine then ok = false end
        if f.age > 0 and (now - (p.at or 0)) > f.age * 86400 then ok = false end
        if ok then
            p.lastActivity, p.replyCount = last, n
            out[#out + 1] = p
        end
    end
    table.sort(out, function(a, b)
        -- Team notices stay on top (setting "Pin notices"), then your pick.
        -- Pinned by the team first, then notices (setting "Pin notices").
        local ap, bp = SK.BoardIsPinned(a), SK.BoardIsPinned(b)
        if ap ~= bp then return ap end
        if SK.db.boardStickyNotices ~= false then
            local an, bn = a.cat == "notice", b.cat == "notice"
            if an ~= bn then return an end
        end
        -- Done posts sink to the bottom.
        local ad, bd = SK.BoardIsDone(a), SK.BoardIsDone(b)
        if ad ~= bd then return bd end
        if f.sort == "active" and a.lastActivity ~= b.lastActivity then return a.lastActivity > b.lastActivity end
        if f.sort == "replies" and a.replyCount ~= b.replyCount then return a.replyCount > b.replyCount end
        if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
        return (a.id or "") > (b.id or "")
    end)
    return out
end

local function BuildFilterMenu()
    local m = CreateFrame("Frame", nil, window, "BackdropTemplate")
    m:SetSize(210, 20 + (#SHOW + #AGES + #SORTS) * 20 + 3 * 20 + 30)
    m:SetFrameLevel(window:GetFrameLevel() + 30)
    m:EnableMouse(true)
    if m.SetBackdrop then
        m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        m:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
        m:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    end
    SK.UI.SkinBox(m, "accent")
    m.checks = {}
    local y = -10
    local function Title(text)
        local fs = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 12, y)
        fs:SetText(text)
        y = y - 18
    end
    local function Option(label, get, set)
        local c = CreateFrame("CheckButton", nil, m, "UICheckButtonTemplate")
        c:SetSize(20, 20)
        c:SetPoint("TOPLEFT", 10, y)
        local text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", c, "RIGHT", 2, 0)
        text:SetText(label)
        c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); m:Refresh(); SK.RefreshBoard() end)
        c.get = get
        m.checks[#m.checks + 1] = c
        y = y - 20
    end
    Title(L["Show"])
    for _, o in ipairs(SHOW) do
        Option(L[o[2]], function() return Filter().show[o[1]] end, function(on)
            local f = Filter()
            f.show[o[1]] = on or nil
            -- "No replies" and "Has replies" can't both be on.
            if on and o[1] == "unanswered" then f.show.answered = nil end
            if on and o[1] == "answered" then f.show.unanswered = nil end
        end)
    end
    y = y - 4
    Title(L["Posted"])
    for _, a in ipairs(AGES) do
        Option(L[a[2]], function() return Filter().age == a[1] end, function() Filter().age = a[1] end)
    end
    y = y - 4
    Title(L["Order"])
    for _, o in ipairs(SORTS) do
        Option(L[o[2]], function() return Filter().sort == o[1] end, function() Filter().sort = o[1] end)
    end
    local clear = Button(m, L["Clear filters"], 100, function()
        local f = Filter()
        f.show, f.age, f.sort = {}, 0, "new"
        m:Refresh()
        SK.RefreshBoard()
    end)
    clear:SetPoint("BOTTOMLEFT", 10, 10)
    local close = Button(m, CLOSE or L["Close"], 70, function() m:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -10, 10)
    function m:Refresh()
        for _, c in ipairs(self.checks) do c:SetChecked(c.get() and true or false) end
    end
    m:SetScript("OnShow", m.Refresh)
    m:Hide()
    return m
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

------------------------------------------------------------------------
-- The category list on the left. The dev team can add, rename and take
-- away categories (signed, like pins), so it's laid out again whenever
-- they change.
------------------------------------------------------------------------

-- (Newer game dialogs call their text box EditBox, older ones editBox.)
local function PopupBox(self) return self.editBox or self.EditBox end

if StaticPopupDialogs then
    StaticPopupDialogs["SCROLLKEEPER_BOARD_NEWCAT"] = {
        text = L["New board category (everyone sees it). Name:"],
        button1 = L["All rulesets"], button2 = L["My ruleset only"], button3 = CANCEL or L["Cancel"],
        hasEditBox = true, maxLetters = 24, timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(self)
            local ok, why = SK.BoardAddCategory(PopupBox(self):GetText(), false)
            if not ok and why then SK.Print(why) end
        end,
        OnCancel = function(self, _, reason)
            if reason ~= "clicked" then return end
            local ok, why = SK.BoardAddCategory(PopupBox(self):GetText(), true)
            if not ok and why then SK.Print(why) end
        end,
        EditBoxOnEnterPressed = function(self)
            local ok, why = SK.BoardAddCategory(self:GetText(), false)
            if not ok and why then SK.Print(why) end
            self:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    }
    StaticPopupDialogs["SCROLLKEEPER_BOARD_EDITCAT"] = {
        text = L["Board category \"%s\": rename it, or take it away (its posts show under General)."],
        button1 = L["Rename"], button2 = L["Take away"], button3 = CANCEL or L["Cancel"],
        hasEditBox = true, maxLetters = 24, timeout = 0, whileDead = true, hideOnEscape = true,
        OnShow = function(self, data) local box = PopupBox(self) if data and box then box:SetText(data.name) box:HighlightText() end end,
        OnAccept = function(self, data)
            local ok, why = SK.BoardAddCategory(PopupBox(self):GetText(), data.mine, data.key)
            if not ok and why then SK.Print(why) end
        end,
        OnCancel = function(_, data, reason)
            if reason ~= "clicked" then return end
            local ok, why = SK.BoardRemoveCategory(data.key)
            if not ok and why then SK.Print(why) end
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    }
end

function SK.BoardLayoutCategories()
    if not (window and window.catButtons) then return end
    local cats = { { key = nil, name = "All" } }
    for _, cat in ipairs(SK.BOARD_CATEGORIES) do cats[#cats + 1] = cat end
    cats[#cats + 1] = { key = "mine", name = "Your posts" }
    local team = SK.BoardIAmTeam and SK.BoardIAmTeam()
    for _, b in ipairs(window.catButtons) do b:Hide() end
    for i, cat in ipairs(cats) do
        local b = window.catButtons[i]
        if not b then
            b = CreateFrame("Button", nil, window)
            b:SetSize(CAT_W, 22)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints()
            b.bg:SetColorTexture(1, 0.82, 0, 0.15)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)
            b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.label:SetPoint("LEFT", 8, 0)
            b.count = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            b.count:SetPoint("RIGHT", -8, 0)
            b:SetScript("OnClick", function(self, button)
                local c = self.cat
                if button == "RightButton" then
                    if team and c.key and c.key ~= "mine" and StaticPopup_Show then
                        StaticPopup_Show("SCROLLKEEPER_BOARD_EDITCAT", L[c.name], nil, { key = c.key, name = L[c.name], mine = c.mine })
                    end
                    return
                end
                picked.cat, picked.post = c.key, nil
                SK.RefreshBoard()
            end)
            b:SetScript("OnEnter", function(self)
                local c = self.cat
                if not (c.mine or team) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L[c.name])
                if c.mine then
                    GameTooltip:AddLine(L["Your ruleset only: you can't trade, group or whisper across rulesets."], 1, 1, 1, true)
                end
                if team and c.key and c.key ~= "mine" then
                    GameTooltip:AddLine(L["Dev team: right-click to rename or take it away."], 0.6, 0.6, 0.6, true)
                end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            window.catButtons[i] = b
        end
        b.cat, b.key = cat, cat.key
        b.label:SetText(L[cat.name])
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", window.catHeader, "BOTTOMLEFT", 0, -4 - (i - 1) * 24)
        b:Show()
    end
    -- Dev team: add a category.
    if team then
        if not state.addCatButton then
            state.addCatButton = Button(window, L["+ Category"], CAT_W - 8, function()
                if StaticPopup_Show then StaticPopup_Show("SCROLLKEEPER_BOARD_NEWCAT") end
            end, L["Dev team: add a board category for everyone (signed, like pins)."])
        end
        state.addCatButton:ClearAllPoints()
        state.addCatButton:SetPoint("TOPLEFT", window.catHeader, "BOTTOMLEFT", 2, -4 - #cats * 24 - 4)
        state.addCatButton:Show()
    elseif state.addCatButton then
        state.addCatButton:Hide()
    end
    window.rules:ClearAllPoints()
    window.rules:SetPoint("TOPLEFT", window.catHeader, "BOTTOMLEFT", 6, -4 - #cats * 24 - 8 - (team and 28 or 0))
    -- The picked category is gone: back to All.
    if picked.cat and picked.cat ~= "mine" then
        local found
        for _, cat in ipairs(SK.BOARD_CATEGORIES) do if cat.key == picked.cat then found = true end end
        if not found then picked.cat = nil end
    end
end

local function Build()
    local ok, frame = pcall(CreateFrame, "Frame", "ScrollkeeperBoardFrame", UIParent, "PortraitFrameTemplate")
    if not (ok and frame and frame.SetTitle) then
        frame = CreateFrame("Frame", "ScrollkeeperBoardFrame", UIParent, "BasicFrameTemplateWithInset")
        frame.SetTitle = function(self, text) if self.TitleText then self.TitleText:SetText(text) end end
    end
    window = frame
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", 0, 20)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Letter_17") end
    window:SetTitle(L["Scrollkeeper: Fellow Mages board"])
    tinsert(UISpecialFrames, "ScrollkeeperBoardFrame")

    local background = window:CreateTexture(nil, "BACKGROUND", nil, -7)
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    SK.UI.Background(background)
    SK.UI.AddHelp(window, "board")

    window.summary = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.summary:SetPoint("TOPLEFT", 64, -36)
    window.summary:SetJustifyH("LEFT")

    -- Top right: whose General posts you see, and New post.
    window.newPost = Button(window, L["New post"], 90, function() window.compose:Show() end,
        L["Post to the board. Posts last 7 days; you can make 3 a day."])
    window.newPost:SetPoint("TOPRIGHT", -40, -32)
    window.onlyMine = Button(window, L["Only my ruleset"], 110, function()
        SK.db.boardRulesets = "mine"; SK.RefreshBoard()
    end, L["General posts and notices from your ruleset only."])
    window.onlyMine:SetPoint("RIGHT", window.newPost, "LEFT", -12, 0)
    window.allRulesets = Button(window, L["All rulesets"], 90, function()
        SK.db.boardRulesets = "all"; SK.RefreshBoard()
    end, L["General posts and notices from mages on every ruleset. Trade, doorway and odds posts are always your ruleset only, since you can't trade, group or whisper across rulesets."])
    window.allRulesets:SetPoint("RIGHT", window.onlyMine, "LEFT", -4, 0)

    -- Left: categories.
    local catHeader = SK.UI.CreateHeader(window, L["Categories"], CAT_W)
    catHeader:SetPoint("TOPLEFT", 16, TOP)
    window.catButtons = {}
    window.catHeader = catHeader
    window.rules = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    SK.BoardLayoutCategories()
    window.rules:SetWidth(CAT_W - 12)
    window.rules:SetJustifyH("LEFT")
    window.rules:SetText(L["Posts last 7 days.\n3 posts a day each."] .. "\n" .. L["Horde and Alliance have separate boards."])
    window.unmute = Button(window, L["Unmute all"], CAT_W - 8, function() SK.BoardUnmuteAll(); SK.RefreshBoard() end,
        L["Show everyone's posts again: muted authors and hidden posts come back."])
    window.unmute:SetPoint("TOPLEFT", window.rules, "BOTTOMLEFT", -2, -10)

    -- Middle: the posts.
    window.listHeader = SK.UI.CreateHeader(window, L["Posts"], LIST_W)
    window.listHeader:SetPoint("TOPLEFT", catHeader, "TOPRIGHT", 12, 0)
    window.search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    -- In the top bar, left of the ruleset buttons (not on the list's heading).
    window.search:SetSize(150, 20)
    window.search:SetPoint("RIGHT", window.allRulesets, "LEFT", -14, 0)
    window.filter = Button(window, L["Filter"], 74, function()
        if not window.filterMenu then
            window.filterMenu = BuildFilterMenu()
            window.filterMenu:SetPoint("TOPRIGHT", window.filter, "BOTTOMRIGHT", 0, -4)
        end
        window.filterMenu:SetShown(not window.filterMenu:IsShown())
    end, L["Show only some posts (new, unanswered, from the dev team, recent...) and choose the order."])
    window.filter:SetPoint("RIGHT", window.search, "LEFT", -10, 0)
    window.refresh = Button(window, L["Refresh"], 74, function()
        if SK.BoardCatchUp then SK.BoardCatchUp(true) end
        SK.RefreshBoard()
        SK.Track("board.refresh")
    end, L["Ask other mages for posts you missed (like ones made while you were offline). New ones show in a few seconds."])
    window.refresh:SetPoint("RIGHT", window.filter, "LEFT", -6, 0)
    window.search:SetAutoFocus(false)
    window.search:SetScript("OnTextChanged", function() SK.RefreshBoard() end)
    window.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    window.searchHint = window.search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.searchHint:SetPoint("LEFT", 2, 0)
    window.searchHint:SetText(L["Search"])
    window.search:SetScript("OnEditFocusGained", function() window.searchHint:Hide() end)
    window.search:SetScript("OnEditFocusLost", function(self) window.searchHint:SetShown((self:GetText() or "") == "") end)
    window.list = SK.UI.CreateScrollList(window, LIST_W, LIST_ROWS, 3)
    window.list:SetPoint("TOPLEFT", window.listHeader, "BOTTOMLEFT", 0, -4)

    -- Right: the picked post and its replies.
    local detailHeader = SK.UI.CreateHeader(window, L["Post"], DETAIL_W)
    detailHeader:SetPoint("TOPLEFT", window.listHeader, "TOPRIGHT", 12, 0)
    window.detailHeader = detailHeader
    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", detailHeader, "BOTTOMLEFT", 4, -6)
    scroll:SetSize(DETAIL_W - 28, 290)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(DETAIL_W - 28, 10)
    scroll:SetScrollChild(content)
    window.detail, window.detailScroll = content, scroll
    content.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    content.meta = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    content.body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    content.line = content:CreateTexture(nil, "ARTWORK")
    content.line:SetColorTexture(1, 1, 1, 0.12)
    content.replies = {}
    for _, fs in ipairs({ content.title, content.meta, content.body }) do
        fs:SetWidth(DETAIL_W - 34)
        fs:SetJustifyH("LEFT")
    end

    -- Reply box, and what you can do with the post.
    window.reply = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    window.reply:SetSize(DETAIL_W - 116, 20)
    window.reply:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 4, -12)
    window.reply:SetAutoFocus(false)
    window.reply:SetMaxBytes(200)
    if SK.UI_LinkTarget then SK.UI_LinkTarget(window.reply) end
    window.reply:SetScript("OnEscapePressed", function(self)
        if state.editReply then state.editReply = nil; self:SetText("") end
        self:ClearFocus()
    end)
    window.replyHint = window.reply:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.replyHint:SetPoint("LEFT", 4, 0)
    window.replyHint:SetText(L["Write a reply..."])
    local function Reply()
        local text = window.reply:GetText() or ""
        if text == "" or not picked.post then return end
        if state.editReply then
            local ok, why = SK.BoardEdit(state.editReply, nil, text)
            state.editReply = nil
            if not ok then SK.Print(why) return end
        else
            local p, why = SK.BoardPost(nil, nil, text, picked.post)
            if not p then SK.Print(why) return end
        end
        window.reply:SetText("")
        window.reply:ClearFocus()
        SK.RefreshBoard()
    end
    window.reply:SetScript("OnEnterPressed", Reply)
    window.reply:SetScript("OnTextChanged", function(self)
        window.replyHint:SetShown((self:GetText() or "") == "" and not self:HasFocus())
    end)
    window.reply:SetScript("OnEditFocusGained", function() window.replyHint:Hide() end)
    window.reply:SetScript("OnEditFocusLost", function(self) window.replyHint:SetShown((self:GetText() or "") == "") end)
    window.replyButton = Button(window, L["Reply"], 70, Reply)
    window.replyEmoji = SK.EmojiButton(window, window.reply)
    window.replyEmoji:SetPoint("LEFT", window.reply, "RIGHT", 4, 0)
    window.replyButton:SetPoint("LEFT", window.replyEmoji, "RIGHT", 4, 0)

    local function Current() return state.current end
    window.whisper = Button(window, WHISPER or L["Whisper"], 70, function()
        local p = Current()
        local name = p and SK.BoardWhisperName(p)
        if name and ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. name .. " ") end
    end, L["Whisper the author. Only works on your own ruleset."])
    window.whisper:SetPoint("TOPLEFT", window.reply, "BOTTOMLEFT", -4, -8)
    window.hide = Button(window, L["Hide post"], 70, function()
        local p = Current()
        if p then SK.BoardHide(p.id); picked.post = nil; SK.RefreshBoard() end
    end, L["Hide this post for you. Unmute all brings it back."])
    window.hide:SetPoint("LEFT", window.whisper, "RIGHT", 4, 0)
    window.mute = Button(window, L["Mute"], 70, function()
        local p = Current()
        if p then SK.BoardMute(p.guid); picked.post = nil; SK.RefreshBoard() end
    end, L["Hide every post and reply from this mage, for you."])
    window.mute:SetPoint("LEFT", window.hide, "RIGHT", 4, 0)
    window.delete = Button(window, DELETE or L["Delete"], 70, function()
        local p = Current()
        if p and SK.BoardDelete(p.id) then picked.post = nil; SK.RefreshBoard() end
    end, L["Take your post down: it goes for everyone who's online now and comes in later."])
    window.delete:SetPoint("LEFT", window.mute, "RIGHT", 4, 0)
    window.edit = Button(window, L["Edit"], 70, function()
        local p = Current()
        if p and SK.BoardIsMine(p) then state.editPost = p; window.compose:Hide(); window.compose:Show() end
    end, L["Change your post's title or text. Everyone online gets the new version."])
    window.edit:SetPoint("RIGHT", window.delete, "LEFT", -4, 0)

    -- When the board can't be used.
    window.off = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.off:SetPoint("BOTTOM", 0, 16)
    window.off:SetWidth(WIDTH - 60)

    window.compose = BuildCompose()

    window:SetScript("OnShow", function()
        state.readBefore = SK.BoardData().lastRead   -- what's "new" this time
        if SK.BoardCatchUp then SK.BoardCatchUp() end
        SK.RefreshBoard()
        SK.BoardMarkRead()
        -- "5m ago" keeps up while it's open.
        if C_Timer.NewTicker and not state.ticker then
            state.ticker = C_Timer.NewTicker(60, function() SK.Safely("board", SK.RefreshBoard) end)
        end
        SK.Track("board.open")
    end)
    window:SetScript("OnHide", function()
        window.compose:Hide()
        SK.UI_CloseMenus()
        if state.ticker then state.ticker:Cancel(); state.ticker = nil end
    end)
    for _, f in ipairs(SK.boardBuilt or {}) do SK.Safely("board addon", f, window) end
    window:Hide()
end

------------------------------------------------------------------------
-- Filling it in
------------------------------------------------------------------------

-- Reactions under a post or reply: only the ones someone used (icon and
-- count, yours lit up; click to switch to it or take it back, hover: who),
-- then a small button that drops down all of them to pick from.
local reactMenu
local function ReactMenu()
    if reactMenu then return reactMenu end
    local list = SK.BOARD_REACTIONS or {}
    reactMenu = CreateFrame("Frame", "ScrollkeeperReactMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    reactMenu:SetFrameStrata("DIALOG")
    reactMenu:SetSize(#list * 26 + 10, 34)
    if reactMenu.SetBackdrop then
        reactMenu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        reactMenu:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    end
    reactMenu:EnableMouse(true)
    for i, e in ipairs(list) do
        local b = CreateFrame("Button", nil, reactMenu)
        b:SetSize(22, 22)
        b:SetPoint("LEFT", 6 + (i - 1) * 26, 0)
        b:SetNormalTexture(SK.EmojiTexture and SK.EmojiTexture(e) or nil)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnClick", function()
            reactMenu:Hide()
            if reactMenu.id then
                local ok, why = SK.BoardReact(reactMenu.id, e)
                if not ok and why then SK.Print(why) end
            end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(":" .. e .. ":")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    reactMenu:Hide()
    SK.UI_AutoClose(reactMenu)
    return reactMenu
end

local function ReactRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(240, 18)
    row.buttons = {}
    for i, e in ipairs(SK.BOARD_REACTIONS or {}) do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(38, 18)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(14, 14)
        b.icon:SetPoint("LEFT", 4, 0)
        b.icon:SetTexture(SK.EmojiTexture and SK.EmojiTexture(e) or nil)
        b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.count:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
        b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
        b:SetScript("OnClick", function()
            if row.id then
                local ok, why = SK.BoardReact(row.id, e)
                if not ok and why then SK.Print(why) end
            end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(":" .. e .. ":")
            local names = self.names or {}
            for i2 = 1, math.min(#names, 12) do GameTooltip:AddLine(names[i2], 1, 1, 1) end
            if #names > 12 then GameTooltip:AddLine(L["and %d more"]:format(#names - 12), 0.7, 0.7, 0.7) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b.emoji = e
        row.buttons[i] = b
    end
    -- The drop-down button: pick a reaction.
    local add = CreateFrame("Button", nil, row)
    add:SetSize(18, 18)
    add:SetNormalTexture(SK.EmojiTexture and SK.EmojiTexture("smile") or nil)
    add:SetAlpha(0.6)
    add:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    add:SetScript("OnClick", function(self)
        local menu = ReactMenu()
        if menu:IsShown() and menu.id == row.id then menu:Hide() return end
        menu.id = row.id
        SK.UI_PopupFrom(menu, self)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", -4, -2)
        menu:Show()
    end)
    add:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["React"])
        GameTooltip:Show()
    end)
    add:SetScript("OnLeave", function(self) self:SetAlpha(0.6); GameTooltip:Hide() end)
    row.add = add
    function row:Show_(id)
        self.id = id
        local counts, mine = SK.BoardReactions(id)
        local x = 0
        for _, b in ipairs(self.buttons) do
            local info = counts[b.emoji]
            b:ClearAllPoints()
            if info and info.count > 0 then
                b.count:SetText(info.count)
                b.names = info.names
                if mine[b.emoji] then b.bg:SetColorTexture(0.3, 0.62, 1, 0.35) else b.bg:SetColorTexture(1, 1, 1, 0.06) end
                b:SetPoint("LEFT", x, 0)
                b:Show()
                x = x + 42
            else
                b.names = nil
                b:Hide()
            end
        end
        self.add:ClearAllPoints()
        self.add:SetPoint("LEFT", x, 0)
        self:Show()
    end
    return row
end

-- What you can do with one reply ("..." on its right): edit or delete
-- your own, hide or mute someone else's, plus anything other addons add
-- with SK.AddBoardReplyAction({ text, func(reply), show(reply) }).
local replyActions = {}
function SK.AddBoardReplyAction(action) replyActions[#replyActions + 1] = action end

local replyMenu
local function ReplyMenu(anchor, r)
    if not replyMenu then
        replyMenu = CreateFrame("Frame", "ScrollkeeperBoardMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        replyMenu:SetFrameStrata("DIALOG")
        if replyMenu.SetBackdrop then
            replyMenu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            replyMenu:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
        end
        replyMenu:EnableMouse(true)
        replyMenu.items = {}
        SK.UI_AutoClose(replyMenu)
    end
    local entries = {}
    entries[#entries + 1] = { text = L["Copy text"], func = function()
        local text = SK.PlainText(r.body or "")
        if r.parent == "" then text = SK.PlainText(r.title or "") .. "\n\n" .. text end
        SK.ShowTextBox(L["Copy text"], text)
    end }
    if r.parent == "" and not SK.BoardIsMine(r) then
        local on = SK.BoardFollowing(r.id)
        entries[#entries + 1] = { text = on and L["Unfollow"] or L["Follow (ping me about replies)"], func = function() SK.BoardFollow(r.id, not on) end }
    end
    if SK.BoardIsMine(r) and r.parent == "" then
        local done = SK.BoardIsDone(r)
        entries[#entries + 1] = { text = done and L["Not done after all"] or L["Mark as done"], func = function()
            local ok, why = SK.BoardSetDone(r.id, not done)
            if not ok and why then SK.Print(why) end
        end }
    end
    if not SK.BoardIsMine(r) and not r.demo then
        local reported = SK.BoardReported(r.id)
        entries[#entries + 1] = { text = reported and ("|cff808080" .. L["Reported"] .. "|r") or L["Report to the team"], func = function()
            if not reported and SK.BoardReport(r.id) then SK.Print(L["thanks, the Scrollkeeper team will have a look."]) end
        end }
    end
    if SK.BoardIsMine(r) then
        entries[#entries + 1] = { text = L["Edit"], func = function()
            if r.parent == "" then
                state.editPost = r; window.compose:Hide(); window.compose:Show()
                return
            end
            state.editReply = r.id
            window.reply:SetText(r.body or "")
            window.reply:SetFocus()
        end }
        entries[#entries + 1] = { text = DELETE or L["Delete"], func = function() SK.BoardDelete(r.id); SK.RefreshBoard() end }
    else
        entries[#entries + 1] = { text = r.parent == "" and L["Hide post"] or L["Hide reply"], func = function() SK.BoardHide(r.id); SK.RefreshBoard() end }
        entries[#entries + 1] = { text = L["Mute"], func = function() SK.BoardMute(r.guid); SK.RefreshBoard() end }
    end
    for _, a in ipairs(replyActions) do
        if not a.show or a.show(r) then entries[#entries + 1] = { text = a.text, func = function() a.func(r) end } end
    end
    for i, e in ipairs(entries) do
        local b = replyMenu.items[i]
        if not b then
            b = CreateFrame("Button", nil, replyMenu)
            b:SetSize(120, 18)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 18)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 4, 0)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            replyMenu.items[i] = b
        end
        b.text:SetText(e.text)
        b:SetScript("OnClick", function() replyMenu:Hide(); e.func() end)
        b:Show()
    end
    for i = #entries + 1, #replyMenu.items do replyMenu.items[i]:Hide() end
    replyMenu:SetSize(132, #entries * 18 + 12)
    SK.UI_PopupFrom(replyMenu, anchor)
    replyMenu:ClearAllPoints()
    replyMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    replyMenu:Show()
end

-- "From my bags": what you need (Scrolls wanted) or have spare.
state.FromBags = function(cat)
    if cat == "spare" and SK.MySpares then
        local parts = {}
        local spares = SK.MySpares()
        for _, tier in ipairs(SK.TIERS or {}) do
            if (spares[tier] or 0) > 0 then parts[#parts + 1] = L["tier %d x%d"]:format(tier, spares[tier]) end
        end
        if #parts == 0 then SK.Print(L["no spare scrolls in your bags right now."]) return nil end
        return L["Spare scrolls: %s. Whisper or mail me!"]:format(table.concat(parts, ", "))
    elseif cat == "wanted" then
        local skill = SK.GetComprehension and SK.GetComprehension()
        if not (skill and skill.known) then return nil end
        local parts = {}
        for _, tier in ipairs(SK.TIERS or {}) do
            local chance = skill.effective >= tier and SK.SkillUpChance and SK.SkillUpChance(tier, skill.rank)
            if chance and chance.gives then parts[#parts + 1] = tostring(tier) end
        end
        if #parts == 0 then SK.Print(L["no tier gives you skill-ups right now."]) return nil end
        return L["Looking for tier %s scrolls (Comprehension %d). Whisper or mail me!"]:format(table.concat(parts, ", "), skill.rank or 0)
    end
end

-- Text size in the post pane (setting boardFontSize).
local FONT_SIZES = { small = "GameFontHighlightSmall", normal = "GameFontHighlight", large = "GameFontHighlightLarge" }
local function BodyFont() return FONT_SIZES[SK.db and SK.db.boardFontSize or "normal"] or "GameFontHighlight" end

local function ShowDetail(p, replies)
    local c = window.detail
    state.current = p
    for _, r in ipairs(c.replies) do r.head:Hide(); r.body:Hide(); if r.react then r.react:Hide() end; if r.more then r.more:Hide() end end
    if state.react then state.react:Hide() end
    if state.postMore then state.postMore:Hide() end
    for _, b in ipairs(state.items or {}) do b:Hide() end
    if not p then
        c.title:SetText(L["Pick a post."])
        c.meta:SetText("")
        c.body:SetText("")
        c.line:Hide()
        c.title:SetPoint("TOPLEFT", 2, -2)
        c:SetHeight(20)
        return
    end
    local cat = SK.BoardCategory(p.cat)
    c.title:SetPoint("TOPLEFT", 2, -2)
    c.title:SetText(SK.FormatText(p.title))
    c.meta:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
    c.meta:SetText((cat and L[cat.name] or "") .. " · " .. AuthorText(p) .. " · " .. Ago(p.at)
        .. ((p.rev or 0) > 0 and (" |cff808080" .. L["(edited)"] .. "|r") or ""))
    c.body:SetPoint("TOPLEFT", c.meta, "BOTTOMLEFT", 0, -8)
    c.body:SetFontObject(BodyFont())
    c.body:SetText(SK.FormatText(p.body))
    -- ••• on the post too (copy, edit, hide, mod actions).
    if not state.postMore then
        local more = CreateFrame("Button", nil, c)
        more:SetSize(22, 14)
        local t = more:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("CENTER")
        t:SetText("•••")
        more:SetAlpha(0.6)
        more:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
        more:SetScript("OnLeave", function(self) self:SetAlpha(0.6) end)
        state.postMore = more
    end
    state.postMore:ClearAllPoints()
    state.postMore:SetPoint("TOPRIGHT", c.title, "TOPRIGHT", 0, 1)
    state.postMore:SetScript("OnClick", function(self)
        if replyMenu and replyMenu:IsShown() then replyMenu:Hide() return end
        ReplyMenu(self, p)
    end)
    state.postMore:SetShown(not p.demo)
    -- Items linked in the post: buttons with their tooltip (shift-click
    -- to link them in chat).
    state.items = state.items or {}
    local ids, itemAnchor = SK.LinkedItems(p.title .. " " .. p.body), c.body
    for i = 1, math.max(#ids, #state.items) do
        local b = state.items[i]
        if i <= #ids and i <= 8 then
            if not b then
                b = CreateFrame("Button", nil, c)
                b:SetSize(24, 24)
                b.icon = b:CreateTexture(nil, "ARTWORK")
                b.icon:SetAllPoints()
                b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                b:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(self.itemID)
                    GameTooltip:AddLine(L["Shift-click to link it in chat."], 0.6, 0.6, 0.6)
                    GameTooltip:Show()
                end)
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                b:SetScript("OnClick", function(self)
                    local link = C_Item and select(2, SK.Try(C_Item.GetItemInfo, self.itemID))
                    if link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
                end)
                state.items[i] = b
            end
            b.itemID = ids[i]
            b.icon:SetTexture(C_Item and SK.Try(C_Item.GetItemIconByID, ids[i]) or nil)
            b:ClearAllPoints()
            if i == 1 then b:SetPoint("TOPLEFT", c.body, "BOTTOMLEFT", 0, -6) else b:SetPoint("LEFT", state.items[i - 1], "RIGHT", 4, 0) end
            b:Show()
            if i == 1 then itemAnchor = b end
        elseif b then
            b:Hide()
        end
    end
    state.react = state.react or ReactRow(c)
    state.react:ClearAllPoints()
    state.react:SetPoint("TOPLEFT", itemAnchor, "BOTTOMLEFT", 0, -6)
    state.react:Show_(p.id)
    c.line:ClearAllPoints()
    c.line:SetPoint("TOPLEFT", state.react, "BOTTOMLEFT", 0, -8)
    c.line:SetSize(DETAIL_W - 34, 1)
    c.line:Show()
    local anchor, height = c.line, (c.title:GetStringHeight() or 14) + (c.meta:GetStringHeight() or 12)
        + (c.body:GetStringHeight() or 14) + 30 + 24 + (#ids > 0 and 30 or 0)
    for i, r in ipairs(replies or {}) do
        local row = c.replies[i]
        if not row then
            row = { head = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
                    body = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight") }
            for _, fs in pairs(row) do fs:SetWidth(DETAIL_W - 34); fs:SetJustifyH("LEFT") end
            c.replies[i] = row
        end
        row.head:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -8 or -10)
        row.head:SetText(AuthorText(r) .. " |cff808080· " .. Ago(r.at) .. ((r.rev or 0) > 0 and (" " .. L["(edited)"]) or "") .. "|r")
        row.body:SetPoint("TOPLEFT", row.head, "BOTTOMLEFT", 0, -2)
        row.body:SetFontObject(BodyFont())
        row.body:SetText(SK.FormatText(r.body))
        row.head:Show()
        row.body:Show()
        if not row.more then
            row.more = CreateFrame("Button", nil, c)
            row.more:SetSize(22, 14)
            row.more.text = row.more:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.more.text:SetPoint("CENTER")
            row.more.text:SetText("•••")
            row.more:SetAlpha(0.6)
            row.more:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
            row.more:SetScript("OnLeave", function(self) self:SetAlpha(0.6) end)
        end
        row.more:ClearAllPoints()
        row.more:SetPoint("TOPRIGHT", row.head, "TOPRIGHT", 0, 1)
        row.more:SetScript("OnClick", function(self)
            if replyMenu and replyMenu:IsShown() then replyMenu:Hide() return end
            ReplyMenu(self, r)
        end)
        row.more:SetShown(not r.demo)
        row.react = row.react or ReactRow(c)
        row.react:ClearAllPoints()
        row.react:SetPoint("TOPLEFT", row.body, "BOTTOMLEFT", 0, -4)
        row.react:Show_(r.id)
        anchor = row.react
        height = height + (row.head:GetStringHeight() or 12) + (row.body:GetStringHeight() or 14) + 12 + 22
    end
    c:SetHeight(math.max(20, height))
end

function SK.RefreshBoard()
    if not (window and window:IsShown()) then return end
    local on = SK.BoardOn()
    if state.catCount ~= #SK.BOARD_CATEGORIES or state.catSig ~= (SK.BoardCategorySig and SK.BoardCategorySig()) then
        state.catCount = #SK.BOARD_CATEGORIES
        state.catSig = SK.BoardCategorySig and SK.BoardCategorySig()
        SK.BoardLayoutCategories()
    end
    local counts, total = SK.BoardCounts()
    state.newIn = {}
    for _, p in pairs(SK.BoardData().posts) do
        if (p.at or 0) > (state.readBefore or 0) and not SK.BoardIsMine(p) and SK.BoardVisible(p) then
            local top = p.parent == "" and p or SK.BoardData().posts[p.parent]
            if top then state.newIn[SK.BoardShownCat(top)] = true end
        end
    end
    for _, b in ipairs(window.catButtons) do
        local n
        if b.key == "mine" then n = state.mineCount or 0
        else n = b.key and (counts[b.key] or 0) or total end
        b.count:SetText(n)
        b.bg:SetShown(b.key == picked.cat)
        -- A green dot: something new in there since you last looked.
        state.dots = state.dots or {}
        local dot = state.dots[b]
        if not dot then
            dot = b:CreateTexture(nil, "OVERLAY")
            dot:SetSize(6, 6)
            dot:SetPoint("RIGHT", b.count, "LEFT", -4, 0)
            dot:SetColorTexture(0.25, 1, 0.25, 1)
            state.dots[b] = dot
        end
        dot:SetShown(b.key ~= nil and b.key ~= "mine" and (state.newIn or {})[b.key] and true or false)
    end
    local all = SK.db.boardRulesets ~= "mine"
    if all then window.allRulesets:LockHighlight(); window.onlyMine:UnlockHighlight()
    else window.onlyMine:LockHighlight(); window.allRulesets:UnlockHighlight() end
    local muted = SK.BoardMutedCount()
    window.unmute:SetShown(muted > 0 or next(SK.BoardData().hidden) ~= nil)

    local search = window.search:GetText()
    search = (type(search) == "string" and search or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if search == "" then search = nil end
    window.searchHint:SetShown(not search and not window.search:HasFocus())
    local posts, replies = SK.BoardPosts(picked.cat, search)
    posts = ApplyFilter(posts, replies)
    local filtersOn = FiltersOn()
    window.filter:SetText(filtersOn > 0 and (L["Filter"] .. " (" .. filtersOn .. ")") or L["Filter"])
    local mineCount = 0
    for _, p in ipairs((SK.BoardPosts("mine"))) do mineCount = mineCount + 1 end
    state.mineCount = mineCount
    local demo = SK.demoCommunity and L[" |cffff8040(demo)|r"] or ""
    window.summary:SetText(L["|cffffffff%d|r |4post:posts;%s"]:format(total, demo))
    local cat = SK.BoardCategory(picked.cat)
    window.listHeader.Title:SetText(picked.cat == "mine" and L["Your posts"] or cat and L[cat.name] or L["All posts"])

    -- The picked post: still there? Else the first one.
    local current
    for _, p in ipairs(posts) do if p.id == picked.post then current = p end end
    if not current then current = posts[1]; picked.post = current and current.id end

    window.list:SetRows(posts, function(row, p)
        local n = replies[p.id] and #replies[p.id] or 0
        local pin = SK.BoardIsPinned(p) and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12:12|t |cffffc94d"
            or p.cat == "notice" and "|TInterface\\Buttons\\UI-GuildButton-PublicNote-Up:12:12|t |cffffc94d" or ""
        local new = (p.at or 0) > (state.readBefore or 0) and not SK.BoardIsMine(p) and not p.demo
        local title = SK.FormatText(p.title)
        if SK.BoardIsDone(p) then title = "|cff808080" .. "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " .. SK.PlainText(p.title) .. "|r" end
        row.label:SetText(pin .. title .. (pin ~= "" and "|r" or "") .. (new and (" |cff40ff40" .. L["new"] .. "|r") or ""))
        -- Under the title: just who and when (tier and ruleset on hover),
        -- and the reactions on a line of their own (to look at; react in the post).
        row.sub:SetText(AuthorText(p, true) .. " |cff808080· " .. Ago(p.at)
            .. (n > 0 and (" · " .. L["%d |4reply:replies;"]:format(n)) or "") .. "|r")
        -- The post's reactions and its replies', added up.
        local counts = {}
        local function Add(id)
            for e, info in pairs((SK.BoardReactions(id))) do counts[e] = { count = (counts[e] and counts[e].count or 0) + info.count } end
        end
        Add(p.id)
        for _, r in ipairs(replies[p.id] or {}) do Add(r.id) end
        local shown = {}
        for _, e in ipairs(SK.BOARD_REACTIONS or {}) do
            local info, tex = counts[e], SK.EmojiTexture and SK.EmojiTexture(e)
            if info and info.count > 0 and tex then shown[#shown + 1] = "|T" .. tex .. ":0|t " .. info.count end
        end
        if row.third then row.third:SetText(table.concat(shown, "   ")) end
        row.tipFunc = function(tip)
            local cat = SK.BoardCategory(p.cat)
            tip:AddLine(SK.FormatText(p.title), 1, 0.82, 0, true)
            tip:AddLine(AuthorText(p))
            tip:AddDoubleLine(cat and L[cat.name] or "", Ago(p.at), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
            if n > 0 then tip:AddLine(L["%d |4reply:replies;"]:format(n), 1, 1, 1) end
            if #shown > 0 then tip:AddLine(table.concat(shown, "   "), 1, 1, 1) end
        end
        local sel = selectTex[row]
        if not sel then
            sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
            sel:SetAllPoints()
            sel:SetColorTexture(0.3, 0.62, 1, 0.22)
            selectTex[row] = sel
        end
        sel:SetShown(p.id == picked.post)
        row.onClick = function() picked.post = p.id; SK.RefreshBoard() end
    end, SK.BoardOn() and ((search or FiltersOn() > 0) and L["Nothing matches that."] or L["No posts here yet. Be the first: New post."]) or "")

    ShowDetail(current, current and replies[current.id])
    local real = current and not current.demo
    local mine = current and SK.BoardIsMine(current)
    window.reply:SetEnabled(on and real and true or false)
    window.replyButton:SetEnabled(on and real and true or false)
    window.whisper:SetEnabled(current and SK.BoardCanWhisper(current) and SK.BoardWhisperName(current) and true or false)
    window.hide:SetEnabled(real and not mine and true or false)
    window.mute:SetEnabled(real and not mine and true or false)
    window.delete:SetShown(mine and true or false)
    window.edit:SetShown(mine and not current.demo and true or false)
    window.hide:SetShown(not mine)
    window.mute:SetShown(not mine)
    window.newPost:SetEnabled(on)
    window.reply:SetMaxBytes(math.max(20, SK.BoardRoom(nil) + 1))

    if not (SK.db and SK.db.share) then
        window.off:SetText("|cffff6666" .. L["Sharing is off, so the board can't send or get posts. Turn it on in /sk options > Sharing."] .. "|r")
    elseif SK.db.boardOn == false then
        window.off:SetText("|cffff6666" .. L["The board is off. Turn it on in /sk options > Fellow Mages board."] .. "|r")
    else
        window.off:SetText("")
    end
end

-- For other addons: the post shown on the right, and a way to add to
-- the window once it's made.
function SK.BoardCurrent() return window and state.current end
function SK.OnBoardBuilt(f)
    SK.boardBuilt = SK.boardBuilt or {}
    table.insert(SK.boardBuilt, f)
    if window then SK.Safely("board addon", f, window) end
end

function SK.ToggleBoard()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

local soon
SK.Listen("BOARD_CHANGED", function()
    if soon or not (window and window:IsShown()) then return end
    soon = true
    C_Timer.After(0.3, function() soon = false; SK.Safely("board", SK.RefreshBoard) end)
end)
