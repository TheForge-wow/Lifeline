--[[
    Lifeline - Settings pages: Click-Casting
    Shared helpers come from OptionsCore.lua (L.Opt); the sidebar order is
    in OptionsSections.lua.
]]

local _, L = ...
local C = L.C
local O = L.Opt
local Bind, Track = O.Bind, O.Track
local DB, PARTY, RAID, PETS = O.DB, O.PARTY, O.RAID, O.PETS
local NewPage, Check, Slider, Drop, Note = O.NewPage, O.Check, O.Slider, O.Drop, O.Note
local GrowthOptions, ORIENT, pct = O.GrowthOptions, O.ORIENT, O.pct


local function BuildClickCast()
    local p = NewPage("Click-Casting")
    local cc = function() return L.cdb.clickCast end
    p:Head("Click-casting (this character)", nil)
    local en = L.Check(p, "Enable click-casting", function() return L.cdb.clickCast.enabled end,
        function(v) L.cdb.clickCast.enabled = v L:ClickCast_Apply() end)
    en:SetWidth(270)
    p:Add(Track(en), 1, 4)

    if L.CliqueOwnsClicks() then
        p:Sync()
        Note(p, 1, "|cffffd100Clique is installed|r - Lifeline frames are registered with Clique and it handles your bindings. Left click still targets and right click opens the menu.", 560)
        return
    end

    p:Sync()

    local sr = L.Dropdown(p, "Smart resurrection", L.CC_SMARTRES,
        function() return L.cdb.clickCast.smartRes or "OFF" end,
        function(v) L.cdb.clickCast.smartRes = v L:ClickCast_Apply() end, 260)
    p:Add(Track(sr), 1, 6)

    -- self-cast key clash warning (only shown while there is one)
    local warn = CreateFrame("Frame", nil, p)
    warn:SetSize(270, 40)
    L.Skin(warn, { 0.902, 0.341, 0.341, 0.10 }, { 0.902, 0.341, 0.341, 0.6 })
    local wt = L.Text(warn, 11, C.text)
    wt:SetPoint("TOPLEFT", 8, -6)
    wt:SetWidth(170)
    wt:SetWordWrap(true)
    local wb = L.Button(warn, "Turn off", 76, 22, function() L:CC_DisableSelfCastKey() end)
    wb:SetPoint("RIGHT", -8, 0)
    warn.Refresh = function()
        local hits, _, keyName = L:CC_SelfCastConflicts()
        warn:SetShown(hits ~= nil)
        if hits then wt:SetText(("%s is your self-cast key - %d binding%s will cast on you."):format(keyName, #hits, #hits == 1 and "" or "s")) end
    end
    p:Add(Track(warn), 2, 6)
    p:Sync()

    -- other unit frames that get the same bindings
    local other = CreateFrame("Frame", nil, p)
    other:SetSize(560, 22)
    local ol = L.Text(other, 12, C.muted)
    ol:SetPoint("LEFT")
    ol:SetText("Also on:")
    local ox = 62
    local otherChecks = {}
    for _, e in ipairs({ { "player", "Player frame" }, { "target", "Target frame" }, { "focus", "Focus frame" },
            { "addons", "Other addons' frames" } }) do
        local c = L.Check(other, e[2], function() return L.cdb.clickCast.otherFrames[e[1]] end,
            function(v) L.cdb.clickCast.otherFrames[e[1]] = v L:ClickCast_Apply() end,
            e[1] == "addons" and "Unit frames from other addons that support click-casting addons like Clique." or nil)
        c:SetWidth(e[1] == "addons" and 160 or 110)
        c:SetPoint("LEFT", ox, 0)
        ox = ox + (e[1] == "addons" and 160 or 112)
        otherChecks[#otherChecks + 1] = c
    end
    other.Refresh = function() for _, c in ipairs(otherChecks) do if c.Refresh then c.Refresh() end end end
    p:Add(Track(other), 1, 8)
    p:Sync()

    -- modifier selector
    local modSel = ""
    local modButtons = {}
    local bar = CreateFrame("Frame", nil, p)
    bar:SetSize(560, 24)
    p:Add(bar, 1, 10)
    p:Sync()

    local rows = {}
    local rebuildRows
    local function refreshRows()
        if rebuildRows then rebuildRows() end
        for _, r in ipairs(rows) do r.Refresh() end
        for k, b in pairs(modButtons) do
            local on = (k == modSel)
            b.text:SetTextColor(on and C.accent[1] or C.text[1], on and C.accent[2] or C.text[2], on and C.accent[3] or C.text[3])
            L.SetC(b.__bg, on and C.accentDim or C.panel2)
        end
    end

    local x = 0
    for _, mod in ipairs(L.CC_MODS) do
        local label = mod.key == "" and "No modifier" or mod.label:gsub(" %+ $", "")
        local b = L.Button(bar, label, 100, 22, function() modSel = mod.key refreshRows() end)
        b:SetPoint("LEFT", x, 0)
        x = x + 106
        modButtons[mod.key] = b
    end

    -- rows live in a scroll area so any number of mouse buttons fit
    local holder = CreateFrame("Frame", nil, p)
    holder:SetSize(580, 166)
    local scroll = L.ScrollFrame(holder)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -14, 0)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(556, 10)
    scroll:SetScrollChild(list)
    p:Add(holder, 1, 8)
    p:Sync()

    local function NewRow(i)
        local row = CreateFrame("Frame", nil, list)
        row:SetSize(556, 26)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 30)
        local lbl = L.Text(row, 12)
        lbl:SetPoint("LEFT")
        lbl:SetWidth(108)

        local function key() return modSel .. row.btn.key end
        local function bind() return cc().bindings[key()] end

        local dd = L.Dropdown(row, "", L.CC_TYPES,
            function() local b = row.btn and bind() return b and b.type or "none" end,
            function(v)
                if v == "none" then
                    if modSel == "" and (row.btn.key == "BUTTON1" or row.btn.key == "BUTTON2") then
                        cc().bindings[key()] = { type = "none" }
                    else
                        cc().bindings[key()] = nil
                    end
                else
                    local old = bind()
                    cc().bindings[key()] = { type = v, value = old and old.value,
                        autoTarget = (v == "spell" and old and old.autoTarget) or nil }
                end
                row.Refresh()
                L:ClickCast_Apply()
                warn.Refresh()
            end, 186)
        dd:SetHeight(22)
        dd.label:Hide()
        dd:SetPoint("LEFT", 112, 0)

        local edit = L.EditBox(row, 130, 22)
        edit:SetPoint("LEFT", 306, 0)
        local function setValue(b, text)
            if b.type == "spell" then L:CC_SetSpellValue(b, text) else b.value = text end
            row.Refresh()
            L:ClickCast_Apply()
        end
        edit:SetScript("OnEnterPressed", function(s)
            local b = bind()
            if b then setValue(b, s:GetText()) end
            s:ClearFocus()
        end)
        edit:SetScript("OnEditFocusLost", function(s)
            L.SetBorderColor(s, C.border[1], C.border[2], C.border[3])
            local b = bind()
            if b and (b.type == "spell" or b.type == "macro") and b.value ~= s:GetText() then
                setValue(b, s:GetText())
            end
        end)
        edit.__withRank = true

        -- rank lock: only for spell bindings that name a rank
        local lock = L.Button(row, "", 42, 22, function()
            local b = bind()
            if not b then return end
            b.fixedRank = (not b.fixedRank) or nil
            row.Refresh()
            L:ClickCast_Apply()
        end)
        lock:SetPoint("LEFT", 440, 0)
        lock:HookScript("OnEnter", function(self)
            local b = bind()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if b and b.fixedRank then
                GameTooltip:AddLine("Rank locked", 1, 0.82, 0)
                GameTooltip:AddLine("Always casts the rank you typed. Click to auto-upgrade to your highest rank instead.", nil, nil, nil, true)
            else
                GameTooltip:AddLine("Auto rank", C.accent[1], C.accent[2], C.accent[3])
                GameTooltip:AddLine("Casts your highest known rank, including ranks you train later. Click to lock the rank you typed.", nil, nil, nil, true)
            end
            GameTooltip:Show()
        end)
        lock:HookScript("OnLeave", function() GameTooltip:Hide() end)

        -- auto target: also make the player your target when this spell is cast
        local tgt = L.Button(row, "Target", 46, 22, function()
            local b = bind()
            if not b then return end
            b.autoTarget = (not b.autoTarget) or nil
            row.Refresh()
            L:ClickCast_Apply()
        end)
        tgt:SetPoint("LEFT", 486, 0)
        tgt:HookScript("OnEnter", function(self)
            local b = bind()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if b and b.autoTarget then
                GameTooltip:AddLine("Auto target: on", C.accent[1], C.accent[2], C.accent[3])
            else
                GameTooltip:AddLine("Auto target: off", 0.6, 0.6, 0.6)
            end
            GameTooltip:AddLine("When on, this binding also makes the player your target as it casts. Your old target is replaced. Click to switch.", nil, nil, nil, true)
            GameTooltip:Show()
        end)
        tgt:HookScript("OnLeave", function() GameTooltip:Hide() end)
        -- shift-click a spell into the box: spell rows take the name,
        -- macro rows get it inserted at the cursor (e.g. after "/cast ")
        L.AcceptLinks(edit,
            function() local b = bind() return (b and b.type == "macro") and "insert" or "replace" end,
            function(s)
                local b = bind()
                if b and b.type == "spell" then
                    s:ClearFocus()
                    setValue(b, s:GetText())
                end
            end)

        local del = L.Button(row, "x", 22, 22, function()
            if row.btn and row.btn.extraNum then
                L.CloseMenu()
                L:CC_RemoveButton(row.btn.extraNum)
                refreshRows()
            end
        end)
        del:SetPoint("LEFT", 534, 0)
        del.text:SetTextColor(C.danger[1], C.danger[2], C.danger[3])

        row.Refresh = function()
            if not row.btn then row:Hide() return end
            row:Show()
            lbl:SetText(row.btn.label)
            dd.Refresh()
            local b = bind()
            local needs = b and (b.type == "spell" or b.type == "macro")
            edit:SetShown(needs and true or false)
            if not edit:HasFocus() then edit:SetText(needs and (b.value or "") or "") end
            local ranked = b and b.type == "spell" and L:CC_HasRank(b.value)
            lock:SetShown(ranked and true or false)
            if ranked then
                if b.fixedRank then
                    lock.text:SetText("Fixed") lock.text:SetTextColor(1, 0.82, 0)
                else
                    lock.text:SetText("Auto") lock.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
                end
            end
            local isSpell = b and b.type == "spell"
            tgt:SetShown(isSpell and true or false)
            if isSpell then
                if b.autoTarget then tgt.text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
                else tgt.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end
                L.SetC(tgt.__bg, b.autoTarget and C.accentDim or C.panel2)
            end
            del:SetShown(row.btn.extraNum ~= nil)
        end
        return row
    end

    -- add-a-button row
    local addRow = CreateFrame("Frame", nil, p)
    addRow:SetSize(560, 24)
    local addLbl = L.Text(addRow, 12, C.muted)
    addLbl:SetPoint("LEFT")
    addLbl:SetText("More mouse buttons:")
    local addChoice
    local addOpts = {}
    local addDD = L.Dropdown(addRow, "", addOpts, function() return addChoice end,
        function(v) addChoice = v end, 140)
    addDD:SetHeight(24)
    addDD.label:Hide()
    addDD:SetPoint("LEFT", 136, 0)
    local addBtn = L.Button(addRow, "Add Button", 100, 24, function()
        if addChoice then
            L:CC_AddButton(addChoice)
            refreshRows()
        end
    end, true)
    addBtn:SetPoint("LEFT", addDD, "RIGHT", 8, 0)
    p:Add(addRow, 1, 8)
    p:Sync()

    -- presets: named sets of bindings for this class
    local preRow = CreateFrame("Frame", nil, p)
    preRow:SetSize(560, 24)
    local preLbl = L.Text(preRow, 12, C.muted)
    preLbl:SetPoint("LEFT")
    preLbl:SetText("Presets:")
    local preChoice
    local preOpts = {}
    local preDD = L.Dropdown(preRow, "", preOpts, function() return preChoice end,
        function(v) preChoice = v end, 150)
    preDD:SetHeight(24)
    preDD.label:Hide()
    preDD:SetPoint("LEFT", 62, 0)
    local function refreshPresets()
        wipe(preOpts)
        for _, n in ipairs(L:CC_PresetNames()) do preOpts[#preOpts + 1] = { value = n, text = n } end
        if #preOpts == 0 then preOpts[1] = { value = nil, text = "No presets yet" } end
        local found = false
        for _, o in ipairs(preOpts) do if o.value == preChoice then found = true end end
        if not found then preChoice = preOpts[1].value end
        preDD.Refresh()
    end
    local loadBtn = L.Button(preRow, "Load", 50, 24, function()
        if preChoice and L:CC_LoadPreset(preChoice) then refreshRows() end
    end)
    loadBtn:SetPoint("LEFT", preDD, "RIGHT", 6, 0)
    local delBtn = L.Button(preRow, "Delete", 56, 24, function()
        if preChoice and L:CC_DeletePreset(preChoice) then preChoice = nil refreshPresets() end
    end)
    delBtn:SetPoint("LEFT", loadBtn, "RIGHT", 4, 0)
    local nameBox = L.EditBox(preRow, 120, 24)
    nameBox:SetPoint("LEFT", delBtn, "RIGHT", 14, 0)
    local nameHint = L.Text(nameBox, 12, C.muted)
    nameHint:SetPoint("LEFT", 6, 0)
    nameHint:SetText("New preset name")
    nameBox:HookScript("OnTextChanged", function(s2) nameHint:SetShown(s2:GetText() == "") end)
    local function doSave()
        local n = nameBox:GetText()
        if L:CC_SavePreset(n) then
            preChoice = n:match("^%s*(.-)%s*$"):sub(1, 40)
            nameBox:SetText("") nameBox:ClearFocus()
            refreshPresets()
        end
    end
    nameBox:SetScript("OnEnterPressed", doSave)
    local saveBtn = L.Button(preRow, "Save", 56, 24, doSave, true)
    saveBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
    preRow.Refresh = refreshPresets
    p:Add(Track(preRow), 1, 8)
    p:Sync()

    local function refreshAddOptions()
        wipe(addOpts)
        local have = {}
        for _, n in ipairs(cc().extraButtons or {}) do have[n] = true end
        for n = L.CC_EXTRA_MIN, L.CC_EXTRA_MAX do
            if not have[n] then addOpts[#addOpts + 1] = { value = n, text = "Button " .. n } end
        end
        if not (addChoice and not have[addChoice]) then addChoice = addOpts[1] and addOpts[1].value end
        addDD.Refresh()
        addBtn:SetShown(#addOpts > 0)
        addDD:SetShown(#addOpts > 0)
    end

    rebuildRows = function()
        local btns = L:CC_GetButtons()
        for i, btn in ipairs(btns) do
            rows[i] = rows[i] or NewRow(i)
            rows[i].btn = btn
        end
        for i = #btns + 1, #rows do rows[i].btn = nil end
        list:SetHeight(math.max(10, #btns * 30))
        refreshAddOptions()
    end

    p:SetScript("OnShow", function() refreshRows() end)
    Note(p, 1, "Type or shift-click a spell. A plain name casts your highest rank; a rank like |cffffffffRenew(Rank 1)|r is kept (Fixed / Auto switches). Turn on |cffffffffTarget|r to also target the player as you cast. Wheel and Buttons 6+ work while your cursor is on a frame. Combat changes apply after combat.", 560)
    refreshRows()
end

-- register the pages (OptionsSections.lua puts them in order)
O.PAGE_BUILDERS["Click-Casting"] = BuildClickCast
