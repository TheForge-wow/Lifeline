--[[
    Lifeline - Theme & widget kit
    Flat, dark, thin-bordered look shared with Artisan Network / Salvage Station.
]]

local _, L = ...

local WHITE = "Interface\\Buttons\\WHITE8x8"
L.WHITE = WHITE

L.C = {
    bg       = { 0.055, 0.063, 0.078, 0.97 },
    panel    = { 0.082, 0.094, 0.114, 1 },
    panel2   = { 0.110, 0.125, 0.150, 1 },
    border   = { 0.180, 0.200, 0.240, 1 },
    accent   = { 0.298, 0.851, 0.549, 1 },   -- #4CD98C
    accentDim= { 0.298, 0.851, 0.549, 0.18 },
    text     = { 0.925, 0.937, 0.953, 1 },
    muted    = { 0.580, 0.612, 0.659, 1 },
    danger   = { 0.902, 0.341, 0.341, 1 },
}
local C = L.C

L.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local function SetC(tex, c, a) tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1) end
L.SetC = SetC

------------------------------------------------------------------------
-- Pixel border
------------------------------------------------------------------------
function L.AddBorder(f, c, size)
    size = size or 1
    c = c or C.border
    if f.__border then
        for _, t in ipairs(f.__border) do t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
        return f.__border
    end
    local b = {}
    local function edge(p1, p2, horiz)
        local t = f:CreateTexture(nil, "BORDER", nil, 7)
        t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        t:SetPoint(p1) t:SetPoint(p2)
        if horiz then t:SetHeight(size) else t:SetWidth(size) end
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
        b[#b + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)
    f.__border = b
    return b
end

function L.SetBorderColor(f, r, g, b, a)
    if not f.__border then return end
    for _, t in ipairs(f.__border) do t:SetColorTexture(r, g, b, a or 1) end
end

function L.Skin(f, c, borderC)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    SetC(bg, c or C.panel)
    f.__bg = bg
    L.AddBorder(f, borderC)
    return f
end

function L.Text(parent, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(L.FONT, size or 12, flags or "")
    local c = color or C.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------
function L.Button(parent, label, w, h, onClick, primary)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 120, h or 24)
    L.Skin(b, primary and C.accentDim or C.panel2, primary and C.accent or C.border)
    b.text = L.Text(b, 12, primary and C.accent or C.text)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label)
    b:SetScript("OnEnter", function(s) L.SetBorderColor(s, C.accent[1], C.accent[2], C.accent[3]) end)
    b:SetScript("OnLeave", function(s)
        local c = primary and C.accent or C.border
        L.SetBorderColor(s, c[1], c[2], c[3])
    end)
    b:SetScript("OnClick", function(s, ...) if onClick then onClick(s, ...) end end)
    return b
end

------------------------------------------------------------------------
-- Checkbox (square toggle with accent fill)
------------------------------------------------------------------------
function L.Check(parent, label, get, set, tip)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(240, 22)
    local box = CreateFrame("Frame", nil, f)
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    L.Skin(box, C.panel2)
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    SetC(fill, C.accent)
    f.text = L.Text(f, 12)
    f.text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    f.text:SetText(label)
    f.Refresh = function() fill:SetShown(get() and true or false) end
    f:SetScript("OnClick", function()
        set(not get())
        f.Refresh()
    end)
    f:SetScript("OnEnter", function()
        L.SetBorderColor(box, C.accent[1], C.accent[2], C.accent[3])
        if tip then
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label, 1, 1, 1)
            GameTooltip:AddLine(tip, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function()
        L.SetBorderColor(box, C.border[1], C.border[2], C.border[3])
        GameTooltip:Hide()
    end)
    f.Refresh()
    return f
end

------------------------------------------------------------------------
-- Slider (thin track, accent fill, value readout)
------------------------------------------------------------------------
function L.Slider(parent, label, minV, maxV, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(240, 38)
    f.label = L.Text(f, 12)
    f.label:SetPoint("TOPLEFT")
    f.label:SetText(label)
    f.value = L.Text(f, 12, C.accent)
    f.value:SetPoint("TOPRIGHT")
    f.value:SetJustifyH("RIGHT")

    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("BOTTOMLEFT", 0, 4)
    s:SetPoint("BOTTOMRIGHT", 0, 4)
    s:SetHeight(12)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT") track:SetPoint("RIGHT") track:SetHeight(4)
    SetC(track, C.panel2)
    local fillT = s:CreateTexture(nil, "ARTWORK")
    fillT:SetPoint("LEFT", track, "LEFT")
    fillT:SetHeight(4)
    SetC(fillT, C.accent)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 12)
    SetC(thumb, C.text)
    s:SetThumbTexture(thumb)

    local function fmtV(v)
        if fmt then return fmt(v) end
        if step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end
    local function paint(v)
        local pct = (v - minV) / (maxV - minV)
        fillT:SetWidth(math.max(1, (s:GetWidth() or 200) * pct))
        f.value:SetText(fmtV(v))
    end
    s:SetScript("OnValueChanged", function(_, v, user)
        if step >= 1 then v = math.floor(v + 0.5) end
        paint(v)
        if user then set(v) end
    end)
    s:SetScript("OnSizeChanged", function() paint(s:GetValue()) end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(_, d)
        local v = math.min(maxV, math.max(minV, s:GetValue() + d * step))
        s:SetValue(v)
        set(v)
    end)
    f.Refresh = function() s:SetValue(get()); paint(get()) end
    f.slider = s
    f.Refresh()
    return f
