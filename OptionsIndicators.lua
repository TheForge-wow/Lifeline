--[[
    Lifeline - Settings pages: Indicators: Icons & Status, Cast Bars
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


local function BuildIndicators()
    local p = NewPage("Indicators")
    p:Head("Icons", 1)
    Check(p, 1, "Role icon (tank / healer / damage)", DB, "showRole", false)
    Check(p, 1, "Leader & assistant crown", DB, "showLeader", false)
    Check(p, 1, "Raid target marker", DB, "showRaidIcon", false)
    Check(p, 1, "Ready check status", DB, "showReadyCheck", false)
    Check(p, 1, "Resurrection & summon pending", DB, "showResurrect", false)

    Check(p, 1, "Main tank & main assist icons", DB, "showRaidRoles", false,
        "Shows Blizzard's main tank and main assist icons for players the raid leader has assigned.")
    Check(p, 1, "Threat icon", DB, "showThreatIcon", false,
        "A small colored square: orange when a player is about to pull, red when they have aggro.")
    Check(p, 1, "Threat icon: also show high threat (yellow)", DB, "threatIconLow", false)

    p:Head("Status", 1)
    Check(p, 1, "Show AFK players", DB, "showAFK", false,
        "Shows AFK in place of the health text while a player is away.")
    Check(p, 1, "Show how long (dead / offline / AFK)", DB, "statusTimer", false,
        "Adds a timer, e.g. DEAD  1:12. Releasing to a ghost doesn't restart it.")


    -- Element positions: nudge any icon or text in any direction
    p:Head("Element positions", 2)
    local ELEMENTS = {
        { value = "name",     text = "Name" },
        { value = "status",   text = "Health text" },
        { value = "role",     text = "Role icon" },
        { value = "leader",   text = "Leader crown" },
        { value = "raidIcon", text = "Raid marker" },
        { value = "center",   text = "Ready check / res icon" },
        { value = "debuffs",  text = "Debuff icons" },
        { value = "buffs",    text = "Your buffs (Auras tab)" },
        { value = "threat",   text = "Threat icon" },
        { value = "castbar",  text = "Cast bar" },
        { value = "incoming", text = "Incoming cast icon" },
        { value = "bigDebuff", text = "Big debuff (middle)" },
        { value = "lowMana",  text = "LOW MANA tag" },
        { value = "soulstone", text = "SOULSTONE tag" },
    }
    local sel = "name"
    local function off()
        L.db.offsets[sel] = L.db.offsets[sel] or { x = 0, y = 0 }
        return L.db.offsets[sel]
    end
    local sx, sy
    local pick = L.Dropdown(p, "Element", ELEMENTS, function() return sel end, function(v)
        sel = v
        sx.Refresh() sy.Refresh()
    end, 260)
    p:Add(pick, 2, 10)
    sx = L.Slider(p, "Left / right", -40, 40, 1, function() return off().x end,
        function(v) off().x = v L:Refresh(false) end, function(v) return (v > 0 and "+" or "") .. v end)
    sx:SetWidth(260)
    p:Add(Track(sx), 2, 10)
    sy = L.Slider(p, "Down / up", -40, 40, 1, function() return off().y end,
        function(v) off().y = v L:Refresh(false) end, function(v) return (v > 0 and "+" or "") .. v end)
    sy:SetWidth(260)
    p:Add(Track(sy), 2, 10)

    local btns = CreateFrame("Frame", nil, p)
    btns:SetSize(260, 22)
    local r1 = L.Button(btns, "Reset this", 90, 22, function()
        off().x, off().y = 0, 0
        sx.Refresh() sy.Refresh()
        L:Refresh(false)
    end)
    r1:SetPoint("LEFT")
    local r2 = L.Button(btns, "Reset all positions", 140, 22, function()
        for _, e in ipairs(ELEMENTS) do L.db.offsets[e.value] = { x = 0, y = 0 } end
        sx.Refresh() sy.Refresh()
        L:Refresh(false)
    end)
    r2:SetPoint("LEFT", r1, "RIGHT", 8, 0)
    p:Add(btns, 2, 8)
    Note(p, 2, "Watch the example panel while you drag. Health text moves with the name; its own nudge adds on top.")
end

local function BuildCastBars()
    local p = NewPage("Cast Bars")
    local function CB() return L.db.castBar end
    local function IN() return L.db.incoming end
    p:Head("Cast bars", 1)
    Check(p, 1, "Show cast bars on frames", CB, "enabled", false,
        "A thin bar on each frame showing what that player is casting.")
    Drop(p, 1, "Position", L.CASTBAR_POSITIONS, CB, "position", false)
    Slider(p, 1, "Height", 3, 16, 1, CB, "height", false)
    Check(p, 1, "Show the spell icon", CB, "showIcon", false)
    Check(p, 1, "Show the spell name (height 8 or more)", CB, "showName", false)
    Note(p, 1, "Casts are gold, channels green, and an interrupted cast flashes red.")

    p:Head("Incoming casts", 2)
    Check(p, 2, "Warn when an enemy casts at a player", IN, "enabled", false,
        "Shows the enemy's spell icon with a countdown on the frame of the player it's being cast at.")
    Drop(p, 2, "Position", L.INCOMING_POSITIONS, IN, "position", false)
    Slider(p, 2, "Icon size", 10, 32, 1, IN, "size", false)
    Note(p, 2, "Enemy casts are read from their nameplates, so turn on enemy nameplates (default key V). Only enemies with a nameplate on screen are tracked.")
    p:Sync()
    Note(p, 1, "Both are off by default. Element positions (Icons & Status tab) can nudge the cast bar and the incoming cast icon.", 560)
end

-- register the pages (OptionsSections.lua puts them in order)
------------------------------------------------------------------------
-- Indicators > Dispels
------------------------------------------------------------------------
local DISPEL_KINDS = { "Magic", "Curse", "Disease", "Poison" }

local function BuildDispels()
    local p = NewPage("Dispels")
    p:Head("Dispel highlight", 1)
    Check(p, 1, "Highlight debuffs you can dispel", DB, "dispelHighlight", false,
        "Colors the frame by debuff type: blue magic, purple curse, brown disease, green poison. Works in combat.")
    Drop(p, 1, "Style", {
        { value = "BORDER", text = "Border & glow" },
        { value = "BAR",    text = "Debuff tint on the bar" },
        { value = "BOTH",   text = "Both" },
    }, DB, "dispelStyle", false)
    Drop(p, 1, "Colors", {
        { value = "DEFAULT",    text = "Standard colors" },
        { value = "COLORBLIND", text = "Colorblind-friendly" },
        { value = "CUSTOM",     text = "Custom" },
    }, DB, "dispelColors", false)

    -- one swatch per type: shows the colors in use; clicking one picks your
    -- own color (and switches to Custom)
    local grid = CreateFrame("Frame", nil, p)
    grid:SetSize(270, 2 * 26)
    local swatches = {}
    local function changed()
        L:DispelColorsChanged()
        L:Refresh(false)
        grid.Refresh()
        L:Options_RefreshControls()
    end
    local function OpenPicker(kind)
        local cur = L.DispelColors()[kind]
        local r, g, b = cur[1], cur[2], cur[3]
        local wasMode = L.db.dispelColors
        local prev = L.db.dispelCustom[kind]
        prev = prev and { r = prev.r, g = prev.g, b = prev.b } or nil
        if L.db.dispelColors ~= "CUSTOM" then
            -- start Custom from the colors you were looking at
            for _, k in ipairs(DISPEL_KINDS) do
                if not L.db.dispelCustom[k] then
                    local c = L.DispelColors()[k]
                    L.db.dispelCustom[k] = { r = c[1], g = c[2], b = c[3] }
                end
            end
            L.db.dispelColors = "CUSTOM"
        end
        local function apply(nr, ng, nb)
            L.db.dispelCustom[kind] = { r = nr, g = ng, b = nb }
            changed()
        end
        local info = {
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function()
                L.db.dispelCustom[kind] = prev
                L.db.dispelColors = wasMode
                changed()
            end,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc = info.swatchFunc, info.cancelFunc
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(r, g, b)
            ShowUIPanel(ColorPickerFrame)
        end
    end
    for i, kind in ipairs(DISPEL_KINDS) do
        local sw = CreateFrame("Button", nil, grid)
        sw:SetSize(128, 22)
        sw:SetPoint("TOPLEFT", ((i - 1) % 2) * 134, -math.floor((i - 1) / 2) * 26)
        sw:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        L.Skin(sw, C.panel2)
        local chip = sw:CreateTexture(nil, "ARTWORK")
        chip:SetSize(14, 14)
        chip:SetPoint("LEFT", 5, 0)
        local label = L.Text(sw, 11)
        label:SetPoint("LEFT", chip, "RIGHT", 6, 0)
        label:SetText(kind)
        sw.Refresh = function()
            local c = L.DispelColors()[kind]
            chip:SetColorTexture(c[1], c[2], c[3])
            local mine = L.db.dispelColors == "CUSTOM" and L.db.dispelCustom[kind]
            if mine then L.SetBorderColor(sw, C.accent[1], C.accent[2], C.accent[3])
            else L.SetBorderColor(sw, C.border[1], C.border[2], C.border[3]) end
        end
        sw:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                L.db.dispelCustom[kind] = nil
                changed()
            else
                OpenPicker(kind)
            end
        end)
        sw:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(kind, 1, 1, 1)
            GameTooltip:AddLine("Left-click to pick your own color (switches Colors to Custom). Right-click to reset it to the standard color.", nil, nil, nil, true)
            GameTooltip:Show()
        end)
        sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        swatches[#swatches + 1] = sw
    end
    grid.Refresh = function() for _, sw in ipairs(swatches) do sw.Refresh() end end
    grid:SetScript("OnShow", grid.Refresh)
    hooksecurefunc(L, "Refresh", function() if grid:IsVisible() then grid.Refresh() end end)
    p:Add(Track(grid), 1, 8)
    local reset = L.Button(p, "Reset custom colors", 150, 22, function()
        wipe(L.db.dispelCustom)
        changed()
    end)
    p:Add(reset, 1, 8)
    Note(p, 1, "Only debuffs your class can remove light up, so a Priest sees Magic & Disease, a Druid sees Curse & Poison, and so on.")

    p:Head("Glow (Border & glow)", 2)
    Slider(p, 2, "Glow strength", 5, 80, 1, DB, "dispelGlowAlpha", false, function(v) return v .. "%" end)
    Slider(p, 2, "Glow height", 20, 100, 5, DB, "dispelGlowHeight", false, function(v) return v .. "%" end)
    Drop(p, 2, "Glow direction", {
        { value = "BOTTOM", text = "From the bottom" },
        { value = "TOP",    text = "From the top" },
        { value = "EDGES",  text = "From both edges" },
        { value = "FULL",   text = "Even wash" },
    }, DB, "dispelGlowDir", false)
    Slider(p, 2, "Border thickness", 1, 4, 1, DB, "dispelBorderSize", false, function(v) return v .. " px" end)

    p:Head("Debuff tint on the bar", 2)
    Note(p, 2, "Only while a debuff you can dispel is up. Your normal health colors aren't changed.", 270)
    Drop(p, 2, "Bar fill", {
        { value = "SOLID",    text = "Solid" },
        { value = "GRADIENT", text = "Gradient" },
    }, DB, "dispelBarFill", false)
    Slider(p, 2, "Gradient strength", 10, 80, 5, DB, "dispelBarGradient", false, function(v) return v .. "%" end)
    p:Sync()
    Note(p, 1, "Changes show right away on the Example and your frames. In combat, frames keep the look they had when the fight started.", 560)
end

------------------------------------------------------------------------
-- Indicators > Status Effects
------------------------------------------------------------------------
local function BuildStatusEffects()
    local p = NewPage("Status Effects")
    p:Head("Banners", 1)
    Check(p, 1, "ICE BLOCK banner", DB, "statusIceBlock", false,
        "A frosty ICE BLOCK banner while a mage is in Ice Block - heals won't land, so help someone else. Works in combat.")
    Check(p, 1, "CC'D banner", DB, "statusCC", false,
        "An orange CC'D banner while a player is crowd controlled: stunned, feared, polymorphed and the like. The game decides what counts. Works in combat.")
    Check(p, 1, "DRINKING banner", DB, "showDrinking", false,
        "A blue DRINKING banner while a player has a drink buff. Out of combat only (nobody drinks in combat).")
    Note(p, 1, "Banners share the strip at the bottom of the frame. When several apply: ICE BLOCK, then CC'D, then DRINKING.", 270)

    local function LM() return L.db.lowMana end
    p:Head("Tags", 1)
    Check(p, 1, "SOULSTONE", DB, "statusSoulstone", false,
        "A small SOULSTONE tag at the top center of the frame while a player can resurrect themselves. Move it under Icons & Status > Element positions. Works in combat.")
    Check(p, 1, "LOW MANA", LM, "enabled", false,
        "A small LOW MANA tag in the bottom-right corner of a player's frame when their mana drops below the threshold.")
    Slider(p, 1, "Below", 5, 50, 1, LM, "percent", false, function(v) return v .. "%" end)
    Check(p, 1, "LOW MANA: healers only", LM, "healersOnly", false)
    p:Head("How it works", 2)
    Note(p, 2, "CC'D uses the game's own crowd-control check, the same kind of check that colors dispellable debuffs, so it works in combat with nothing to set up. Ice Block and the soulstone buff are matched by spell ID.", 270)
    p:Sync()
end

O.PAGE_BUILDERS["Indicators"] = BuildIndicators
O.PAGE_BUILDERS["Status Effects"] = BuildStatusEffects
O.PAGE_BUILDERS["Dispels"] = BuildDispels
O.PAGE_BUILDERS["Cast Bars"] = BuildCastBars
