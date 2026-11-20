--[[
    Lifeline - Settings window: live example panel docked beside the window
]]

local _, L = ...
local C = L.C
local O = L.Opt

local example
-- each sample frame shows off a different set of indicators
local EXAMPLE_UNITS = {
    { idx = 1, tweak = function(f) f.buffs = { "Interface\\Icons\\Spell_Holy_Renew", "Interface\\Icons\\Spell_Holy_PowerWordShield" } f.hp = 90 f.heal = 18 f.raidRole = "MAINTANK" f.incoming = "Interface\\Icons\\Spell_Shadow_ShadowBolt" end,
      tip = { "Tank", "Aggro border, leader crown, raid marker, your own buffs (Auras tab) and overheal (the bright strip is heal that would be wasted), main tank icon, threat icon and an enemy casting at them (Cast Bars tab)." } },
    { idx = 2, tweak = function(f) f.target = true f.absorb = 10 f.cast = { name = "Flash Heal", icon = "Interface\\Icons\\Spell_Holy_FlashHeal", pct = 0.6 } end,
      tip = { "Healer", "Dispellable Magic debuff, incoming heals (green), an absorb shield (white), the white target border and a cast bar (Cast Bars tab)." } },
    { idx = 4, tip = { "Drinking", "DRINKING banner, plus any buff indicators you've placed." } },
    { idx = 7, tweak = function(f) f.oor = true f.bigDebuff = "Interface\\Icons\\Spell_Shadow_UnholyStrength" end,
      tip = { "Out of range", "Faded by your out-of-range opacity, with debuff icons and a boss debuff shown big in the middle (Auras tab)." } },
    { idx = 9, tweak = function(f) f.res = true f.debuffs = nil f.buffs = nil end,
      tip = { "Dead", "Grayed out with DEAD and how long they've been dead, plus the resurrection-pending icon. Missing-buff reminders are skipped." } },
}
-- simulated answers when you press "Ready check" on the example
local READY_DEMO = { "ready", "ready", "waiting", "notready", nil }

local function PlaceExample()
    -- dock right of the window, or left if that would run off screen
    example:ClearAllPoints()
    local right = O.win:GetRight() or 0
    local screen = UIParent:GetRight() or GetScreenWidth()
    if right + 8 + example:GetWidth() > screen then
        example:SetPoint("TOPRIGHT", O.win, "TOPLEFT", -8, 0)
    else
        example:SetPoint("TOPLEFT", O.win, "TOPRIGHT", 8, 0)
    end
end

