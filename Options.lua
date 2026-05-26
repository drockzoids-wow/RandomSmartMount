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

local function API()
    return RandomSmartMountAPI or {}
end

local function Print(msg)
    if API().Print then
        API().Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

local function GetDB()
    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.preferredServiceMounts = RandomSmartMountDB.preferredServiceMounts or {}
    RandomSmartMountDB.blacklist = RandomSmartMountDB.blacklist or {}
    RandomSmartMountDB.mountUsage = RandomSmartMountDB.mountUsage or {}
	RandomSmartMountDB.preferredMount = RandomSmartMountDB.preferredMount or nil
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
    if API().NormalizeMountName then
        return API().NormalizeMountName(name)
    end

    if not name then return "" end
    name = string.lower(name)
    name = name:gsub("’", "'")
    name = name:gsub("reins of the ", "")
    name = name:gsub("reins of ", "")
    return name
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, 24)
    button:SetText(text)
    return button
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

local function GetCollectedMounts()
    EnsureMountJournalLoaded()

    local mounts = {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return mounts
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, _, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)

        if name and isCollected then
            table.insert(mounts, {
                id = mountID,
                name = name,
                normalized = NormalizeMountName(name),
            })
        end
    end

    table.sort(mounts, function(a, b)
        return a.name < b.name
    end)

    return mounts
end

-- Main service mount panel
local mainPanel = CreateFrame("Frame")
mainPanel.name = PANEL_NAME
mainPanel.dropdowns = {}

local title = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Random Smart Mount")

local subtitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Choose preferred service mounts. If the selected mount is unavailable, the addon falls back to the default priority list.")
subtitle:SetWidth(700)
subtitle:SetJustifyH("LEFT")



local function CreateDropdown(parent, serviceType)
    local dropdown = CreateFrame("Frame", "RandomSmartMountDropdown_" .. serviceType, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, 240)

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

local previous = subtitle
local preferredRow = CreateFrame("Frame", nil, mainPanel)
preferredRow:SetSize(620, 150)
preferredRow:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -18)

local preferredLabel = preferredRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
preferredLabel:SetPoint("TOPLEFT", 0, 0)
preferredLabel:SetText("Preferred Smart Mount")

local preferredCurrent = preferredRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
preferredCurrent:SetPoint("TOPLEFT", preferredLabel, "BOTTOMLEFT", 0, -6)
preferredCurrent:SetWidth(620)
preferredCurrent:SetJustifyH("LEFT")

local preferredSearchBox = CreateFrame("EditBox", nil, preferredRow, "InputBoxTemplate")
preferredSearchBox:SetSize(280, 24)
preferredSearchBox:SetPoint("TOPLEFT", preferredCurrent, "BOTTOMLEFT", 6, -8)
preferredSearchBox:SetAutoFocus(false)

local preferredResetButton = CreateButton(preferredRow, "Reset Default", 120)
preferredResetButton:SetPoint("LEFT", preferredSearchBox, "RIGHT", 10, 0)

local preferredResultsContainer = CreateFrame("Frame", nil, preferredRow, "BackdropTemplate")
preferredResultsContainer:SetPoint("TOPLEFT", preferredSearchBox, "BOTTOMLEFT", -6, -8)
preferredResultsContainer:SetSize(490, 92)

preferredResultsContainer:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3
    }
})

preferredResultsContainer:SetBackdropColor(0, 0, 0, 0.85)
preferredResultsContainer:SetFrameStrata("DIALOG")
preferredResultsContainer:SetFrameLevel(50)

local preferredResultsFrame = CreateFrame("Frame", nil, preferredResultsContainer)
preferredResultsFrame:SetPoint("TOPLEFT", 8, -8)
preferredResultsFrame:SetSize(480, 72)
preferredResultsFrame.rows = {}

preferredResultsContainer:Hide()
mainPanel.preferredResultsContainer = preferredResultsContainer

mainPanel.preferredCurrent = preferredCurrent
mainPanel.preferredSearchBox = preferredSearchBox
mainPanel.preferredResultsFrame = preferredResultsFrame

previous = preferredRow