end

------------------------------------------------------------------------
-- Dropdown (custom flat popup, no UIDropDownMenu taint)
------------------------------------------------------------------------
local openMenu
local function CloseMenu() if openMenu then openMenu:Hide(); openMenu = nil end end
L.CloseMenu = CloseMenu

function L.Dropdown(parent, label, options, get, set, width)
    -- options: { {value=, text=}, ... }
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 240, 44)
    f.label = L.Text(f, 12)
    f.label:SetPoint("TOPLEFT")
    f.label:SetText(label)

    local b = CreateFrame("Button", nil, f)
    b:SetPoint("BOTTOMLEFT") b:SetPoint("BOTTOMRIGHT")
    b:SetHeight(22)
    L.Skin(b, C.panel2)
    b.text = L.Text(b, 12)
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetPoint("RIGHT", -20, 0)
    local arrow = L.Text(b, 12, C.muted)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")

    local function textFor(v)
        for _, o in ipairs(options) do if o.value == v then return o.text end end
        return tostring(v)
    end
    f.Refresh = function() b.text:SetText(textFor(get())) end

    b:SetScript("OnEnter", function() L.SetBorderColor(b, C.accent[1], C.accent[2], C.accent[3]) end)
    b:SetScript("OnLeave", function() L.SetBorderColor(b, C.border[1], C.border[2], C.border[3]) end)
    b:SetScript("OnClick", function()
        if openMenu and openMenu.owner == b then CloseMenu() return end
        CloseMenu()
        local m = CreateFrame("Frame", nil, UIParent)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
        m:SetWidth(b:GetWidth())
        -- long lists (fonts, textures) scroll with the mouse wheel
        local MAXROWS = 14
        local rows = math.min(#options, MAXROWS)
        m:SetHeight(rows * 20 + 4)
        L.Skin(m, C.panel, C.accent)
        m.owner = b
        local holder = m
        if #options > MAXROWS then
            local clip = CreateFrame("Frame", nil, m)
            clip:SetPoint("TOPLEFT", 0, 0) clip:SetPoint("BOTTOMRIGHT", 0, 0)
            clip:SetClipsChildren(true)
            holder = CreateFrame("Frame", nil, clip)
            holder:SetPoint("TOPLEFT") holder:SetPoint("TOPRIGHT")
            holder:SetHeight(#options * 20 + 4)
            local offset, maxOff = 0, (#options - MAXROWS) * 20
            -- start scrolled to the current choice
            for i, o in ipairs(options) do
                if o.value == get() then offset = math.min(maxOff, math.max(0, (i - 3) * 20)) end
            end
            local function place()
                holder:ClearAllPoints()
                holder:SetPoint("TOPLEFT", 0, offset) holder:SetPoint("TOPRIGHT", 0, offset)
            end
            place()
            m:EnableMouseWheel(true)
            m:SetScript("OnMouseWheel", function(_, delta)
                offset = math.max(0, math.min(maxOff, offset - delta * 40))
                place()
            end)
        end
        for i, o in ipairs(options) do
            local it = CreateFrame("Button", nil, holder)
            it:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20)
            it:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * 20)
            it:SetHeight(20)
            local hl = it:CreateTexture(nil, "BACKGROUND")
            hl:SetAllPoints() SetC(hl, C.accentDim) hl:Hide()
            if o.texture then
                -- texture preview: a sample bar behind the name
                local bar = it:CreateTexture(nil, "BORDER")
                bar:SetPoint("TOPLEFT", 1, -2) bar:SetPoint("BOTTOMRIGHT", -1, 2)
                bar:SetTexture(o.texture)
                bar:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.35)
            end
            local t = L.Text(it, 12, o.value == get() and C.accent or C.text)
            t:SetPoint("LEFT", 6, 0)
            t:SetPoint("RIGHT", -4, 0)
            t:SetText(o.text)
            if o.font then
                -- font preview: the name written in that font (falls back if it won't load)
                if not pcall(t.SetFont, t, o.font, 13, "") then t:SetFont(L.FONT, 12, "") end
                local file = o.font
                C_Timer.After(0.1, function() pcall(t.SetFont, t, file, 13, "") t:SetText(o.text) end)
            end
            it:SetScript("OnEnter", function() hl:Show() end)
            it:SetScript("OnLeave", function() hl:Hide() end)
            it:SetScript("OnClick", function()
                set(o.value)
                f.Refresh()
                CloseMenu()
            end)
        end
        m:Show()
        openMenu = m
    end)
    f:SetScript("OnHide", function() if openMenu and openMenu.owner == b then CloseMenu() end end)
    f.Refresh()
    return f
end

------------------------------------------------------------------------
-- Edit box
------------------------------------------------------------------------
function L.EditBox(parent, w, h)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w or 200, h or 22)
    e:SetAutoFocus(false)
    e:SetFont(L.FONT, 12, "")
    e:SetTextColor(C.text[1], C.text[2], C.text[3])
    e:SetTextInsets(6, 6, 0, 0)
    L.Skin(e, C.panel2)
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(s) L.SetBorderColor(s, C.accent[1], C.accent[2], C.accent[3]) end)
    e:SetScript("OnEditFocusLost", function(s) L.SetBorderColor(s, C.border[1], C.border[2], C.border[3]) end)
    return e