local function CreateExample()
    example = CreateFrame("Frame", "LifelineExample", O.win)
    example:SetFrameStrata("HIGH")
    example.mode = "party"
    L.Skin(example, C.bg)

    local title = L.Text(example, 12)
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("Example")
    local tick = example:CreateTexture(nil, "ARTWORK")
    tick:SetSize(3, 12)
    tick:SetPoint("RIGHT", title, "LEFT", -6, 0)
    L.SetC(tick, C.accent)

    local close = CreateFrame("Button", nil, example)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -6)
    local x = L.Text(close, 13, C.muted)
    x:SetPoint("CENTER")
    x:SetText("x")
    close:SetScript("OnEnter", function() x:SetTextColor(C.danger[1], C.danger[2], C.danger[3]) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function()
        L.db.showExample = false
        L:Example_Refresh()
        L:Options_RefreshControls()
    end)

    -- Party / Raid switch: shows the size & layout of whichever you're editing
    example.modeBtns = {}
    local function modeBtn(mode, label, anchor)
        local b = L.Button(example, label, 52, 18, function()
            example.mode = mode
            L:Example_Refresh()
        end)
        b.text:SetFont(L.FONT, 10, "")
        b:SetPoint("TOPLEFT", anchor or title, anchor and "TOPRIGHT" or "BOTTOMLEFT", anchor and 4 or 0, anchor and 0 or -8)
        example.modeBtns[mode] = b
        return b
    end
    local pb = modeBtn("party", "Party")
    modeBtn("raid", "Raid", pb)

    -- simulate a ready check on the example frames
    local rcBtn
    rcBtn = L.Button(example, "Ready check", 78, 18, function()
        example.readyDemo = not example.readyDemo
        for i, b in ipairs(example.buttons) do
            b.fake.ready = example.readyDemo and READY_DEMO[i] or nil
        end
        rcBtn.text:SetTextColor(example.readyDemo and C.accent[1] or C.muted[1],
            example.readyDemo and C.accent[2] or C.muted[2], example.readyDemo and C.accent[3] or C.muted[3])
        L:Example_Refresh()
    end)
    rcBtn.text:SetFont(L.FONT, 10, "")
    rcBtn.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    rcBtn:SetPoint("LEFT", example.modeBtns.raid, "RIGHT", 10, 0)
    example.rcBtn = rcBtn
    rcBtn:SetScript("OnEnter", function(s)
        L.SetBorderColor(s, C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine("Ready check preview", C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:AddLine("Shows what ready / not ready / waiting look like on your frames.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    rcBtn:SetScript("OnLeave", function(s)
        L.SetBorderColor(s, C.border[1], C.border[2], C.border[3])
        GameTooltip:Hide()
    end)

    -- holder carries the overall scale so the example matches in-game size
    example.holder = CreateFrame("Frame", nil, example)
    example.holder:SetSize(1, 1)

    example.buttons = {}
    for i, def in ipairs(EXAMPLE_UNITS) do
        local fake = L.FakeData(def.idx)
        fake.oor, fake.target = false, false
        if def.tweak then def.tweak(fake) end
        local b = L:CreateFakeButton(example.holder, fake, def.tip)
        example.buttons[i] = b
    end

    -- sample pets (shown when "Show pets" is on)
    example.pets = {}
    local PET_SAMPLES = { { "Wolf", 100 }, { "Voidwalker", 64 } }
    for i, d in ipairs(PET_SAMPLES) do
        local c = L.PET_COLOR
        local b = L:CreateFakeButton(example.holder, { index = 200 + i, name = d[1], r = c[1], g = c[2], b = c[3],
            hp = d[2], heal = (d[2] < 90) and 15 or 0, power = "FOCUS", pp = 70, isPet = true },
            { "Pet", "Pet frames use your Pet width / height (General tab) and sit just past the player frames." })
        example.pets[i] = b
    end
end

function L:Example_Refresh()
    if not O.win then return end
    if not L.db.showExample then
        if example then example:Hide() end
        return
    end
    if not example then CreateExample() end

    for mode, b in pairs(example.modeBtns) do
        local on = mode == example.mode
        b.text:SetTextColor(on and C.accent[1] or C.muted[1], on and C.accent[2] or C.muted[2], on and C.accent[3] or C.muted[3])
        L.SetC(b.__bg, on and C.accentDim or C.panel2)
    end

    local cfg = (example.mode == "raid") and L.Opt.RaidEditing() or L.db.party
    local scale = L.db.scale or 1
    example.holder:SetScale(scale)

    -- follow the chosen orientation + growth direction
    local horizontal = cfg.orientation == "HORIZONTAL"
    local growth = cfg.growth or "DOWN_RIGHT"
    local down = growth:find("^DOWN") ~= nil
    local right = growth:find("RIGHT$") ~= nil
    local corner = (down and "TOP" or "BOTTOM") .. (right and "LEFT" or "RIGHT")
    local n = #example.buttons
    for i, b in ipairs(example.buttons) do
        b:SetSize(cfg.width, cfg.height)
        b:ClearAllPoints()
        local step = i - 1
        local dx, dy = 0, 0
        if horizontal then dx = step * (cfg.width + cfg.spacing) * (right and 1 or -1)
        else dy = step * (cfg.height + cfg.spacing) * (down and -1 or 1) end
        b:SetPoint(corner, example.holder, corner, dx, dy)
        L:Button_ApplyStyle(b)
        b:Show()
        L:Button_UpdateAll(b)
    end

    local w = horizontal and (n * cfg.width + (n - 1) * cfg.spacing) or cfg.width
    local h = horizontal and cfg.height or (n * cfg.height + (n - 1) * cfg.spacing)

    -- pets: placed exactly like in game, just past the player block
    local pets = L.db.pets
    local isRaid = example.mode == "raid"
    if pets.enabled and L.Pets_Offset then
        local ox, oy = L.Pets_Offset(cfg, 1, isRaid)
        local np = #example.pets
        for i, b in ipairs(example.pets) do
            b:SetSize(pets.width, pets.height)
            L:Button_ApplyStyle(b)
            local step = i - 1
            local dx, dy = ox, oy
            if horizontal then dx = dx + step * (pets.width + cfg.spacing) * (right and 1 or -1)
            else dy = dy + step * (pets.height + cfg.spacing) * (down and -1 or 1) end
            b:ClearAllPoints()
            b:SetPoint(corner, example.holder, corner, dx, dy)
            b:Show()
            L:Button_UpdateAll(b)
        end
        -- grow the panel to fit the pet block
        local petW = horizontal and (np * pets.width + (np - 1) * cfg.spacing) or pets.width
        local petH = horizontal and pets.height or (np * pets.height + (np - 1) * cfg.spacing)
        if horizontal then
            h = math.abs(oy) + petH
            w = math.max(w, petW)
        else
            w = math.abs(ox) + petW
            h = math.max(h, petH)
        end
    else
        for _, b in ipairs(example.pets) do b:Hide() end
    end

    example.holder:SetSize(w, h)
    example.holder:ClearAllPoints()
    example.holder:SetPoint("TOPLEFT", example, "TOPLEFT", 14 / scale, -64 / scale)

    example:SetSize(math.max(226, w * scale + 28), h * scale + 64 + 14)
    PlaceExample()
    example:Show()
end


-- the window keeps the example docked when it's dragged
function O.PlaceExampleIfShown()
    if example and example:IsShown() then PlaceExample() end
end

