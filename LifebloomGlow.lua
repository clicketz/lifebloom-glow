--[[ USER VARIABLE(S)

This number represents the number of seconds between each update.

The lower the THROTTLE_VALUE the more accurate the addon is,
but also the more CPU intensive it is.

Default: 0.1

]]


local THROTTLE_VALUE = 0.1

---------------------------


-- Only load for druids
local _, playerClass = UnitClass("player")
if (playerClass ~= "DRUID") then
    print("|cFF50C878L|rifebloom |cFF50C878G|rlow Disabled")
    return
end

local refreshRaid = CreateFrame("Frame")
local refreshTarget = CreateFrame("Frame")
local refreshFocus = CreateFrame("Frame")

local refresh = {
    [RaidFrame] = refreshRaid,
    [TargetFrame] = refreshTarget,
    [FocusFrame] = refreshFocus,
}

local enabled = {
    [RaidFrame] = false,
    [TargetFrame] = false,
    [FocusFrame] = false,
}

local unit = {
    [TargetFrame] = TargetFrame.unit,
    [FocusFrame] = FocusFrame.unit,
}

local lastUpdate = {
    [RaidFrame] = 0,
    [TargetFrame] = 0,
    [FocusFrame] = 0,
}

local unitBuffFrame, frame

-- Compact Unit Frames
function CompactUnitFrame_UtilSetBuff_Hook(buffFrame, index, ...)
    local name, icon, count, debuffType, duration, expirationTime, caster, canStealOrPurge, _,
    spellId, canApplyAura, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod = ...

    if (buffFrame and not buffFrame.glow) then
        local glow = buffFrame:CreateTexture(nil, "OVERLAY")
        glow:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
        glow:SetPoint("TOPLEFT", -2.5, 2.5)
        glow:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
        glow:SetBlendMode("ADD")
        buffFrame.glow = glow
        buffFrame.glow:Hide()
    end

    -- In order to directly iterate over visible buffs on raid frame
    buffFrame.spellId = spellId

    if (spellId == 33763 and casterIsPlayer) then
        unitBuffFrame = buffFrame:GetParent()
        if enabled[RaidFrame] == false then
            enabled[RaidFrame] = true
            lastUpdate[RaidFrame] = 0
            refresh[RaidFrame]:SetScript("OnUpdate", function(self, elapsed)
                lastUpdate[RaidFrame] = lastUpdate[RaidFrame] + elapsed
                if lastUpdate[RaidFrame] >= THROTTLE_VALUE then
                    lastUpdate[RaidFrame] = 0

                    if unitBuffFrame.displayedUnit then
                        for i = 1, MAX_TARGET_BUFFS do
                            local buffName, icon, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod = UnitBuff(unitBuffFrame.displayedUnit, i)

                            if buffName then
                                if (spellId == 33763 and casterIsPlayer) then
                                    local timeRemaining = (expirationTime - GetTime()) / timeMod
                                    local refreshTime = duration * 0.3

                                    if (timeRemaining <= refreshTime) then
                                        for i = 1, #unitBuffFrame.buffFrames do
                                            if unitBuffFrame.buffFrames[i].glow and unitBuffFrame.buffFrames[i].spellId == 33763 then
                                                unitBuffFrame.buffFrames[i].glow:Show()
                                            end
                                        end
                                        refresh[RaidFrame]:SetScript("OnUpdate", nil)
                                        enabled[RaidFrame] = false
                                    else
                                        for i = 1, #unitBuffFrame.buffFrames do
                                            if unitBuffFrame.buffFrames[i].glow then
                                                unitBuffFrame.buffFrames[i].glow:Hide()
                                            end
                                        end
                                    end
                                    break
                                end
                            else
                                refresh[RaidFrame]:SetScript("OnUpdate", nil)
                                enabled[RaidFrame] = false
                                break
                            end
                        end
                    else
                        refresh[RaidFrame]:SetScript("OnUpdate", nil)
                        enabled[RaidFrame] = false
                    end
                end
            end)
        end
    elseif buffFrame and buffFrame.glow then
        buffFrame.glow:Hide()
    end
end

-- Target / Focus frames
function TargetFrame_UpdateAuras_Hook(self)
    if not unit[self] then return end -- Fix for BossFrames triggering this event

    for i = 1, MAX_TARGET_BUFFS do
        local buffName, icon, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod = UnitBuff(unit[self], i)

        -- Making our own glow frame for Target because Blizzard constantly updates default stealable
        -- border which often results in odd behaviors.
        -- TODO: fix checking global table every update
        frame = _G[self:GetName().. "Buff" ..i]
        if (frame and not frame.glow) then
            local glow = frame:CreateTexture(nil, "OVERLAY")
            glow:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
            glow:SetPoint("TOPLEFT", -2.5, 2.5)
            glow:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
            glow:SetBlendMode("ADD")
            frame.glow = glow
            frame.glow:Hide()
        end

        if buffName then
            if (spellId == 33763 and casterIsPlayer) then
                if enabled[self] == false then
                    enabled[self] = true
                    lastUpdate[self] = 0
                    refresh[self]:SetScript("OnUpdate", function(s, elapsed)
                        lastUpdate[self] = lastUpdate[self] + elapsed
                        if lastUpdate[self] >= THROTTLE_VALUE then
                            lastUpdate[self] = 0

                            for i = 1, MAX_TARGET_BUFFS do
                                local buffName, icon, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod = UnitBuff(unit[self], i)

                                if buffName then
                                    if (spellId == 33763 and casterIsPlayer) then
                                        frame = _G[self:GetName().. "Buff"..i]
                                        if (frame and icon) then
                                            local timeRemaining = (expirationTime - GetTime()) / timeMod
                                            local refreshTime = duration * 0.3

                                            if (timeRemaining <= refreshTime) then
                                                frame.glow:Show()
                                                refresh[self]:SetScript("OnUpdate", nil)
                                                enabled[self] = false
                                            else
                                                frame.glow:Hide()
                                            end
                                        end
                                        break
                                    end
                                else
                                    refresh[self]:SetScript("OnUpdate", nil)
                                    enabled[self] = false
                                    break
                                end
                            end
                        end
                    end)
                end
            elseif frame and frame.glow then
                frame.glow:Hide()
            end
        else
            break
        end
    end
end

-- Do our hooks
hooksecurefunc("CompactUnitFrame_UtilSetBuff", CompactUnitFrame_UtilSetBuff_Hook)
hooksecurefunc("TargetFrame_UpdateAuras", TargetFrame_UpdateAuras_Hook)
