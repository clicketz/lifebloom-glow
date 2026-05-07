local addonName, addon = ...

function addon:Options()
    local panel = CreateFrame("Frame", addonName .. "OptionsPanel")
    panel.name = addonName
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFF50C878L|rifebloom|cFF50C878G|rlow")

    local author = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    author:SetFormattedText("|cFF50C878Author|r: %s", C_AddOns.GetAddOnMetadata(addonName, "Author"))

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -8)
    version:SetFormattedText("|cFF50C878Version|r: %s", C_AddOns.GetAddOnMetadata(addonName, "Version"))

    -- lifebloom settings
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
        local red, green, blue = unpack(self.db.lbColor)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = red, g = green, b = blue }

        local info = {}
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.db.lbColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
            self:UpdateColorCache()
        end
        info.cancelFunc = function()
            local prev = ColorPickerFrame.previousValues
            self.db.lbColor = { prev.r, prev.g, prev.b }
            s:SetBackdropColor(prev.r, prev.g, prev.b)
            self:UpdateColorCache()
        end

        info.r, info.g, info.b = unpack(self.db.lbColor)
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local glow = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    glow:SetPoint("LEFT", glowColor, "RIGHT", 8, 0)
    glow:SetHitRectInsets(0, -100, 0, 0)
    glow.text:SetText("Show Lifebloom Glow")
    glow.tooltipText = "Enable a glow effect on buff frames when Lifebloom is within the \"pandemic\" window."
    glow:SetChecked(self.db.lb)
    glow:SetScript("OnClick", function(s)
        self.db.lb = s:GetChecked()
        -- Force update immediately if unticked
        if not self.db.lb then
            if self.lbUpdate then self.lbUpdate:Hide() end
            if self.lbAuras then
                for buffFrame, _ in pairs(self.lbAuras) do
                    if buffFrame.glow then buffFrame.glow:Hide() end
                end
                wipe(self.lbAuras)
            end
        end
    end)
    glow:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.tooltipText, nil, nil, nil, nil, true)
    end)
    glow:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local glowFrameInstead = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    glowFrameInstead:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", 0, -8)
    glowFrameInstead:SetHitRectInsets(0, -100, 0, 0)
    glowFrameInstead.text:SetText("Glow Party/Raid Frames")
    glowFrameInstead.tooltipText = "Apply the glow to the entire frame for Party and Raid frames. If disabled, Party/Raid frames will not glow."
    glowFrameInstead:SetChecked(self.db.glowFrameInstead)
    glowFrameInstead:SetScript("OnClick", function(s)
        self.db.glowFrameInstead = s:GetChecked()
        if self.cufPool then
            for cuf in pairs(self.cufPool) do
                if cuf:IsVisible() then
                    self:UpdateCUF(cuf)
                end
            end
        end
    end)
    glowFrameInstead:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.tooltipText, nil, nil, nil, nil, true)
    end)
    glowFrameInstead:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local notes = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    notes:SetPoint("TOPLEFT", glowFrameInstead, "BOTTOMLEFT", 4, -4)
    notes:SetWidth(500)
    notes:SetJustifyH("LEFT")
    notes:SetText("|cffa8a8a8Note: Due to recent Blizzard UI restrictions introduced in 12.0.5, buff/debuff icons on CompactUnitFrames can no longer be changed/edited in any way. This includes adding glow borders. 'Glow Party/Raid Frames' setting is not ideal, but is the best workaround available at this time. Target and Focus frames remain unaffected, for now..|r")

    -- rejuv settings
    local rejuvColorButton = CreateFrame("Button", nil, panel, "BackdropTemplate")
    rejuvColorButton:SetPoint("TOPLEFT", glowColor, "BOTTOMLEFT", 0, -85)
    rejuvColorButton:SetSize(20, 20)
    rejuvColorButton:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 4,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    rejuvColorButton:SetBackdropColor(unpack(self.db.rejuvColor))
    rejuvColorButton:SetScript("OnClick", function(s)
        local red, green, blue = unpack(self.db.rejuvColor)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = red, g = green, b = blue }

        local info = {}
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.db.rejuvColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
            self:UpdateColorCache()
        end
        info.cancelFunc = function()
            local prev = ColorPickerFrame.previousValues
            self.db.rejuvColor = { prev.r, prev.g, prev.b }
            s:SetBackdropColor(prev.r, prev.g, prev.b)
            self:UpdateColorCache()
        end

        info.r, info.g, info.b = unpack(self.db.rejuvColor)
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local rejuvGlow = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    rejuvGlow:SetPoint("LEFT", rejuvColorButton, "RIGHT", 8, 0)
    rejuvGlow:SetHitRectInsets(0, -100, 0, 0)
    rejuvGlow.text:SetText("Show Empowered Rejuvenation Glow")
    rejuvGlow.tooltipText = "Enable a glow effect when Rejuvenation or Germination is empowered (e.g. via Soul of the Forest)."
    rejuvGlow:SetChecked(self.db.rejuvGlow)
    rejuvGlow:SetScript("OnClick", function(s)
        self.db.rejuvGlow = s:GetChecked()
    end)
    rejuvGlow:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.tooltipText, nil, nil, nil, nil, true)
    end)
    rejuvGlow:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- glow size slider
    local sizeSlider = CreateFrame("Slider", addonName .. "SizeSlider", panel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", rejuvColorButton, "BOTTOMLEFT", 0, -30)
    sizeSlider:SetMinMaxValues(0.1, 2.5)
    sizeSlider:SetValueStep(0.05)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetValue(self.db.glowMult or 1.0)
    sizeSlider.Low:SetText("0.1")
    sizeSlider.High:SetText("2.5")
    sizeSlider.Text:SetText(string.format("Glow Scale: %.2f", self.db.glowMult or 1.0))
    sizeSlider.tooltipText = "Scale of the border. Default is 1.0."
    sizeSlider:SetScript("OnValueChanged", function(s, value)
        self.db.glowMult = value
        s.Text:SetText(string.format("Glow Scale: %.2f", value))
        self:UpdateAllGlowLayouts()
    end)
    sizeSlider:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.tooltipText, nil, nil, nil, nil, true)
    end)
    sizeSlider:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, addonName)
    Settings.RegisterAddOnCategory(category)
    self.optionsCategoryID = category:GetID()
end