local function RefreshPreferredSearchResults()
    EnsureMountJournalLoaded()

    local db = GetDB()
    local query = NormalizeMountName(mainPanel.preferredSearchBox:GetText() or "")
    local resultsFrame = mainPanel.preferredResultsFrame

    mainPanel.preferredCurrent:SetText("Current Preferred: " .. (db.preferredMount or "Default Random Behavior"))

    for _, row in ipairs(resultsFrame.rows) do
        row:Hide()
    end

    if query == "" then
        mainPanel.preferredResultsContainer:Hide()
        return
    end

    mainPanel.preferredResultsContainer:Show()
	local resultCount = 0
	
    local matches = {}

    for _, mount in ipairs(GetCollectedMounts()) do
        if string.find(mount.normalized, query, 1, true) then
            table.insert(matches, mount)
			resultCount = resultCount + 1
            if #matches >= 3 then
                break
            end
        end
    end

	local containerHeight = math.max(40, (resultCount * 26) + 18)
	mainPanel.preferredResultsContainer:SetHeight(containerHeight)
	mainPanel.preferredResultsFrame:SetHeight(containerHeight - 20)

    for index, mount in ipairs(matches) do
        local row = resultsFrame.rows[index]

        if not row then
            row = CreateFrame("Frame", nil, resultsFrame)
            row:SetSize(470, 24)

            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 0, 0)
            row.text:SetWidth(390)
            row.text:SetJustifyH("LEFT")

            row.use = CreateButton(row, "Use", 70)
            row.use:SetPoint("LEFT", row.text, "RIGHT", 8, 0)

            resultsFrame.rows[index] = row
        end

        row:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 0, -((index - 1) * 26))
        row.text:SetText(mount.name)

        row.use:SetScript("OnClick", function()
            db.preferredMount = mount.name
            mainPanel.preferredSearchBox:SetText("")
            mainPanel.preferredSearchBox:ClearFocus()
            RefreshPreferredSearchResults()
            Print("Preferred Smart Mount set to " .. mount.name .. ".")
        end)

        row:Show()
    end
end

preferredSearchBox:SetScript("OnTextChanged", function()
    RefreshPreferredSearchResults()
end)

preferredSearchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

preferredResetButton:SetScript("OnClick", function()
    local db = GetDB()
    db.preferredMount = nil
    preferredSearchBox:SetText("")
    preferredSearchBox:ClearFocus()
    RefreshPreferredSearchResults()
    Print("Preferred Smart Mount reset to Default Random Behavior.")
end)

for _, serviceType in ipairs(SERVICE_ORDER) do
    local row = CreateFrame("Frame", nil, mainPanel)
    row:SetSize(620, 36)
    row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -18)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(180)
    label:SetJustifyH("LEFT")
    label:SetText(SERVICE_LABELS[serviceType])

    local dropdown = CreateDropdown(row, serviceType)
    dropdown:SetPoint("LEFT", label, "RIGHT", -12, -2)

    mainPanel.dropdowns[serviceType] = dropdown
    previous = row
end

local note = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
note:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -22)
note:SetText("Default Priority uses the built-in order from the addon. Specific selections are tried first, then fallback to default.")
note:SetWidth(680)
note:SetJustifyH("LEFT")

local resetButton = CreateButton(mainPanel, "Reset All Defaults", 150)
resetButton:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -16)
resetButton:SetScript("OnClick", function()
    local db = GetDB()
    db.preferredServiceMounts = {}

    for _, serviceType in ipairs(SERVICE_ORDER) do
        UIDropDownMenu_SetText(mainPanel.dropdowns[serviceType], "Default Priority")
    end

    Print("All service mount preferences reset to Default Priority.")
end)

mainPanel:SetScript("OnShow", function()
    EnsureMountJournalLoaded()

    local db = GetDB()
	RefreshPreferredSearchResults()
	
    for _, serviceType in ipairs(SERVICE_ORDER) do
        local selected = db.preferredServiceMounts[serviceType]
        UIDropDownMenu_SetText(mainPanel.dropdowns[serviceType], selected or "Default Priority")
    end
end)

-- Statistics panel
local statsPanel = CreateFrame("Frame")
statsPanel.name = "Statistics"
statsPanel.parent = PANEL_NAME
statsPanel.rows = {}

local statsTitle = statsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
statsTitle:SetPoint("TOPLEFT", 16, -16)
statsTitle:SetText("Random Smart Mount Statistics")

