local _,playerClass = UnitClass("player")
local CF = CreateFrame("Frame")
CF:RegisterEvent("PLAYER_LOGIN")

CF:SetScript("OnEvent", function(self, event)

	if (playerClass ~= "DRUID") then
		print("|cFF50C878L|rifebloom |cFF50C878G|rlow Disabled")
		return
	end

	--Compact Unit Frame
	function CompactUnitFrame_UtilSetBuff_Hook(buffFrame, unit, index, filter)
		local buffName, _, icon, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal,
		spellId, canApplyAura, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod, _ = UnitBuff(unit, index, filter)

		if spellId == 33763 and casterIsPlayer then
			local timeRemaining = (expirationTime - GetTime()) / timeMod
			local refreshTime = duration * 0.3

			if not buffFrame.highlight then
				local highlight = buffFrame:CreateTexture(nil, "OVERLAY")
				highlight:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
				highlight:SetPoint("TOPLEFT", -3, 3)
				highlight:SetPoint("BOTTOMRIGHT", 3, -3)
				highlight:SetBlendMode("ADD")
				buffFrame.highlight = highlight
			end

			if timeRemaining <= refreshTime then
				buffFrame.highlight:Show()
			else
				buffFrame.highlight:Hide()
			end

		elseif buffFrame.highlight then
			buffFrame.highlight:Hide()
		end
	end
	hooksecurefunc("CompactUnitFrame_UtilSetBuff", CompactUnitFrame_UtilSetBuff_Hook)

	--Target Frame
	function TargetFrame_UpdateAuras_Hook(self)
		local frame, frameName
		local selfName = self:GetName()

		for i = 1, MAX_TARGET_BUFFS do
		local buffName, _, icon, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal,
		spellId, canApplyAura, isBossDebuff, casterIsPlayer, nameplateShowAll, timeMod, _ = UnitBuff(self.unit, i, nil)

			if buffName then
				if spellId == 33763 and casterIsPlayer then
					frameName = selfName.."Buff"..(i)
					frame = _G[frameName]
					if frame and icon and (not self.maxBuffs or i <= self.maxBuffs) then
						local timeRemaining = (expirationTime - GetTime()) / timeMod
						local refreshTime = duration * 0.3
						local frameStealable = _G[frameName.."Stealable"]

						if timeRemaining <= refreshTime then
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