local addonName, addon = ...

---------------------------
-- Lua Upvalues
---------------------------
local pairs    = pairs
local unpack   = unpack
local next     = next
local select   = select
local tinsert  = table.insert
local tonumber = tonumber
local min      = math.min

---------------------------
-- WoW API Upvalues
---------------------------
local CopyTable = CopyTable
local GetTime = GetTime
local UnitIsFriend = UnitIsFriend
local UnitClass = UnitClass
local after = C_Timer.After
local wipe = wipe
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

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

--------------------------------
-- Spells Affected by SoTF
-- [spellId] = sotf multiplier
--------------------------------
local sotf_spells = {
    [774] = 2.4, -- Rejuv
    [155777] = 2.4, -- Germination
    [8936] = 2.35, -- Regrowth
    [48438] = 1.45, -- Wild Growth
}

---------------------------
-- Lifebloom SpellIds
---------------------------
local lifeblooms = {
    [33763] = true, -- Normal
    [188550] = true, -- Undergrowth
}

---------------------------------------
-- All Druid hots that affect mastery
---------------------------------------
local druidHots = {
    [774] = true, -- Rejuv
    [155777] = true, -- Germination
    [8936] = true, -- Regrowth
    [48438] = true, -- Wild Growth
    [33763] = true, -- Lifebloom
    [188550] = true, -- Undergrowth
    [740] = true, -- Tranquility
    [102352] = true, -- Cenarion Ward Hot
    [200389] = true, -- Cultivation
    [22842] = true, -- Frenzied Regen
    [383193] = true, -- Grove Tending
    [207386] = true, -- Spring Blossoms
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
function addon:Print(msg)
    print("|cFF50C878L|rifebloom|cFF50C878G|rlow: " .. msg)
end

---------------------------------
-- Hidden Tooltip
-- Credit: WeakAuras
-- For processing tooltip info
---------------------------------
function addon:GetHiddenTooltip()
    if not self.hiddenTooltip then
        self.hiddenTooltip = CreateFrame("GameTooltip", "LifebloomGlowTooltip", nil, "GameTooltipTemplate")
        self.hiddenTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        self.hiddenTooltip:AddFontStrings(
            self.hiddenTooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),
            self.hiddenTooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText")
        )
    end

    return self.hiddenTooltip
end

----------------------------------------
-- Get Tooltip Info
-- Credit: WeakAuras
-- Replace with C_TooltipInfo in 10.0.2
----------------------------------------
function addon:GetTooltipInfo(unit, auraInstanceID)
    local tooltip = addon:GetHiddenTooltip()
    tooltip:ClearLines()
    tooltip:SetUnitBuffByAuraInstanceID(unit, auraInstanceID)

    local tooltipTextLine = select(5, tooltip:GetRegions())
    local text = tooltipTextLine and tooltipTextLine:GetObjectType() == "FontString" and tooltipTextLine:GetText() or ""
    local tooltipSize = {}

    if text then
        for t in text:gmatch("(%d[%d%.,]*)") do
            if (LARGE_NUMBER_SEPERATOR == ",") then
                t = t:gsub(",", "");
            else
                t = t:gsub("%.", "");
                t = t:gsub(",", ".");
            end
            tinsert(tooltipSize, tonumber(t));
        end
    end

    if #tooltipSize then
        return text, unpack(tooltipSize)
    else
        return text, 0
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
-- SotF Tables
---------------------------
local sotfGlows = {}
local amts = {}

---------------------------
-- SotF Glow Func
---------------------------
local function glowSotf(buffFrame, aura, amtNeeded)
    buffFrame.glow:SetVertexColor(unpack(addon.db.sotfColor))
    buffFrame.glow:Show()

    sotfGlows[aura.auraInstanceID] = sotfGlows[aura.auraInstanceID] or {}
    sotfGlows[aura.auraInstanceID].state = amtNeeded
    sotfGlows[aura.auraInstanceID].aura = aura
end

