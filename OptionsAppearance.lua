--[[
    Lifeline - Settings pages: Appearance: Bars & Text, Textures & Colors
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


local function BuildBars()
    local p = NewPage("Bars & Text")
    p:Head("Health bar", 1)
    Drop(p, 1, "Health color", {
        { value = "CLASS",  text = "Class color" },
        { value = "DARK",   text = "Dark (class color shows damage)" },
        { value = "CUSTOM", text = "Single color (green)" },
    }, DB, "healthColor", false)
    Slider(p, 1, "Background darkness", 0, 1, 0.05, DB, "bgDarkness", false, pct)
    Check(p, 1, "Show incoming heals", DB, "showHealPred", false)
    Check(p, 1, "Only show heals I'm casting", DB, "healPredMineOnly", false,
        "Ignore other healers' incoming heals and only show the heals you are casting.")
    Check(p, 1, "Show absorb shields", DB, "showAbsorb", false)
    Drop(p, 1, "Overheal", {
        { value = "OFF",     text = "Off" },
        { value = "INSIDE",  text = "Bright strip at the bar's edge" },
        { value = "OUTSIDE", text = "Sticks out past the frame" },
    }, DB, "overheal", false)
    Slider(p, 1, "Overheal strip width", 2, 30, 1, DB, "overhealWidth", false)

    p:Head("Power bar", 1)
    Check(p, 1, "Show power bar", DB, "showPower", false)
    Check(p, 1, "Only fill for healers", DB, "powerHealersOnly", false)
    Slider(p, 1, "Power bar height", 1, 12, 1, DB, "powerHeight", false)

    p:Head("Text", 2)
    Check(p, 2, "Class-colored names", DB, "nameClassColor", false)
    Slider(p, 2, "Name size", 7, 18, 1, DB, "nameSize", false)
    Drop(p, 2, "Health text", {
        { value = "NONE",    text = "None" },
        { value = "PERCENT", text = "Percent" },
        { value = "DEFICIT", text = "Missing health (-12.4k)" },
    }, DB, "healthText", false)
    Slider(p, 2, "Health text size", 7, 16, 1, DB, "healthTextSize", false)
    Drop(p, 2, "Text outline", {
        { value = "THIN",   text = "Thin outline" },
        { value = "THICK",  text = "Thick outline" },
        { value = "SHADOW", text = "Shadow only" },
        { value = "NONE",   text = "None" },
    }, DB, "textOutline", false)
    Note(p, 2, "In raids, dungeons and PvP the game hides exact health; percent still works, missing health goes blank.")

end

local function BuildTextures()
    local p = NewPage("Textures & Colors")
    p:Head("Bars", 1)
    Drop(p, 1, "Health fill direction", {
        { value = "LEFT_TO_RIGHT", text = "Left to right" },
        { value = "RIGHT_TO_LEFT", text = "Right to left" },
        { value = "BOTTOM_TO_TOP", text = "Bottom to top" },
        { value = "TOP_TO_BOTTOM", text = "Top to bottom" },
    }, DB, "fillDirection", false)
    -- picking a texture or font applies right away (re-applied a moment later
    -- too, because a font file from another addon may still be loading)
    local function mediaDrop(label, opts, key)
        local w = L.Dropdown(p, label, opts, function() return L.db[key] end,
            function(v)
                L.db[key] = v
                L:Refresh(false)
                L:Media_ReapplySoon()
            end, 260)
        return p:Add(Track(w), 1, 10)
    end
    local texDD = mediaDrop("Bar texture", L.TEXTURE_OPTIONS, "barTexture")
    local fontDD = mediaDrop("Font (names, health text, cast bars)", L.FONT_OPTIONS, "frameFont")
    -- the font box itself is written in the chosen font
    local fontBtn = select(1, fontDD:GetChildren())
    hooksecurefunc(fontDD, "Refresh", function()
        if fontBtn and fontBtn.text then
            if not pcall(fontBtn.text.SetFont, fontBtn.text, L:FrameFont(), 12, "") then
                fontBtn.text:SetFont(L.FONT, 12, "")
            end
        end
    end)
    local mediaNote = Note(p, 1, "Install any addon that uses LibSharedMedia (most UI packs do) to get more textures and fonts here.")
    Slider(p, 1, "Bar opacity", 0.1, 1, 0.05, DB, "barAlpha", false, pct)
    Slider(p, 1, "Background opacity", 0, 1, 0.05, DB, "bgAlpha", false, pct)

    -- dead / offline background color
    local deadRow = CreateFrame("Button", nil, p)
    deadRow:SetSize(260, 22)
    deadRow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    L.Skin(deadRow, C.panel2)
    local chip = deadRow:CreateTexture(nil, "ARTWORK")
    chip:SetSize(14, 14)
    chip:SetPoint("LEFT", 5, 0)
    local dl = L.Text(deadRow, 12)
    dl:SetPoint("LEFT", chip, "RIGHT", 8, 0)
    dl:SetText("Dead & offline color")
    deadRow.Refresh = function()
        local c = L.db.deadColor
        chip:SetColorTexture(c.r, c.g, c.b)
    end
    deadRow:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            L.db.deadColor = { r = 0.12, g = 0.12, b = 0.12 }
            self.Refresh() L:Refresh(false)
            return
        end
        local c = L.db.deadColor
        local prev = { r = c.r, g = c.g, b = c.b }
        local function apply(r, g, b) L.db.deadColor = { r = r, g = g, b = b } self.Refresh() L:Refresh(false) end
        local info = { r = c.r, g = c.g, b = c.b, hasOpacity = false,
            swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() apply(prev.r, prev.g, prev.b) end }
        if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc = info.swatchFunc, info.cancelFunc
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            ShowUIPanel(ColorPickerFrame)
        end
    end)
    deadRow:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Dead & offline color", 1, 1, 1)
        GameTooltip:AddLine("The background of a dead or offline player's frame. Left-click to pick, right-click to reset.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    deadRow:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p:Add(Track(deadRow), 1, 8)

    -- shared media lists are filled when the page opens (other addons may load late)
    local function refreshMedia()
        local has = L:Media_RefreshLists()
        texDD.Refresh() fontDD.Refresh()
        mediaNote.text:SetText(has and ("%d textures and %d fonts found from your other addons."):format(#L.TEXTURE_OPTIONS - 1, #L.FONT_OPTIONS - 1)
            or "Install any addon that uses LibSharedMedia (most UI packs do) to get more textures and fonts here.")
    end
    p:SetScript("OnShow", refreshMedia)
    refreshMedia()

    p:Head("Class colors", 2)
    -- Class colors: darken all of them, or pick your own per class
    Slider(p, 2, "Darken class colors", 0, 60, 1, DB, "classDarken", false, function(v) return v .. "%" end)

    local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
    local grid = CreateFrame("Frame", nil, p)
    grid:SetSize(270, 3 * 26)
    local swatches = {}

    local function OpenPicker(class, sw)
        local cur = L.db.classColors[class]
        local r, g, b
        if cur then r, g, b = cur.r, cur.g, cur.b else r, g, b = L:DefaultClassColor(class) end
        local prev = cur and { r = cur.r, g = cur.g, b = cur.b } or nil
        local function apply(nr, ng, nb)
            L.db.classColors[class] = { r = nr, g = ng, b = nb }
            sw.Refresh()
            L:Refresh(false)
        end
        local info = {
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function()
                L.db.classColors[class] = prev
                sw.Refresh()
                L:Refresh(false)
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

    for i, class in ipairs(CLASSES) do
        local sw = CreateFrame("Button", nil, grid)
        sw:SetSize(86, 22)
        sw:SetPoint("TOPLEFT", ((i - 1) % 3) * 92, -math.floor((i - 1) / 3) * 26)
        sw:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        L.Skin(sw, C.panel2)
        local chip = sw:CreateTexture(nil, "ARTWORK")
        chip:SetSize(14, 14)
        chip:SetPoint("LEFT", 5, 0)
        local label = L.Text(sw, 11)
        label:SetPoint("LEFT", chip, "RIGHT", 6, 0)
        local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or (class:sub(1, 1) .. class:sub(2):lower())
        label:SetText(name)
        sw.Refresh = function()
            local r, g, b = L:GetClassColor(class)
            chip:SetColorTexture(r, g, b)
            label:SetTextColor(r, g, b)
            -- a small accent marks classes you've changed
            if L.db.classColors[class] then L.SetBorderColor(sw, C.accent[1], C.accent[2], C.accent[3])
            else L.SetBorderColor(sw, C.border[1], C.border[2], C.border[3]) end
        end
        sw:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                L.db.classColors[class] = nil
                self.Refresh()
                L:Refresh(false)
            else
                OpenPicker(class, self)
            end
        end)
        sw:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(name, 1, 1, 1)
            GameTooltip:AddLine("Left-click to pick a color. Right-click to reset to Blizzard's color.", nil, nil, nil, true)
            GameTooltip:Show()
        end)
        sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        swatches[#swatches + 1] = sw
    end
    grid.Refresh = function() for _, sw in ipairs(swatches) do sw.Refresh() end end
    p:Add(Track(grid), 2, 8)

    local reset = L.Button(p, "Reset all class colors", 160, 22, function()
        wipe(L.db.classColors)
        L.db.classDarken = 0
        L:Refresh(false)
        L:Options_RefreshControls()
    end)
    p:Add(reset, 2, 8)
end

-- register the pages (OptionsSections.lua puts them in order)
O.PAGE_BUILDERS["Bars & Text"] = BuildBars
O.PAGE_BUILDERS["Textures & Colors"] = BuildTextures