local statsSummary = statsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
statsSummary:SetPoint("TOPLEFT", statsTitle, "BOTTOMLEFT", 0, -8)
statsSummary:SetWidth(700)
statsSummary:SetJustifyH("LEFT")

local resetUsageButton = CreateButton(statsPanel, "Reset Usage History", 160)
resetUsageButton:SetPoint("TOPLEFT", statsSummary, "BOTTOMLEFT", 0, -16)

local usageListTitle = statsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
usageListTitle:SetPoint("TOPLEFT", resetUsageButton, "BOTTOMLEFT", 0, -18)
usageListTitle:SetText("Most Used Mounts")

local function RefreshStatsPanel()
    EnsureMountJournalLoaded()

    local total = API().GetTotalMountUses and API().GetTotalMountUses() or 0
    local entries = API().GetSortedUsageMounts and API().GetSortedUsageMounts(true) or {}

    statsSummary:SetText("Total tracked mount uses: " .. tostring(total))

    for _, row in ipairs(statsPanel.rows) do
        row:Hide()
    end

    local maxRows = math.min(15, #entries)

    if maxRows == 0 then
        if not statsPanel.emptyText then
            statsPanel.emptyText = statsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            statsPanel.emptyText:SetPoint("TOPLEFT", usageListTitle, "BOTTOMLEFT", 0, -10)
            statsPanel.emptyText:SetText("No mount usage has been tracked yet.")
        end

        statsPanel.emptyText:Show()
        return
    end

    if statsPanel.emptyText then
        statsPanel.emptyText:Hide()
    end

    for index = 1, maxRows do
        local entry = entries[index]
        local row = statsPanel.rows[index]

        if not row then
            row = statsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row:SetWidth(680)
            row:SetJustifyH("LEFT")
            statsPanel.rows[index] = row
        end

        row:SetPoint("TOPLEFT", usageListTitle, "BOTTOMLEFT", 0, -10 - ((index - 1) * 18))
        row:SetText(index .. ". " .. entry.name .. " - " .. tostring(entry.count))
        row:Show()
    end
end

resetUsageButton:SetScript("OnClick", function()
    if API().ClearMountUsage then
        API().ClearMountUsage()
    else
        GetDB().mountUsage = {}
    end

    RefreshStatsPanel()
    Print("Mount usage history reset.")
end)

statsPanel:SetScript("OnShow", function()
    EnsureMountJournalLoaded()
    RefreshStatsPanel()
end)

-- Blacklist panel with search
local blacklistPanel = CreateFrame("Frame")
blacklistPanel.name = "Blacklist"
blacklistPanel.parent = PANEL_NAME
blacklistPanel.searchRows = {}
blacklistPanel.blacklistRows = {}
blacklistPanel.searchText = ""

local blacklistTitle = blacklistPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
blacklistTitle:SetPoint("TOPLEFT", 16, -16)
blacklistTitle:SetText("Random Smart Mount Blacklist")

local blacklistSubtitle = blacklistPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
blacklistSubtitle:SetPoint("TOPLEFT", blacklistTitle, "BOTTOMLEFT", 0, -8)
blacklistSubtitle:SetText("Blacklisted mounts will not be selected by the smart random mount system.")
blacklistSubtitle:SetWidth(700)
blacklistSubtitle:SetJustifyH("LEFT")

local addLastButton = CreateButton(blacklistPanel, "Blacklist Last Mount", 160)
addLastButton:SetPoint("TOPLEFT", blacklistSubtitle, "BOTTOMLEFT", 0, -16)

local clearBlacklistButton = CreateButton(blacklistPanel, "Clear Blacklist", 130)
clearBlacklistButton:SetPoint("LEFT", addLastButton, "RIGHT", 8, 0)

local searchLabel = blacklistPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
searchLabel:SetPoint("TOPLEFT", addLastButton, "BOTTOMLEFT", 0, -20)
searchLabel:SetText("Search collected mounts:")

local searchBox = CreateFrame("EditBox", nil, blacklistPanel, "InputBoxTemplate")
searchBox:SetSize(280, 24)
searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 6, -6)
searchBox:SetAutoFocus(false)
searchBox:SetText("")

local clearSearchButton = CreateButton(blacklistPanel, "Clear Search", 110)
clearSearchButton:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

