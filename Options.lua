local addonName, addon = ...

--[[----------------------------------------------------

Options Table

Specifically not using the new Blizzard options
because of taint issues

------------------------------------------------------]]
function addon:Options()
    local panel = CreateFrame("Frame", addonName .. "OptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = addonName
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(addonName)

    local glowColor = CreateFrame("Button", addonName .. "OptionsPanelGlowColor", panel, "BackdropTemplate")
    glowColor:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -50)
    glowColor:SetSize(20, 20)
    glowColor:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 4,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    glowColor:SetBackdropColor(unpack(self.db.glowColor))
    glowColor:SetScript("OnClick", function(s)
        ColorPickerFrame:SetColorRGB(unpack(self.db.glowColor))
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { unpack(self.db.glowColor) }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.db.glowColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
        end
        ColorPickerFrame.cancelFunc = function()
            local r, g, b = unpack(ColorPickerFrame.previousValues)
            self.db.glowColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
        end
        ColorPickerFrame:Show()
    end)

    local glow = CreateFrame("CheckButton", addonName .. "OptionsPanelGlow", panel, "InterfaceOptionsCheckButtonTemplate")
    glow:SetPoint("LEFT", glowColor, "RIGHT", 8, 0)
    glow:SetHitRectInsets(0, -100, 0, 0)
    glow.text:SetText("Show Glow")
    glow.tooltipText = "Enable the glow effect on Lifebloom frames."
    glow:SetChecked(self.db.glow)
    glow:SetScript("OnClick", function(s)
        self.db.glow = s:GetChecked()
    end)

    local sotfColor = CreateFrame("Button", addonName .. "OptionsPanelSotfColor", panel, "BackdropTemplate")
    sotfColor:SetPoint("TOPLEFT", glowColor, "BOTTOMLEFT", 0, -8)
    sotfColor:SetSize(20, 20)
    sotfColor:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 4,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    sotfColor:SetBackdropColor(unpack(self.db.sotfColor))
    sotfColor:SetScript("OnClick", function(s)
        ColorPickerFrame:SetColorRGB(unpack(self.db.sotfColor))
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { unpack(self.db.sotfColor) }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.db.sotfColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
        end
        ColorPickerFrame.cancelFunc = function()
            local r, g, b = unpack(ColorPickerFrame.previousValues)
            self.db.sotfColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
        end
        ColorPickerFrame:Show()
    end)
    sotfColor:SetEnabled(false)

    local sotf = CreateFrame("CheckButton", addonName .. "OptionsPanelSotf", panel, "InterfaceOptionsCheckButtonTemplate")
    sotf:SetPoint("LEFT", sotfColor, "RIGHT", 8, 0)
    sotf:SetHitRectInsets(0, -100, 0, 0)
    sotf.text:SetText("Show Soul of the Forest Glow [Work in Progress]")
    sotf.tooltipText = "Enable the glow effect on Lifebloom frames when SotF is active."
    sotf:SetChecked(false)
    sotf:SetScript("OnClick", function(s)
        self.db.sotf = s:GetChecked()
    end)
    sotf:SetEnabled(false)

    InterfaceOptions_AddCategory(panel, addonName)
end
