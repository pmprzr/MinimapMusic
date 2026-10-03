local addonName = ...

local ADDON_PATH = "Interface\\AddOns\\MinimapMusic\\Textures\\"
local ICON_PLAY = ADDON_PATH .. "play_bronze.tga"
local ICON_PAUSE = ADDON_PATH .. "pause_bronze.tga"
local ICON_NOTE_MINIMAP = ADDON_PATH .. "boombox_minimap.tga"
local BUTTON_DISC = ADDON_PATH .. "button_disc.tga"
local PANEL_ROUND = ADDON_PATH .. "panel_round.tga"
local PANEL_BORDER = ADDON_PATH .. "panel_border.tga"

local defaults = {
    buttonX = nil,
    buttonY = nil,
    panelOpacity = 0.50,
    panelX = nil,
    panelY = nil,
}

local settingsCategoryID
local optionsPanel

local function MakeTextureSmooth(texture)
    if not texture then return end
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
    end
    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(0)
    end
end

local function GetCVarSafe(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    if GetCVar then
        return GetCVar(name)
    end
end

local function SetCVarSafe(name, value)
    value = tostring(value)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, value)
        return
    end
    if SetCVar then
        SetCVar(name, value)
    end
end

local function IsMusicEnabled()
    return tonumber(GetCVarSafe("Sound_EnableMusic") or "1") ~= 0
end

local function GetMusicVolumePercent()
    local volume = tonumber(GetCVarSafe("Sound_MusicVolume") or "1") or 1
    volume = math.max(0, math.min(1, volume))
    return math.floor(volume * 100 + 0.5)
end

local function SetMusicVolumePercent(percent)
    percent = math.max(0, math.min(100, percent or 0))
    SetCVarSafe("Sound_MusicVolume", string.format("%.2f", percent / 100))
end


-- Compact popup ------------------------------------------------------------
local panel = CreateFrame("Frame", "MinimapMusicPanel", UIParent)
panel:SetSize(206, 36)
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:Hide()

local panelBg = panel:CreateTexture(nil, "BACKGROUND")
panelBg:SetAllPoints()
panelBg:SetTexture(PANEL_ROUND)
panelBg:SetVertexColor(0.025, 0.021, 0.017, 1)
MakeTextureSmooth(panelBg)

local innerBg = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
innerBg:SetPoint("TOPLEFT", 3, -3)
innerBg:SetPoint("BOTTOMRIGHT", -3, 3)
innerBg:SetTexture(PANEL_ROUND)
innerBg:SetVertexColor(0.10, 0.075, 0.045, 1)
MakeTextureSmooth(innerBg)

local panelBorder = panel:CreateTexture(nil, "BORDER", nil, 2)
panelBorder:SetAllPoints()
panelBorder:SetTexture(PANEL_BORDER)
MakeTextureSmooth(panelBorder)

local function ApplyPanelOpacity()
    local opacity = defaults.panelOpacity
    if MinimapMusicDB and tonumber(MinimapMusicDB.panelOpacity) then
        opacity = math.max(0.20, math.min(1.00, tonumber(MinimapMusicDB.panelOpacity)))
    end
    panelBg:SetAlpha(opacity)
    innerBg:SetAlpha(0.24 * opacity)
end

local function UpdatePanelAnchor()
    panel:ClearAllPoints()

    if MinimapMusicDB and MinimapMusicDB.panelX and MinimapMusicDB.panelY then
        panel:SetPoint("CENTER", UIParent, "CENTER", MinimapMusicDB.panelX, MinimapMusicDB.panelY)
    else
        -- Default placement: slightly left of the minimap, like the reference screenshot.
        panel:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", -36, -6)
    end
end

local function SavePanelPosition()
    if not MinimapMusicDB then return end

    local px, py = panel:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if px and py and ux and uy then
        MinimapMusicDB.panelX = math.floor((px - ux) + 0.5)
        MinimapMusicDB.panelY = math.floor((py - uy) + 0.5)
    end
end

panel:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePanelPosition()
end)

-- Round mute button ---------------------------------------------------------
-- Use Blizzard's own minimap chrome instead of baking the ring into a custom
-- texture. This keeps the circle crisp at small sizes and matches the rest of
-- the Classic UI.
local muteButton = CreateFrame("Button", nil, panel)
muteButton:SetSize(22, 22)
muteButton:SetPoint("LEFT", 6, 0)

local muteBackground = muteButton:CreateTexture(nil, "BACKGROUND")
muteBackground:SetSize(16, 16)
muteBackground:SetTexture(BUTTON_DISC)
muteBackground:SetPoint("TOPLEFT", 4, -3)
MakeTextureSmooth(muteBackground)

