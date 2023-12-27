local addonName, addon = ...

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
local after = C_Timer.After
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

---------------------------
-- Database Defaults
---------------------------
local defaults = {
    throttle = 0.01,
    lb = true,
    lbColor = { 0, 1, 0, 1 },
    sotf = false,
    sotfColor = { 0.66, 0, 1, 1 },
    ver = 1,
}

--------------------------------
-- Spells Affected by SoTF
--------------------------------
local sotfSpells = {
    [774] = true,    -- Rejuv
    [155777] = true, -- Germination
    [8936] = true,   -- Regrowth
    [48438] = true,  -- Wild Growth
}

---------------------------------
-- Spells to allow through CLEU
---------------------------------
local cleuSpells = {
    [774] = true,    -- Rejuv
    [155777] = true, -- Germination
    [8936] = true,   -- Regrowth
    [48438] = true,  -- Wild Growth
    [114108] = true, -- Soul of the Forest
    [197721] = true, -- Flourish
    [203651] = true, -- Overgrowth
}

---------------------------
-- Lifebloom SpellIds
---------------------------
local lifeblooms = {
    [33763] = true,  -- Normal
    [188550] = true, -- Undergrowth
}

---------------------------
-- Rejuv SpellIds
---------------------------
local rejuvs = {
    [774] = true,    -- Rejuv
    [155777] = true, -- Germination
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
    -- Use this frame to ensure the glow is always on top of the buff frame
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

------------------------------------------
-- Create a Callback for luxuriant soil
-- workarounds to more quickly hide glows
-- that "proc" incorrectly
------------------------------------------
local function CreateGlowCallback(buffFrame)
    buffFrame.cb = function(_, spellId, GUID)
        if buffFrame.spellId == spellId and buffFrame.GUID == GUID then
            buffFrame.glow:Hide()
        end
    end
    EventRegistry:RegisterCallback("DELETE_CACHED_AURA", buffFrame.cb)
end

---------------------------
-- SotF Tables
---------------------------
local sotfCache = {}
local function updateCache(spellId, GUID, time, expirationTime)
    sotfCache[spellId .. GUID] = {
        enabled = true,
        time = time,
        expirationTime = expirationTime or 0,
    }
end

local function deleteCachedAura(spellId, GUID)
    sotfCache[spellId .. GUID] = nil

    if addon.luxuriantSoil then
        EventRegistry:TriggerEvent("DELETE_CACHED_AURA", spellId, GUID)
    end
end

---------------------------
-- SotF Glow Func
---------------------------
local function glowSotf(buffFrame)
    buffFrame.glow:SetVertexColor(unpack(addon.db.sotfColor))
    buffFrame.glow:Show()
end

---------------------------
-- SotF Decider
---------------------------
local function glowIfSotf(aura, buffFrame)
    local GUID = buffFrame.GUID
    local spellId = aura.spellId
    local cache = sotfCache[spellId .. GUID]

    if cache then
        if addon.overgrowth then
            local time = aura.expirationTime - aura.duration
            if difftime(time, cache.time) == 0 and rejuvs[spellId] then
                cache.enabled = true
            else
                deleteCachedAura(spellId, GUID)
                return
            end
        end

        if cache.enabled then
            local time = aura.expirationTime - aura.duration
            local expirationDiff = math.floor(aura.expirationTime - cache.expirationTime + 0.5)

            if cache.expirationTime ~= 0
            and rejuvs[spellId]
            and expirationDiff == 2 then -- Nurturing Dormancy
                cache.time = time
            end

            if difftime(time, cache.time) == 0 then
                glowSotf(buffFrame)
                cache.expirationTime = aura.expirationTime
            end
        end
    end
end

---------------------------
-- LB Decider
---------------------------
local function glowIfLB(aura, buffFrame)
    if lifeblooms[aura.spellId] and (aura.sourceUnit == "player") then
        addon.lbInstances[aura.auraInstanceID] = true
        addon.lbAuras[buffFrame] = aura
        addon.lbUpdate:Show()
    else
        buffFrame.glow:Hide()
        addon.lbAuras[buffFrame] = nil
    end
end

-------------------------------------
-- Decide if we care about the aura
-------------------------------------
function addon:HandleAura(buffFrame, aura)
    if not buffFrame.glow then
        CreateGlowFrame(buffFrame)
    end

    if not aura
    or aura.isHarmful then
        buffFrame.glow:Hide()
        return
    end

    local spellId = aura.spellId

    if self.db.sotf then
        if not buffFrame.cb and self.luxuriantSoil then
            CreateGlowCallback(buffFrame)
        end
        buffFrame.spellId = spellId
        buffFrame.GUID = UnitGUID(buffFrame:GetParent().unit)
    end

    if self.db.lb then
        glowIfLB(aura, buffFrame)
    else
        buffFrame.glow:Hide()
    end

    if aura.sourceUnit ~= "player" then
        return
    end

    if self.db.sotf and sotfSpells[spellId] then
        glowIfSotf(aura, buffFrame)
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

-----------------------------------
-- Localized functions for CLEU
-- so C_Timer doesn't have to
-- create new functions every run
-----------------------------------
local function disableOvergrowth()
    addon.overgrowth = false
end

local function disableSotfAura()
    addon.sotfUp = false
end

---------------------------
-- CLEU
---------------------------
function addon:SPELL_CAST_SUCCESS(spellId)
    if spellId == 203651 then
        self.overgrowth = true
        after(0, disableOvergrowth)
    end
end

function addon:SPELL_AURA_APPLIED(spellId, destGUID, timestamp)
    if spellId == 114108 then
        self.sotfUp = true
    end

    if sotfSpells[spellId] then
        if self.sotfUp then
            updateCache(spellId, destGUID, timestamp)

            if self.luxuriantSoil then
                after(0.01, function()
                    -- if sotf is still up now, it wasn't consumed and instead
                    -- luxuriant soil most likely proc'd while sotf buff was active
                    if self.sotfUp then
                        deleteCachedAura(spellId, destGUID)
                    end
                end)
            end
        elseif sotfCache[spellId .. destGUID] then
            deleteCachedAura(spellId, destGUID)
        end
    end
end

function addon:SPELL_AURA_REFRESH(spellId, destGUID, timestamp)
    if sotfSpells[spellId] then
        if self.sotfUp then
            updateCache(spellId, destGUID, timestamp)

            if self.luxuriantSoil then
                after(0.01, function()
                    -- if sotf is still up now, it wasn't consumed and instead
                    -- luxuriant soil most likely proc'd while sotf buff was active
                    if self.sotfUp then
                        deleteCachedAura(spellId, destGUID)
                    end
                end)
            end
        elseif sotfCache[spellId .. destGUID] then
            deleteCachedAura(spellId, destGUID)
        end
    end
end

function addon:SPELL_AURA_REMOVED(spellId)
    if spellId == 114108 then
        after(0, disableSotfAura)
    end
end

function addon:COMBAT_LOG_EVENT_UNFILTERED()
    if not self.db.sotf then
        eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end

    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= self.playerGUID
    or not cleuSpells[spellId] then
        return
    end

    if self[subevent] then
        self[subevent](self, spellId, destGUID, GetTime())
    end
end

---------------------------
-- Talent Updates
---------------------------
function addon:TRAIT_TREE_CURRENCY_INFO_UPDATED()
    -- Check if talented into Luxuriant Soil so we can enable some workarounds
    -- which are less performant but necessary to stop random procs
    local lsNode = C_Traits.GetNodeInfo(C_ClassTalents.GetActiveConfigID(), 82068)
    self.luxuriantSoil = (lsNode and lsNode.activeRank > 0) and true or false
end

function addon:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
    self:TRAIT_TREE_CURRENCY_INFO_UPDATED()
end

---------------------------
-- Toggle Sotf
---------------------------
function addon:EnableSotf(enable)
    self.db.sotf = enable

    if self.playerClass == "DRUID" and enable then
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        eventFrame:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
        eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
        self:TRAIT_TREE_CURRENCY_INFO_UPDATED()
    else
        eventFrame:UnregisterAllEvents()
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

    -------------------------------------------
    -- Register to Blizzard Compartment Frame
    -------------------------------------------
    if AddonCompartmentFrame then
        AddonCompartmentFrame:RegisterAddon({
            text = "LifebloomGlow",
            icon = "Interface\\AddOns\\LifebloomGlow\\media\\logo",
            notCheckable = true,
            func = function()
                InterfaceOptionsFrame_OpenToCategory(addonName)
                InterfaceOptionsFrame_OpenToCategory(addonName)
            end,
        })
    end

    -- Only load for druids
    if (self.playerClass ~= "DRUID") then
        self:Print("Functionality disabled when not playing a |cffff7c0aDruid|r")
        return
    end

    self:EnableSotf(self.db.sotf)

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

            if next(self.lbAuras) == nil then
                s:Hide()
                return
            end

            for buffFrame, aura in pairs(self.lbAuras) do
                if aura.expirationTime < GetTime() then
                    buffFrame.glow:Hide()
                    self.lbAuras[buffFrame] = nil
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
                    self.lbAuras[buffFrame] = nil
                end
            end
        end
    end)
    self.lbUpdate:Hide()

    self:Print("Loaded. Type |cFF50C878/lbg|r for options.")
end
