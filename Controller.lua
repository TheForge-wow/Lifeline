--[[
    Lifeline - Controller support (healer mode)

    With healer mode on, the D-pad picks a player on Lifeline's frames and the
    face buttons (A/B/X/Y, or Cross/Circle/Square/Triangle) cast on the picked
    player. Everything that runs on a button press is secure code, so picking
    and casting work in combat.

      LifelinePadHeader   holds the mode, the picked frame and the key list,
                          and owns the D-pad / face button bindings while
                          healer mode is active
      LifelinePadUp/...   D-pad: move the pick to the nearest frame that way
      LifelinePadA/...    face buttons: cast on the picked player
      LifelinePadToggle   flips healer mode on/off (any mode, in combat too)

    Face button actions reuse the click-casting action types. They're stored as
    macro text written for "@mouseover" and the press swaps in the picked unit,
    so smart resurrection and rank handling behave the same as on the mouse.
]]

local _, L = ...
local C = L.C

------------------------------------------------------------------------
-- Buttons and their pictures
------------------------------------------------------------------------
-- face buttons by position; Nintendo prints the letters in swapped spots
L.PAD_FACES = {
    { key = "PAD1", pos = "Bottom", xbox = "A", ps = "Cross",    nin = "B", btn = "LifelinePadA" },
    { key = "PAD2", pos = "Right",  xbox = "B", ps = "Circle",   nin = "A", btn = "LifelinePadB" },
    { key = "PAD3", pos = "Left",   xbox = "X", ps = "Square",   nin = "Y", btn = "LifelinePadX" },
    { key = "PAD4", pos = "Top",    xbox = "Y", ps = "Triangle", nin = "X", btn = "LifelinePadY" },
}
local DPAD = {
    { key = "PADDUP",    dir = "UP",    btn = "LifelinePadUp" },
    { key = "PADDDOWN",  dir = "DOWN",  btn = "LifelinePadDown" },
    { key = "PADDLEFT",  dir = "LEFT",  btn = "LifelinePadLeft" },
    { key = "PADDRIGHT", dir = "RIGHT", btn = "LifelinePadRight" },
}

L.PAD_MODES = {
    { value = "OFF",    text = "Off" },
    { value = "ALWAYS", text = "Always on" },
    { value = "COMBAT", text = "In combat only" },
}
L.PAD_STYLES = {
    { value = "AUTO",     text = "Auto" },
    { value = "XBOX",     text = "Xbox" },
    { value = "PS",       text = "PlayStation" },
    { value = "NINTENDO", text = "Nintendo" },
}
L.PAD_TOGGLE_KEYS = {
    { value = "",           text = "None (use Key Bindings)" },
    { value = "PADBACK",    text = "Back / Share / Minus" },
    { value = "PADLSTICK",  text = "Left stick click (L3)" },
    { value = "PADRSTICK",  text = "Right stick click (R3)" },
    { value = "PADPADDLE1", text = "Paddle 1" },
    { value = "PADPADDLE2", text = "Paddle 2" },
    { value = "PADPADDLE3", text = "Paddle 3" },
    { value = "PADPADDLE4", text = "Paddle 4" },
}
-- no unit menu: the game only opens it from a real right-click
L.PAD_TYPES = {
    { value = "none",   text = "Nothing (game's own)" },
    { value = "target", text = "Target unit" },
    { value = "focus",  text = "Set focus" },
    { value = "spell",  text = "Cast spell" },
    { value = "macro",  text = "Run macro text" },
}

BINDING_HEADER_LIFELINE = "Lifeline"
_G["BINDING_NAME_CLICK LifelinePadToggle:LeftButton"] = "Toggle controller healer mode"

local function PadDB() return L.cdb and L.cdb.controller end

-- What kind of controller is in use: "XBOX", "PS", "NINTENDO" or nil (none found).
-- Name first, then the game's own label style, then the maker's USB vendor ID.
local VENDORS = { [1356] = "PS", [1406] = "NINTENDO", [1118] = "XBOX" }
local function Classify(text)
    text = L.Readable(text)
    if type(text) ~= "string" then return nil end
    local s = text:lower()
    if s:find("dualsense") or s:find("dualshock") or s:find("playstation") or s:find("sony")
        or s:find("shape") then return "PS" end
    if s:find("nintendo") or s:find("switch") or s:find("joy%-?con") or s:find("pro controller")
        or s:find("rev") then return "NINTENDO" end
    if s:find("xbox") or s:find("xinput") or s:find("letter") then return "XBOX" end
