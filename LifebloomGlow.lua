local _, addon = ...

---------------------------
-- Lua Upvalues
---------------------------
local pairs = pairs
local unpack = unpack
local next = next
local select = select

---------------------------
-- WoW API Upvalues
---------------------------
local CopyTable = CopyTable
local GetTime = GetTime
local UnitClass = UnitClass
local CreateFrame = CreateFrame
local UnitGUID = UnitGUID
local C_UnitAuras = C_UnitAuras
-- Fallback for <12.0 where secret values don't exist
local issecretvalue = issecretvalue or function() return false end

---------------------------
-- Database Defaults
---------------------------
local defaults = {
    throttle = 0.01,
    lb = true,
    lbColor = { 0, 1, 0 },
    ver = 1,
}

---------------------------
-- Lifebloom SpellIds
---------------------------
local lifeblooms = {
    [33763] = true,
    -- [188550] = true, -- Undergrowth (removed in midnight, keeping for hopium)
}

---------------------------
-- Event Handling
---------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    addon[event](addon, ...)
end)

---------------------------
-- Print Functions
---------------------------
function addon:Print(...)
    print("|cFF50C878L|rifebloom|cFF50C878G|rlow:", ...)
end

---------------------------
-- Glow Frame Func
---------------------------
local function CreateGlowFrame(buffFrame)
    local glowFrame = CreateFrame("Frame", nil, buffFrame)
    glowFrame:SetAllPoints()
    glowFrame:SetFrameLevel(buffFrame:GetFrameLevel() + 10)

    local glow = glowFrame:CreateTexture(nil, "OVERLAY")
    glow:SetAtlas("newplayertutorial-drag-slotgreen")
    glow:SetDesaturated(true)
    glow:SetAllPoints()
    glow:SetTexCoord(.24, .76, .24, .76)

    buffFrame.glow = glow
end

-------------------------------------------------------
-- LB Decider
-- Note: Lifebloom has been added as a neversecret aura
-- by Blizzard, but this is a temporary change and will
-- likely be reverted in the future.
-------------------------------------------------------
local function glowIfLB(aura, buffFrame)
    if issecretvalue(aura.spellId) then
        buffFrame.glow:Hide()
        addon.lbAuras[buffFrame] = nil
        return
    end

    if lifeblooms[aura.spellId] then
        if aura.sourceUnit == "player" then
            local expirationTime = aura.expirationTime or 0
            local duration = aura.duration or 0
            local now = GetTime()

            if expirationTime < now then
                buffFrame.glow:Hide()
                addon.lbAuras[buffFrame] = nil
                if aura.auraInstanceID then
                    addon.lbInstances[aura.auraInstanceID] = nil
                end
            else
                local timeRemaining = expirationTime - now

                local timeMod = aura.timeMod or 1
                if timeMod <= 0 then timeMod = 1 end

                timeRemaining = timeRemaining / timeMod
                local refreshTime = duration * 0.3

                if not buffFrame._safeAura then buffFrame._safeAura = {} end
                buffFrame._safeAura.expirationTime = expirationTime
                buffFrame._safeAura.duration = duration
                buffFrame._safeAura.timeMod = timeMod
                buffFrame._safeAura.auraInstanceID = aura.auraInstanceID

                addon.lbAuras[buffFrame] = buffFrame._safeAura
                addon.lbInstances[aura.auraInstanceID] = true
                addon.lbUpdate:Show()

                if timeRemaining <= refreshTime then
                    buffFrame.glow:SetVertexColor(unpack(addon.db.lbColor))
                    buffFrame.glow:Show()
                else
                    buffFrame.glow:Hide()
                end
            end
            return
        end
    end

    buffFrame.glow:Hide()
    addon.lbAuras[buffFrame] = nil
end

-------------------------------------
-- HandleAura Entry Point
-------------------------------------
function addon:HandleAura(buffFrame, aura)
    if not buffFrame.glow then
        CreateGlowFrame(buffFrame)
    end

    if not aura then
        buffFrame.glow:Hide()
        return
    end

    if self.db.lb then
        glowIfLB(aura, buffFrame)
    else
        buffFrame.glow:Hide()
    end
