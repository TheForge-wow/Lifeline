--[[
    Lifeline - Pet frames
    A row/column of smaller pet frames placed just past the party or raid
    frames, following the same orientation and growth direction. Uses the
    game's secure pet headers, so pets get the same click-casting, heals,
    dispel highlights and range fading as players.
]]

local _, L = ...

local partyPets, raidPets
local PET_COLOR = { 0.42, 0.72, 0.34 }   -- pets get one soft green, not their owner's class color
L.PET_COLOR = PET_COLOR

function L.IsPetUnit(unit)
    return type(unit) == "string" and unit:find("pet") ~= nil
end

local function NewPetHeader(name, isRaid)
    local h = CreateFrame("Frame", name, L.anchor, "SecureGroupPetHeaderTemplate")
    h.initButton = L.Headers_InitButtonMethod
    h.isRaid = isRaid
    h.isPet = true
    h:SetAttribute("template", "LifelineUnitButtonTemplate")
    h:SetAttribute("useOwnerUnit", false)
    h:SetAttribute("filterOnPet", true)
    h.llWidth, h.llHeight = 70, 26
    h:SetAttribute("initialConfigFunction", L:Headers_InitSnippet(h))
    table.insert(L.headers, h)
    return h
end

local function Create()
    if partyPets or not L.anchor then return end
    partyPets = NewPetHeader("LifelinePartyPetHeader", false)
    partyPets:SetAttribute("showParty", true)
    raidPets = NewPetHeader("LifelineRaidPetHeader", true)
    raidPets:SetAttribute("showRaid", true)
    raidPets:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
end

-- how many columns (vertical) / rows (horizontal) the player frames use right now
local function PlayerBlocks(isRaid)
    if not isRaid then return 1 end
    local raid = L:RaidCfg()
    if raid.groupBy == "GROUP" then
        local maxGroup = 1
        for i = 1, (GetNumGroupMembers() or 0) do
            local _, _, sub = GetRaidRosterInfo(i)
            if sub and sub > maxGroup then maxGroup = sub end
        end
        return maxGroup
    end
    local n = GetNumGroupMembers() or 0
    return math.max(1, math.min(raid.maxColumns or 8, math.ceil(n / math.max(1, raid.unitsPerColumn or 5))))
end

-- where the pet block starts, measured from the player block's starting corner
local function PetOffset(cfg, blocks, isRaid)
    local growth = cfg.growth or "DOWN_RIGHT"
    local right = growth:find("RIGHT$") ~= nil
    local down = growth:find("^DOWN") ~= nil
    local gap = (isRaid and cfg.groupSpacing or cfg.spacing) + 4
    if cfg.orientation == "HORIZONTAL" then
        local dy = blocks * (cfg.height + (isRaid and cfg.groupSpacing or cfg.spacing)) - (isRaid and cfg.groupSpacing or cfg.spacing) + gap
        return 0, down and -dy or dy
    else
        local dx = blocks * (cfg.width + (isRaid and cfg.groupSpacing or cfg.spacing)) - (isRaid and cfg.groupSpacing or cfg.spacing) + gap
        return right and dx or -dx, 0
    end
end
L.Pets_Offset = PetOffset

local function Place(h, cfg, isRaid)
    local _, _, _, _, headerCorner, anchorCorner = L.GrowthInfo(cfg.orientation, cfg.growth or "DOWN_RIGHT", 0)
    local dx, dy = PetOffset(cfg, PlayerBlocks(isRaid), isRaid)
    h:ClearAllPoints()
    h:SetPoint(headerCorner, L.anchor, anchorCorner, dx, dy)
end

