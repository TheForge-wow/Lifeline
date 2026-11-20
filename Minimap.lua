--[[
    Lifeline - Minimap button
]]

local _, L = ...
local btn

local function UpdatePosition()
    local angle = math.rad(L.db.minimap.angle or 205)
    local r = (Minimap:GetWidth() / 2) + 6
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function L:Minimap_Create()
    if btn then return end
    btn = CreateFrame("Button", "LifelineMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\Lifeline\\Media\\icon")
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            L:SetLocked(not L.db.locked)
        elseif IsShiftKeyDown() then
            L:Preview_Toggle()
        else
            L:Options_Toggle()
        end
    end)

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            cx, cy = cx / s, cy / s
            L.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff4cd98cLifeline|r  v" .. L.version)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Left-click", "Settings", 1, 1, 1, 0.6, 0.65, 0.7)
        GameTooltip:AddDoubleLine("Right-click", L.db.locked and "Unlock frames" or "Lock frames", 1, 1, 1, 0.6, 0.65, 0.7)
        GameTooltip:AddDoubleLine("Shift-click", "Toggle preview", 1, 1, 1, 0.6, 0.65, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    L:Minimap_Update()
end

function L:Minimap_Update()
    if not btn then return end
    btn:SetShown(not L.db.minimap.hide)
    UpdatePosition()
end
