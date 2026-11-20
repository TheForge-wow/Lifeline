--[[
    Lifeline - Debug report window (/ll debug)

    Shows the debug report in a box with the text already selected, so a
    player only has to press Ctrl+C and paste it in Discord. Copying from the
    chat box is hard for newer players; this is the easy way.
]]

local ADDON, L = ...
local C = L.C

local win

local function SelectAll()
    win.box:SetFocus()
    win.box:HighlightText()
end

local function Create()
    win = CreateFrame("Frame", "LifelineDebugReport", UIParent)
    win:SetSize(560, 440)
    win:SetPoint("CENTER", 0, 40)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    L.Skin(win, C.bg, C.border)
    tinsert(UISpecialFrames, "LifelineDebugReport")

    local bar = win:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1) bar:SetPoint("TOPRIGHT", -1, -1) bar:SetHeight(2)
    L.SetC(bar, C.accent)
    local logo = win:CreateTexture(nil, "ARTWORK")
    logo:SetSize(24, 24)
    logo:SetPoint("TOPLEFT", 14, -12)
    logo:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\icon")
    local title = L.Text(win, 15)
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("Lifeline")
    local sub = L.Text(win, 12, C.accent)
    sub:SetPoint("LEFT", title, "RIGHT", 8, -1)
    sub:SetText("debug report")

    local note = L.Text(win, 12, C.muted)
    note:SetPoint("TOPLEFT", 16, -48)
    note:SetWidth(528)
    note:SetWordWrap(true)
    note:SetJustifyH("LEFT")
    note:SetText("The text is already selected. Press |cff4cd98cCtrl+C|r to copy it, then paste it in Discord with |cff4cd98cCtrl+V|r.")

    local holder = CreateFrame("Frame", nil, win)
    holder:SetPoint("TOPLEFT", 16, -72)
    holder:SetPoint("BOTTOMRIGHT", -16, 52)
    L.Skin(holder, C.panel2)
    local scroll = L.ScrollFrame(holder)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -16, 8)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetAutoFocus(false)
    box:SetFont(L.FONT, 11, "")
    box:SetTextColor(C.text[1], C.text[2], C.text[3])
    box:SetWidth(500)
    -- read-only: typing puts the report back and keeps it selected
    box:SetScript("OnTextChanged", function(s, user)
        if user and win.text then s:SetText(win.text) s:HighlightText() end
    end)
    box:SetScript("OnEscapePressed", function() win:Hide() end)
    scroll:SetScrollChild(box)
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", SelectAll)
    win.box, win.scroll = box, scroll

    local sel = L.Button(win, "Select all", 110, 26, SelectAll, true)
    sel:SetPoint("BOTTOMLEFT", 16, 14)
    local close = L.Button(win, "Close", 100, 26, function() win:Hide() end)
    close:SetPoint("LEFT", sel, "RIGHT", 8, 0)
    win:SetScript("OnHide", function() box:ClearFocus() end)
end

function L:DebugWindow_Show(text)
    if not win then Create() end
    win.text = text
    win.box:SetText(text)
    win:Show()
    if win.scroll.ScrollToTop then win.scroll.ScrollToTop() end
    SelectAll()
end