function L:Pets_ApplyLayout()
    if InCombatLockdown() then
        L:RunAfterCombat("pets", function() L:Pets_ApplyLayout() end)
        return
    end
    Create()
    if not partyPets then return end
    local db, pets = L.db, L.db.pets

    UnregisterAttributeDriver(partyPets, "state-visibility")
    UnregisterAttributeDriver(raidPets, "state-visibility")
    if not pets.enabled then
        partyPets:Hide()
        raidPets:Hide()
        return
    end

    for _, entry in ipairs({ { partyPets, db.party, false }, { raidPets, L:RaidCfg(), true } }) do
        local h, cfg, isRaid = entry[1], entry[2], entry[3]
        -- same layout as the players, but at pet size
        local petCfg = {
            width = pets.width, height = pets.height, spacing = cfg.spacing,
            orientation = cfg.orientation, growth = cfg.growth,
            groupSpacing = cfg.groupSpacing,
        }
        L.Headers_SetCommon(h, petCfg, "INDEX")
        h:SetAttribute("unitsPerColumn", 5)
        h:SetAttribute("maxColumns", isRaid and 8 or 1)
        Place(h, cfg, isRaid)
    end
    partyPets:SetAttribute("showPlayer", db.showPlayerInParty)
    partyPets:SetAttribute("showSolo", db.showSolo)
    RegisterAttributeDriver(partyPets, "state-visibility",
        db.showSolo and "[group:raid] hide; show" or "[group:raid] hide; [group:party] show; hide")
    RegisterAttributeDriver(raidPets, "state-visibility", "[group:raid] show; hide")
end

-- the player block grows/shrinks as people join, so move the pets with it
L:On("GROUP_ROSTER_UPDATE", function()
    if L.db and L.db.pets and L.db.pets.enabled and partyPets then
        L:RunAfterCombat("petsPlace", function()
            Place(partyPets, L.db.party, false)
            Place(raidPets, L:RaidCfg(), true)
        end)
    end
end)

------------------------------------------------------------------------
-- Preview: a few fake pets next to the fake players
------------------------------------------------------------------------
local fakePets = {}
local PET_NAMES = { "Wolf", "Voidwalker", "Cat", "Imp", "Boar", "Felhunter", "Raptor", "Succubus" }

hooksecurefunc(L, "Preview_Refresh", function()
    local preview = L.previewFrame
    local mode = L.Preview_IsShown and L:Preview_IsShown()
    local pets = L.db.pets
    local count = 0
    if preview and mode and pets.enabled then
        local isRaid = mode ~= "party"
        local cfg = isRaid and L:RaidCfg() or L.db.party
        count = isRaid and 4 or 2
        local blocks = isRaid and (({ raid10 = 2, raid25 = 5, raid40 = 8 })[mode] or 5) or 1
        if isRaid and cfg.groupBy ~= "GROUP" then
            local n = ({ raid10 = 10, raid25 = 25, raid40 = 40 })[mode] or 25
            blocks = math.max(1, math.min(cfg.maxColumns or 8, math.ceil(n / math.max(1, cfg.unitsPerColumn))))
        end
        local growth = cfg.growth or "DOWN_RIGHT"
        local right = growth:find("RIGHT$") ~= nil
        local down = growth:find("^DOWN") ~= nil
        local _, _, _, _, corner = L.GrowthInfo(cfg.orientation, growth, 0)
        local ox, oy = PetOffset(cfg, blocks, isRaid)
        for i = 1, count do
            local b = fakePets[i]
            if not b then
                b = L:CreateFakeButton(preview, { index = 100 + i, name = PET_NAMES[i],
                    r = PET_COLOR[1], g = PET_COLOR[2], b = PET_COLOR[3],
                    hp = ({ 100, 64, 100, 38 })[i], power = "FOCUS", pp = 70, isPet = true })
                fakePets[i] = b
            end
            b:SetParent(preview)
            b:SetSize(pets.width, pets.height)
            L:Button_ApplyStyle(b)
            local step = i - 1
            local dx, dy = ox, oy
            if cfg.orientation == "HORIZONTAL" then dx = dx + step * (pets.width + cfg.spacing) * (right and 1 or -1)
            else dy = dy + step * (pets.height + cfg.spacing) * (down and -1 or 1) end
            b:ClearAllPoints()
            b:SetPoint(corner, preview, corner, dx, dy)
            b:Show()
            L:Button_UpdateAll(b)
        end
    end
    for i = count + 1, #fakePets do fakePets[i]:Hide() end
end)
