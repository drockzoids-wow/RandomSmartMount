local PANEL_NAME = "Random Smart Mount"

RandomSmartMountUI = RandomSmartMountUI or {}

local panel = CreateFrame("Frame")
panel.name = PANEL_NAME

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Random Smart Mount")

local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
description:SetWidth(700)
description:SetJustifyH("LEFT")
description:SetText("Random Smart Mount now uses its own Control Center window for configuration.")

local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
openButton:SetSize(190, 28)
openButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
openButton:SetText("Open Control Center")

openButton:SetScript("OnClick", function()

    local function OpenControlCenter()
        if RandomSmartMountUI and RandomSmartMountUI.Show then
            RandomSmartMountUI.Show()
        end
    end

    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
        C_Timer.After(0, OpenControlCenter)
        return
    end

    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        HideUIPanel(InterfaceOptionsFrame)
        C_Timer.After(0, OpenControlCenter)
        return
    end

    OpenControlCenter()
end)

local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", 0, -12)
hint:SetWidth(700)
hint:SetJustifyH("LEFT")
hint:SetText("You can also open it by right-clicking the minimap button or typing /rsmui.")

local function RegisterOptions()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME, PANEL_NAME)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

RegisterOptions()