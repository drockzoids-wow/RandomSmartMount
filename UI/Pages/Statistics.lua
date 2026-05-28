RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

function RandomSmartMountUI.Pages.CreateStatisticsPage(parent)
    local frame = CreateFrame("Frame", nil, parent)

    frame:SetPoint("TOPLEFT", 220, -82)
    frame:SetPoint("BOTTOMRIGHT", -30, 30)
    frame:Hide()

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

    local listTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -20)
    listTitle:SetText("Most Used Mounts")

    local rows = {}

    local function Refresh()
        local total = RandomSmartMountAPI.GetTotalMountUses and RandomSmartMountAPI.GetTotalMountUses() or 0
        local entries = RandomSmartMountAPI.GetSortedUsageMounts and RandomSmartMountAPI.GetSortedUsageMounts(true) or {}

        totalText:SetText("Total tracked mount uses: " .. tostring(total))

        for _, row in ipairs(rows) do
            row:Hide()
        end

        local maxRows = math.min(15, #entries)

        for i = 1, maxRows do
            local entry = entries[i]
            local row = rows[i]

            if not row then
                row = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row:SetWidth(560)
                row:SetJustifyH("LEFT")
                rows[i] = row
            end

            row:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -10 - ((i - 1) * 22))
            row:SetText(i .. ". " .. entry.name .. " - " .. tostring(entry.count))
            row:Show()
        end
    end

    resetButton:SetScript("OnClick", function()
        if RandomSmartMountAPI.ClearMountUsage then
            RandomSmartMountAPI.ClearMountUsage()
        end

        Refresh()
        Print("Mount usage history reset.")
    end)

    frame.Refresh = Refresh
    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end