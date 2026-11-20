--[[
    Lifeline - Settings window: frame, sidebar tabs, footer and open/close
]]

local _, L = ...
local C = L.C
local O = L.Opt


------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------

-- which sidebar section a page belongs to, and the page last open in each section
local sectionOf, lastPage = {}, {}
local SUBBAR_H = 34

local function SelectPage(page)
    local sec = sectionOf[page]
    for n, p in pairs(O.pages) do p:SetShown(n == page) end
    for n, t in pairs(O.tabs) do
        local on = sec and n == sec.name
        t.tick:SetShown(on)
        t.bg:SetShown(on)
        local c = on and C.accent or C.muted
        t.text:SetTextColor(c[1], c[2], c[3])
    end
    -- sub-tab bar of the active section
    for _, s2 in ipairs(O.SECTIONS) do
        if s2.bar then
            s2.bar:SetShown(s2 == sec)
            for _, b in ipairs(s2.bar.buttons) do
                local on = b.page == page
                b.text:SetTextColor(on and C.accent[1] or C.text[1], on and C.accent[2] or C.text[2], on and C.accent[3] or C.text[3])
                L.SetC(b.__bg, on and C.accentDim or C.panel2)
                L.SetBorderColor(b, on and C.accent[1] or C.border[1], on and C.accent[2] or C.border[2], on and C.accent[3] or C.border[3])
            end
        end
    end
    if sec then lastPage[sec.name] = page end
    L.CloseMenu()
    O.win.current = page
    O.win.section = sec and sec.name or nil
end
O.SelectPage = SelectPage

-- a sidebar click opens the page you last used in that section
local function SelectSection(name)
    for _, s2 in ipairs(O.SECTIONS) do
        if s2.name == name then SelectPage(lastPage[name] or s2.pages[1][2]) return end
    end
end
O.SelectSection = SelectSection

------------------------------------------------------------------------
-- Live example panel docked beside the settings window
------------------------------------------------------------------------