end

local detected, detectedAt, deviceName
function L:Pad_Detect()
    local now = GetTime and GetTime() or 0
    if detectedAt and now - detectedAt < 3 then return detected, deviceName end
    detectedAt, detected, deviceName = now, nil, nil
    local pad = rawget(_G, "C_GamePad")
    if type(pad) ~= "table" or type(pad.GetActiveDeviceID) ~= "function" then return nil end
    local ok, id = pcall(pad.GetActiveDeviceID)
    if not ok or id == nil then return nil end
    for _, getter in ipairs({ "GetDeviceMappedState", "GetDeviceRawState" }) do
        local fn = pad[getter]
        if not detected and type(fn) == "function" then
            local ok2, st = pcall(fn, id)
            if ok2 and type(st) == "table" then
                deviceName = deviceName or L.Readable(st.name)
                detected = Classify(st.name) or Classify(st.labelStyle)
                if not detected and type(st.labelStyle) == "number" and Enum and Enum.GamePadLabelStyle then
                    for k, v in pairs(Enum.GamePadLabelStyle) do
                        if v == st.labelStyle then detected = Classify(k) end
                    end
                end
                detected = detected or VENDORS[tonumber(L.Readable(st.vendorID)) or -1]
            end
        end
    end
    if deviceName and not detected then detected = "XBOX" end   -- a pad, just not one we recognize
    return detected, deviceName
end

-- the picture style in use: the setting, or the detected controller (Xbox if none)
function L:Pad_Style()
    local db = PadDB()
    local s = db and db.glyphs or "AUTO"
    if s ~= "AUTO" then return s end
    return L:Pad_Detect() or "XBOX"
end

-- label for a face button in the current style ("A", "Cross", ...)
function L:Pad_FaceLabel(face, style)
    style = style or L:Pad_Style()
    if style == "PS" then return face.ps elseif style == "NINTENDO" then return face.nin end
    return face.xbox
end

-- the game's own button pictures; ours are drawn when one is missing
local ATLAS = {
    XBOX = { A = "Gamepad_Ltr_A_32", B = "Gamepad_Ltr_B_32", X = "Gamepad_Ltr_X_32", Y = "Gamepad_Ltr_Y_32" },
    PS   = { Cross = "Gamepad_Shp_Cross_32", Circle = "Gamepad_Shp_Circle_32",
             Square = "Gamepad_Shp_Square_32", Triangle = "Gamepad_Shp_Triangle_32" },
}
local FALLBACK = {   -- color and text of our own drawn glyphs
    A = { 0.43, 0.78, 0.35 }, B = { 0.86, 0.31, 0.27 }, X = { 0.31, 0.55, 0.90 }, Y = { 0.92, 0.78, 0.27 },
    Cross = { 0.47, 0.63, 0.92, "X" }, Circle = { 0.88, 0.35, 0.37, "O" },
    Square = { 0.86, 0.47, 0.78, "[ ]" }, Triangle = { 0.35, 0.78, 0.67, "/\\" },
}
local function AtlasExists(name)
    local tex = rawget(_G, "C_Texture")
    if not name or type(tex) ~= "table" or not tex.GetAtlasInfo then return false end
    local ok, info = pcall(tex.GetAtlasInfo, name)
    return ok and info ~= nil
end
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- a small button picture: g = L.PadGlyph(parent, 22); g:Set(face)
function L.PadGlyph(parent, size)
    local g = CreateFrame("Frame", nil, parent)
    g:SetSize(size, size)
    g.atlas = g:CreateTexture(nil, "ARTWORK")
    g.atlas:SetAllPoints()
    local ring = g:CreateTexture(nil, "BORDER")
    ring:SetAllPoints()
    local inner = g:CreateTexture(nil, "BORDER", nil, 1)
    inner:SetPoint("TOPLEFT", 2, -2)
    inner:SetPoint("BOTTOMRIGHT", -2, 2)
    inner:SetColorTexture(0.10, 0.11, 0.14, 1)
    if g.CreateMaskTexture then
        for _, t in ipairs({ ring, inner }) do
            local m = g:CreateMaskTexture()
            if m then
                m:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                m:SetAllPoints(t)
                t:AddMaskTexture(m)
            end
        end
    end
    g.ring, g.inner = ring, inner
    g.text = L.Text(g, math.floor(size * 0.5), C.text)
    g.text:SetPoint("CENTER", 0, 0)
    function g:Set(face, style)
        style = style or L:Pad_Style()
        local label = L:Pad_FaceLabel(face, style)
        local atlas = ATLAS[style] and ATLAS[style][label]
        if atlas and AtlasExists(atlas) then
            self.atlas:SetAtlas(atlas)
            self.atlas:Show() self.ring:Hide() self.inner:Hide() self.text:Hide()
            return
        end
        -- drawn: Nintendo is plain grey and white like the real buttons
        local c = style == "NINTENDO" and { 0.85, 0.85, 0.88 } or FALLBACK[label] or { 0.8, 0.8, 0.8 }
        self.atlas:Hide()
        self.ring:SetColorTexture(c[1], c[2], c[3], 1)
        self.ring:Show() self.inner:Show()
        self.text:SetText(c[4] or label)
        self.text:SetTextColor(c[1], c[2], c[3])
        self.text:Show()
    end
    return g