local muteIcon = muteButton:CreateTexture(nil, "ARTWORK")
muteIcon:SetSize(11, 11)
muteIcon:SetPoint("CENTER", muteBackground, "CENTER", 0, 0)
MakeTextureSmooth(muteIcon)
muteIcon:SetTexture(ICON_PAUSE)
muteButton.icon = muteIcon

local muteBorder = muteButton:CreateTexture(nil, "OVERLAY")
muteBorder:SetSize(38, 38)
muteBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
muteBorder:SetPoint("TOPLEFT", 0, 0)

local muteHighlight = muteButton:CreateTexture(nil, "HIGHLIGHT")
muteHighlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
muteHighlight:SetPoint("CENTER", muteButton, "CENTER", 0, 0)
muteHighlight:SetSize(22, 22)
muteHighlight:SetBlendMode("ADD")
muteHighlight:SetAlpha(0.45)

-- Play/Pause style icon state for the popup mute button.
local muteX1 = muteButton:CreateTexture(nil, "OVERLAY", nil, 7)
muteX1:SetColorTexture(0.95, 0.08, 0.05, 1)
muteX1:SetSize(13, 2)
muteX1:SetPoint("CENTER", muteBackground, "CENTER", 0, 0)
if muteX1.SetRotation then muteX1:SetRotation(math.rad(45)) end
muteX1:Hide()

local muteX2 = muteButton:CreateTexture(nil, "OVERLAY", nil, 7)
muteX2:SetColorTexture(0.95, 0.08, 0.05, 1)
muteX2:SetSize(13, 2)
muteX2:SetPoint("CENTER", muteBackground, "CENTER", 0, 0)
if muteX2.SetRotation then muteX2:SetRotation(math.rad(-45)) end
muteX2:Hide()

local sliderTrack = CreateFrame("Frame", nil, panel)
sliderTrack:SetSize(118, 9)
sliderTrack:SetPoint("LEFT", muteButton, "RIGHT", 5, 0)

local trackOuter = sliderTrack:CreateTexture(nil, "BACKGROUND")
trackOuter:SetAllPoints()
trackOuter:SetColorTexture(0.035, 0.030, 0.024, 0.95)

local trackTop = sliderTrack:CreateTexture(nil, "BORDER")
trackTop:SetPoint("TOPLEFT", 0, 0)
trackTop:SetPoint("TOPRIGHT", 0, 0)
trackTop:SetHeight(1)
trackTop:SetColorTexture(0.50, 0.42, 0.29, 0.95)

local trackBottom = sliderTrack:CreateTexture(nil, "BORDER")
trackBottom:SetPoint("BOTTOMLEFT", 0, 0)
trackBottom:SetPoint("BOTTOMRIGHT", 0, 0)
trackBottom:SetHeight(1)
trackBottom:SetColorTexture(0.10, 0.075, 0.05, 0.95)

local fill = sliderTrack:CreateTexture(nil, "ARTWORK")
fill:SetPoint("LEFT", 2, 0)
fill:SetHeight(4)
fill:SetColorTexture(0.61, 0.48, 0.20, 0.86)

local slider = CreateFrame("Slider", nil, panel)
slider:SetOrientation("HORIZONTAL")
slider:SetMinMaxValues(0, 100)
slider:SetValueStep(1)
if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
slider:SetSize(114, 20)
slider:SetPoint("CENTER", sliderTrack, "CENTER", 0, 0)

local thumb = slider:CreateTexture(nil, "OVERLAY")
thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
thumb:SetSize(14, 14)
slider:SetThumbTexture(thumb)

local percentText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
percentText:SetWidth(36)
percentText:SetJustifyH("RIGHT")
percentText:SetPoint("LEFT", sliderTrack, "RIGHT", 4, 0)
percentText:SetTextColor(1.0, 0.82, 0.05)

-- Minimap button -----------------------------------------------------------
-- Match the standard LibDBIcon / Blizzard minimap-button construction. The
-- other addon in the reference screenshot uses this same classic chrome: a
-- 31x31 hit frame, 20x20 black circular background, and the 53x53 tracking
-- border texture layered over it.
local button = CreateFrame("Button", "MinimapMusicButton", UIParent)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetClampedToScreen(true)
button:SetMovable(true)

local buttonBackground = button:CreateTexture(nil, "BACKGROUND")
buttonBackground:SetSize(22, 22)
buttonBackground:SetTexture(BUTTON_DISC)
buttonBackground:SetPoint("TOPLEFT", 6, -4)
MakeTextureSmooth(buttonBackground)

local buttonIcon = button:CreateTexture(nil, "ARTWORK")
buttonIcon:SetSize(18, 18)
buttonIcon:SetPoint("CENTER", buttonBackground, "CENTER", 0, 0)
MakeTextureSmooth(buttonIcon)
buttonIcon:SetTexture(ICON_NOTE_MINIMAP)
button.icon = buttonIcon

