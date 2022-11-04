local addonName, addon = ...

---------------------------
-- Lua Upvalues
---------------------------
local pairs = pairs
local unpack = unpack
local next = next
local modf = math.modf
local select = select

---------------------------
-- WoW API Upvalues
---------------------------
local CopyTable = CopyTable
local GetTime = GetTime
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local after = C_Timer.After
local UnitIsFriend = UnitIsFriend
local UnitClass = UnitClass

---------------------------
-- Database Defaults
---------------------------
local defaults = {
    throttle = 0.01,
    lb = true,
    lbColor = { 0, 1, 0, 1 },
    sotf = true,
    sotfColor = { 0.66, 0, 1, 1 },
}

---------------------------
-- Spells Affected by SoTF
---------------------------
local sotf_spells = {
    [774] = true, -- Rejuv
    [155777] = true, -- Germination
    [8936] = true, -- Regrowth
    [48438] = true, -- Wild Growth
}

----------------------------------------
-- Spells Affected by Invigorate & SotF
----------------------------------------
local invigorate_spells = {
    [774] = true, -- Rejuv
    [155777] = true, -- Germination
}

---------------------------------------------
-- Spells Affected by Power of the Archdruid
---------------------------------------------
local archdruid_spells = {
    [774] = true, -- Rejuv
    [155777] = true, -- Germination
    [8936] = true, -- Regrowth
}

--[[-----------------------------------
    Casting Overgrowth with SotF up
    causes only rejuv or germ to be
    empowered, so we need to block
    these spells from being checked
-------------------------------------]]
local overgrowth_blocked = {
    [8936] = true, -- Regrowth
    [48438] = true, -- Wild Growth
}

---------------------------
-- Lifebloom SpellIds
---------------------------
local lifeblooms = {
    [33763] = true, -- Normal
    [188550] = true, -- Undergrowth
}

------------------------------
-- Spell Cast Success Spells
------------------------------
local cast_success_spells = {
    [203651] = true, -- Overgrowth
    [392160] = true, -- Invigorate
    [18562] = true, -- Swiftmend
    [197721] = true, -- Flourish
}

