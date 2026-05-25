local PANEL_NAME = "Random Smart Mount"

local SERVICE_LABELS = {
    vendor = "Vendor Mount",
    auctionHouse = "Auction House Mount",
    rideAlong = "Ride-Along Mount",
}

local SERVICE_ORDER = {
    "vendor",
    "auctionHouse",
    "rideAlong",
}

local function Print(msg)
    print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
end

local function GetDB()
    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.preferredServiceMounts = RandomSmartMountDB.preferredServiceMounts or {}
    return RandomSmartMountDB
end

local function NormalizeMountName(name)
    if not name then return "" end

    name = string.lower(name)
    name = name:gsub("’", "'")
    name = name:gsub("reins of the ", "")
    name = name:gsub("reins of ", "")

    return name
end

local function IsKnownServiceMount(serviceType, mountName)
    if not RSM_SERVICE_MOUNT_PRIORITY or not RSM_SERVICE_MOUNT_PRIORITY[serviceType] then
        return false
    end

    local normalizedMount = NormalizeMountName(mountName)

    for _, wantedName in ipairs(RSM_SERVICE_MOUNT_PRIORITY[serviceType]) do
        local normalizedWanted = NormalizeMountName(wantedName)

        if normalizedMount == normalizedWanted then
            return true
        end
    end

    return false
end

local function GetOwnedServiceMountNames(serviceType)
    local names = {}
    local seen = {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return names
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, _, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)

        if name and isCollected and IsKnownServiceMount(serviceType, name) then
            local normalized = NormalizeMountName(name)

            if not seen[normalized] then
                seen[normalized] = true
                table.insert(names, name)
            end
        end
    end

    table.sort(names)
    return names
end

local function CreateDropdown(parent, serviceType)
    local dropdown = CreateFrame("Frame", "RandomSmartMountDropdown_" .. serviceType, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, 240)

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local db = GetDB()
        local selected = db.preferredServiceMounts[serviceType]

        local info = UIDropDownMenu_CreateInfo()
        info.text = "Default Priority"
        info.checked = not selected
        info.func = function()
            db.preferredServiceMounts[serviceType] = nil
            UIDropDownMenu_SetText(dropdown, "Default Priority")
            Print(SERVICE_LABELS[serviceType] .. " set to Default Priority.")
        end
        UIDropDownMenu_AddButton(info, level)

        for _, mountName in ipairs(GetOwnedServiceMountNames(serviceType)) do
            local mountInfo = UIDropDownMenu_CreateInfo()
            mountInfo.text = mountName
            mountInfo.checked = selected == mountName
            mountInfo.func = function()
                db.preferredServiceMounts[serviceType] = mountName
                UIDropDownMenu_SetText(dropdown, mountName)
                Print(SERVICE_LABELS[serviceType] .. " preference set to " .. mountName .. ".")
            end
            UIDropDownMenu_AddButton(mountInfo, level)
        end
    end)

    return dropdown
end

local panel = CreateFrame("Frame")
panel.name = PANEL_NAME
panel.dropdowns = {}

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Random Smart Mount")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Choose preferred service mounts. If the selected mount is unavailable, the addon falls back to the default priority list.")
subtitle:SetWidth(700)
subtitle:SetJustifyH("LEFT")

local previous = subtitle

for _, serviceType in ipairs(SERVICE_ORDER) do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(620, 36)
    row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -18)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(180)
    label:SetJustifyH("LEFT")
    label:SetText(SERVICE_LABELS[serviceType])

    local dropdown = CreateDropdown(row, serviceType)
    dropdown:SetPoint("LEFT", label, "RIGHT", -12, -2)

    panel.dropdowns[serviceType] = dropdown
    previous = row
end

local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
note:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 18, -28)
note:SetText("Default Priority uses the built-in order from the addon. Specific selections are tried first, then fallback to default.")
note:SetWidth(680)
note:SetJustifyH("LEFT")

local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetButton:SetSize(150, 24)
resetButton:SetText("Reset All Defaults")
resetButton:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -16)

resetButton:SetScript("OnClick", function()
    local db = GetDB()
    db.preferredServiceMounts = {}

    for _, serviceType in ipairs(SERVICE_ORDER) do
        UIDropDownMenu_SetText(panel.dropdowns[serviceType], "Default Priority")
    end

    Print("All service mount preferences reset to Default Priority.")
end)

panel:SetScript("OnShow", function()
    local db = GetDB()

    for _, serviceType in ipairs(SERVICE_ORDER) do
        local selected = db.preferredServiceMounts[serviceType]
        UIDropDownMenu_SetText(panel.dropdowns[serviceType], selected or "Default Priority")
    end
end)

local function RegisterOptions()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME, PANEL_NAME)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

RegisterOptions()