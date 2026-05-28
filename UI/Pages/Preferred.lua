RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

local function GetDB()
    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.preferredMount = RandomSmartMountDB.preferredMount or nil
    return RandomSmartMountDB
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

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 26)
    button:SetText(text)
    return button
end

function RandomSmartMountUI.Pages.CreatePreferredPage(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", 285, -140)
    frame:SetPoint("BOTTOMRIGHT", -30, 30)
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Preferred Smart Mount")

    local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    description:SetWidth(480)
    description:SetJustifyH("LEFT")
    description:SetText("Choose one mount to prefer above normal random selection. If unavailable, normal smart random behavior is used.")

    local currentText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    currentText:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
    currentText:SetWidth(560)
    currentText:SetJustifyH("LEFT")

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(300, 26)
    searchBox:SetPoint("TOPLEFT", currentText, "BOTTOMLEFT", 6, -12)
    searchBox:SetAutoFocus(false)

    local resetButton = CreateButton(frame, "Reset Default", 130)
    resetButton:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)

    local resultsContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    resultsContainer:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -6, -12)
    resultsContainer:SetSize(450, 40)
	resultsContainer:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		tile = true,
		tileSize = 16,
		insets = {
			left = 0,
			right = 0,
			top = 0,
			bottom = 0
		}
	})
    resultsContainer:SetBackdropColor(0, 0, 0, 0.55)
    resultsContainer:SetFrameStrata("DIALOG")
    resultsContainer:SetFrameLevel(50)
    resultsContainer:Hide()

    local resultsFrame = CreateFrame("Frame", nil, resultsContainer)
    resultsFrame:SetPoint("TOPLEFT", 8, -8)
    resultsFrame:SetSize(480, 72)
    resultsFrame.rows = {}

    local function Refresh()
        local db = GetDB()
        local query = NormalizeMountName(searchBox:GetText() or "")

        currentText:SetText("Current Preferred: " .. (db.preferredMount or "Default Random Behavior"))

        for _, row in ipairs(resultsFrame.rows) do
            row:Hide()
        end

        if query == "" then
            resultsContainer:Hide()
            return
        end

        local matches = {}

        for _, mount in ipairs(GetCollectedMounts()) do
            if string.find(mount.normalized, query, 1, true) then
                table.insert(matches, mount)

                if #matches >= 5 then
                    break
                end
            end
        end

        local resultCount = #matches
        local containerHeight = math.max(40, (resultCount * 28) + 18)

        resultsContainer:SetHeight(containerHeight)
        resultsFrame:SetHeight(containerHeight - 20)
        resultsContainer:Show()

        if resultCount == 0 then
            return
        end

        for index, mount in ipairs(matches) do
            local row = resultsFrame.rows[index]

            if not row then
                row = CreateFrame("Frame", nil, resultsFrame)
                row:SetSize(470, 26)

                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.text:SetPoint("LEFT", 0, 0)
                row.text:SetWidth(360)
                row.text:SetJustifyH("LEFT")

                row.use = CreateButton(row, "Use", 70)
                row.use:SetPoint("LEFT", row.text, "RIGHT", 8, 0)

                resultsFrame.rows[index] = row
            end

            row:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 0, -((index - 1) * 28))
            row.text:SetText(mount.name)

            row.use:SetScript("OnClick", function()
                db.preferredMount = mount.name
                searchBox:SetText("")
                searchBox:ClearFocus()
                Refresh()
                Print("Preferred Smart Mount set to " .. mount.name .. ".")
            end)

            row:Show()
        end
    end

    searchBox:SetScript("OnTextChanged", Refresh)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    resetButton:SetScript("OnClick", function()
        local db = GetDB()
        db.preferredMount = nil
        searchBox:SetText("")
        searchBox:ClearFocus()
        Refresh()
        Print("Preferred Smart Mount reset to Default Random Behavior.")
    end)

    frame.Refresh = Refresh
    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end