local searchHelp = blacklistPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
searchHelp:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -6, -6)
searchHelp:SetText("Type part of a mount name, then click Add.")
searchHelp:SetWidth(700)
searchHelp:SetJustifyH("LEFT")

local searchResultsTitle = blacklistPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
searchResultsTitle:SetPoint("TOPLEFT", searchHelp, "BOTTOMLEFT", 0, -12)
searchResultsTitle:SetText("Search Results")

local searchScrollFrame = CreateFrame("ScrollFrame", nil, blacklistPanel, "UIPanelScrollFrameTemplate")
searchScrollFrame:SetPoint("TOPLEFT", searchResultsTitle, "BOTTOMLEFT", 0, -8)
searchScrollFrame:SetSize(560, 170)

local searchScrollChild = CreateFrame("Frame", nil, searchScrollFrame)
searchScrollChild:SetSize(540, 1)
searchScrollFrame:SetScrollChild(searchScrollChild)

local blacklistedTitle = blacklistPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
blacklistedTitle:SetPoint("TOPLEFT", searchScrollFrame, "BOTTOMLEFT", 0, -22)
blacklistedTitle:SetText("Blacklisted Mounts")

local blacklistedScrollFrame = CreateFrame("ScrollFrame", nil, blacklistPanel, "UIPanelScrollFrameTemplate")
blacklistedScrollFrame:SetPoint("TOPLEFT", blacklistedTitle, "BOTTOMLEFT", 0, -8)
blacklistedScrollFrame:SetSize(560, 190)

local blacklistedScrollChild = CreateFrame("Frame", nil, blacklistedScrollFrame)
blacklistedScrollChild:SetSize(540, 1)
blacklistedScrollFrame:SetScrollChild(blacklistedScrollChild)

local function MountIsBlacklisted(mountID)
    if API().IsMountBlacklisted then
        return API().IsMountBlacklisted(mountID)
    end

    local db = GetDB()
    return db.blacklist and (db.blacklist[mountID] == true or db.blacklist[tostring(mountID)] == true)
end

local function GetSearchMatches()
    EnsureMountJournalLoaded()

    local query = NormalizeMountName(blacklistPanel.searchText or "")
    local matches = {}

    if query == "" then
        return matches
    end

    for _, mount in ipairs(GetCollectedMounts()) do
        if not MountIsBlacklisted(mount.id) and string.find(mount.normalized, query, 1, true) then
            table.insert(matches, mount)

            if #matches >= 25 then
                break
            end
        end
    end

    return matches
end