end

------------------------------------------------------------------------
-- Secure code
------------------------------------------------------------------------
-- the unit buttons on screen, from every visible Lifeline group header
local GATHER = [[
    local list = newtable()
    for i = 1, PAD:GetAttribute("g-n") or 0 do
        local g = PAD:GetFrameRef("g" .. i)
        if g and g:IsVisible() then g:GetChildList(list) end
    end
]]

-- header: work out whether healer mode is active and (re)set the bindings
local APPLY = [[
    if name == "state-combat" then
        if self:GetAttribute("ll-mode") == "COMBAT" then self:SetAttribute("ll-override", nil) end
    elseif name == "ll-flip" then
        self:SetAttribute("ll-override", self:GetAttribute("ll-active") == 1 and "off" or "on")
    elseif name ~= "ll-refresh" then
        return
    end
    local mode = self:GetAttribute("ll-mode") or "OFF"
    local active = mode == "ALWAYS" or (mode == "COMBAT" and self:GetAttribute("state-combat") == "on")
    local ov = self:GetAttribute("ll-override")
    if ov == "on" then active = true elseif ov == "off" then active = false end
    self:ClearBindings()
    if active then
        for i = 1, self:GetAttribute("k-n") or 0 do
            local k, b = self:GetAttribute("k" .. i), self:GetAttribute("kb" .. i)
            if k and b then self:SetBindingClick(true, k, b, "LeftButton") end
        end
    end
    self:SetAttribute("ll-active", active and 1 or 0)
]]

-- D-pad: move the pick to the nearest frame in that direction, wrapping around
-- to the far end of the row or column. The first press picks you.
local NAV = [[
    if down == false then return end
    local PAD = self:GetFrameRef("pad")
    if not PAD or PAD:GetAttribute("ll-active") ~= 1 then return end
]] .. GATHER .. [[
    local dir = self:GetAttribute("ll-dir")
    local picked = PAD:GetAttribute("picked")
    local cands = newtable()
    local cur, mine
    for i = 1, #list do
        local c = list[i]
        if c:IsVisible() and c:GetAttribute("unit") then
            cands[#cands + 1] = c
            if c:GetName() == picked then cur = c end
            if c:GetAttribute("unit") == "player" then mine = c end
        end
    end
    if #cands == 0 then return end
    local pick
    if not cur then
        pick = mine
        if not pick then
            local bx, by
            for i = 1, #cands do
                local l, b, w, h = cands[i]:GetRect()
                if l and (not pick or b + h > by + 1 or (b + h >= by - 1 and l < bx)) then
                    pick, bx, by = cands[i], l, b + h
                end
            end
        end
    else
        local l, b, w, h = cur:GetRect()
        if not l then return end
        local cx, cy = l + w / 2, b + h / 2
        local best, bestScore, wrap, wrapScore
        for i = 1, #cands do
            local c = cands[i]
            if c:GetName() ~= picked then
                local l2, b2, w2, h2 = c:GetRect()
                if l2 then
                    local dx, dy = l2 + w2 / 2 - cx, b2 + h2 / 2 - cy
                    local along, across
                    if dir == "UP" then along, across = dy, dx
                    elseif dir == "DOWN" then along, across = -dy, dx
                    elseif dir == "RIGHT" then along, across = dx, dy
                    else along, across = -dx, dy end
                    if across < 0 then across = -across end
                    local s = along + across * 3
                    if along > 1 then
                        if not bestScore or s < bestScore then best, bestScore = c, s end
                    elseif along < -1 and across < 2 then
                        if not wrapScore or s < wrapScore then wrap, wrapScore = c, s end
                    end
                end
            end
        end
        pick = best or wrap
    end
    if pick then PAD:SetAttribute("picked", pick:GetName()) end
]]

-- face button (wrapped OnClick, owner = header): put the picked unit into
-- the action's macro text, or cancel the press if nobody is picked
local CAST = [[
    if not down then return false end
    local PAD = owner
    if PAD:GetAttribute("ll-active") ~= 1 then return false end
    local picked = PAD:GetAttribute("picked")
    local t = self:GetAttribute("ll-macro")
    if not picked or not t or t == "" then return false end
]] .. GATHER .. [[
    local unit
    for i = 1, #list do
        local c = list[i]
        if c:GetName() == picked and c:IsVisible() then unit = c:GetAttribute("unit") end
    end
    if not unit then return false end
    t = t:gsub("@mouseover", "@" .. unit)
    t = t:gsub("target=mouseover", "target=" .. unit)
    self:SetAttribute("macrotext", t)
]]

local TOGGLE = [[
    local h = self:GetFrameRef("pad")
    if h then h:SetAttribute("ll-flip", (h:GetAttribute("ll-flip") or 0) + 1) end
]]

------------------------------------------------------------------------
-- Frames
------------------------------------------------------------------------
local header, toggle
local cast = {}       -- face key -> button
local refresh = 0
local flipped         -- a toggle press is on its way (for the on-screen note)

local function NewHidden(name, template)
    local b = CreateFrame("Button", name, UIParent, template)
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10, -10)   -- off screen
    b:EnableMouse(false)
    return b
