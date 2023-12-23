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
    title:SetText("|cFF50C878L|rifebloom|cFF50C878G|rlow")

    local author = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    author:SetFormattedText("|cFF50C878Author|r: %s", GetAddOnMetadata(addonName, "Author"))

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -8)
    version:SetFormattedText("|cFF50C878Version|r: %s", GetAddOnMetadata(addonName, "Version"))

    local glowColor = CreateFrame("Button", nil, panel, "BackdropTemplate")
    glowColor:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -50)
    glowColor:SetSize(20, 20)
    glowColor:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 4,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    glowColor:SetBackdropColor(unpack(self.db.lbColor))
    glowColor:SetScript("OnClick", function(s)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { unpack(self.db.lbColor) }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.db.lbColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
        end
        ColorPickerFrame.cancelFunc = function()
            local r, g, b = unpack(ColorPickerFrame.previousValues)
            self.db.lbColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
        end
        ColorPickerFrame:SetColorRGB(unpack(self.db.lbColor))
        ShowUIPanel(ColorPickerFrame)
    end)

    local glow = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    glow:SetPoint("LEFT", glowColor, "RIGHT", 8, 0)
    glow:SetHitRectInsets(0, -100, 0, 0)
    glow.text:SetText("Show Lifebloom Glow")
    glow.tooltipText = "Enable a glow effect on buff frames when Lifebloom is within the \"pandemic\" window."
    glow:SetChecked(self.db.lb)
    glow:SetScript("OnClick", function(s)
        self.db.lb = s:GetChecked()
    end)
    glow:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.tooltipText, nil, nil, nil, nil, true)
    end)
    glow:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local sotfColor = CreateFrame("Button", nil, panel, "BackdropTemplate")
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
        ColorPickerFrame:SetColorRGB(unpack(self.db.sotfColor))
        ShowUIPanel(ColorPickerFrame)
    end)

    local sotf = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    sotf:SetPoint("LEFT", sotfColor, "RIGHT", 8, 0)
    sotf:SetHitRectInsets(0, -100, 0, 0)
    sotf.text:SetText("Show Soul of the Forest Glow |cFFFF0000(BETA)|r")
    sotf.tooltipText = "Enable a glow effect on buff frames when the buff is empowered by Soul of the Forest. This is in beta and likely has some quirks."
    sotf:SetChecked(self.db.sotf)
    sotf:SetScript("OnClick", function(s)
        self:EnableSotf(s:GetChecked())
    end)
    sotf:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.tooltipText, nil, nil, nil, nil, true)
    end)
    sotf:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    InterfaceOptions_AddCategory(panel, addonName)
end