local buttonBorder = button:CreateTexture(nil, "OVERLAY")
buttonBorder:SetSize(53, 53)
buttonBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
buttonBorder:SetPoint("TOPLEFT")

local buttonHighlight = button:CreateTexture(nil, "HIGHLIGHT")
buttonHighlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
buttonHighlight:SetAllPoints(button)
buttonHighlight:SetBlendMode("ADD")
buttonHighlight:SetAlpha(0.55)

local function UpdateMinimapButtonPosition()
    button:ClearAllPoints()

    if MinimapMusicDB and MinimapMusicDB.buttonX and MinimapMusicDB.buttonY then
        button:SetPoint("CENTER", UIParent, "CENTER", MinimapMusicDB.buttonX, MinimapMusicDB.buttonY)
    else
        -- Default position sits outside the minimap rim. Once dragged, the
        -- button is completely free and its screen position is remembered.
        local angle = math.rad(220)
        local radius = 96
        button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
end

local function SaveMinimapButtonPosition()
    if not MinimapMusicDB then return end
    local bx, by = button:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if bx and by and ux and uy then
        MinimapMusicDB.buttonX = math.floor((bx - ux) + 0.5)
        MinimapMusicDB.buttonY = math.floor((by - uy) + 0.5)
    end
end

local function UpdateVisuals()
    local percent = GetMusicVolumePercent()
    local enabled = IsMusicEnabled()

    if not slider._setting then
        slider._syncing = true
        slider:SetValue(percent)
        slider._syncing = false
    end

    percentText:SetText(percent .. "%")
    fill:SetWidth(math.max(1, 114 * (percent / 100)))

    muteIcon:SetTexture(enabled and ICON_PAUSE or ICON_PLAY)
    buttonIcon:SetTexture(ICON_NOTE_MINIMAP)

    muteIcon:SetVertexColor(1, 1, 1, 1)

    if enabled then
        buttonIcon:SetVertexColor(1, 1, 1, 1)
    else
        buttonIcon:SetVertexColor(0.55, 0.55, 0.55, 1)
    end

    muteX1:Hide()
    muteX2:Hide()
end

slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    percentText:SetText(value .. "%")
    fill:SetWidth(math.max(1, 114 * (value / 100)))

    if self._syncing then
        return
    end

    self._setting = true
    SetMusicVolumePercent(value)
    self._setting = false
end)

muteButton:SetScript("OnClick", function()
    if IsMusicEnabled() then
        SetCVarSafe("Sound_EnableMusic", "0")
    else
        SetCVarSafe("Sound_EnableMusic", "1")
    end
    UpdateVisuals()
end)

button:SetScript("OnClick", function(self, mouseButton)
    if self._dragged then
        self._dragged = nil
        return
    end

    if mouseButton == "RightButton" then
        MinimapMusicDB.buttonX = nil
        MinimapMusicDB.buttonY = nil
        UpdateMinimapButtonPosition()
        return
    end

    if panel:IsShown() then
        panel:Hide()
    else
        UpdatePanelAnchor()
        ApplyPanelOpacity()
        UpdateVisuals()
        panel:Show()
    end
end)

button:SetScript("OnDragStart", function(self)
    self._dragging = true
    self._dragged = true
    self:StartMoving()
end)

button:SetScript("OnDragStop", function(self)
    self._dragging = false
    self:StopMovingOrSizing()
    SaveMinimapButtonPosition()
end)


