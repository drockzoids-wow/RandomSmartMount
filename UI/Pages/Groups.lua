RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    end
end

local function NormalizeMountName(name)
    if RandomSmartMountAPI and RandomSmartMountAPI.NormalizeMountName then
        return RandomSmartMountAPI.NormalizeMountName(name)
    end

    if not name then return "" end
    name = string.lower(name)
    name = name:gsub("reins of the ", "")
    name = name:gsub("reins of ", "")
    return name
end

local function EnsureMountJournalLoaded()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_Collections")
    end
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
            mounts[#mounts + 1] = {
                id = mountID,
                name = name,
                normalized = NormalizeMountName(name),
            }
        end
    end

    table.sort(mounts, function(a, b)
        return a.name < b.name
    end)

    return mounts
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 26)
    button:SetText(text)
    return button
end

local function GetActiveGroup()
    if RandomSmartMountAPI and RandomSmartMountAPI.GetActiveMountGroup then
        return RandomSmartMountAPI.GetActiveMountGroup()
    end

    return nil
end

local function GetGroupNames()
    if RandomSmartMountAPI and RandomSmartMountAPI.GetMountGroupNames then
        return RandomSmartMountAPI.GetMountGroupNames()
    end

    return {}
end

function RandomSmartMountUI.Pages.CreateGroupsPage(parent)
    local frame = RandomSmartMountUI.CreatePageFrame(parent)
    frame.searchText = ""
    frame.searchRows = {}
    frame.groupRows = {}

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Mount Groups")

    local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    description:SetWidth(520)
    description:SetJustifyH("LEFT")
    description:SetText("Choose an active group to limit normal smart random selection to that group.")

    local activeLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    activeLabel:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
    activeLabel:SetText("Active group:")

    local activeDropdown = CreateFrame("Frame", "RandomSmartMountGroupsActiveDropdown", frame, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(activeDropdown, 220)
    activeDropdown:SetPoint("LEFT", activeLabel, "RIGHT", -8, -2)

    local newGroupBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    newGroupBox:SetSize(180, 24)
    newGroupBox:SetPoint("TOPLEFT", activeLabel, "BOTTOMLEFT", 6, -14)
    newGroupBox:SetAutoFocus(false)

    local createButton = CreateButton(frame, "Create Group", 110)
    createButton:SetPoint("LEFT", newGroupBox, "RIGHT", 12, 0)

    local deleteButton = CreateButton(frame, "Delete Active", 110)
    deleteButton:SetPoint("LEFT", createButton, "RIGHT", 10, 0)

    local searchLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", newGroupBox, "BOTTOMLEFT", -6, -18)
    searchLabel:SetText("Add collected mount:")

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(300, 24)
    searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 6, -8)
    searchBox:SetAutoFocus(false)

    local searchResultsContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    searchResultsContainer:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -6, -10)
    searchResultsContainer:SetSize(500, 40)
    searchResultsContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    searchResultsContainer:SetBackdropColor(0.02, 0.02, 0.02, 1)
    searchResultsContainer:SetBackdropBorderColor(0.8, 0.65, 0.35, 0.75)
    searchResultsContainer:SetFrameStrata("DIALOG")
    searchResultsContainer:SetFrameLevel(80)
    searchResultsContainer:Hide()

    local searchResultsFrame = CreateFrame("Frame", nil, searchResultsContainer)
    searchResultsFrame:SetPoint("TOPLEFT", 8, -8)
    searchResultsFrame:SetSize(480, 72)

    searchResultsFrame.emptyText = searchResultsFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchResultsFrame.emptyText:SetPoint("LEFT", 0, 0)
    searchResultsFrame.emptyText:SetWidth(460)
    searchResultsFrame.emptyText:SetJustifyH("LEFT")
    searchResultsFrame.emptyText:SetText("No matching collected mounts found.")
    searchResultsFrame.emptyText:Hide()

    local groupTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    groupTitle:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -6, -22)
    groupTitle:SetText("Active Group Mounts")

    local groupScrollFrame = CreateFrame("ScrollFrame", "RandomSmartMountGroupsScrollFrame", frame, "UIPanelScrollFrameTemplate")
    groupScrollFrame:SetPoint("TOPLEFT", groupTitle, "BOTTOMLEFT", 0, -8)
    groupScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -44, 18)

    local groupScrollChild = CreateFrame("Frame", nil, groupScrollFrame)
    groupScrollChild:SetSize(440, 1)
    groupScrollFrame:SetScrollChild(groupScrollChild)

    local scrollBar = _G["RandomSmartMountGroupsScrollFrameScrollBar"]

    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", groupScrollFrame, "TOPRIGHT", 6, -16)
        scrollBar:SetPoint("BOTTOMLEFT", groupScrollFrame, "BOTTOMRIGHT", 6, 16)

        scrollBar:SetScript("OnValueChanged", function(_, value)
            groupScrollFrame:SetVerticalScroll(value)
        end)

        scrollBar:SetShown(false)
    end

    groupScrollFrame:EnableMouseWheel(true)
    groupScrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if not scrollBar or not scrollBar:IsShown() then return end

        local current = scrollBar:GetValue()
        local minValue, maxValue = scrollBar:GetMinMaxValues()
        local step = 30

        if delta > 0 then
            scrollBar:SetValue(math.max(current - step, minValue))
        else
            scrollBar:SetValue(math.min(current + step, maxValue))
        end
    end)

    local function SetDropdownText()
        local activeGroup = GetActiveGroup()
        UIDropDownMenu_SetText(activeDropdown, activeGroup or "All Eligible Mounts")
    end

    UIDropDownMenu_Initialize(activeDropdown, function(_, level)
        local allInfo = UIDropDownMenu_CreateInfo()
        allInfo.text = "All Eligible Mounts"
        allInfo.checked = GetActiveGroup() == nil
        allInfo.func = function()
            if RandomSmartMountAPI and RandomSmartMountAPI.SetActiveMountGroup then
                RandomSmartMountAPI.SetActiveMountGroup(nil)
            end
            searchBox:SetText("")
            frame.searchText = ""
            frame.Refresh()
        end
        UIDropDownMenu_AddButton(allInfo, level)

        for _, groupName in ipairs(GetGroupNames()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = groupName
            info.checked = GetActiveGroup() == groupName
            info.func = function()
                if RandomSmartMountAPI and RandomSmartMountAPI.SetActiveMountGroup then
                    RandomSmartMountAPI.SetActiveMountGroup(groupName)
                end
                searchBox:SetText("")
                frame.searchText = ""
                frame.Refresh()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local function GetSearchMatches()
        local activeGroup = GetActiveGroup()
        local query = NormalizeMountName(frame.searchText or "")
        local matches = {}

        if not activeGroup or query == "" then
            return matches
        end

        for _, mount in ipairs(GetCollectedMounts()) do
            local alreadyInGroup =
                RandomSmartMountAPI
                and RandomSmartMountAPI.MountIsInGroup
                and RandomSmartMountAPI.MountIsInGroup(activeGroup, mount.id)

            if not alreadyInGroup and string.find(mount.normalized, query, 1, true) then
                matches[#matches + 1] = mount

                if #matches >= 5 then
                    break
                end
            end
        end

        return matches
    end

    local function RefreshSearchResults()
        local activeGroup = GetActiveGroup()
        local matches = GetSearchMatches()

        for _, row in ipairs(frame.searchRows) do
            row:Hide()
        end

        searchResultsFrame.emptyText:Hide()

        if not activeGroup or (frame.searchText or "") == "" then
            searchResultsContainer:Hide()
            return
        end

        if #matches == 0 then
            searchResultsContainer:SetHeight(40)
            searchResultsFrame:SetHeight(22)
            searchResultsFrame.emptyText:Show()
            searchResultsContainer:Show()
            return
        end

        searchResultsContainer:SetHeight(math.max(40, (#matches * 30) + 18))
        searchResultsFrame:SetHeight(math.max(22, (#matches * 30)))
        searchResultsContainer:Show()

        for index, mount in ipairs(matches) do
            local row = frame.searchRows[index]

            if not row then
                row = CreateFrame("Frame", nil, searchResultsFrame)
                row:SetSize(480, 28)

                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.text:SetPoint("LEFT", 0, 0)
                row.text:SetWidth(365)
                row.text:SetJustifyH("LEFT")

                row.add = CreateButton(row, "Add", 70)
                row.add:SetPoint("LEFT", row.text, "RIGHT", 12, 0)

                frame.searchRows[index] = row
            end

            row:SetPoint("TOPLEFT", searchResultsFrame, "TOPLEFT", 0, -((index - 1) * 30))
            row.text:SetText(mount.name)
            row.add:SetScript("OnClick", function()
                if RandomSmartMountAPI and RandomSmartMountAPI.AddMountToGroup then
                    RandomSmartMountAPI.AddMountToGroup(activeGroup, mount.id)
                end

                searchBox:SetText("")
                frame.searchText = ""
                frame.Refresh()
                Print("Added " .. mount.name .. " to " .. activeGroup .. ".")
            end)
            row:Show()
        end
    end

    local function RefreshGroupRows()
        local activeGroup = GetActiveGroup()
        local mountIDs = {}

        if activeGroup and RandomSmartMountAPI and RandomSmartMountAPI.GetMountGroupMountIDs then
            mountIDs = RandomSmartMountAPI.GetMountGroupMountIDs(activeGroup)
        end

        groupTitle:SetText(activeGroup and ("Mounts in " .. activeGroup) or "No Active Group")

        for _, row in ipairs(frame.groupRows) do
            row:Hide()
        end

        if not activeGroup then
            if not frame.emptyText then
                frame.emptyText = groupScrollChild:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
                frame.emptyText:SetPoint("TOPLEFT", groupScrollChild, "TOPLEFT", 0, 0)
                frame.emptyText:SetText("Choose or create a group to edit its mounts.")
            end
            frame.emptyText:Show()
            groupScrollChild:SetHeight(24)

            groupScrollFrame:SetVerticalScroll(0)
            if scrollBar then
                scrollBar:SetMinMaxValues(0, 0)
                scrollBar:SetValue(0)
                scrollBar:SetShown(false)
            end

            return
        end

        if #mountIDs == 0 then
            if not frame.emptyText then
                frame.emptyText = groupScrollChild:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
                frame.emptyText:SetPoint("TOPLEFT", groupScrollChild, "TOPLEFT", 0, 0)
            end
            frame.emptyText:SetText("This group is empty.")
            frame.emptyText:Show()
            groupScrollChild:SetHeight(24)

            groupScrollFrame:SetVerticalScroll(0)
            if scrollBar then
                scrollBar:SetMinMaxValues(0, 0)
                scrollBar:SetValue(0)
                scrollBar:SetShown(false)
            end

            return
        end

        if frame.emptyText then
            frame.emptyText:Hide()
        end

        for index, mountID in ipairs(mountIDs) do
            local row = frame.groupRows[index]

            if not row then
                row = CreateFrame("Frame", nil, groupScrollChild)
                row:SetSize(440, 28)

                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.text:SetPoint("LEFT", 0, 0)
                row.text:SetWidth(325)
                row.text:SetJustifyH("LEFT")

                row.remove = CreateButton(row, "Remove", 80)
                row.remove:SetPoint("LEFT", row.text, "RIGHT", 12, 0)

                frame.groupRows[index] = row
            end

            local mountName =
                RandomSmartMountAPI
                and RandomSmartMountAPI.GetMountName
                and RandomSmartMountAPI.GetMountName(mountID)
                or ("Mount " .. tostring(mountID))

            row:SetPoint("TOPLEFT", groupScrollChild, "TOPLEFT", 0, -((index - 1) * 30))
            row.text:SetText(mountName)
            row.remove:SetScript("OnClick", function()
                if RandomSmartMountAPI and RandomSmartMountAPI.RemoveMountFromGroup then
                    RandomSmartMountAPI.RemoveMountFromGroup(activeGroup, mountID)
                end

                frame.Refresh()
                Print("Removed " .. mountName .. " from " .. activeGroup .. ".")
            end)
            row:Show()
        end

        groupScrollChild:SetHeight(math.max(1, #mountIDs * 30))
        groupScrollFrame:UpdateScrollChildRect()

        local maxScroll = groupScrollFrame:GetVerticalScrollRange()
        local current = groupScrollFrame:GetVerticalScroll()

        if current > maxScroll then
            groupScrollFrame:SetVerticalScroll(maxScroll)
        end

        if scrollBar then
            scrollBar:SetMinMaxValues(0, maxScroll)
            scrollBar:SetValueStep(30)
            scrollBar:SetValue(groupScrollFrame:GetVerticalScroll())
            scrollBar:SetShown(maxScroll > 0)
        end
    end

    local function Refresh()
        SetDropdownText()
        RefreshSearchResults()
        RefreshGroupRows()
        deleteButton:SetEnabled(GetActiveGroup() ~= nil)
    end

    createButton:SetScript("OnClick", function()
        local groupName = newGroupBox:GetText() or ""

        if RandomSmartMountAPI and RandomSmartMountAPI.CreateMountGroup then
            local ok, createdName = RandomSmartMountAPI.CreateMountGroup(groupName)
            if ok then
                RandomSmartMountAPI.SetActiveMountGroup(createdName)
                newGroupBox:SetText("")
                newGroupBox:ClearFocus()
                Refresh()
                Print("Created mount group: " .. createdName .. ".")
                return
            end
        end

        Print("Enter a group name first.")
    end)

    deleteButton:SetScript("OnClick", function()
        local activeGroup = GetActiveGroup()
        if not activeGroup then return end

        RandomSmartMountUI.ConfirmAction("Delete mount group '" .. activeGroup .. "'?", function()
            if RandomSmartMountAPI and RandomSmartMountAPI.DeleteMountGroup then
                RandomSmartMountAPI.DeleteMountGroup(activeGroup)
            end

            searchBox:SetText("")
            frame.searchText = ""
            Refresh()
            Print("Deleted mount group: " .. activeGroup .. ".")
        end)
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        frame.searchText = self:GetText() or ""
        RefreshSearchResults()
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    RandomSmartMountUI.AddEditBoxPlaceholder(newGroupBox, "New group name")
    RandomSmartMountUI.AddEditBoxPlaceholder(searchBox, "Type a mount name...")

    frame.Refresh = Refresh
    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end