end

------------------------------------------------------------------------
-- Shift-click links into Lifeline edit boxes
-- When you shift-click a spell (spellbook, action bar, tooltip...) the game
-- calls ChatEdit_InsertLink. We post-hook it: if one of our boxes has focus,
-- the spell's name goes into that box.
------------------------------------------------------------------------
local linkTarget, lostAt, lastLink, lastLinkTime

-- mode: "replace" (box becomes the spell name) or "insert" (add at cursor);
-- may be a function returning one of those. onLink(box, name) runs after.
function L.AcceptLinks(e, mode, onLink)
    e.__linkMode, e.__onLink = mode, onLink
    e:HookScript("OnEditFocusGained", function(s) linkTarget = s lostAt = nil end)
    e:HookScript("OnEditFocusLost", function(s) if linkTarget == s then lostAt = GetTime() end end)
end

-- withRank: a rank lower than your best one comes back as "Renew(Rank 1)"
local function LinkToName(link, withRank)
    local id = tonumber(link:match("|Hspell:(%d+)"))
    if id and C_Spell and C_Spell.GetSpellName then
        local name = L.Readable(C_Spell.GetSpellName(id))
        if name then
            if withRank and C_Spell.GetSpellSubtext and C_Spell.GetSpellInfo then
                local sub = L.Readable(C_Spell.GetSpellSubtext(id))
                local best = C_Spell.GetSpellInfo(name)
                local bestID = best and L.Readable(best.spellID)
                if type(sub) == "string" and sub:match("%d+") and bestID and bestID ~= id then
                    return ("%s(%s)"):format(name, sub)
                end
            end
            return name
        end
    end
    return link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]")
end

local function OnInsertLink(link)
    if type(link) ~= "string" or not linkTarget then return end
    local e = linkTarget
    if not e:IsVisible() then return end
    -- clicking the spellbook can steal focus a moment before the link arrives
    if not e:HasFocus() and not (lostAt and GetTime() - lostAt < 0.5) then return end
    -- some clients route one click through two insert functions; only take it once
    local now = GetTime()
    if link == lastLink and now == lastLinkTime then return end
    lastLink, lastLinkTime = link, now

    local name = LinkToName(link, e.__withRank)
    if not name or name == "" then return end
    local mode = e.__linkMode
    if type(mode) == "function" then mode = mode() end
    if mode == "insert" then
        e:SetFocus()
        e:Insert(name)
    else
        e:SetText(name)
        e:SetCursorPosition(#name)
    end
    if e.__onLink then e.__onLink(e, name) end
end

if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", OnInsertLink) end
if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink) end

