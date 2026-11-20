--[[
    Lifeline - Settings pages: Layout: Party & Raid, Tank Frames
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


local function BuildLayout()
    local p = NewPage("Layout")
    p:Head("Party (2-5)", 1)
    local partyGrowth = GrowthOptions(PARTY)
    local pg
    local po = Drop(p, 1, "Orientation", ORIENT, PARTY, "orientation", true)
    pg = Drop(p, 1, "Growth direction", partyGrowth, PARTY, "growth", true)
    local function relabelParty() partyGrowth.Relabel() pg.Refresh() end
    hooksecurefunc(po, "Refresh", relabelParty)
    Slider(p, 1, "Width", 40, 220, 1, PARTY, "width", true)
    Slider(p, 1, "Height", 20, 120, 1, PARTY, "height", true)
    Slider(p, 1, "Spacing", 0, 20, 1, PARTY, "spacing", true)

    p:Head("Sorting (party & raid)", 1)
    Drop(p, 1, "Sort members by", {
        { value = "INDEX", text = "Group order" },
        { value = "NAME",  text = "Name" },
        { value = "ROLE",  text = "Role (tank, healer, damage)" },
    }, DB, "sortBy", true)

    p:Head("Raid sizes", 1)
    local SIZES = {
        { value = "raid",   text = "Up to 10 players" },
        { value = "raid20", text = "11 to 20 players" },
        { value = "raid40", text = "21 to 40 players" },
    }
    local raidHead
    local sizeDD
    local bySize = L.Check(p, "Separate layouts by raid size", function() return L.db.raidBySize end,
        function(v)
            L.db.raidBySize = v
            if not v then O.raidEdit = "raid" end
            L:Refresh(true)
        end, "Give 10, 20 and 40-player raids their own size, spacing and layout. Lifeline switches when the raid crosses 10 or 20 players (after combat).")
    bySize:SetWidth(270)
    p:Add(Track(bySize), 1, 4)
    sizeDD = L.Dropdown(p, "Editing the raid layout for", SIZES, function() return O.raidEdit end,
        function(v)
            if not L.db.raidBySize then L:Print("Turn on \"Separate layouts by raid size\" first.") return end
            O.raidEdit = v
            L:Options_RefreshControls()
            if L.Example_Refresh then L:Example_Refresh() end
        end, 260)
    local oldRefresh = sizeDD.Refresh
    sizeDD.Refresh = function()
        oldRefresh()
        sizeDD:SetAlpha(L.db.raidBySize and 1 or 0.4)
        if raidHead then
            local label = "Raid (6-40)"
            if L.db.raidBySize then
                for _, o in ipairs(SIZES) do if o.value == O.raidEdit then label = "Raid - " .. o.text:lower() end end
            end
            raidHead.text:SetText(label)
        end
    end
    p:Add(Track(sizeDD), 1, 10)

    raidHead = p:Head("Raid (6-40)", 2)
    Drop(p, 2, "Group layout", {
        { value = "GROUP", text = "One column per group" },
        { value = "ROLE",  text = "Combined, by role" },
        { value = "CLASS", text = "Combined, by class" },
        { value = "NONE",  text = "Combined, raid order" },
    }, RAID, "groupBy", true)
    local raidGrowth = GrowthOptions(RAID)
    local rg
    local ro = Drop(p, 2, "Orientation", ORIENT, RAID, "orientation", true)
    rg = Drop(p, 2, "Growth direction", raidGrowth, RAID, "growth", true)
    hooksecurefunc(ro, "Refresh", function() raidGrowth.Relabel() rg.Refresh() end)
    Slider(p, 2, "Width", 30, 200, 1, RAID, "width", true)
    Slider(p, 2, "Height", 16, 100, 1, RAID, "height", true)
    Slider(p, 2, "Spacing", 0, 20, 1, RAID, "spacing", true)
    Slider(p, 2, "Gap between groups", 0, 40, 1, RAID, "groupSpacing", true)
    Slider(p, 2, "Members per column (combined)", 1, 40, 1, RAID, "unitsPerColumn", true)
    Check(p, 2, "Group labels (Group 1, Group 2...)", DB, "groupLabels", false,
        "Shows the group number next to each raid group when the raid is laid out one column per group.")
end

local function BuildTanks()
    local p = NewPage("Tank Frames")
    local function T() return L.db.tanks end
    p:Head("Tank frames (raids)", 1)
    Check(p, 1, "Show tank frames", T, "enabled", true,
        "A separate small group, with its own mover, that keeps your tanks in one place. Unlock frames to move it.")
    Drop(p, 1, "Who to show", {
        { value = "TANKS", text = "Tanks and main tanks / assists" },
        { value = "NAMES", text = "Players I list" },
    }, T, "mode", true)
    do
        local box = CreateFrame("Frame", nil, p)
        box:SetSize(260, 44)
        local lbl = L.Text(box, 12)
        lbl:SetPoint("TOPLEFT")
        lbl:SetText("Players (separate with commas)")
        local e = L.EditBox(box, 260, 22)
        e:SetPoint("BOTTOMLEFT")
        local function save(s2)
            local v = s2:GetText() or ""
            if v ~= L.db.tanks.names then L.db.tanks.names = v L:Refresh(true) end
        end
        e:SetScript("OnEnterPressed", function(s2) save(s2) s2:ClearFocus() end)
        e:HookScript("OnEditFocusLost", save)
        box.Refresh = function()
            if not e:HasFocus() then e:SetText(L.db.tanks.names or "") end
            box:SetAlpha(L.db.tanks.mode == "NAMES" and 1 or 0.4)
        end
        p:Add(Track(box), 1, 10)
    end
    local tg = O.GrowthOptions(T)
    local tgd
    local to = Drop(p, 1, "Orientation", O.ORIENT, T, "orientation", true)
    tgd = Drop(p, 1, "Growth direction", tg, T, "growth", true)
    hooksecurefunc(to, "Refresh", function() tg.Relabel() tgd.Refresh() end)

    p:Head("Size", 2)
    Slider(p, 2, "Width", 40, 220, 1, T, "width", true)
    Slider(p, 2, "Height", 16, 100, 1, T, "height", true)
    Slider(p, 2, "Spacing", 0, 20, 1, T, "spacing", true)
    Note(p, 2, "Tanks are players with the Tank role, or set as main tank / main assist by the raid leader. Changes made in combat apply when combat ends.")
end

-- register the pages (OptionsSections.lua puts them in order)
O.PAGE_BUILDERS["Layout"] = BuildLayout
O.PAGE_BUILDERS["Tank Frames"] = BuildTanks
