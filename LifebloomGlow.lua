local _, addon = ...

---------------------------
-- Lua Upvalues
---------------------------
local pairs = pairs
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
local UnitExists = UnitExists
local C_UnitAuras = C_UnitAuras
-- Fallback for <12.0 where secret values don't exist
local issecretvalue = issecretvalue or function() return false end

---------------------------
-- Database Defaults
---------------------------
local defaults = {
    throttle = 0.01,
    lb = true,
    rejuvGlow = true,
    glowFrameInstead = true,
    lbColor = { 0, 1, 0 },
    rejuvColor = { 0.83, 0, 1 },
    glowPadding = 0,
    ver = 1,
}

---------------------------
-- Spells & Icons
---------------------------
local lifeblooms = {
    [33763] = true,
    -- [188550] = true, -- Undergrowth (removed in midnight, keeping for hopium)
}

local rejuvSpells = {
    [774] = true,    -- Rejuvenation
    [155777] = true, -- Germination
}

local empoweredIcons = {
    [7195165] = true, -- Rejuvenation
    [1033486] = true, -- Germination
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
    --glow:SetAtlas("spellbook-item-unassigned-glow")
    glow:SetAtlas("newplayertutorial-drag-slotgreen")
    glow:SetDesaturated(true)
    glow:SetTexCoord(.25, .75, .25, .75)

    local padding = addon.db.glowPadding
    glow:SetPoint("TOPLEFT", -padding, padding)
    glow:SetPoint("BOTTOMRIGHT", padding, -padding)

    buffFrame.glow = glow
end

---------------------------------------------------------------
-- Aura Evaluation
-- Note: Lifebloom/Rejuv has been added as neversecret auras
-- by Blizzard, but this is a temporary change and will
-- likely be reverted in the future.
---------------------------------------------------------------
local function EvaluateGlows(aura, buffFrame)
    -- if this is a secret aura we don't care about it regardless
    if issecretvalue(aura.spellId) then
        buffFrame.glow:Hide()
        addon.lbAuras[buffFrame] = nil
        return
    end

    if aura.sourceUnit == "player" then
        if lifeblooms[aura.spellId] and addon.db.lb then
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
                buffFrame._safeAura.refreshTime = refreshTime

                addon.lbAuras[buffFrame] = buffFrame._safeAura
                addon.lbInstances[aura.auraInstanceID] = true
                addon.lbUpdate:Show()

                if timeRemaining <= refreshTime then
                    buffFrame.glow:SetVertexColor(addon.cachedLbR, addon.cachedLbG, addon.cachedLbB)
                    buffFrame.glow:Show()
                else
                    buffFrame.glow:Hide()
                end
            end

            return
        elseif rejuvSpells[aura.spellId] and addon.db.rejuvGlow and empoweredIcons[aura.icon] then
            buffFrame.glow:SetVertexColor(addon.cachedRejuvR, addon.cachedRejuvG, addon.cachedRejuvB)
            buffFrame.glow:Show()
            addon.lbAuras[buffFrame] = nil -- Clean up in case this frame used to be a lifebloom

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

    if self.db.lb or self.db.rejuvGlow then
        EvaluateGlows(aura, buffFrame)
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

----------------------
-- CompactUnitFrame
----------------------
function addon:ClearCUFGlows(frame)
    if frame.glow then
        frame.auraInstanceID = nil
        self:HandleAura(frame, nil)
    end
end

function addon:UpdateCUF(frame)
    local unit = frame.displayedUnit or frame.unit
    if not unit or not UnitExists(unit) or not self.db.glowFrameInstead then
        self:ClearCUFGlows(frame)
        return
    end

    local foundAura = nil

    if self.db.lb then
        for spellId in pairs(lifeblooms) do
            local aura = C_UnitAuras.GetUnitAuraBySpellID(unit, spellId, "PLAYER|HELPFUL")
            if aura and not issecretvalue(aura.spellId) then
                foundAura = aura
                break
            end
        end
    end

    if not foundAura and self.db.rejuvGlow then
        for spellId in pairs(rejuvSpells) do
            local aura = C_UnitAuras.GetUnitAuraBySpellID(unit, spellId, "PLAYER|HELPFUL")
            if aura and not issecretvalue(aura.spellId) and empoweredIcons[aura.icon] then
                foundAura = aura
                break
            end
        end
    end

    if foundAura then
        frame.auraInstanceID = foundAura.auraInstanceID
        self:HandleAura(frame, foundAura)
    else
        self:ClearCUFGlows(frame)
    end
end

function addon:UNIT_AURA(unit)
    if not self.cufPool then return end
    for cuf in pairs(self.cufPool) do
        if cuf:IsVisible() and (cuf.unit == unit or cuf.displayedUnit == unit) then
            self:UpdateCUF(cuf)
        end
    end
end

function addon:GROUP_ROSTER_UPDATE()
    if not self.cufPool then return end
    for cuf in pairs(self.cufPool) do
        if cuf:IsVisible() then
            self:UpdateCUF(cuf)
        end
    end
end

---------------------------
-- Helpers
---------------------------
function addon:UpdateColorCache()
    self.cachedLbR = self.db.lbColor[1]
    self.cachedLbG = self.db.lbColor[2]
    self.cachedLbB = self.db.lbColor[3]

    self.cachedRejuvR = self.db.rejuvColor[1]
    self.cachedRejuvG = self.db.rejuvColor[2]
    self.cachedRejuvB = self.db.rejuvColor[3]
end

---------------------------
-- Initializations
---------------------------

function addon:InitHooks()
    self.cufPool = {}

    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        if not frame:IsForbidden() then
            self.cufPool[frame] = true
            self:UpdateCUF(frame)
        end
    end)

    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    hooksecurefunc(TargetFrame, "UpdateAuras", function(s)
        self:TargetFocus(s)
    end)
    hooksecurefunc(FocusFrame, "UpdateAuras", function(s)
        self:TargetFocus(s)
    end)

    -- Workarounds for other addons. See Compatibility.lua
    self:Compatibility()