------------------------------------------------------------------------
-- Section header with accent tick
------------------------------------------------------------------------
function L.Header(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(500, 22)
    local tick = f:CreateTexture(nil, "ARTWORK")
    tick:SetSize(3, 14)
    tick:SetPoint("LEFT")
    SetC(tick, C.accent)
    local t = L.Text(f, 13, C.text)
    t:SetPoint("LEFT", tick, "RIGHT", 8, 0)
    t:SetText(text)
    f.text = t
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", t, "RIGHT", 10, 0)
    line:SetPoint("RIGHT")
    SetC(line, C.border)
    return f
end

------------------------------------------------------------------------
-- Yes / no dialog in the Lifeline style
------------------------------------------------------------------------
local dialog
function L.Confirm(title, text, yesLabel, noLabel, onYes, onNo)
    if not dialog then
        dialog = CreateFrame("Frame", "LifelineConfirmDialog", UIParent)
        dialog:SetSize(380, 170)
        dialog:SetPoint("CENTER", 0, 120)
        dialog:SetFrameStrata("DIALOG")
        dialog:SetToplevel(true)
        dialog:EnableMouse(true)
        L.Skin(dialog, C.bg, C.border)
        local bar = dialog:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", 1, -1)
        bar:SetPoint("TOPRIGHT", -1, -1)
        bar:SetHeight(2)
        SetC(bar, C.accent)
        dialog.title = L.Text(dialog, 14, C.text)
        dialog.title:SetPoint("TOPLEFT", 16, -16)
        dialog.body = L.Text(dialog, 12, C.muted)
        dialog.body:SetPoint("TOPLEFT", 16, -42)
        dialog.body:SetWidth(348)
        dialog.body:SetWordWrap(true)
        dialog.body:SetSpacing(2)
        dialog.yes = L.Button(dialog, "", 120, 26, function()
            dialog:Hide()
            if dialog.onYes then dialog.onYes() end
        end, true)
        dialog.yes:SetPoint("BOTTOMRIGHT", -16, 14)
        dialog.no = L.Button(dialog, "", 120, 26, function()
            dialog:Hide()
            if dialog.onNo then dialog.onNo() end
        end)
        dialog.no:SetPoint("RIGHT", dialog.yes, "LEFT", -8, 0)
        tinsert(UISpecialFrames, "LifelineConfirmDialog")
    end
    dialog.title:SetText(title)
    dialog.body:SetText(text)
    dialog.yes.text:SetText(yesLabel or "Yes")
    dialog.no.text:SetText(noLabel or "No")
    dialog.onYes, dialog.onNo = onYes, onNo
    dialog:SetHeight(math.max(150, dialog.body:GetStringHeight() + 100))
    dialog:Show()
end

------------------------------------------------------------------------
-- Scroll area with a slim Lifeline-style scroll bar (instead of the game's
-- gray arrow buttons). The bar sits just right of the area and only shows
-- when there is something to scroll. Mouse wheel scrolls, the thumb drags.
------------------------------------------------------------------------
function L.ScrollFrame(parent)
    local s = CreateFrame("ScrollFrame", nil, parent)
    s:EnableMouseWheel(true)

    local track = CreateFrame("Frame", nil, parent)
    track:SetWidth(4)
    track:SetPoint("TOPLEFT", s, "TOPRIGHT", 6, 0)
    track:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", 6, 0)
    local tbg = track:CreateTexture(nil, "BACKGROUND")
    tbg:SetAllPoints()
    SetC(tbg, C.panel2)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(4)
    thumb:EnableMouse(true)
    local tt = thumb:CreateTexture(nil, "ARTWORK")
    tt:SetAllPoints()
    SetC(tt, C.border)
    thumb:SetScript("OnEnter", function() SetC(tt, C.accent) end)
    thumb:SetScript("OnLeave", function() if not thumb.dragging then SetC(tt, C.border) end end)
    s.track, s.thumb = track, thumb

    local function range() return math.max(0, (s.GetVerticalScrollRange and s:GetVerticalScrollRange()) or 0) end
    local function update()
        local r = range()
        local h = s:GetHeight() or 0
        if r <= 0.5 or h <= 0 then track:Hide() return end
        track:Show()
        local th = math.max(16, h * h / (h + r))
        thumb:SetHeight(th)
        local cur = s:GetVerticalScroll() or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -((h - th) * (cur / r)))
    end
    local function scrollTo(v)
        s:SetVerticalScroll(math.max(0, math.min(range(), v)))
        update()
    end
    s.ScrollToTop = function() scrollTo(0) end
    s.UpdateBar = update
    s:SetScript("OnMouseWheel", function(_, delta) scrollTo((s:GetVerticalScroll() or 0) - delta * 40) end)
    s:SetScript("OnScrollRangeChanged", update)
    s:SetScript("OnVerticalScroll", update)
    s:SetScript("OnSizeChanged", update)

    -- drag the thumb
    thumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        local _, y = GetCursorPosition()
        self.startY, self.startScroll = y / self:GetEffectiveScale(), s:GetVerticalScroll() or 0
        self:SetScript("OnUpdate", function()
            local _, cy = GetCursorPosition()
            cy = cy / self:GetEffectiveScale()
            local h, th = s:GetHeight(), self:GetHeight()
            local free = math.max(1, h - th)
            scrollTo(self.startScroll + (self.startY - cy) / free * range())
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        if not self:IsMouseOver() then SetC(tt, C.border) end
    end)
    track:Hide()
    return s
end
