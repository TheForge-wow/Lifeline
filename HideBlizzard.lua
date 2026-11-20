--[[
    Lifeline - Hide the default party/raid frames
    Turning this off needs a /reload to bring Blizzard's frames back.
]]

local _, L = ...

local hidden = CreateFrame("Frame", "LifelineHiddenParent", UIParent)
hidden:SetAllPoints()
hidden:Hide()

local function Kill(frame)
    if not frame then return end
    pcall(frame.UnregisterAllEvents, frame)
    pcall(frame.Hide, frame)
    pcall(frame.SetParent, frame, hidden)
end

local function HideParty()
    Kill(_G.CompactPartyFrame)
    local pf = _G.PartyFrame
    if pf then
        pcall(pf.SetScript, pf, "OnShow", nil)
        if pf.PartyMemberFramePool then
            pcall(function()
                for frame in pf.PartyMemberFramePool:EnumerateActive() do Kill(frame) end
            end)
        end
        Kill(pf)
    end
    for i = 1, 4 do Kill(_G["PartyMemberFrame" .. i]) end
end

local function HideRaid()
    Kill(_G.CompactRaidFrameContainer)
end

local function HideManager()
    local m = _G.CompactRaidFrameManager
    if not m then return end
    pcall(m.UnregisterAllEvents, m)
    pcall(m.Hide, m)
    pcall(m.SetParent, m, hidden)
end

function L:HideBlizzard_Apply()
    L:RunAfterCombat("hideblizz", function()
        if L.db.hideBlizzard then
            HideParty()
            HideRaid()
        end
        if L.db.hideBlizzardManager then HideManager() end
    end)
end

-- Blizzard's frames can be re-shown by Edit Mode / roster changes; keep them down.
L:On("GROUP_ROSTER_UPDATE", function()
    if L.db and L.db.hideBlizzard and not InCombatLockdown() then
        local cp = _G.CompactPartyFrame
        if cp and cp:GetParent() ~= hidden then HideParty() end
    end
end)