end

function addon:InitLBLoop()
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

            local now = GetTime()

            for buffFrame, aura in pairs(self.lbAuras) do
                if buffFrame.auraInstanceID ~= aura.auraInstanceID then
                    buffFrame.glow:Hide()
                    self.lbAuras[buffFrame] = nil
                else
                    if aura.expirationTime < now then
                        buffFrame.glow:Hide()
                        self.lbAuras[buffFrame] = nil
                        if aura.auraInstanceID then
                            self.lbInstances[aura.auraInstanceID] = nil
                        end
                    elseif self.lbInstances[aura.auraInstanceID] then
                        local timeRemaining = (aura.expirationTime - now) / aura.timeMod

                        if (timeRemaining <= aura.refreshTime) then
                            buffFrame.glow:SetVertexColor(self.cachedLbR, self.cachedLbG, self.cachedLbB)
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
end

function addon:InitDatabase()
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
end

function addon:InitCommands()
    SLASH_LIFEBLOOMGLOW1 = "/lbg"
    function SlashCmdList.LIFEBLOOMGLOW(msg)
        if msg == "help" then
            self:Print("Available commands:")
            self:Print("/lbg help - Show this help")
        else
            if InCombatLockdown() then
                self:Print("Cannot open options while in combat.")
            else
                Settings.OpenToCategory(self.optionsCategoryID)
            end
        end
    end

    if AddonCompartmentFrame then
        AddonCompartmentFrame:RegisterAddon({
            text = "LifebloomGlow",
            icon = "Interface\\AddOns\\LifebloomGlow\\media\\logo",
            notCheckable = true,
            func = function()
                if InCombatLockdown() then
                    self:Print("Cannot open options while in combat.")
                else
                    Settings.OpenToCategory(self.optionsCategoryID)
                end
            end,
        })
    end
end

function addon:PLAYER_LOGIN()
    self:InitDatabase()
    self:UpdateColorCache()
    self:Options()
    self:InitCommands()

    self.lbInstances = {}
    self.lbAuras = {}
    self.playerGUID = UnitGUID("player")
    self.playerClass = select(2, UnitClass("player"))

    if (self.playerClass ~= "DRUID") then
        self:Print("Functionality disabled when not playing a |cffff7c0aDruid|r")
        return
    end

    self:InitHooks()
    self:InitLBLoop()

    self:Print("Loaded. Type |cFF50C878/lbg|r for options.")
end
