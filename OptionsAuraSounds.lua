--[[
    Lifeline - Settings pages: Auras: Aura Sounds
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


local function BuildAuraSounds()
    local p = NewPage("Aura Sounds")
    local function cfg() return L.cdb.auraSounds end
    local function list() return cfg().list end
    p:Head("Aura sounds (this character)", nil)
    Note(p, 1, "Play a sound when a buff or debuff is gained, fades or gains a stack - for example |cffffffffWeakened Soul|r fading, or a debuff landing on someone. The game plays the sound itself, so it works in combat too. Sound changes made in combat or during a boss fight apply afterwards.", 560)

    local en = L.Check(p, "Play aura sounds", function() return cfg().enabled end,
        function(v) cfg().enabled = v L:Sounds_Request() end)
    en:SetWidth(270)
    p:Add(Track(en), 1, 8)
    p:Sync()
    if not L:Sounds_Available() then
        Note(p, 1, "|cffffd100This game version doesn't offer aura sounds to addons.|r", 560)
    end

    -- add row
    local add = CreateFrame("Frame", nil, p)
    add:SetSize(560, 26)
    local edit = L.EditBox(add, 230, 24)
    edit:SetPoint("LEFT")
    local hint = L.Text(edit, 12, C.muted)
    hint:SetPoint("LEFT", 6, 0)
    hint:SetText("Spell name or ID - or shift-click a spell")
    edit:HookScript("OnTextChanged", function(s) hint:SetShown(s:GetText() == "") end)

    local rows = {}
    local function refreshRows()
        local l = list()
        for i, row in ipairs(rows) do row.Refresh(l[i]) end
    end
    local newTrigger = "REMOVED"
    local function doAdd()
        local text = (edit:GetText() or ""):match("^%s*(.-)%s*$")
        if text == "" then return end
        if #list() >= L.SOUND_MAX then L:Print("You can have up to " .. L.SOUND_MAX .. " aura sounds.") return end
        table.insert(list(), { spell = text, trigger = newTrigger, who = "ALL", sound = "chime" })
        edit:SetText("")
        edit:ClearFocus()
        refreshRows()
        L:Sounds_Request()
    end
    edit:SetScript("OnEnterPressed", doAdd)
    L.AcceptLinks(edit, "replace")
    local trigDD = L.Dropdown(add, "", L.SOUND_TRIGGERS, function() return newTrigger end,
        function(v) newTrigger = v end, 150)
    trigDD:SetHeight(24)
    trigDD.label:Hide()
    trigDD:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    local addBtn = L.Button(add, "Add", 70, 24, doAdd, true)
    addBtn:SetPoint("LEFT", trigDD, "RIGHT", 8, 0)
    p:Add(add, 1, 12)
    p:Sync()

    local cols = CreateFrame("Frame", nil, p)
    cols:SetSize(560, 14)
    local function colText(text, x)
        local t = L.Text(cols, 11, C.muted)
        t:SetPoint("LEFT", x, 0)
        t:SetText(text)
    end
    colText("Spell", 26) colText("When it", 140) colText("On", 258) colText("Sound", 396)
    p:Add(cols, 1, 4)
    p:Sync()

    for i = 1, L.SOUND_MAX do
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(580, 26)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local name = L.Text(row, 12)
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetWidth(108)

        local function cur() return list()[i] end
        local function dd(opts, key, x, w)
            local d = L.Dropdown(row, "", opts,
                function() local c = cur() return c and c[key] end,
                function(v)
                    local c = cur()
                    if c then
                        c[key] = v
                        L:Sounds_Request()
                        if key == "sound" then L:Sounds_Play(v) end
                    end
                end, w)
            d:SetHeight(22)
            d.label:Hide()
            d:SetPoint("LEFT", x, 0)
            return d
        end
        local trig  = dd(L.SOUND_TRIGGERS, "trigger", 140, 112)
        local who   = dd(L.SOUND_WHO,      "who",     258, 132)
        local sound = dd(L.SOUNDS,         "sound",   396, 118)

        local play = L.Button(row, "Play", 36, 22, function()
            local c = cur()
            if c then L:Sounds_Play(c.sound) end
        end)
        play:SetPoint("LEFT", 518, 0)
        local del = L.Button(row, "x", 22, 22, function()
            table.remove(list(), i)
            L.CloseMenu()
            refreshRows()
            L:Sounds_Request()
        end)
        del:SetPoint("LEFT", 558, 0)
        del.text:SetTextColor(C.danger[1], C.danger[2], C.danger[3])

        row.Refresh = function(e)
            row:SetShown(e ~= nil)
            if not e then return end
            icon:SetTexture(L:Ind_SpellIcon(e.spell))
            name:SetText(L:Ind_SpellName(e.spell))
            trig.Refresh() who.Refresh() sound.Refresh()
        end
        rows[i] = row
        p:Add(row, 1, 4)
    end
    p:Sync()
    p:SetScript("OnShow", refreshRows)
    refreshRows()
end

-- register the pages (OptionsSections.lua puts them in order)
O.PAGE_BUILDERS["Aura Sounds"] = BuildAuraSounds