end

local function Highlight(b)
    if b.__llPadHL then return b.__llPadHL end
    local f = CreateFrame("Frame", nil, b)
    f:SetAllPoints()
    f:SetFrameLevel(b:GetFrameLevel() + 12)
    local fill = f:CreateTexture(nil, "OVERLAY")
    fill:SetAllPoints()
    fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.12)
    L.AddBorder(f, { C.accent[1], C.accent[2], C.accent[3], 1 }, 2)
    f:Hide()
    b.__llPadHL = f
    return f
end

local shown
function L:Pad_UpdateHighlight()
    if shown then shown:Hide() shown = nil end
    if not header or header:GetAttribute("ll-active") ~= 1 then return end
    local name = header:GetAttribute("picked")
    local b = name and _G[name]
    if b and b.__ll then
        shown = Highlight(b)
        shown:Show()
    end
end

function L:Pad_IsActive() return header ~= nil and header:GetAttribute("ll-active") == 1 end
function L:Pad_Picked()
    local name = header and header:GetAttribute("picked")
    local b = name and _G[name]
    return b and b:IsVisible() and b:GetAttribute("unit") or nil
end

-- macro text (written for @mouseover) for a face button's binding
local function MacroFor(bind)
    if not bind or not bind.type or bind.type == "none" then return nil end
    if bind.type == "target" then return "/target [@mouseover]" end
    if bind.type == "focus" then return "/focus [@mouseover]" end
    if bind.type == "spell" and bind.value and bind.value ~= "" then
        local spell = L:CC_SpellName(bind.value, bind.fixedRank)
        local res = L.CC_SmartResMacro and L:CC_SmartResMacro(spell)
        return res or ("/cast [@mouseover] " .. spell)
    end
    if bind.type == "macro" and bind.value and bind.value ~= "" then return bind.value end
end
L.Pad_MacroFor = MacroFor