end

---------------------------
-- Target/Focus Frame Core
---------------------------
function addon:TargetFocus(root)
    for buffFrame in root.auraPools:EnumerateActive() do
        self:HandleAura(buffFrame, C_UnitAuras.GetAuraDataByAuraInstanceID(root.unit, buffFrame.auraInstanceID))
    end
end

---------------------------
-- Initialize
---------------------------
function addon:PLAYER_LOGIN()
    LifebloomGlowDB = LifebloomGlowDB or CopyTable(defaults)

    local ver = LifebloomGlowDB.ver or 0
    if ver < 1 then
        LifebloomGlowDB = CopyTable(defaults)
    else
        for k in pairs(defaults) do
            if LifebloomGlowDB[k] == nil then
                LifebloomGlowDB = CopyTable(defaults)
                break
            end
        end
    end

    self.db = LifebloomGlowDB
    self.lbInstances = {}
    self.lbAuras = {}
    self.playerGUID = UnitGUID("player")
    self.playerClass = select(2, UnitClass("player"))

    self:Options()

    SLASH_LIFEBLOOMGLOW1 = "/lbg"
    function SlashCmdList.LIFEBLOOMGLOW(msg)
        if msg == "help" then
            self:Print("Available commands:")
            self:Print("/lbg help - Show this help")
        else
            Settings.OpenToCategory(self.optionsCategoryID)
        end
    end

    if AddonCompartmentFrame then
        AddonCompartmentFrame:RegisterAddon({
            text = "LifebloomGlow",
            icon = "Interface\\AddOns\\LifebloomGlow\\media\\logo",
            notCheckable = true,
            func = function()
                Settings.OpenToCategory(self.optionsCategoryID)
            end,
        })
    end

    if (self.playerClass ~= "DRUID") then
        self:Print("Functionality disabled when not playing a |cffff7c0aDruid|r")
        return
    end

    hooksecurefunc("CompactUnitFrame_UtilSetBuff", function(s, ...)
        self:HandleAura(s, ...)
    end)

    hooksecurefunc(TargetFrame, "UpdateAuras", function(s)
        self:TargetFocus(s)
    end)

    hooksecurefunc(FocusFrame, "UpdateAuras", function(s)
        self:TargetFocus(s)
    end)

    self.lbUpdate = CreateFrame("Frame")
    local lastUpdate = 0
    self.lbUpdate:SetScript("OnUpdate", function(s, elapsed)
        if not self.db.lb then
            s:Hide()
            return
        end

        lastUpdate = lastUpdate + elapsed
        if lastUpdate >= self.db.throttle then
            lastUpdate = 0

            if next(self.lbAuras) == nil then
                s:Hide()
                return
            end

            for buffFrame, aura in pairs(self.lbAuras) do
                if buffFrame.auraInstanceID ~= aura.auraInstanceID then
                    buffFrame.glow:Hide()
                    self.lbAuras[buffFrame] = nil
                else
                    local now = GetTime()

                    if aura.expirationTime < now then
                        buffFrame.glow:Hide()
                        self.lbAuras[buffFrame] = nil
                        if aura.auraInstanceID then
                            self.lbInstances[aura.auraInstanceID] = nil
                        end
                    elseif self.lbInstances[aura.auraInstanceID] then
                        local timeRemaining = (aura.expirationTime - now) / aura.timeMod
                        local refreshTime = aura.duration * 0.3

                        if (timeRemaining <= refreshTime) then
                            buffFrame.glow:SetVertexColor(unpack(self.db.lbColor))
                            buffFrame.glow:Show()
                        else
                            buffFrame.glow:Hide()
                        end
                    else
                        buffFrame.glow:Hide()
                        self.lbAuras[buffFrame] = nil
                    end
                end
            end
        end
    end)
    self.lbUpdate:Hide()

    self:Print("Loaded. Type |cFF50C878/lbg|r for options.")
end
