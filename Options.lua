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
        ColorPickerFrame.previousValues = {
            r = red,
            g = green,
            b = blue,
        }

        local info = {}
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.db.lbColor = { r, g, b }
            s:SetBackdropColor(r, g, b)
        end
        info.cancelFunc = function()
            local prev = ColorPickerFrame.previousValues
            self.db.lbColor = { prev.r, prev.g, prev.b }
            s:SetBackdropColor(prev.r, prev.g, prev.b)
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

    local category = Settings.RegisterCanvasLayoutCategory(panel, addonName)
    Settings.RegisterAddOnCategory(category)
    self.optionsCategoryID = category:GetID()
end