--[[------------------------------------------------------------------------
    Talent Info Ids

    [traitNodeId] = { name = "name used check", entryID = traitEntryId}
--------------------------------------------------------------------------]]
local talentIds = {
    [82079] = { name = "verdant", entryID = 103137 }, -- Verdant Infusion
    [82068] = { name = "luxuriant", entryID = 103124 }, -- Luxuriant Soil
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
-- Enabling SotF Checking
---------------------------
function addon:EnableSotF(enable)
    if enable then
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end

---------------------------
-- Print Functions
---------------------------
function addon:Print(msg)
    print("|cFF50C878L|rifebloom|cFF50C878G|rlow: " .. msg)
end

function addon:Debug(msg)
    if addon.db.debug then
        print("|cFF50C878DEBUG|r: " .. msg)
    end
end

---------------------------
-- Glow Frame Func
---------------------------
local function CreateGlowFrame(buffFrame)
    -- Use this frame to ensure the glow is always on top of the buff frame
    local glowFrame = CreateFrame("Frame", nil, buffFrame)
    glowFrame:SetAllPoints()
    glowFrame:SetFrameLevel(buffFrame:GetFrameLevel() + 10)

    local glow = glowFrame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
    glow:SetDesaturated(true)
    glow:SetPoint("TOPLEFT", -2.5, 2.5)
    glow:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
    glow:SetBlendMode("ADD")
    buffFrame.glow = glow
end

---------------------------
-- SotF Glow Func
---------------------------
local function ShowSotFGlow(buffFrame, spellId, aura)
    buffFrame.glow:SetVertexColor(unpack(addon.db.sotfColor))
    buffFrame.glow:Show()
    addon.sotfInfo.instances[spellId].aura = aura
end

---------------------------
-- SotF Decider
---------------------------
local function glowIfSotf(aura, buffFrame)
    local spellId = aura.spellId
    local sotf = addon.sotfInfo
    local spell = sotf.instances[spellId]

    if spell then
        -- First time an aura is seen
        if spell.aura == nil then

            local aura_time = modf(aura.expirationTime - aura.duration)
            local saved_time = modf(spell.time)

            if addon.potad and archdruid_spells[spellId] then
                ShowSotFGlow(buffFrame, spellId, aura)
                addon.potad = false
            elseif addon.overgrowth and overgrowth_blocked[spellId] then
                sotf.instances[spellId] = nil
                return
            elseif aura_time == saved_time then
                ShowSotFGlow(buffFrame, spellId, aura)
            end
        elseif spellId == 48438 or (spell.aura.auraInstanceID == aura.auraInstanceID) then
            if addon.invigorate and invigorate_spells[spellId] then
                spell.aura = aura
            elseif addon.flourish then
                spell.aura = aura
            elseif addon.verdant then
                spell.aura = aura
                ShowSotFGlow(buffFrame, spellId, aura)
                return
            elseif (modf(spell.aura.expirationTime) + 1) == modf(aura.expirationTime) then
                -- Workaround for Nurturing Dormancy
                spell.aura = aura
            end

            if spell.aura.expirationTime == aura.expirationTime then
                ShowSotFGlow(buffFrame, spellId, aura)
            elseif modf(spell.aura.expirationTime) == modf(aura.expirationTime) then
                -- this should be rare, but sometimes the expiration is off by a thousandth of a second or so
                -- so we'll just double check here, as that's probably still the right aura.
                ShowSotFGlow(buffFrame, spellId, aura)
            end
        end
    end

    if addon.lux then
        after(0.01, function()
            glowIfSotf(aura, buffFrame)
        end)
    end
end

---------------------------
-- LB Decider
---------------------------
local function glowIfLB(aura, buffFrame)
    if lifeblooms[aura.spellId] then
        addon.lbInstances[aura.auraInstanceID] = true
        addon.auras[buffFrame] = aura
        addon.lbUpdate:Show()
    elseif addon.auras[buffFrame] then
        addon.auras[buffFrame] = nil
    end
end

-------------------------------------
-- Decide if we care about the aura
-------------------------------------
function addon:HandleAura(buffFrame, aura)
    if not buffFrame.glow then
        CreateGlowFrame(buffFrame)
    end

    buffFrame.glow:Hide()

    if not aura or not aura.isFromPlayerOrPlayerPet or aura.isHarmful then return end

    if self.db.sotf then
        local spell = self.sotfInfo.instances[aura.spellId]
        if spell and spell.aura then
            if spell.aura.expirationTime < GetTime() then
                self.sotfInfo.instances[aura.spellId] = nil
            end
        end
        glowIfSotf(aura, buffFrame)
    end

    if self.db.lb then
        glowIfLB(aura, buffFrame)
    end
end

---------------------------
-- Target/Focus Frame Core
---------------------------
function addon:TargetFocus(root)
    -- No need to waste CPU on enemies except mages for spell stealing our hots
    if not UnitIsFriend("player", root.unit) and not select(2, UnitClass(root.unit) == "MAGE") then return end

    for buffFrame in root.auraPools:EnumerateActive() do
        self:HandleAura(buffFrame, C_UnitAuras.GetAuraDataByAuraInstanceID(root.unit, buffFrame.auraInstanceID))
    end
end

local function addInstance(spellId, time)
    local sotf = addon.sotfInfo
    if spellId == 774 and addon.activeTalents.luxuriant then
        addon.lux = true
        after(0.01, function()
            if not addon.sotf_up then
                sotf.instances[spellId] = {
                    time = time,
                }
            end
            addon.lux = false
        end)
    else
        sotf.instances[spellId] = {
            time = GetTime(),
        }
    end
end

--[[-------------------------------------------------------
    Localize these functions so C_Timer isn't creating new
    anonymous functions every time it's called.
---------------------------------------------------------]]
local function disableSotf()
    addon.sotf_up = false
end

local function disableOvergrowth()
    addon.overgrowth = false
end

local function disableInvigorate()
    addon.invigorate = false
end

local function disableVerdant()
    addon.verdant = false
end

local function disableFlourish()
    addon.flourish = false
end

---------------------------
-- SotF Combat Log Checking
---------------------------
function addon:COMBAT_LOG_EVENT_UNFILTERED()
    local _, event, _, sourceGUID, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= self.playerGUID then
        return
    end

    if event == "SPELL_CAST_SUCCESS" and (cast_success_spells[spellId] or invigorate_spells[spellId]) then
        if spellId == 392160 then
            self.invigorate = true
            after(0.1, disableInvigorate)
        elseif spellId == 203651 then
            self.overgrowth = true
            after(0.1, disableOvergrowth)
        elseif self.activeTalents.verdant and spellId == 18562 then
            self.verdant = true
            after(0.1, disableVerdant)
        elseif spellId == 197721 then
            self.flourish = true
            after(0.1, disableFlourish)
        end
    elseif event == "SPELL_AURA_APPLIED" and (spellId == 114108 or spellId == 392303 or sotf_spells[spellId]) then
        if spellId == 114108 then
            self.sotf_up = true
        elseif spellId == 392303 then
            -- power of the arch druid
            self.potad = true
        elseif self.sotf_up and spellId then
            addInstance(spellId, GetTime())
        end
    elseif event == "SPELL_AURA_REFRESH" and spellId and sotf_spells[spellId] and self.sotf_up then
        addInstance(spellId, GetTime())
    elseif event == "SPELL_AURA_REMOVED" and (spellId == 114108 or sotf_spells[spellId]) then
        --[[
            Wait until the next frame to disable sotf otherwise
            the game sometimes sends the aura_removed event before
            the aura_applied event due to batching
        ]]
        if spellId == 114108 then
            after(0, disableSotf)
        end
    end
end

---------------------------
-- Target / Focus Changing
---------------------------
function addon:PLAYER_TARGET_CHANGED()
    self:TargetFocus(TargetFrame)
end

function addon:PLAYER_FOCUS_CHANGED()
    self:TargetFocus(FocusFrame)
end

---------------------------
-- Talent Update
---------------------------
function addon:SPELLS_CHANGED()
    wipe(self.activeTalents)

    local configID = C_ClassTalents.GetActiveConfigID()
    if configID then
        for nodeID, info in pairs(talentIds) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo.currentRank > 0 then
                if info.entryID and info.entryID == nodeInfo.activeEntry.entryID then
                    self.activeTalents[info.name] = true
                elseif info.entryID == nil then
                    self.activeTalents[info.name] = true
                end
            end
        end
    end
end

---------------------------
-- Initialize
---------------------------
function addon:PLAYER_LOGIN()
    LifebloomGlowDB = LifebloomGlowDB or CopyTable(defaults)

    ---------------------------
    -- DB Validation
    ---------------------------
    for k in pairs(defaults) do
        if LifebloomGlowDB[k] == nil then
            LifebloomGlowDB = CopyTable(defaults)
        end
    end

    self.db = LifebloomGlowDB
    self.auras = {}
    self.sotfInfo = {
        instances = {},
    }
    self.lbInstances = {}
    self.playerGUID = UnitGUID("player")
    self.activeTalents = {}

    self:Options()

    ---------------------------
    -- Slash Handler
    ---------------------------
    SLASH_LIFEBLOOMGLOW1 = "/lbg"
    function SlashCmdList.LIFEBLOOMGLOW(msg)
        if msg == "help" then
            self:Print("Available commands:")
            self:Print("/lbg help - Show this help")
        else
            InterfaceOptionsFrame_OpenToCategory(addonName)
            InterfaceOptionsFrame_OpenToCategory(addonName)
        end
    end

    -- Only load for druids
    if (select(2, UnitClass("player")) ~= "DRUID") then
        self:Print("Disabled when not playing a Druid.")
        return
    end

    eventFrame:RegisterEvent("SPELLS_CHANGED")
    self:EnableSotF(self.db.sotf)

    ---------------------------
    -- Hooks
    ---------------------------
    hooksecurefunc("CompactUnitFrame_UtilSetBuff", function(s, ...)
        self:HandleAura(s, ...)
    end)

    hooksecurefunc(TargetFrame, "UpdateAuras", function(s)
        self:TargetFocus(s)
    end)

    hooksecurefunc(FocusFrame, "UpdateAuras", function(s)
        self:TargetFocus(s)
    end)

    ----------------------------------------
    -- Lifebloom Update Frame (Main Loop)
    ----------------------------------------
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

            if next(self.auras) == nil then
                s:Hide()
                return
            end

            for buffFrame, aura in pairs(self.auras) do
                if aura.expirationTime < GetTime() then
                    buffFrame.glow:Hide()
                    self.auras[buffFrame] = nil
                    self.lbInstances[aura.auraInstanceID] = nil
                elseif self.lbInstances[aura.auraInstanceID] then
                    local timeRemaining = (aura.expirationTime - GetTime()) / aura.timeMod
                    local refreshTime = aura.duration * 0.3

                    if (timeRemaining <= refreshTime) then
                        buffFrame.glow:SetVertexColor(unpack(self.db.lbColor))
                        buffFrame.glow:Show()
                    else
                        buffFrame.glow:Hide()
                    end
                else
                    buffFrame.glow:Hide()
                    self.auras[buffFrame] = nil
                end
            end
        end
    end)
    self.lbUpdate:Hide()

    self:Print("Loaded. Type |cFF50C878/lbg|r for options.")
end
