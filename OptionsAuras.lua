--[[
    Lifeline - Settings pages: Auras: Buffs & Debuffs (+ Debuff Filters), Buff Indicators
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


-- a small list of debuff names / spell IDs with Add and x buttons
function O.ListEditor(p, col, key, title, hint)
    local box = CreateFrame("Frame", nil, p)
    box:SetSize(270, 160)
    local t = L.Text(box, 12)
    t:SetPoint("TOPLEFT")
    t:SetText(title)
    local e = L.EditBox(box, 200, 22)
    e:SetPoint("TOPLEFT", 0, -18)
    local h = L.Text(e, 11, C.muted)
    h:SetPoint("LEFT", 6, 0)
    h:SetText(hint)
    e:HookScript("OnTextChanged", function(s2) h:SetShown(s2:GetText() == "") end)
    local rows = {}
    local scroll = L.ScrollFrame(box)
    scroll:SetPoint("TOPLEFT", 0, -46)
    scroll:SetPoint("BOTTOMRIGHT", -14, 0)
    local holder = CreateFrame("Frame", nil, scroll)
    holder:SetSize(254, 10)
    scroll:SetScrollChild(holder)
    local function refresh()
        local list = L.db[key]
        for i = 1, math.max(#list, #rows) do
            local r = rows[i]
            if not r and list[i] then
                r = CreateFrame("Frame", nil, holder)
                r:SetSize(246, 22)
                r:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
                r.icon = r:CreateTexture(nil, "ARTWORK")
                r.icon:SetSize(18, 18)
                r.icon:SetPoint("LEFT")
                r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                r.text = L.Text(r, 12)
                r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
                r.text:SetWidth(190)
                r.del = L.Button(r, "x", 20, 20, function()
                    table.remove(L.db[key], i)
                    L.CloseMenu()
                    L:Refresh(false)
                    if L.AC_RefreshAll then L:AC_RefreshAll() end
                    box.Refresh()
                end)
                r.del:SetPoint("RIGHT")
                r.del.text:SetTextColor(C.danger[1], C.danger[2], C.danger[3])
                rows[i] = r
            end
            if r then
                local v = list[i]
                r:SetShown(v ~= nil)
                if v then
                    r.icon:SetTexture(L:Ind_SpellIcon(v))
                    local name = L:Ind_SpellName(v)
                    if tonumber(v) and name == v then
                        -- the game doesn't know this spell ID
                        r.text:SetText("|cffe65757Unknown spell|r  |cff949ca8" .. v .. "|r")
                    else
                        r.text:SetText(tonumber(v) and (name .. "  |cff949ca8" .. v .. "|r") or name)
                    end
                end
            end
        end
        holder:SetHeight(math.max(10, #list * 24))
    end
    local function add()
        local v = (e:GetText() or ""):match("^%s*(.-)%s*$")
        if v == "" then return end
        local list = L.db[key]
        if #list >= 40 then L:Print("That list is full (40).") return end
        for _, x in ipairs(list) do if x:lower() == v:lower() then e:SetText("") return end end
        list[#list + 1] = v
        e:SetText("") e:ClearFocus()
        refresh()
        L:Refresh(false)
        if L.AC_RefreshAll then L:AC_RefreshAll() end
    end
    e:SetScript("OnEnterPressed", add)
    L.AcceptLinks(e, "replace")
    local b = L.Button(box, "Add", 60, 22, add, true)
    b:SetPoint("LEFT", e, "RIGHT", 6, 0)
    box.Refresh = refresh
    p:Add(Track(box), col, 8)
end

local function BuildAuras()
    local p = NewPage("Auras")
    p:Head("Debuffs", 1)
    Check(p, 1, "Show debuffs", DB, "showDebuffs", false)
    Slider(p, 1, "Max debuffs", 1, 5, 1, DB, "maxDebuffs", false)
    Slider(p, 1, "Debuff size", 8, 30, 1, DB, "debuffSize", false)

    p:Head("Your buffs & HoTs", 2)
    Check(p, 2, "Show buffs you cast", DB, "showBuffs", false,
        "A row of every buff you cast on the player. Leave it off to see only the buffs you set up as buff indicators.")
    Slider(p, 2, "Max buffs", 1, 5, 1, DB, "maxBuffs", false)
    Slider(p, 2, "Buff size", 8, 30, 1, DB, "buffSize", false)
    p:Sync()
    Note(p, 1, "Your buffs, debuffs and active buff indicators are drawn by the game's own aura containers, so they keep showing in combat.", 560)

    -- debuff filters get their own sub-page (Auras > Debuff Filters)
    p = NewPage("Debuff Filters")
    p:Head("Debuff filters", nil)
    Note(p, 1, "Keep the debuff row clean, and make the debuffs that matter stand out. Everything here uses the game's own checks, so it works in combat.", 560)
    Check(p, 1, "Hide minor debuffs", DB, "debuffRaidOnly", false,
        "The debuff row uses the game's own raid filter. It hides clutter like Recently Bandaged, but also Weakened Soul. Mob debuffs (poisons, curses, slows) still show.")
    Check(p, 1, "Show boss debuffs big in the middle", DB, "bigBossDebuffs", false,
        "Debuffs cast by bosses skip the row and show as a bigger icon in the middle of the frame.")
    Check(p, 1, "Show crowd control big in the middle", DB, "bigCC", false,
        "Stuns, fears, polymorphs and the like show as a bigger icon in the middle of the frame, so you can see which one it is. Uses the game's own crowd-control check, so it works in combat.")
    Slider(p, 2, "Big debuff size", 14, 36, 1, DB, "bigDebuffSize", false)
    p:Sync()
    Note(p, 1, "Why no spell lists? WoW Forever ignores spell IDs for debuffs, so lists of debuffs to hide or show big never worked in a real fight. The dispel highlight already only shows debuffs you can remove.", 560)
end

local function BuildBuffIndicators()
    local p = NewPage("Buff Indicators")
    local function list() return L.cdb.indicators end
    p:Head("Buff indicators (this character)", nil)
    Note(p, 1, "Pick a spell and where its icon sits. |cffffffffMissing|r shows an icon only when the buff isn't there (grayed out, hidden in combat) - great for Fortitude reminders.", 560)
    Drop(p, 1, "Icons at the same spot", {
        { value = true,  text = "Fill from the corner" },
        { value = false, text = "Keep fixed spots (list order)" },
    }, DB, "indicatorFill", false)

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
    local newMode = "MISSING"
    local function doAdd()
        local text = (edit:GetText() or ""):match("^%s*(.-)%s*$")
        if text == "" then return end
        if #list() >= L.IND_MAX then L:Print("You can have up to " .. L.IND_MAX .. " buff indicators.") return end
        table.insert(list(), { spell = text, anchor = "TOPRIGHT", mode = newMode, size = 14 })
        edit:SetText("")
        edit:ClearFocus()
        refreshRows()
        L:Refresh(false)
    end
    edit:SetScript("OnEnterPressed", doAdd)
    L.AcceptLinks(edit, "replace")
    -- choose "show when" up front so a missing-buff reminder is one step
    local modeDD = L.Dropdown(add, "", L.IND_MODES, function() return newMode end,
        function(v) newMode = v end, 190)
    modeDD:SetHeight(24)
    modeDD.label:Hide()
    modeDD:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    local addBtn = L.Button(add, "Add", 70, 24, doAdd, true)
    addBtn:SetPoint("LEFT", modeDD, "RIGHT", 8, 0)
    p:Add(add, 1, 12)
    p:Sync()

    -- column titles
    local cols = CreateFrame("Frame", nil, p)
    cols:SetSize(560, 14)
    local function colText(text, x)
        local t = L.Text(cols, 11, C.muted)
        t:SetPoint("LEFT", x, 0)
        t:SetText(text)
    end
    colText("Spell", 26) colText("Position", 172) colText("Show when", 308) colText("Size", 484)
    p:Add(cols, 1, 4)
    p:Sync()

    for i = 1, L.IND_MAX do
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(570, 26)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local name = L.Text(row, 12)
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetWidth(138)

        local function cur() return list()[i] end
        local function dd(opts, key, x, w)
            local d = L.Dropdown(row, "", opts,
                function() local c = cur() return c and c[key] end,
                function(v) local c = cur() if c then c[key] = v L:Refresh(false) end end, w)
            d:SetHeight(22)
            d.label:Hide()
            d:SetPoint("LEFT", x, 0)
            return d
        end
        local pos  = dd(L.IND_ANCHORS, "anchor", 172, 128)
        local mode = dd(L.IND_MODES,   "mode",   308, 168)
        local size = dd(L.IND_SIZES,   "size",   484, 62)

        local del = L.Button(row, "x", 22, 22, function()
            table.remove(list(), i)
            L.CloseMenu()
            refreshRows()
            L:Refresh(false)
        end)
        del:SetPoint("LEFT", 552, 0)
        del.text:SetTextColor(C.danger[1], C.danger[2], C.danger[3])

        row.Refresh = function(ind)
            row:SetShown(ind ~= nil)
            if not ind then return end
            icon:SetTexture(L:Ind_SpellIcon(ind.spell))
            name:SetText(L:Ind_SpellName(ind.spell))
            pos.Refresh() mode.Refresh() size.Refresh()
        end
        rows[i] = row
        p:Add(row, 1, 4)
    end
    p:Sync()
    p:SetScript("OnShow", refreshRows)
    refreshRows()
end

-- register the pages (OptionsSections.lua puts them in order)
O.PAGE_BUILDERS["Auras"] = BuildAuras
O.PAGE_BUILDERS["Buff Indicators"] = BuildBuffIndicators
