local addonName, addon = ...

---------------------------
-- Lua Upvalues
---------------------------
local CopyTable = CopyTable
local GetTime = GetTime
local pairs = pairs
local unpack = unpack
local next = next

---------------------------
-- Database Defaults
---------------------------
local defaults = {
    throttle = 0.01,
    glow = true,
    glowColor = { 0, 1, 0, 1 },
    sotf = true,
    sotfColor = { 1, 0, 0, 1 },
}

---------------------------
-- EventHandler
---------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    addon[event](addon, ...)
end)

---------------------------
-- Print Function
---------------------------
function addon:Print(msg)
    print("|cFF50C878L|rifebloom|cFF50C878G|rlow: " .. msg)
end

---------------------------
-- CompactUnitFrame Core
---------------------------
function addon:CompactUnitFrame(buffFrame, aura)
    if not buffFrame.glow then
        local glow = buffFrame:CreateTexture(nil, "OVERLAY")
        glow:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
        glow:SetPoint("TOPLEFT", -2.5, 2.5)
        glow:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
        glow:SetBlendMode("ADD")
        buffFrame.glow = glow
    end

    buffFrame.glow:Hide()

    if aura.spellId == 33763 and aura.isFromPlayerOrPlayerPet then
        aura.isGlow = true
        self.aura = aura.auraInstanceID
        self.auras[buffFrame] = aura
        self.update:Show()
    elseif self.auras[buffFrame] then
        self.auras[buffFrame] = nil
    end
end

---------------------------
-- Target/Focus Frame Core
---------------------------
function addon:TargetFocus(root)
    for frame in root.auraPools:EnumerateActive() do
        local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(root.unit, frame.auraInstanceID)

        if not frame.glow then
            local glow = frame:CreateTexture(nil, "OVERLAY")
            glow:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
            glow:SetPoint("TOPLEFT", -2.5, 2.5)
            glow:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
            glow:SetBlendMode("ADD")
            frame.glow = glow
        end

        frame.glow:Hide()

        if aura.spellId == 33763 and aura.isFromPlayerOrPlayerPet then
            aura.isGlow = true
            self.aura = aura.auraInstanceID
            self.auras[frame] = aura
            self.update:Show()
        elseif self.auras[frame] then
            self.auras[frame] = nil
        end
    end
end

---------------------------
-- Initialize
---------------------------
function addon:PLAYER_LOGIN()
    LifebloomGlowDB = LifebloomGlowDB or CopyTable(defaults)
    self.db = LifebloomGlowDB

    self.auras = {}

    addon:Options()

    SLASH_LBG1 = "/lbg"
    function SlashCmdList.LBG(msg)
        if msg == "help" then
            addon:Print("Available commands:")
            addon:Print("/lbg help - Show this help")
        else
            InterfaceOptionsFrame_OpenToCategory(addonName)
            InterfaceOptionsFrame_OpenToCategory(addonName)
        end
    end

    -- Only load for druids
    if (select(2, UnitClass("player")) ~= "DRUID") then
        self:Print("Disabled when not playing a Druid.")
        return
    else
        self:Print("Loaded. Type |cFF50C878/lbg|r for options.")
    end

    -- Do our hooks
    hooksecurefunc("CompactUnitFrame_UtilSetBuff", function(s, ...)
        self:CompactUnitFrame(s, ...)
    end)

    hooksecurefunc(TargetFrame, "UpdateAuras", function(s)
        self:TargetFocus(s)
    end)

    hooksecurefunc(FocusFrame, "UpdateAuras", function(s)
        self:TargetFocus(s)
    end)

    ---------------------------
    -- Update Frame (Main Loop)
    ---------------------------
    self.update = CreateFrame("Frame")
    self.lastUpdate = 0
    self.update:SetScript("OnUpdate", function(s, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed
        if self.lastUpdate >= self.db.throttle then
            self.lastUpdate = 0

            if next(self.auras) == nil then
                s:Hide()
            end

            for frame, aura in pairs(self.auras) do
                if aura.expirationTime < GetTime() then
                    frame.glow:Hide()
                    self.auras[frame] = nil
                elseif aura.auraInstanceID == self.aura then
                    local timeRemaining = (aura.expirationTime - GetTime()) / aura.timeMod
                    local refreshTime = aura.duration * 0.3

                    if (timeRemaining <= refreshTime) then
                        if self.db.glow and aura.isGlow then
                            frame.glow:SetVertexColor(unpack(self.db.glowColor))
                        end
                        if self.db.sotf and aura.isSotf then
                            frame.glow:SetVertexColor(unpack(self.db.sotfColor))
                        end
                        if aura.isGlow and self.db.glow or aura.isSotf and self.db.sotf then
                            frame.glow:Show()
                        end
                    else
                        frame.glow:Hide()
                    end
                else
                    frame.glow:Hide()
                    self.auras[frame] = nil
                end
            end
        end
    end)
    self.update:Hide()
end