-- Options ------------------------------------------------------------------
local function CreateOptionsPanel()
    if optionsPanel then return end

    optionsPanel = CreateFrame("Frame", "MinimapMusicOptionsPanel")
    optionsPanel.name = "Minimap Music Volume"

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Minimap Music Volume")

    local description = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Appearance settings for the compact music popup.")

    local opacityLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -28)
    opacityLabel:SetText("Panel background opacity")

    local opacityValue = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    opacityValue:SetPoint("LEFT", opacityLabel, "RIGHT", 10, 0)

    local opacityTrack = CreateFrame("Frame", nil, optionsPanel)
    opacityTrack:SetSize(250, 10)
    opacityTrack:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -14)

    local opacityTrackBg = opacityTrack:CreateTexture(nil, "BACKGROUND")
    opacityTrackBg:SetAllPoints()
    opacityTrackBg:SetColorTexture(0.08, 0.07, 0.055, 0.9)

    local opacityTrackTop = opacityTrack:CreateTexture(nil, "BORDER")
    opacityTrackTop:SetPoint("TOPLEFT")
    opacityTrackTop:SetPoint("TOPRIGHT")
    opacityTrackTop:SetHeight(1)
    opacityTrackTop:SetColorTexture(0.5, 0.42, 0.29, 0.9)

    local opacitySlider = CreateFrame("Slider", nil, optionsPanel)
    opacitySlider:SetOrientation("HORIZONTAL")
    opacitySlider:SetMinMaxValues(20, 100)
    opacitySlider:SetValueStep(1)
    if opacitySlider.SetObeyStepOnDrag then opacitySlider:SetObeyStepOnDrag(true) end
    opacitySlider:SetSize(246, 24)
    opacitySlider:SetPoint("CENTER", opacityTrack, "CENTER")

    local opacityThumb = opacitySlider:CreateTexture(nil, "OVERLAY")
    opacityThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    opacityThumb:SetSize(18, 18)
    opacitySlider:SetThumbTexture(opacityThumb)

    local opacityHelp = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    opacityHelp:SetPoint("TOPLEFT", opacityTrack, "BOTTOMLEFT", 0, -12)
    opacityHelp:SetWidth(420)
    opacityHelp:SetJustifyH("LEFT")
    opacityHelp:SetText("Changes only the popup background. Buttons, text and the volume slider stay fully visible.")

    opacitySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        opacityValue:SetText(value .. "%")
        if self._syncing or not MinimapMusicDB then return end
        MinimapMusicDB.panelOpacity = value / 100
        ApplyPanelOpacity()
    end)

    local function RefreshOptions()
        if not MinimapMusicDB then return end
        local value = math.floor((MinimapMusicDB.panelOpacity or defaults.panelOpacity) * 100 + 0.5)
        opacitySlider._syncing = true
        opacitySlider:SetValue(value)
        opacitySlider._syncing = false
        opacityValue:SetText(value .. "%")
    end

    optionsPanel:SetScript("OnShow", RefreshOptions)

    -- Required callbacks for modern canvas Settings panels.
    optionsPanel.OnCommit = function() end
    optionsPanel.OnRefresh = RefreshOptions
    optionsPanel.OnDefault = function()
        if not MinimapMusicDB then return end
        MinimapMusicDB.panelOpacity = defaults.panelOpacity
        ApplyPanelOpacity()
        RefreshOptions()
    end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Minimap Music Volume")
        Settings.RegisterAddOnCategory(category)
        if category and category.GetID then
            settingsCategoryID = category:GetID()
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end
end

local function OpenOptions()
    panel:Hide()

    if Settings and Settings.OpenToCategory and settingsCategoryID then
        Settings.OpenToCategory(settingsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory and optionsPanel then
        -- Calling twice is a long-standing workaround for the legacy panel scrolling correctly.
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    end
end

-- Events -------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CVAR_UPDATE")

-- Forever exposes GLOBAL_MOUSE_DOWN. It lets us close the popup without using
-- an invisible fullscreen frame, so the click still reaches the game normally.
pcall(function()
    eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
end)

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        MinimapMusicDB = MinimapMusicDB or {}
        for key, value in pairs(defaults) do
            if MinimapMusicDB[key] == nil then
                MinimapMusicDB[key] = value
            end
        end

        -- Preserve custom opacity values while migrating the old development default to 50%.
        if not MinimapMusicDB.opacityDefaultMigrated then
            if tonumber(MinimapMusicDB.panelOpacity) == 0.78 then
                MinimapMusicDB.panelOpacity = defaults.panelOpacity
            end
            MinimapMusicDB.opacityDefaultMigrated = true
        end

        CreateOptionsPanel()
        UpdateMinimapButtonPosition()
        UpdatePanelAnchor()
        ApplyPanelOpacity()
        UpdateVisuals()

    elseif event == "CVAR_UPDATE" then
        if panel:IsShown() then
            UpdateVisuals()
        end

    elseif event == "GLOBAL_MOUSE_DOWN" then
        if panel:IsShown() and not panel:IsMouseOver() and not button:IsMouseOver() then
            panel:Hide()
        end
    end
end)

-- Slash commands -----------------------------------------------------------
SLASH_MINIMAPMUSIC1 = "/mmusic"
SlashCmdList.MINIMAPMUSIC = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "reset" then
        MinimapMusicDB.buttonX = nil
        MinimapMusicDB.buttonY = nil
        MinimapMusicDB.panelX = nil
        MinimapMusicDB.panelY = nil
        UpdateMinimapButtonPosition()
        UpdatePanelAnchor()
        print("|cffffcc33Minimap Music Volume:|r button and popup positions reset.")
        return
    end

    if msg == "resetpanel" then
        MinimapMusicDB.panelX = nil
        MinimapMusicDB.panelY = nil
        UpdatePanelAnchor()
        print("|cffffcc33Minimap Music Volume:|r popup position reset.")
        return
    end

    if msg == "options" or msg == "config" then
        OpenOptions()
        return
    end

    if panel:IsShown() then
        panel:Hide()
    else
        UpdatePanelAnchor()
        ApplyPanelOpacity()
        UpdateVisuals()
        panel:Show()
    end
end

-- Let Escape close the popup like a normal WoW popup.
table.insert(UISpecialFrames, "MinimapMusicPanel")