local function CreateWindow()
    O.win = CreateFrame("Frame", "LifelineOptions", UIParent)
    O.win:SetSize(800, 640)
    O.win:SetPoint("CENTER")
    O.win:SetFrameStrata("HIGH")
    O.win:SetToplevel(true)
    O.win:SetMovable(true)
    O.win:EnableMouse(true)
    O.win:SetClampedToScreen(true)
    O.win:RegisterForDrag("LeftButton")
    O.win:SetScript("OnDragStart", O.win.StartMoving)
    O.win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        O.PlaceExampleIfShown()
    end)
    L.Skin(O.win, C.bg)
    tinsert(UISpecialFrames, "LifelineOptions")

    -- title bar
    local title = CreateFrame("Frame", nil, O.win)
    title:SetPoint("TOPLEFT", 1, -1)
    title:SetPoint("TOPRIGHT", -1, -1)
    title:SetHeight(40)
    local tbg = title:CreateTexture(nil, "BACKGROUND")
    tbg:SetAllPoints()
    L.SetC(tbg, C.panel)
    local line = title:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT") line:SetPoint("BOTTOMRIGHT") line:SetHeight(1)
    L.SetC(line, C.border)

    local logo = title:CreateTexture(nil, "ARTWORK")
    logo:SetSize(26, 26)
    logo:SetPoint("LEFT", 12, 0)
    logo:SetTexture("Interface\\AddOns\\Lifeline\\Media\\icon")
    local tt = L.Text(title, 16)
    tt:SetPoint("LEFT", logo, "RIGHT", 10, 1)
    tt:SetText("Lifeline")
    local tv = L.Text(title, 11, C.muted)
    tv:SetPoint("LEFT", tt, "RIGHT", 8, -1)
    tv:SetText("v" .. L.version .. "  -  party & raid frames")
    O.win.profileText = L.Text(title, 11, C.accent)
    O.win.profileText:SetPoint("RIGHT", -76, 0)

    -- "i": About (slash commands, Discord)
    local info = CreateFrame("Button", nil, title)
    info:SetSize(22, 22)
    info:SetPoint("RIGHT", -40, 0)
    L.Skin(info, C.panel2)
    local it = L.Text(info, 13, C.muted)
    it:SetPoint("CENTER", 0, 0)
    it:SetJustifyH("CENTER")
    it:SetText("i")
    info:SetScript("OnEnter", function(self)
        L.SetBorderColor(self, C.accent[1], C.accent[2], C.accent[3])
        it:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("About Lifeline", 1, 1, 1)
        GameTooltip:AddLine("Slash commands and The Forge Discord.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    info:SetScript("OnLeave", function(self)
        L.SetBorderColor(self, C.border[1], C.border[2], C.border[3])
        it:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        GameTooltip:Hide()
    end)
    info:SetScript("OnClick", function()
        if O.win.current == "About" then SelectSection(O.lastSection or "General") else
            O.lastSection = O.win.section
            SelectPage("About")
        end
    end)
    O.win.profileText:SetJustifyH("RIGHT")

    local close = CreateFrame("Button", nil, title)
    close:SetSize(26, 26)
    close:SetPoint("RIGHT", -8, 0)
    local x = L.Text(close, 16, C.muted)
    x:SetPoint("CENTER")
    x:SetText("x")
    close:SetScript("OnEnter", function() x:SetTextColor(C.danger[1], C.danger[2], C.danger[3]) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function() O.win:Hide() end)

    -- sidebar
    local side = CreateFrame("Frame", nil, O.win)
    side:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, 0)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(170)
    local sbg = side:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints()
    L.SetC(sbg, C.panel)
    local sline = side:CreateTexture(nil, "ARTWORK")
    sline:SetPoint("TOPRIGHT") sline:SetPoint("BOTTOMRIGHT") sline:SetWidth(1)
    L.SetC(sline, C.border)

    for i, sec in ipairs(O.SECTIONS) do
        local name = sec.name
        local t = CreateFrame("Button", nil, side)
        t:SetSize(168, 34)
        t:SetPoint("TOPLEFT", 0, -10 - (i - 1) * 38)
        t.bg = t:CreateTexture(nil, "BACKGROUND")
        t.bg:SetAllPoints()
        L.SetC(t.bg, C.accentDim)
        t.tick = t:CreateTexture(nil, "ARTWORK")
        t.tick:SetPoint("TOPLEFT") t.tick:SetPoint("BOTTOMLEFT") t.tick:SetWidth(3)
        L.SetC(t.tick, C.accent)
        t.text = L.Text(t, 13, C.muted)
        t.text:SetPoint("LEFT", 18, 0)
        t.text:SetText(name)
        t:SetScript("OnEnter", function() if O.win.section ~= name then t.text:SetTextColor(C.text[1], C.text[2], C.text[3]) end end)
        t:SetScript("OnLeave", function() if O.win.section ~= name then t.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end end)
        t:SetScript("OnClick", function() SelectSection(name) end)
        O.tabs[name] = t
    end

    -- footer
    local foot = CreateFrame("Frame", nil, O.win)
    foot:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(44)
    local fline = foot:CreateTexture(nil, "ARTWORK")
    fline:SetPoint("TOPLEFT") fline:SetPoint("TOPRIGHT") fline:SetHeight(1)
    L.SetC(fline, C.border)

    O.win.lockBtn = L.Button(foot, "Unlock Frames", 120, 26, function() L:SetLocked(not L.db.locked) end, true)
    O.win.lockBtn:SetPoint("LEFT", 16, 0)

    local pl = L.Text(foot, 12, C.muted)
    pl:SetPoint("LEFT", O.win.lockBtn, "RIGHT", 18, 0)
    pl:SetText("Preview:")
    local prev
    for _, m in ipairs({ { "party", "Party" }, { "raid10", "10" }, { "raid25", "25" }, { "raid40", "40" } }) do
        local b = L.Button(foot, m[2], m[1] == "party" and 58 or 40, 26, function() L:Preview_Toggle(m[1]) end)
        b:SetPoint("LEFT", prev or pl, "RIGHT", prev and 4 or 8, 0)
        prev = b
    end
    local reload = L.Button(foot, "Reload UI", 96, 26, function() ReloadUI() end)
    reload:SetPoint("RIGHT", -16, 0)

    -- body
    local body = CreateFrame("Frame", nil, O.win)
    body:SetPoint("TOPLEFT", side, "TOPRIGHT", 24, -16)
    body:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", -20, 8)
    O.win.body = body

    for _, entry in ipairs(O.TAB_BUILDERS) do entry[2]() end

    -- sections with several pages get a sub-tab bar; their pages start below it
    for _, sec in ipairs(O.SECTIONS) do
        for _, pg in ipairs(sec.pages) do sectionOf[pg[2]] = sec end
        if #sec.pages > 1 then
            local bar = CreateFrame("Frame", nil, body)
            bar:SetPoint("TOPLEFT", 0, 0)
            bar:SetPoint("TOPRIGHT", 0, 0)
            bar:SetHeight(26)
            bar.buttons = {}
            local x = 0
            for _, pg in ipairs(sec.pages) do
                local label, page = pg[1], pg[2]
                local w = math.max(96, 26 + #label * 7)
                local b = L.Button(bar, label, w, 24, function() SelectPage(page) end)
                b:SetPoint("LEFT", x, 0)
                b:SetScript("OnLeave", function(self)
                    local on = O.win.current == page
                    local c = on and C.accent or C.border
                    L.SetBorderColor(self, c[1], c[2], c[3])
                end)
                b.page = page
                x = x + w + 6
                bar.buttons[#bar.buttons + 1] = b
                local p = O.pages[page]
                if p then
                    p:ClearAllPoints()
                    p:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -SUBBAR_H)
                    p:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
                end
            end
            local line = bar:CreateTexture(nil, "ARTWORK")
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
            line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -4)
            L.SetC(line, C.border)
            bar:Hide()
            sec.bar = bar
        end
    end
    sectionOf.About = nil

    O.win:SetScript("OnShow", function()
        xpcall(function() L:Options_RefreshControls() L:Example_Refresh() end, geterrorhandler())
    end)
    O.win:SetScript("OnHide", function() L.CloseMenu() end)
    SelectPage("General")
end

-- Open/close the settings window. Built so a single click *always* opens it:
-- the window is built inside xpcall (any error is still reported, but can't
-- leave the window half-made and closed), and opening is always an explicit
-- Show rather than relying on how a new frame starts out.
function L:Options_Toggle()
    if O.win and O.win:IsShown() then
        O.win:Hide()
        return
    end
    if not O.win then
        xpcall(CreateWindow, geterrorhandler())
        if not O.win then return end
    end
    O.win:Show()
    xpcall(function()
        L:Options_RefreshControls()
        L:Example_Refresh()
    end, geterrorhandler())
end

