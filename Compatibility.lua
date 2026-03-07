local _, addon = ...

--[[
    General catch-all compat file for other addons
]]

function addon:DandersFrames()
    local function HookDandersAuras(df, frame)
        if not frame or not frame.buffIcons then return end

        local unit = frame.unit
        if not unit then return end

        for i = 1, #frame.buffIcons do
            local buffFrame = frame.buffIcons[i]

            if buffFrame:IsShown() and buffFrame.auraData then
                -- This field is needed so we don't instantly hide the glow
                buffFrame.auraInstanceID = buffFrame.auraData.auraInstanceID

                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, buffFrame.auraInstanceID)
                self:HandleAura(buffFrame, aura)
            else
                buffFrame.auraInstanceID = nil
                self:HandleAura(buffFrame, nil)
            end
        end
    end

    if DandersFrames.UpdateAuras then
        hooksecurefunc(DandersFrames, "UpdateAuras", HookDandersAuras)
    end
    if DandersFrames.UpdateAuras_Enhanced then
        hooksecurefunc(DandersFrames, "UpdateAuras_Enhanced", HookDandersAuras)
    end
end

function addon:Compatibility()
    if DandersFrames then
        self:DandersFrames()
    end
end
