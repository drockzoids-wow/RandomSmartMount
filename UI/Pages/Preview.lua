RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local DETAIL_COLUMN_WIDTH = 330
local RECENT_COLUMN_X = 358
local RECENT_COLUMN_WIDTH = 160
local DETAIL_ROW_HEIGHT = 18
local MAX_DETAIL_ROWS = 14
local RECENT_MOUNT_LIMIT = 5
local RECENT_ROW_HEIGHT = 18

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 26)
    button:SetText(text)
    return button
end

local function FormatDetailLine(text)
    text = text or ""
    text = text:gsub("^Recent cooldown:", "Recent CD:")
    return text
end

function RandomSmartMountUI.Pages.CreatePreviewPage(parent)
    local frame = RandomSmartMountUI.CreatePageFrame(parent)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Pick Preview")

    local refreshButton = CreateButton(frame, "Refresh", 100)
    refreshButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -2)

    local summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    summary:SetWidth(520)
    summary:SetJustifyH("LEFT")

    local detailTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -20)
    detailTitle:SetText("Decision Details")

    local rows = {}

    local recentTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    recentTitle:SetPoint("TOPLEFT", detailTitle, "TOPLEFT", RECENT_COLUMN_X, 0)
    recentTitle:SetText("Recent Mounts (last 5)")

    local recentRows = {}
    local recentEmptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    recentEmptyText:SetPoint("TOPLEFT", recentTitle, "BOTTOMLEFT", 0, -10)
    recentEmptyText:SetWidth(RECENT_COLUMN_WIDTH)
    recentEmptyText:SetJustifyH("LEFT")
    recentEmptyText:SetText("None recorded yet.")

    local function SetRecentRow(index, text)
        local row = recentRows[index]

        if not row then
            row = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row:SetWidth(RECENT_COLUMN_WIDTH)
            row:SetJustifyH("LEFT")
            row:SetMaxLines(1)
            row:SetWordWrap(false)
            recentRows[index] = row
        end

        row:SetPoint("TOPLEFT", recentTitle, "BOTTOMLEFT", 0, -10 - ((index - 1) * RECENT_ROW_HEIGHT))
        row:SetText(text)
        row:Show()
    end

    local function SetRow(index, text)
        local row = rows[index]

        if not row then
            row = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row:SetWidth(DETAIL_COLUMN_WIDTH)
            row:SetJustifyH("LEFT")
            row:SetMaxLines(1)
            row:SetWordWrap(false)
            rows[index] = row
        end

        row:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -10 - ((index - 1) * DETAIL_ROW_HEIGHT))
        row:SetText(FormatDetailLine(text))
        row:Show()
    end

    local function Refresh()
        local preview =
            RandomSmartMountAPI
            and RandomSmartMountAPI.GetSmartMountPreview
            and RandomSmartMountAPI.GetSmartMountPreview()
            or { summary = "Preview unavailable.", lines = {} }

        summary:SetText(preview.summary or "Preview unavailable.")

        for _, row in ipairs(rows) do
            row:Hide()
        end

        for index, line in ipairs(preview.lines or {}) do
            if index > MAX_DETAIL_ROWS then break end
            SetRow(index, line)
        end

        for _, row in ipairs(recentRows) do
            row:Hide()
        end

        recentEmptyText:Hide()

        local recentIDs =
            RandomSmartMountAPI
            and RandomSmartMountAPI.GetRecentMountIDs
            and RandomSmartMountAPI.GetRecentMountIDs(RECENT_MOUNT_LIMIT)
            or {}

        for index, mountID in ipairs(recentIDs) do
            if index > RECENT_MOUNT_LIMIT then break end

            local mountName =
                RandomSmartMountAPI
                and RandomSmartMountAPI.GetMountName
                and RandomSmartMountAPI.GetMountName(mountID)
                or tostring(mountID)

            SetRecentRow(index, mountName)
        end

        if #recentIDs == 0 then
            recentEmptyText:Show()
        end
    end

    refreshButton:SetScript("OnClick", function()
        Refresh()
        Print("Pick preview refreshed.")
    end)

    local function RefreshIfVisible()
        if not frame:IsShown() then return end

        Refresh()

        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                if frame:IsShown() then
                    Refresh()
                end
            end)
        end
    end

    local lastMountedState = IsMounted and IsMounted() or false

    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and unit ~= "player" then
            return
        end

        local mountedState = IsMounted and IsMounted() or false

        if event == "UNIT_AURA" and mountedState == lastMountedState then
            return
        end

        lastMountedState = mountedState
        RefreshIfVisible()
    end)

    RandomSmartMountUI.RefreshPreview = RefreshIfVisible

    frame.Refresh = Refresh
    frame:SetScript("OnShow", function()
        lastMountedState = IsMounted and IsMounted() or false
        Refresh()
    end)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end
