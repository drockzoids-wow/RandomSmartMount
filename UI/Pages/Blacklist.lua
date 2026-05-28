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
    RandomSmartMountDB.blacklist = RandomSmartMountDB.blacklist or {}
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

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 26)
    button:SetText(text)
    return button
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

local function MountIsBlacklisted(mountID)
    if RandomSmartMountAPI and RandomSmartMountAPI.IsMountBlacklisted then
        return RandomSmartMountAPI.IsMountBlacklisted(mountID)
    end

    local db = GetDB()

    return db.blacklist
        and (
            db.blacklist[mountID] == true
            or db.blacklist[tostring(mountID)] == true
        )
end

function RandomSmartMountUI.Pages.CreateBlacklistPage(parent)

    local frame = CreateFrame("Frame", nil, parent)

    frame:SetPoint("TOPLEFT", 220, -82)
    frame:SetPoint("BOTTOMRIGHT", -30, 30)
    frame:Hide()

    frame.blacklistRows = {}
    frame.searchText = ""

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Blacklist")

    local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Blacklisted mounts will not be selected by the smart random mount system."
    )

    local addLastButton = CreateButton(frame, "Blacklist Last Mount", 160)
    addLastButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)

    local clearBlacklistButton = CreateButton(frame, "Clear Blacklist", 130)
    clearBlacklistButton:SetPoint("LEFT", addLastButton, "RIGHT", 10, 0)

    local searchLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", addLastButton, "BOTTOMLEFT", 0, -22)
    searchLabel:SetText("Search collected mounts:")

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(300, 26)
    searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 6, -8)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")

    local clearSearchButton = CreateButton(frame, "Clear Search", 110)
    clearSearchButton:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)

    local searchHelp = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchHelp:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -6, -8)
    searchHelp:SetWidth(560)
    searchHelp:SetJustifyH("LEFT")
    searchHelp:SetText("Type part of a mount name, then click Add.")

    ------------------------------------------------------------------------
    -- SEARCH RESULTS OVERLAY
    ------------------------------------------------------------------------

    local searchResultsContainer = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    searchResultsContainer:SetPoint(
        "TOPLEFT",
        searchBox,
        "BOTTOMLEFT",
        -6,
        -10
    )

    searchResultsContainer:SetSize(525, 40)

    searchResultsContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
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

    searchResultsContainer:SetBackdropColor(0.02, 0.02, 0.02, 1)
    searchResultsContainer:SetBackdropBorderColor(0.8, 0.65, 0.35, 0.75)

    searchResultsContainer:SetFrameStrata("DIALOG")
    searchResultsContainer:SetFrameLevel(80)

    searchResultsContainer:Hide()

    local searchResultsFrame = CreateFrame(
        "Frame",
        nil,
        searchResultsContainer
    )

    searchResultsFrame:SetPoint("TOPLEFT", 8, -8)
    searchResultsFrame:SetSize(540, 72)

    searchResultsFrame.rows = {}

    ------------------------------------------------------------------------
    -- BLACKLIST SECTION
    ------------------------------------------------------------------------

    local blacklistedTitle = frame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    blacklistedTitle:SetPoint(
        "TOPLEFT",
        searchHelp,
        "BOTTOMLEFT",
        0,
        -10
    )

    blacklistedTitle:SetText("Blacklisted Mounts")

    local blacklistedScrollFrame = CreateFrame(
        "ScrollFrame",
        "RandomSmartMountBlacklistScrollFrame",
        frame,
        "UIPanelScrollFrameTemplate"
    )

    blacklistedScrollFrame:SetPoint(
        "TOPLEFT",
        blacklistedTitle,
        "BOTTOMLEFT",
        0,
        -8
    )

    blacklistedScrollFrame:SetSize(540, 255)

    local blacklistedScrollChild = CreateFrame(
        "Frame",
        nil,
        blacklistedScrollFrame
    )

    blacklistedScrollChild:SetSize(520, 1)

    blacklistedScrollFrame:SetScrollChild(blacklistedScrollChild)

    local scrollBar = _G["RandomSmartMountBlacklistScrollFrameScrollBar"]

	if scrollBar then
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPLEFT", blacklistedScrollFrame, "TOPRIGHT", 8, -16)
		scrollBar:SetPoint("BOTTOMLEFT", blacklistedScrollFrame, "BOTTOMRIGHT", 8, 16)

		scrollBar:SetScript("OnValueChanged", function(self, value)
			blacklistedScrollFrame:SetVerticalScroll(value)
		end)
	end

	blacklistedScrollFrame:EnableMouseWheel(true)
	blacklistedScrollFrame:SetScript("OnMouseWheel", function(self, delta)
		if not scrollBar then return end

		local current = scrollBar:GetValue()
		local minValue, maxValue = scrollBar:GetMinMaxValues()
		local step = 30

		if delta > 0 then
			scrollBar:SetValue(math.max(current - step, minValue))
		else
			scrollBar:SetValue(math.min(current + step, maxValue))
		end
	end)

    ------------------------------------------------------------------------
    -- SEARCH MATCHES
    ------------------------------------------------------------------------

    local function GetSearchMatches()

        EnsureMountJournalLoaded()

        local query = NormalizeMountName(frame.searchText or "")
        local matches = {}

        if query == "" then
            return matches
        end

        for _, mount in ipairs(GetCollectedMounts()) do

            if not MountIsBlacklisted(mount.id)
                and string.find(
                    mount.normalized,
                    query,
                    1,
                    true
                )
            then

                table.insert(matches, mount)

                if #matches >= 5 then
                    break
                end
            end
        end

        return matches
    end

    ------------------------------------------------------------------------
    -- REFRESH
    ------------------------------------------------------------------------

    local function Refresh()

        EnsureMountJournalLoaded()

        local matches = GetSearchMatches()
        local blacklistedIDs = {}

        if RandomSmartMountAPI
            and RandomSmartMountAPI.GetBlacklistedMountIDs
        then
            blacklistedIDs =
                RandomSmartMountAPI.GetBlacklistedMountIDs()
        end

        --------------------------------------------------------------------
        -- CLEAR OLD ROWS
        --------------------------------------------------------------------

        for _, row in ipairs(searchResultsFrame.rows) do
            row:Hide()
        end

        for _, row in ipairs(frame.blacklistRows) do
            row:Hide()
        end

        --------------------------------------------------------------------
        -- SEARCH RESULTS
        --------------------------------------------------------------------

        if (frame.searchText or "") == "" then

            searchResultsContainer:Hide()

        else

            local resultCount = math.min(#matches, 5)

            local containerHeight =
                math.max(40, (resultCount * 30) + 18)

            searchResultsContainer:SetHeight(containerHeight)
            searchResultsFrame:SetHeight(containerHeight - 20)

            if resultCount == 0 then

                searchResultsContainer:Hide()

            else

                searchResultsContainer:Show()

                for index = 1, resultCount do

                    local mount = matches[index]
                    local row = searchResultsFrame.rows[index]

                    if not row then

                        row = CreateFrame(
                            "Frame",
                            nil,
                            searchResultsFrame
                        )

                        row:SetSize(540, 28)

                        row.text = row:CreateFontString(
                            nil,
                            "ARTWORK",
                            "GameFontHighlight"
                        )

                        row.text:SetPoint("LEFT", 0, 0)
                        row.text:SetWidth(430)
                        row.text:SetJustifyH("LEFT")

                        row.add = CreateButton(row, "Add", 70)

                        row.add:SetPoint(
                            "LEFT",
                            row.text,
                            "RIGHT",
                            8,
                            0
                        )

                        searchResultsFrame.rows[index] = row
                    end

                    row:SetPoint(
                        "TOPLEFT",
                        searchResultsFrame,
                        "TOPLEFT",
                        0,
                        -((index - 1) * 30)
                    )

                    row.text:SetText(mount.name)

                    row.add:SetScript("OnClick", function()

                        if RandomSmartMountAPI
                            and RandomSmartMountAPI.SetMountBlacklisted
                        then
                            RandomSmartMountAPI.SetMountBlacklisted(
                                mount.id,
                                true
                            )
                        else
                            GetDB().blacklist[mount.id] = true
                        end

                        searchBox:SetText("")
                        searchBox:ClearFocus()

                        frame.searchText = ""

                        Refresh()

                        Print("Blacklisted " .. mount.name .. ".")
                    end)

                    row:Show()
                end
            end
        end

        --------------------------------------------------------------------
        -- EMPTY BLACKLIST
        --------------------------------------------------------------------

        if #blacklistedIDs == 0 then

            if not frame.blacklistEmptyText then

                frame.blacklistEmptyText =
                    blacklistedScrollChild:CreateFontString(
                        nil,
                        "ARTWORK",
                        "GameFontDisableSmall"
                    )

                frame.blacklistEmptyText:SetPoint(
                    "TOPLEFT",
                    blacklistedScrollChild,
                    "TOPLEFT",
                    0,
                    0
                )

                frame.blacklistEmptyText:SetText(
                    "No mounts are currently blacklisted."
                )
            end

            frame.blacklistEmptyText:Show()

            blacklistedScrollChild:SetHeight(24)

            return
        end

        if frame.blacklistEmptyText then
            frame.blacklistEmptyText:Hide()
        end

        --------------------------------------------------------------------
        -- BLACKLIST ROWS
        --------------------------------------------------------------------

        for index, mountID in ipairs(blacklistedIDs) do

            local row = frame.blacklistRows[index]

            if not row then

                row = CreateFrame(
                    "Frame",
                    nil,
                    blacklistedScrollChild
                )

                row:SetSize(540, 28)

                row.text = row:CreateFontString(
                    nil,
                    "ARTWORK",
                    "GameFontHighlight"
                )

                row.text:SetPoint("LEFT", 0, 0)
                row.text:SetWidth(430)
                row.text:SetJustifyH("LEFT")

                row.remove = CreateButton(row, "Remove", 80)

                row.remove:SetPoint(
                    "LEFT",
                    row.text,
                    "RIGHT",
                    8,
                    0
                )

                frame.blacklistRows[index] = row
            end

            local mountName =
                RandomSmartMountAPI
                and RandomSmartMountAPI.GetMountName
                and RandomSmartMountAPI.GetMountName(mountID)
                or ("Mount " .. tostring(mountID))

            row:SetPoint(
                "TOPLEFT",
                blacklistedScrollChild,
                "TOPLEFT",
                0,
                -((index - 1) * 30)
            )

            row.text:SetText(
                mountName .. " (" .. tostring(mountID) .. ")"
            )

            row.remove:SetScript("OnClick", function()

                if RandomSmartMountAPI
                    and RandomSmartMountAPI.SetMountBlacklisted
                then
                    RandomSmartMountAPI.SetMountBlacklisted(
                        mountID,
                        false
                    )
                else
                    GetDB().blacklist[mountID] = nil
                end

                Refresh()

                Print(
                    "Removed "
                    .. mountName
                    .. " from blacklist."
                )
            end)

            row:Show()
        end

        --------------------------------------------------------------------
        -- SCROLL HEIGHT
        --------------------------------------------------------------------

        blacklistedScrollChild:SetHeight(
            math.max(1, #blacklistedIDs * 30)
        )

        blacklistedScrollFrame:UpdateScrollChildRect()

        local maxScroll =
            blacklistedScrollFrame:GetVerticalScrollRange()

        local current =
            blacklistedScrollFrame:GetVerticalScroll()

        if current > maxScroll then
            blacklistedScrollFrame:SetVerticalScroll(maxScroll)
        end

		if scrollBar then
			scrollBar:SetMinMaxValues(0, maxScroll)
			scrollBar:SetValueStep(30)
			scrollBar:SetValue(blacklistedScrollFrame:GetVerticalScroll())
			scrollBar:SetShown(maxScroll > 0)
		end
    end

    ------------------------------------------------------------------------
    -- EVENTS
    ------------------------------------------------------------------------

    searchBox:SetScript("OnTextChanged", function(self)
        frame.searchText = self:GetText() or ""
        Refresh()
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    clearSearchButton:SetScript("OnClick", function()

        frame.searchText = ""

        searchBox:SetText("")
        searchBox:ClearFocus()

        Refresh()
    end)

    addLastButton:SetScript("OnClick", function()

        local lastMountID =
            RandomSmartMountAPI
            and RandomSmartMountAPI.GetLastMountID
            and RandomSmartMountAPI.GetLastMountID()

        if not lastMountID then
            Print("No last mount found.")
            return
        end

        if RandomSmartMountAPI
            and RandomSmartMountAPI.SetMountBlacklisted
        then
            RandomSmartMountAPI.SetMountBlacklisted(
                lastMountID,
                true
            )
        else
            GetDB().blacklist[lastMountID] = true
        end

        local mountName =
            RandomSmartMountAPI
            and RandomSmartMountAPI.GetMountName
            and RandomSmartMountAPI.GetMountName(lastMountID)
            or tostring(lastMountID)

        Refresh()

        Print(
            "Blacklisted last mount: "
            .. mountName
            .. "."
        )
    end)

    clearBlacklistButton:SetScript("OnClick", function()

        GetDB().blacklist = {}

        Refresh()

        Print("Blacklist cleared.")
    end)

    frame.Refresh = Refresh

    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI
    and RandomSmartMountUI.RefreshPages
then
    RandomSmartMountUI.RefreshPages()
end