local function Create()
    if header or InCombatLockdown() then return end
    header = CreateFrame("Frame", "LifelinePadHeader", UIParent, "SecureHandlerAttributeTemplate")
    header:SetAttribute("_onattributechanged", APPLY)
    for i, h in ipairs(L.headers or {}) do header:SetFrameRef("g" .. i, h) end
    header:SetAttribute("g-n", #(L.headers or {}))

    for _, d in ipairs(DPAD) do
        local b = NewHidden(d.btn, "SecureHandlerClickTemplate")
        b:RegisterForClicks("AnyDown")
        b:SetAttribute("ll-dir", d.dir)
        b:SetFrameRef("pad", header)
        b:SetAttribute("_onclick", NAV)
    end
    for _, f in ipairs(L.PAD_FACES) do
        local b = NewHidden(f.btn, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetAttribute("useOnKeyDown", true)   -- the press casts, whatever "cast on key release" says
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "")
        SecureHandlerWrapScript(b, "OnClick", header, CAST)
        b:HookScript("PostClick", function(self, button, down) if L._LogClick then L._LogClick(self, button, down) end end)
        cast[f.key] = b
    end
    toggle = NewHidden("LifelinePadToggle", "SecureHandlerClickTemplate")
    toggle:RegisterForClicks("AnyDown")
    toggle:SetFrameRef("pad", header)
    toggle:SetAttribute("_onclick", TOGGLE)
    -- (runs before the secure part, so the note below knows it was a toggle press)
    toggle:SetScript("PreClick", function() flipped = true end)

    pcall(RegisterStateDriver, header, "combat", "[combat] on; off")

    header:HookScript("OnAttributeChanged", function(_, name)
        if name == "picked" or name == "ll-active" then L:Pad_UpdateHighlight() end
        if name == "ll-active" and flipped then
            flipped = nil
            local on = header:GetAttribute("ll-active") == 1
            if UIErrorsFrame then
                UIErrorsFrame:AddMessage("Lifeline healer mode: " .. (on and "on" or "off"), C.accent[1], C.accent[2], C.accent[3])
            end
        end
        if name == "ll-active" and L.Opt and L.Opt.win and L.Opt.win:IsShown() and L.Options_RefreshControls then
            L:Options_RefreshControls()
        end
    end)
end

-- Is ControllerForever's own healer D-pad running? Then two addons would
-- fight over the same buttons.
function L:Pad_OtherAddon()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
    return isLoaded and isLoaded("ControllerForever") and true or false
end

-- push the settings into the secure frames (out of combat)
function L:Pad_Apply(resetToggle)
    L:RunAfterCombat("controller", function()
        Create()
        if not header then return end
        local db = PadDB()
        -- face button actions
        local keys = {}
        for _, d in ipairs(DPAD) do keys[#keys + 1] = { d.key, d.btn } end
        for _, f in ipairs(L.PAD_FACES) do
            local m = MacroFor(db.bindings[f.key])
            cast[f.key]:SetAttribute("ll-macro", m)
            if m then keys[#keys + 1] = { f.key, f.btn } end
        end
        local old = header:GetAttribute("k-n") or 0
        for i = 1, math.max(old, #keys) do
            header:SetAttribute("k" .. i, keys[i] and keys[i][1] or nil)
            header:SetAttribute("kb" .. i, keys[i] and keys[i][2] or nil)
        end
        header:SetAttribute("k-n", #keys)
        header:SetAttribute("ll-mode", db.mode or "OFF")
        if resetToggle then header:SetAttribute("ll-override", nil) end
        -- toggle key on the controller (it's also in the game's Key Bindings)
        ClearOverrideBindings(toggle)
        if db.toggleKey and db.toggleKey ~= "" then
            SetOverrideBindingClick(toggle, true, db.toggleKey, "LifelinePadToggle", "LeftButton")
        end
        refresh = refresh + 1
        header:SetAttribute("ll-refresh", refresh)
    end)
end

L:On("PLAYER_LOGIN", function() L:Pad_Apply() end)
-- spells learned / respec: rank and resurrection text in the face actions
L:On("SPELLS_CHANGED", function()
    if header then L:Debounce("padspells", 1, function() L:Pad_Apply() end) end
end)

-- a frame that already exists when it's picked gets its highlight lazily;
-- frames spawned later get one the first time they're picked
hooksecurefunc(L, "Button_Init", function(_, b)
    if b.fake then return end
    if header and header:GetAttribute("picked") == b:GetName() then L:Pad_UpdateHighlight() end
end)

-- /ll debug
function L:Pad_DebugLines()
    local db = PadDB()
    local style, dev = L:Pad_Detect()
    local out = {}
    out[#out + 1] = ("controller: %s | healer mode setting: %s | active now: %s | picked: %s"):format(
        tostring(dev or "none found"), tostring(db and db.mode), tostring(L:Pad_IsActive()),
        tostring(L:Pad_Picked() or "nobody"))
    out[#out + 1] = ("button pictures: %s (detected %s) | toggle key: %s"):format(
        tostring(db and db.glyphs), tostring(style or "-"), (db and db.toggleKey ~= "" and db.toggleKey) or "none")
    for _, f in ipairs(L.PAD_FACES) do
        local m = cast[f.key] and cast[f.key]:GetAttribute("ll-macro")
        out[#out + 1] = ("  %s (%s): %s"):format(f.key, f.xbox, m and m:gsub("\n", " / ") or "game's own")
    end
    return out
end
