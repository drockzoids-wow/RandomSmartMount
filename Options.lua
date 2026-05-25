local PANEL_NAME = "Random Smart Mount"

local SERVICE_LABELS = {
    vendor = "Vendor Mounts",
    auctionHouse = "Auction House Mounts",
    rideAlong = "Ride-Along Mounts",
}

local SERVICE_ORDER = {
    "vendor",
    "auctionHouse",
    "rideAlong",
}

local rows = {}

local function Print(msg)
    print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
end

local function GetDB()
    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.serviceMounts = RandomSmartMountDB.serviceMounts or {}

    for _, serviceType in ipairs(SERVICE_ORDER) do
        RandomSmartMountDB.serviceMounts[serviceType] =
            RandomSmartMountDB.serviceMounts[serviceType] or {}
    end

    return RandomSmartMountDB
end

local function CopyDefaultList(serviceType)
    local list = {}

    if RSM_SERVICE_MOUNT_PRIORITY and RSM_SERVICE_MOUNT_PRIORITY[serviceType] then
        for _, name in ipairs(RSM_SERVICE_MOUNT_PRIORITY[serviceType]) do
            table.insert(list, name)
        end
    end

    return list
end

local function EnsureCustomList(serviceType)
    local db = GetDB()

    if not db.serviceMounts[serviceType] or #db.serviceMounts[serviceType] == 0 then
        db.serviceMounts[serviceType] = CopyDefaultList(serviceType)
    end
end

local function MoveItem(list, index, offset)
    local newIndex = index + offset
    if newIndex < 1 or newIndex > #list then return end

    list[index], list[newIndex] = list[newIndex], list[index]
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 90, 24)
    button:SetText(text)
    return button
end

local panel = CreateFrame("Frame")
panel.name = PANEL_NAME

local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", -28, 4)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(760, 1)
scrollFrame:SetScrollChild(content)

panel.content = content
panel.sections = {}

local function RefreshPanel()
    local db = GetDB()

    for _, rowSet in pairs(rows) do
        for _, row in ipairs(rowSet) do
            row:Hide()
        end
    end

    local totalHeight = 90

    for _, serviceType in ipairs(SERVICE_ORDER) do
        local section = panel.sections[serviceType]

        EnsureCustomList(serviceType)

        local list = db.serviceMounts[serviceType]
        rows[serviceType] = rows[serviceType] or {}

        for index, mountName in ipairs(list) do
            local row = rows[serviceType][index]

            if not row then
                row = CreateFrame("Frame", nil, section)
                row:SetSize(680, 28)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.text:SetPoint("LEFT", 8, 0)
                row.text:SetWidth(460)
                row.text:SetJustifyH("LEFT")

                row.up = CreateButton(row, "Up", 48)
                row.up:SetPoint("LEFT", row.text, "RIGHT", 12, 0)

                row.down = CreateButton(row, "Down", 58)
                row.down:SetPoint("LEFT", row.up, "RIGHT", 4, 0)

                rows[serviceType][index] = row
            end

            row:SetPoint("TOPLEFT", section.listAnchor, "BOTTOMLEFT", 0, -4 - ((index - 1) * 30))
            row.text:SetText(index .. ". " .. mountName)
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #list)

            row.up:SetScript("OnClick", function()
                MoveItem(db.serviceMounts[serviceType], index, -1)
                RefreshPanel()
            end)

            row.down:SetScript("OnClick", function()
                MoveItem(db.serviceMounts[serviceType], index, 1)
                RefreshPanel()
            end)

            row:Show()
        end

        local sectionHeight = 92 + (#list * 30)
        section:SetHeight(sectionHeight)
        totalHeight = totalHeight + sectionHeight + 28
    end

    content:SetHeight(math.max(totalHeight, 640))
end

local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Random Smart Mount")

local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Configure service mount priority lists. Move mounts up or down to choose which mounts are preferred first.")
subtitle:SetWidth(700)
subtitle:SetJustifyH("LEFT")

local previousAnchor = subtitle

local function CreateServiceSection(serviceType, anchor)
    local section = CreateFrame("Frame", nil, content)
    section:SetSize(720, 120)
    section:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -26)

    local title = section:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(SERVICE_LABELS[serviceType])

    section.resetButton = CreateButton(section, "Reset Default", 130)
    section.resetButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    local help = section:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", section.resetButton, "BOTTOMLEFT", 4, -6)
    help:SetText("The first usable owned mount in this list will be selected.")
    help:SetWidth(640)
    help:SetJustifyH("LEFT")

    section.listAnchor = CreateFrame("Frame", nil, section)
    section.listAnchor:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -8)
    section.listAnchor:SetSize(680, 1)

    section.resetButton:SetScript("OnClick", function()
        local db = GetDB()
        db.serviceMounts[serviceType] = CopyDefaultList(serviceType)
        RefreshPanel()
        Print(SERVICE_LABELS[serviceType] .. " reset to default priority.")
    end)

    return section
end

for _, serviceType in ipairs(SERVICE_ORDER) do
    local section = CreateServiceSection(serviceType, previousAnchor)
    panel.sections[serviceType] = section
    previousAnchor = section
end

panel:SetScript("OnShow", function()
    RefreshPanel()
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