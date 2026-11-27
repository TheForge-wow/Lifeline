--[[
    Lifeline - Settings page: Controller (healer mode)
    Shared helpers come from OptionsCore.lua (L.Opt); the sidebar order is
    in OptionsSections.lua.
]]

local _, L = ...
local C = L.C
local O = L.Opt
local Track = O.Track
local NewPage, Note = O.NewPage, O.Note

local function PAD() return L.cdb.controller end

local function BuildController()
    local p = NewPage("Controller")
    p:Head("Controller healer mode (this character)", nil)

    local mode = L.Dropdown(p, "Healer mode", L.PAD_MODES,
        function() return PAD().mode or "OFF" end,
        function(v) PAD().mode = v L:Pad_Apply(true) end, 260)
    p:Add(Track(mode), 1, 10)

    local tog = L.Dropdown(p, "Toggle button", L.PAD_TOGGLE_KEYS,
        function() return PAD().toggleKey or "" end,
        function(v) PAD().toggleKey = v L:Pad_Apply() end, 260)
    p:Add(Track(tog), 2, 10)

    -- "Auto" shows what it found
    local styles = {}
    for i, o in ipairs(L.PAD_STYLES) do styles[i] = { value = o.value, text = o.text } end
    local NAMES = { XBOX = "Xbox", PS = "PlayStation", NINTENDO = "Nintendo" }
    local pics = L.Dropdown(p, "Button pictures", styles,
        function() return PAD().glyphs or "AUTO" end,
        function(v) PAD().glyphs = v L:Refresh() end, 260)
    local picsRefresh = pics.Refresh
    pics.Refresh = function()
        local found = L:Pad_Detect()
        styles[1].text = found and ("Auto (detected: " .. NAMES[found] .. ")") or "Auto (no controller found)"
        picsRefresh()
    end
    p:Add(Track(pics), 1, 10)

    -- status: is it on right now?
    local status = CreateFrame("Frame", nil, p)
    status:SetSize(260, 44)
    L.Skin(status, C.panel2)
    local st = L.Text(status, 12, C.text)
    st:SetPoint("TOPLEFT", 10, -7)
    st:SetWidth(240)
    st:SetJustifyH("LEFT")
    local st2 = L.Text(status, 11, C.muted)
    st2:SetPoint("TOPLEFT", st, "BOTTOMLEFT", 0, -3)
    st2:SetWidth(240)
    st2:SetJustifyH("LEFT")
    status.Refresh = function()
        local on = L:Pad_IsActive()
        st:SetText(on and "|cff4cd98cHealer mode is on|r" or "Healer mode is off right now")
        local _, dev = L:Pad_Detect()
        st2:SetText(dev and ("Controller: " .. dev) or "No controller found (Game Menu > Options > Controls > Gamepad)")
    end
    p:Add(Track(status), 2, 10)
    p:Sync()

    Note(p, 1, "While healer mode is on, the |cffffffffD-pad|r picks a player on your Lifeline frames (the first press picks you) and the |cfffffffffour face buttons|r cast on the picked player. Face buttons set to \"Nothing\" keep doing what the game gives them. " ..
        "|cffffffffIn combat only|r switches it on as a fight starts and off when it ends. The toggle button flips it at any time, in any mode, in combat too. You can also set the toggle under the game's Key Bindings > Lifeline.", 560)

    if L:Pad_OtherAddon() then
        Note(p, 1, "|cffffd100ControllerForever is installed.|r If its own Healer D-pad is on too, both addons want the same buttons. Use one or the other.", 560)
    end
    p:Space(4)

    p:Head("Face buttons (cast on the picked player)", nil)
    local rows = {}
    for i, face in ipairs(L.PAD_FACES) do
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(560, 28)
        local glyph = L.PadGlyph(row, 24)
        glyph:SetPoint("LEFT", 2, 0)
        local lbl = L.Text(row, 12)
        lbl:SetPoint("LEFT", 34, 0)
        lbl:SetWidth(90)
        lbl:SetJustifyH("LEFT")

        local function bind() return PAD().bindings[face.key] end
        local edit
        local dd = L.Dropdown(row, "", L.PAD_TYPES,
            function() local b = bind() return b and b.type or "none" end,
            function(v)
                if v == "none" then
                    PAD().bindings[face.key] = nil
                else
                    local old = bind()
                    PAD().bindings[face.key] = { type = v, value = old and old.value, fixedRank = old and old.fixedRank }
                end
                row.Refresh()
                L:Pad_Apply()
            end, 180)
        dd:SetHeight(22)
        dd.label:Hide()
        dd:SetPoint("LEFT", 128, 0)

        edit = L.EditBox(row, 240, 22)
        edit:SetPoint("LEFT", 316, 0)
        local function setValue(b, text)
            if b.type == "spell" then L:CC_SetSpellValue(b, text) else b.value = text end
            row.Refresh()
            L:Pad_Apply()
        end
        edit:SetScript("OnEnterPressed", function(s)
            local b = bind()
            if b then setValue(b, s:GetText()) end
            s:ClearFocus()
        end)
        edit:SetScript("OnEditFocusLost", function(s)
            L.SetBorderColor(s, C.border[1], C.border[2], C.border[3])
            local b = bind()
            if b and (b.type == "spell" or b.type == "macro") and b.value ~= s:GetText() then setValue(b, s:GetText()) end
        end)
        edit.__withRank = true
        L.AcceptLinks(edit,
            function() local b = bind() return (b and b.type == "macro") and "insert" or "replace" end,
            function(s)
                local b = bind()
                if b and b.type == "spell" then s:ClearFocus() setValue(b, s:GetText()) end
            end)

        row.Refresh = function()
            glyph:Set(face)
            lbl:SetText(L:Pad_FaceLabel(face) .. "  |cff8c93a0" .. face.pos .. "|r")
            dd.Refresh()
            local b = bind()
            local needs = b and (b.type == "spell" or b.type == "macro")
            edit:SetShown(needs and true or false)
            if not edit:HasFocus() then edit:SetText(needs and (b.value or "") or "") end
        end
        p:Add(Track(row), 1, 4)
        rows[i] = row
    end
    p:Sync()
    Note(p, 1, "Spells cast your highest rank unless you type one (\"Renew(Rank 2)\"). Smart resurrection from Click-Casting works here too. In macro text, |cffffffff@mouseover|r becomes the picked player.", 560)
    p:Space(4)

    p:Head("D-pad", nil)
    Note(p, 1, "Up, Down, Left and Right move the pick to the nearest frame that way, wrapping around to the other end of the column or row. The picked frame gets a green outline. " ..
        "Face button presses do nothing until someone is picked.", 560)
end

O.PAGE_BUILDERS["Controller"] = BuildController
