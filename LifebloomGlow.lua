local _, playerClass = UnitClass("player")
local cf = CreateFrame("Frame")
cf:RegisterEvent("PLAYER_LOGIN")

cf:SetScript("OnEvent", function(self, event)

	if (playerClass ~= "DRUID") then
		print("|cFF50C878L|rifebloom |cFF50C878G|rlow Disabled")
		return
	end

	--Compact Unit Frame
	function CompactUnitFrame_UtilSetBuff_Hook(buffFrame, index, ...)
        
        local name, icon, count, debuffType, duration, expirationTime, caster, canStealOrPurge, _,
        spellId, canApplyAura, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod = ...

		if (spellId == 33763 and casterIsPlayer) then
			local timeRemaining = (expirationTime - GetTime()) / timeMod
			local refreshTime = duration * 0.3

			if (not buffFrame.glow) then
				local glow = buffFrame:CreateTexture(nil, "OVERLAY")
				glow:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
				glow:SetPoint("TOPLEFT", -2.5, 2.5)
				glow:SetPoint("BOTTOMRIGHT", 2.5, -2.5)
				glow:SetBlendMode("ADD")
				buffFrame.glow = glow
			end

			if (timeRemaining <= refreshTime) then
				buffFrame.glow:Show()
			else
				buffFrame.glow:Hide()
			end

		elseif buffFrame.glow then
			buffFrame.glow:Hide()
		end
	end
	hooksecurefunc("CompactUnitFrame_UtilSetBuff", CompactUnitFrame_UtilSetBuff_Hook)

	--Target Frame
	function TargetFrame_UpdateAuras_Hook(self)
		local frame, frameName
		local selfName = self:GetName()

		for i = 1, MAX_TARGET_BUFFS do
		local buffName, icon, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal,
		spellId, canApplyAura, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod = UnitBuff(self.unit, i, nil)

			if buffName then
				if (spellId == 33763 and casterIsPlayer) then
					frameName = selfName.."Buff"..(i)
					frame = _G[frameName]
					if (frame and icon and (not self.maxBuffs or i <= self.maxBuffs)) then
						local timeRemaining = (expirationTime - GetTime()) / timeMod
						local refreshTime = duration * 0.3
						local frameStealable = _G[frameName.."Stealable"]
                        frameStealable:SetHeight(frame:GetHeight() + 3)
                        frameStealable:SetWidth(frame:GetWidth() + 3)

						if (timeRemaining <= refreshTime) then
							frameStealable:Show()
						else
							frameStealable:Hide()
						end
					end
					break
				end
			else
				break
			end
		end
	end
	hooksecurefunc("TargetFrame_UpdateAuras", TargetFrame_UpdateAuras_Hook)

end)
