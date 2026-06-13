RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

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
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    end
end

local function GetDB()
    if RandomSmartMountAPI and RandomSmartMountAPI.GetDB then
        return RandomSmartMountAPI.GetDB()
    end

    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.preferredServiceMounts = RandomSmartMountDB.preferredServiceMounts or {}
    return RandomSmartMountDB
end

local function EnsureMountJournalLoaded()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_Collections")
    end
end

local function NormalizeMountName(name)
    if RandomSmartMountAPI and RandomSmartMountAPI.NormalizeMountName then
        return RandomSmartMountAPI.NormalizeMountName(name)
    end

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
        if normalizedMount == NormalizeMountName(wantedName) then
            return true
        end
    end

    return false
end

local function GetOwnedServiceMountNames(serviceType)
    EnsureMountJournalLoaded()

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

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 26)
    button:SetText(text)
    return button
end

local function CreateServiceDropdown(parent, serviceType)
    local dropdown = CreateFrame("Frame", "RandomSmartMountServiceDropdown_" .. serviceType, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, 260)

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        EnsureMountJournalLoaded()

        local db = GetDB()
        local selected = db.preferredServiceMounts[serviceType]

        local defaultInfo = UIDropDownMenu_CreateInfo()
        defaultInfo.text = "Default Priority"
        defaultInfo.checked = not selected
        defaultInfo.func = function()
            db.preferredServiceMounts[serviceType] = nil
            UIDropDownMenu_SetText(dropdown, "Default Priority")
            Print(SERVICE_LABELS[serviceType] .. " set to Default Priority.")
        end
        UIDropDownMenu_AddButton(defaultInfo, level)

        for _, mountName in ipairs(GetOwnedServiceMountNames(serviceType)) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = mountName
            info.checked = selected == mountName
            info.func = function()
                db.preferredServiceMounts[serviceType] = mountName
                UIDropDownMenu_SetText(dropdown, mountName)
                Print(SERVICE_LABELS[serviceType] .. " preference set to " .. mountName .. ".")
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return dropdown
end

function RandomSmartMountUI.Pages.CreateServiceMountsPage(parent)
    local frame = RandomSmartMountUI.CreatePageFrame(parent)
    frame.dropdowns = {}

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Service Mounts")

    local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    description:SetWidth(480)
    description:SetJustifyH("LEFT")
    description:SetText("Choose preferred mounts for vendor, auction house, and ride-along keybinds. If unavailable, the addon falls back to the built-in priority order.")

    local previous = description

    for _, serviceType in ipairs(SERVICE_ORDER) do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(520, 42)
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -22)

        local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", 0, 0)
        label:SetWidth(170)
        label:SetJustifyH("LEFT")
        label:SetText(SERVICE_LABELS[serviceType])

        local dropdown = CreateServiceDropdown(row, serviceType)
        dropdown:SetPoint("LEFT", label, "RIGHT", -12, -2)

        frame.dropdowns[serviceType] = dropdown
        previous = row
    end

    local resetButton = CreateButton(frame, "Reset All Defaults", 160)
    resetButton:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -24)

    local note = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -14)
    note:SetWidth(480)
    note:SetJustifyH("LEFT")
    note:SetText("Vendor and auction house defaults use the addon's built-in order. Ride-Along defaults choose from eligible passenger mounts for the current area.")

    local function Refresh()
        local db = GetDB()

        for _, serviceType in ipairs(SERVICE_ORDER) do
            local selected = db.preferredServiceMounts[serviceType]
            UIDropDownMenu_SetText(frame.dropdowns[serviceType], selected or "Default Priority")
        end
    end

    resetButton:SetScript("OnClick", function()
        RandomSmartMountUI.ConfirmAction("Reset all service mount preferences to default priority?", function()
            local db = GetDB()
            db.preferredServiceMounts = {}

            Refresh()
            Print("All service mount preferences reset to Default Priority.")
        end)
    end)

    frame.Refresh = Refresh
    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end
