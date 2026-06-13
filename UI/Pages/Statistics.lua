RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local STATS_COLUMN_WIDTH = 252
local STATS_SECOND_COLUMN_X = 268
local STATS_MAX_TEXT_LENGTH = 46

local VIEW_ORDER = {
    {
        key = "most",
        label = "Most Used",
        title = "Most Used Mounts",
        emptyText = "No mount usage recorded yet.",
    },
    {
        key = "recent",
        label = "Recent",
        title = "Recently Used Mounts",
        emptyText = "No recent mounts recorded yet.",
    },
    {
        key = "least",
        label = "Least Used",
        title = "Least Used Mounts",
        emptyText = "No mount usage recorded yet.",
    },
}

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    end
end

local function GetViewInfo(viewKey)
    for _, viewInfo in ipairs(VIEW_ORDER) do
        if viewInfo.key == viewKey then
            return viewInfo
        end
    end

    return VIEW_ORDER[1]
end

local function GetUsageRows(viewKey)
    if viewKey == "recent" then
        local rows = {}
        local recentIDs =
            RandomSmartMountAPI
            and RandomSmartMountAPI.GetRecentMountIDs
            and RandomSmartMountAPI.GetRecentMountIDs(20)
            or {}

        for _, mountID in ipairs(recentIDs) do
            local name =
                RandomSmartMountAPI
                and RandomSmartMountAPI.GetMountName
                and RandomSmartMountAPI.GetMountName(mountID)
                or tostring(mountID)

            local count =
                RandomSmartMountAPI
                and RandomSmartMountAPI.GetMountUsage
                and RandomSmartMountAPI.GetMountUsage(mountID)
                or 0

            rows[#rows + 1] = {
                name = name,
                count = count,
            }
        end

        return rows
    end

    return
        RandomSmartMountAPI
        and RandomSmartMountAPI.GetSortedUsageMounts
        and RandomSmartMountAPI.GetSortedUsageMounts(viewKey ~= "least")
        or {}
end

local function FormatRowText(index, entry)
    local text = index .. ". " .. tostring(entry.name or "Unknown Mount") .. " - " .. tostring(entry.count or 0)

    if string.len(text) > STATS_MAX_TEXT_LENGTH then
        text = string.sub(text, 1, STATS_MAX_TEXT_LENGTH - 3) .. "..."
    end

    return text
end

function RandomSmartMountUI.Pages.CreateStatisticsPage(parent)
    local frame = RandomSmartMountUI.CreatePageFrame(parent)
    local activeView = "most"

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Statistics")

    local totalText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    totalText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    totalText:SetJustifyH("LEFT")

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetSize(180, 28)
    resetButton:SetPoint("TOPLEFT", totalText, "BOTTOMLEFT", 0, -12)
    resetButton:SetText("Reset Usage History")

    local viewBar = CreateFrame("Frame", nil, frame)
    viewBar:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -14)
    viewBar:SetSize(330, 26)

    local viewButtons = {}
    local Refresh

    for index, viewInfo in ipairs(VIEW_ORDER) do
        local button = CreateFrame("Button", nil, viewBar, "UIPanelButtonTemplate")
        button:SetSize(98, 24)
        button:SetPoint("LEFT", viewBar, "LEFT", (index - 1) * 108, 0)
        button:SetText(viewInfo.label)
        button:SetScript("OnClick", function()
            activeView = viewInfo.key
            Refresh()
        end)

        viewButtons[viewInfo.key] = button
    end

    local listTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", viewBar, "BOTTOMLEFT", 0, -18)

    local emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -12)
    emptyText:SetWidth(500)
    emptyText:SetJustifyH("LEFT")
    emptyText:Hide()

    local rows = {}

    local function UpdateViewButtons()
        for _, viewInfo in ipairs(VIEW_ORDER) do
            local button = viewButtons[viewInfo.key]
            local fontString = button and button:GetFontString()

            if button then
                if activeView == viewInfo.key then
                    button:LockHighlight()
                    if fontString then
                        fontString:SetTextColor(1, 0.82, 0)
                    end
                else
                    button:UnlockHighlight()
                    if fontString then
                        fontString:SetTextColor(1, 1, 1)
                    end
                end
            end
        end
    end

    Refresh = function()
        local total =
            RandomSmartMountAPI
            and RandomSmartMountAPI.GetTotalMountUses
            and RandomSmartMountAPI.GetTotalMountUses()
            or 0

        local viewInfo = GetViewInfo(activeView)
        local entries = GetUsageRows(activeView)
        local maxRows = math.min(20, #entries)

        totalText:SetText("Total tracked mount uses: " .. tostring(total))
        listTitle:SetText(viewInfo.title)
        emptyText:Hide()
        resetButton:SetEnabled(total > 0)
        UpdateViewButtons()

        for _, row in ipairs(rows) do
            row:Hide()
        end

        if maxRows == 0 then
            emptyText:SetText(viewInfo.emptyText)
            emptyText:Show()
            return
        end

        for index = 1, maxRows do
            local entry = entries[index]
            local row = rows[index]

            if not row then
                row = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row:SetWidth(STATS_COLUMN_WIDTH)
                row:SetJustifyH("LEFT")
                row:SetMaxLines(1)
                row:SetWordWrap(false)
                rows[index] = row
            end

            local column = index <= 10 and 1 or 2
            local rowIndex = column == 1 and index or index - 10
            local xOffset = column == 1 and 0 or STATS_SECOND_COLUMN_X

            row:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", xOffset, -10 - ((rowIndex - 1) * 22))
            row:SetText(FormatRowText(index, entry))
            row:Show()
        end
    end

    resetButton:SetScript("OnClick", function()
        RandomSmartMountUI.ConfirmAction("Reset all mount usage history?", function()
            if RandomSmartMountAPI and RandomSmartMountAPI.ClearMountUsage then
                RandomSmartMountAPI.ClearMountUsage()
            end

            Refresh()
            Print("Mount usage history reset.")
        end)
    end)

    frame.Refresh = Refresh
    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end
