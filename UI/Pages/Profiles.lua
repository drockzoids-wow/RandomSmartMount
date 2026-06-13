RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    end
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 26)
    button:SetText(text)
    return button
end

local function GetProfileOptions()
    if RandomSmartMountAPI and RandomSmartMountAPI.GetProfileScopeOptions then
        return RandomSmartMountAPI.GetProfileScopeOptions()
    end

    return {
        { key = "account", label = "Account-wide", detail = "Shared by every character." },
    }
end

local function GetProfileDisplayName(scope)
    if RandomSmartMountAPI and RandomSmartMountAPI.GetProfileDisplayName then
        return RandomSmartMountAPI.GetProfileDisplayName(scope)
    end

    return "Account-wide"
end

local function GetProfileScope()
    if RandomSmartMountAPI and RandomSmartMountAPI.GetProfileScope then
        return RandomSmartMountAPI.GetProfileScope()
    end

    return "account"
end

local function RefreshUIForProfileChange()
    if RandomSmartMountUI.UpdateMinimapButtonVisibility then
        RandomSmartMountUI.UpdateMinimapButtonVisibility()
    end

    if RandomSmartMountUI.RefreshPages then
        RandomSmartMountUI.RefreshPages()
    end
end

function RandomSmartMountUI.Pages.CreateProfilesPage(parent)
    local frame = RandomSmartMountUI.CreatePageFrame(parent)
    local copySourceScope = "account"

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Profiles")

    local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    description:SetWidth(520)
    description:SetJustifyH("LEFT")
    description:SetText("Choose whether Random Smart Mount settings are shared account-wide, per character, or per class.")

    local activeLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    activeLabel:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -22)
    activeLabel:SetText("Active profile:")

    local activeDropdown = CreateFrame("Frame", "RandomSmartMountProfilesActiveDropdown", frame, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(activeDropdown, 240)
    activeDropdown:SetPoint("LEFT", activeLabel, "RIGHT", -8, -2)

    local currentText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    currentText:SetPoint("TOPLEFT", activeLabel, "BOTTOMLEFT", 0, -34)
    currentText:SetWidth(520)
    currentText:SetJustifyH("LEFT")

    local copyTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    copyTitle:SetPoint("TOPLEFT", currentText, "BOTTOMLEFT", 0, -28)
    copyTitle:SetText("Copy Settings")

    local copyDescription = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    copyDescription:SetPoint("TOPLEFT", copyTitle, "BOTTOMLEFT", 0, -8)
    copyDescription:SetWidth(520)
    copyDescription:SetJustifyH("LEFT")
    copyDescription:SetText("Copy another profile's settings into the active profile.")

    local copyLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    copyLabel:SetPoint("TOPLEFT", copyDescription, "BOTTOMLEFT", 0, -16)
    copyLabel:SetText("Copy from:")

    local copyDropdown = CreateFrame("Frame", "RandomSmartMountProfilesCopyDropdown", frame, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(copyDropdown, 240)
    copyDropdown:SetPoint("LEFT", copyLabel, "RIGHT", -8, -2)

    local copyButton = CreateButton(frame, "Copy Into Active", 145)
    copyButton:SetPoint("LEFT", copyDropdown, "RIGHT", -6, 2)

    local resetTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    resetTitle:SetPoint("TOPLEFT", copyLabel, "BOTTOMLEFT", 0, -34)
    resetTitle:SetText("Reset")

    local resetDescription = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    resetDescription:SetPoint("TOPLEFT", resetTitle, "BOTTOMLEFT", 0, -8)
    resetDescription:SetWidth(520)
    resetDescription:SetJustifyH("LEFT")
    resetDescription:SetText("Reset only the active profile. Other profiles are not changed.")

    local resetButton = CreateButton(frame, "Reset Active Profile", 160)
    resetButton:SetPoint("TOPLEFT", resetDescription, "BOTTOMLEFT", 0, -14)

    local note = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -18)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetText("Profiles include general settings, mount groups, preferred mounts, service mount choices, blacklist, recent mounts, and usage statistics. The minimap icon position stays shared.")

    local function Refresh()
        local activeScope = GetProfileScope()
        local activeName = GetProfileDisplayName(activeScope)
        local copyName = GetProfileDisplayName(copySourceScope)

        UIDropDownMenu_SetText(activeDropdown, activeName)
        UIDropDownMenu_SetText(copyDropdown, copyName)
        currentText:SetText("Using profile: " .. activeName)
        copyButton:SetEnabled(copySourceScope ~= activeScope)
    end

    UIDropDownMenu_Initialize(activeDropdown, function(_, level)
        for _, option in ipairs(GetProfileOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.checked = GetProfileScope() == option.key
            info.func = function()
                if RandomSmartMountAPI and RandomSmartMountAPI.SetProfileScope then
                    RandomSmartMountAPI.SetProfileScope(option.key)
                end

                Print("Profile set to " .. GetProfileDisplayName(option.key) .. ".")
                RefreshUIForProfileChange()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_Initialize(copyDropdown, function(_, level)
        for _, option in ipairs(GetProfileOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.checked = copySourceScope == option.key
            info.func = function()
                copySourceScope = option.key
                Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    copyButton:SetScript("OnClick", function()
        local activeScope = GetProfileScope()
        if copySourceScope == activeScope then return end

        local sourceName = GetProfileDisplayName(copySourceScope)
        local targetName = GetProfileDisplayName(activeScope)

        RandomSmartMountUI.ConfirmAction(
            "Copy settings from " .. sourceName .. " into " .. targetName .. "?",
            function()
                if RandomSmartMountAPI and RandomSmartMountAPI.CopyProfile then
                    RandomSmartMountAPI.CopyProfile(copySourceScope, activeScope)
                end

                Print("Copied " .. sourceName .. " into " .. targetName .. ".")
                RefreshUIForProfileChange()
            end
        )
    end)

    resetButton:SetScript("OnClick", function()
        local activeScope = GetProfileScope()
        local activeName = GetProfileDisplayName(activeScope)

        RandomSmartMountUI.ConfirmAction("Reset " .. activeName .. "?", function()
            if RandomSmartMountAPI and RandomSmartMountAPI.ResetProfile then
                RandomSmartMountAPI.ResetProfile(activeScope)
            end

            Print("Reset " .. activeName .. ".")
            RefreshUIForProfileChange()
        end)
    end)

    frame.Refresh = Refresh
    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end