---------------------------
-- SotF Decider
---------------------------
local function glowIfSotf(aura, buffFrame)
    local mult = sotf_spells[aura.spellId]
    if not mult then return end
    local sId = aura.spellId
    local amtNeeded
    local unit = buffFrame:GetParent().unit
    local prevGlow = sotfGlows[aura.auraInstanceID]
    local _, curTick, rate = addon:GetTooltipInfo(unit, aura.auraInstanceID)
    local cachedTick = addon.baseTickCache[sId]
    -- Rejuv (and germ) apply its own mastery to itself, but the tooltip doesn't reflect it.
    -- This is unique to these two spells, so we need to account for it.
    curTick = curTick / rate * ((sId == 774 or sId == 155777) and (1 + addon.mastery) or 1)

    -- Workaround for Overgrowth. It always applies SotF to rejuv/germ and also at the base tick rate.
    if addon.overgrowth and (sId == 774 or sId == 155777) then
        if curTick > cachedTick * mult then
            glowSotf(buffFrame, aura, curTick)
        end
        return
    end

    if prevGlow then
        amtNeeded = prevGlow.state
    else
        local hots = 0
        AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(_, _, _, _, _, _, _, _, _, spellId)
            local incr = 1
            if spellId == 33763 then
                incr = addon.harmBlooming
            end
            if druidHots[spellId] then
                hots = hots + incr
            end
        end)
        hots = (hots - 1 > 0) and hots - 1 or 0

        local masteryBonus = 1 + (addon.mastery * hots)
        amtNeeded = cachedTick * mult * masteryBonus
    end

    if not cachedTick then
        addon:TRAIT_TREE_CURRENCY_INFO_UPDATED()
    elseif not prevGlow and (sId == 48438) then
        -- Fix for Wild Growth having different tick values for different targets
        -- but Blizzard still uses the same auraInstanceID for all of them.
        tinsert(amts, amtNeeded)
        after(0.05, function()
            if next(amts) ~= nil then
                amtNeeded = min(unpack(amts))

                if (curTick > amtNeeded) then
                    glowSotf(buffFrame, aura, amtNeeded)
                end

                wipe(amts)
            else
                glowIfSotf(aura, buffFrame)
            end
        end)
    elseif (curTick >= amtNeeded) then
        glowSotf(buffFrame, aura, amtNeeded)
    end
end

---------------------------
-- LB Decider
---------------------------
local function glowIfLB(aura, buffFrame)
    if lifeblooms[aura.spellId] then
        addon.lbInstances[aura.auraInstanceID] = true
        addon.lbAuras[buffFrame] = aura
        addon.lbUpdate:Show()
    elseif addon.lbAuras[buffFrame] then
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

    buffFrame.glow:Hide()

    if not aura
    or not aura.isFromPlayerOrPlayerPet
    or aura.isHarmful then return end

    if self.db.sotf then
        for k, v in pairs(sotfGlows) do
            local a = v.aura
            if a and (a.expirationTime < GetTime()) then
                sotfGlows[k] = nil
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

---------------------------
-- Talent Updates
---------------------------
function addon:TRAIT_TREE_CURRENCY_INFO_UPDATED()
    self.mastery = GetMasteryEffect() / 100
    wipe(self.baseTickCache)

    local hbNode = C_Traits.GetNodeInfo(C_ClassTalents.GetActiveConfigID(), 82065)
    local hbRank = hbNode and hbNode.activeRank or 0

    self.harmBlooming = hbRank + 1

    -- Check for Overgrowth
    local ogNode = C_Traits.GetNodeInfo(C_ClassTalents.GetActiveConfigID(), 82061)
    self.overgrowthEnabled = ogNode and ogNode.activeRank > 0

    -- We need to use CLEU for overgrowth
    if self.overgrowthEnabled then
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end

    for spellId in pairs(sotf_spells) do
        local spell = Spell:CreateFromSpellID(spellId)

        spell:ContinueOnSpellLoad(function()
            local desc = spell:GetSpellDescription()

            desc = desc:gsub(",", "")
            local amount, dur = desc:match("(%d+) over (%d+) sec")

            self.baseTickCache[spellId] = amount / dur
        end)
    end
end

function addon:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
    self:TRAIT_TREE_CURRENCY_INFO_UPDATED()
end

---------------------------
-- CLEU
---------------------------
local function disableOvergrowth()
    addon.overgrowth = false
end

function addon:COMBAT_LOG_EVENT_UNFILTERED()
    if not self.db.sotf then
        eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end

    local _, event, _, sourceGUID, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= self.playerGUID then return end

    if event == "SPELL_CAST_SUCCESS" and spellId == 203651 then
        self.overgrowth = true

        after(0, disableOvergrowth)
    end
end

---------------------------
-- Toggle Sotf
---------------------------
function addon:EnableSotf(enable)
    self.db.sotf = enable

    if enable then
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
    for k in pairs(defaults) do
        if LifebloomGlowDB[k] == nil then
            LifebloomGlowDB = CopyTable(defaults)
        end
    end

    self.db = LifebloomGlowDB
    self.baseTickCache = {}
    self.lbInstances = {}
    self.lbAuras = {}
    self.playerGUID = UnitGUID("player")

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
