--[[
    Lifeline - Tank frames and raid group labels

    Tank frames (Layout tab, off by default): a separate small group, with its
    own size and its own mover, showing your raid's tanks - players with the
    Tank role or assigned main tank / main assist - or players you name.
    Raids only; in a party everyone is already on screen.

    Group labels (Layout tab, off by default): "Group 1", "Group 2"... next to
    each raid group when the raid is laid out one column per group.
]]

local _, L = ...
local C = L.C

local tankAnchor, tankHeader

------------------------------------------------------------------------
-- Mover
------------------------------------------------------------------------
local function CreateTankAnchor()
    local a = CreateFrame("Frame", "LifelineTankAnchor", UIParent)
    a:SetSize(150, 18)
    a:SetMovable(true)
    a:SetClampedToScreen(true)
    a:EnableMouse(false)
    a:RegisterForDrag("LeftButton")
    local handle = CreateFrame("Frame", nil, a)
    handle:SetAllPoints()
    L.Skin(handle, C.accentDim, C.accent)
    local t = L.Text(handle, 11, C.accent)
    t:SetPoint("CENTER")
    t:SetJustifyH("CENTER")
    t:SetText("Lifeline tanks  -  drag")
    a.handle = handle
    a:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    a:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        local pos = L.db.tanks.position
        pos.point, pos.x, pos.y = point, x, y
    end)
    tankAnchor = a
end

------------------------------------------------------------------------
-- Header
------------------------------------------------------------------------
local function CreateTankHeader()
    local h = CreateFrame("Frame", "LifelineTankHeader", tankAnchor, "SecureGroupHeaderTemplate")
    h.initButton = L.Headers_InitButtonMethod
    h.isRaid = true
    h.isTanks = true
    h:SetAttribute("template", "LifelineUnitButtonTemplate")
    h:SetAttribute("showRaid", true)
    h.llWidth, h.llHeight = 100, 36
    h:SetAttribute("initialConfigFunction", L:Headers_InitSnippet(h))
    table.insert(L.headers, h)
    tankHeader = h
end

-- names typed as "Name, Other Name" -> "Name,Other Name"
local function NameList(text)
    local out = {}
    for n in tostring(text or ""):gmatch("[^,;\n]+") do
        n = n:match("^%s*(.-)%s*$")
        if n ~= "" then out[#out + 1] = n end
    end
    return table.concat(out, ",")
end

function L:Tanks_ApplyLayout()
    if not tankHeader then return end
    if InCombatLockdown() then
        L:RunAfterCombat("tanks", function() L:Tanks_ApplyLayout() end)
        return
    end
    local db = L.db
    local cfg = db.tanks
    local pos = cfg.position
    tankAnchor:ClearAllPoints()
    tankAnchor:SetPoint(pos.point or "TOPLEFT", UIParent, pos.point or "TOPLEFT", pos.x or 0, pos.y or 0)
    tankAnchor:SetScale(db.scale)
    local unlocked = cfg.enabled and not db.locked
    tankAnchor.handle:SetShown(unlocked)
    tankAnchor:EnableMouse(unlocked)

    UnregisterAttributeDriver(tankHeader, "state-visibility")
    if not cfg.enabled then
        tankHeader:Hide()
        return
    end
    L.Headers_SetCommon(tankHeader, cfg, db.sortBy == "NAME" and "NAME" or "INDEX")
    tankHeader:SetAttribute("unitsPerColumn", 10)
    tankHeader:SetAttribute("maxColumns", 1)
    if cfg.mode == "NAMES" then
        tankHeader:SetAttribute("groupFilter", nil)
        tankHeader:SetAttribute("nameList", NameList(cfg.names))
    else
        tankHeader:SetAttribute("nameList", nil)
        tankHeader:SetAttribute("strictFiltering", nil)
        -- assigned main tanks / main assists and anyone with the Tank role
        tankHeader:SetAttribute("groupFilter", "MAINTANK,MAINASSIST,TANK")
    end
    local side = (cfg.growth or "DOWN_RIGHT"):find("RIGHT$") and "LEFT" or "RIGHT"
    tankHeader:ClearAllPoints()
    -- frames start just below the mover (or above it when growing up)
    if (cfg.growth or "DOWN_RIGHT"):find("^DOWN") then
        tankHeader:SetPoint("TOP" .. side, tankAnchor, "BOTTOM" .. side, 0, -2)
    else
        tankHeader:SetPoint("BOTTOM" .. side, tankAnchor, "TOP" .. side, 0, 2)
    end
    RegisterAttributeDriver(tankHeader, "state-visibility", "[group:raid] show; hide")
end

------------------------------------------------------------------------
-- Group labels
------------------------------------------------------------------------
local labels = {}

local function Label(i)
    local h = L.raidGroups and L.raidGroups[i]
    if not h then return nil end
    if not labels[i] then
        local t = h:CreateFontString(nil, "OVERLAY")
        t:SetFont(L:FrameFont(), 10, "OUTLINE")
        t:SetShadowOffset(1, -1)
        t:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        t:SetText("Group " .. i)
        labels[i] = t
    end
    return labels[i]
end

function L:GroupLabels_Update()
    local db = L.db
    if not db or not L.raidGroups then return end
    local cfg = L:RaidCfg()
    local byGroup = cfg.groupBy == "GROUP"
    local growth = cfg.growth or "DOWN_RIGHT"
    local down, right = growth:find("^DOWN") ~= nil, growth:find("RIGHT$") ~= nil
    for i = 1, #L.raidGroups do
        local t = Label(i)
        local h = L.raidGroups[i]
        local child = h:GetAttribute("child1")
        local has = child and child:IsShown()
        if t then
            t:SetFont(L:FrameFont(), 10, "OUTLINE")
            t:ClearAllPoints()
            if cfg.orientation == "VERTICAL" then
                t:SetText(cfg.width >= 60 and ("Group " .. i) or ("G" .. i))
                if down then t:SetPoint("BOTTOM", h, "TOP", 0, 2) else t:SetPoint("TOP", h, "BOTTOM", 0, -2) end
            else
                t:SetText("G" .. i)
                if right then t:SetPoint("RIGHT", h, "LEFT", -3, 0) else t:SetPoint("LEFT", h, "RIGHT", 3, 0) end
            end
            t:SetShown(db.groupLabels and byGroup and has and true or false)
        end
    end
end

------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------
hooksecurefunc(L, "Headers_Create", function()
    if tankHeader then return end
    CreateTankAnchor()
    CreateTankHeader()
    L:Tanks_ApplyLayout()
    L:GroupLabels_Update()
end)
hooksecurefunc(L, "Headers_ApplyLayout", function()
    L:Tanks_ApplyLayout()
    L:Debounce("groupLabels", 0, function() L:GroupLabels_Update() end)
end)
hooksecurefunc(L, "Anchor_Update", function() L:Tanks_ApplyLayout() end)
L:On("GROUP_ROSTER_UPDATE", function() L:Debounce("groupLabels", 0.2, function() L:GroupLabels_Update() end) end)