local function RefreshBlacklistPanel()
    EnsureMountJournalLoaded()

    local matches = GetSearchMatches()
    local blacklistedIDs = API().GetBlacklistedMountIDs and API().GetBlacklistedMountIDs() or {}

    for _, row in ipairs(blacklistPanel.searchRows) do
        row:Hide()
    end

    for _, row in ipairs(blacklistPanel.blacklistRows) do
        row:Hide()
    end

    if blacklistPanel.searchEmptyText then
        blacklistPanel.searchEmptyText:Hide()
    end

    if #matches == 0 then
        if not blacklistPanel.searchEmptyText then
            blacklistPanel.searchEmptyText = searchScrollChild:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            blacklistPanel.searchEmptyText:SetPoint("TOPLEFT", searchScrollChild, "TOPLEFT", 0, 0)
            blacklistPanel.searchEmptyText:SetWidth(520)
            blacklistPanel.searchEmptyText:SetJustifyH("LEFT")
        end

        if (blacklistPanel.searchText or "") == "" then
            blacklistPanel.searchEmptyText:SetText("Type in the search box to find collected mounts.")
        else
            blacklistPanel.searchEmptyText:SetText("No matching collected mounts found.")
        end

        blacklistPanel.searchEmptyText:Show()
        searchScrollChild:SetHeight(24)
    else
        for index, mount in ipairs(matches) do
            local row = blacklistPanel.searchRows[index]

            if not row then
                row = CreateFrame("Frame", nil, searchScrollChild)
                row:SetSize(520, 26)

                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 0, 0)
                row.text:SetWidth(390)
                row.text:SetJustifyH("LEFT")

                row.add = CreateButton(row, "Add", 70)
                row.add:SetPoint("LEFT", row.text, "RIGHT", 8, 0)

                blacklistPanel.searchRows[index] = row
            end

            row:SetPoint("TOPLEFT", searchScrollChild, "TOPLEFT", 0, -((index - 1) * 28))
            row.text:SetText(mount.name)

            row.add:SetScript("OnClick", function()
                if API().SetMountBlacklisted then
                    API().SetMountBlacklisted(mount.id, true)
                else
                    GetDB().blacklist[mount.id] = true
                end

                RefreshBlacklistPanel()
                Print("Blacklisted " .. mount.name .. ".")
            end)

            row:Show()
        end

        searchScrollChild:SetHeight(math.max(1, #matches * 28))
    end

    if #blacklistedIDs == 0 then
        if not blacklistPanel.emptyText then
            blacklistPanel.emptyText = blacklistedScrollChild:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            blacklistPanel.emptyText:SetPoint("TOPLEFT", blacklistedScrollChild, "TOPLEFT", 0, 0)
            blacklistPanel.emptyText:SetText("No mounts are currently blacklisted.")
        end

        blacklistPanel.emptyText:Show()
        blacklistedScrollChild:SetHeight(24)
        return
    end

    if blacklistPanel.emptyText then
        blacklistPanel.emptyText:Hide()
    end

    for index, mountID in ipairs(blacklistedIDs) do
        local row = blacklistPanel.blacklistRows[index]

        if not row then
            row = CreateFrame("Frame", nil, blacklistedScrollChild)
            row:SetSize(520, 26)

            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 0, 0)
            row.text:SetWidth(390)
            row.text:SetJustifyH("LEFT")

            row.remove = CreateButton(row, "Remove", 80)
            row.remove:SetPoint("LEFT", row.text, "RIGHT", 8, 0)

            blacklistPanel.blacklistRows[index] = row
        end

        local mountName = API().GetMountName and API().GetMountName(mountID) or ("Mount " .. mountID)

        row:SetPoint("TOPLEFT", blacklistedScrollChild, "TOPLEFT", 0, -((index - 1) * 28))
        row.text:SetText(mountName .. " (" .. tostring(mountID) .. ")")

        row.remove:SetScript("OnClick", function()
            if API().SetMountBlacklisted then
                API().SetMountBlacklisted(mountID, false)
            else
                GetDB().blacklist[mountID] = nil
            end

            RefreshBlacklistPanel()
            Print("Removed " .. mountName .. " from blacklist.")
        end)

        row:Show()
    end

    blacklistedScrollChild:SetHeight(math.max(1, #blacklistedIDs * 28))
end

searchBox:SetScript("OnTextChanged", function(self)
    blacklistPanel.searchText = self:GetText() or ""
    RefreshBlacklistPanel()
end)

searchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

clearSearchButton:SetScript("OnClick", function()
    blacklistPanel.searchText = ""
    searchBox:SetText("")
    searchBox:ClearFocus()
    RefreshBlacklistPanel()
end)

addLastButton:SetScript("OnClick", function()
    local lastMountID = API().GetLastMountID and API().GetLastMountID()

    if not lastMountID then
        Print("No last mount found.")
        return
    end

    if API().SetMountBlacklisted then
        API().SetMountBlacklisted(lastMountID, true)
    else
        GetDB().blacklist[lastMountID] = true
    end

    RefreshBlacklistPanel()

    local mountName = API().GetMountName and API().GetMountName(lastMountID) or tostring(lastMountID)
    Print("Blacklisted last mount: " .. mountName .. ".")
end)

clearBlacklistButton:SetScript("OnClick", function()
    GetDB().blacklist = {}
    RefreshBlacklistPanel()
    Print("Blacklist cleared.")
end)

blacklistPanel:SetScript("OnShow", function()
    EnsureMountJournalLoaded()
    blacklistPanel.searchText = searchBox:GetText() or ""
    RefreshBlacklistPanel()
end)

local function RegisterOptions()
    EnsureMountJournalLoaded()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(mainPanel, PANEL_NAME, PANEL_NAME)
        Settings.RegisterCanvasLayoutSubcategory(category, statsPanel, statsPanel.name, statsPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(category, blacklistPanel, blacklistPanel.name, blacklistPanel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(mainPanel)
        InterfaceOptions_AddCategory(statsPanel)
        InterfaceOptions_AddCategory(blacklistPanel)
    end
end

RegisterOptions()