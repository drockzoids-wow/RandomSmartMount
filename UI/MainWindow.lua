RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local pages = {}
local buttons = {}

local WINDOW_WIDTH = 900
local WINDOW_HEIGHT = 640
local SIDEBAR_X = 48
local SIDEBAR_TOP = -176
local SIDEBAR_BUTTON_WIDTH = 176
local SIDEBAR_BUTTON_HEIGHT = 36
local SIDEBAR_BUTTON_GAP = 42
local CONTENT_LEFT = 276
local CONTENT_TOP = -168
local CONTENT_RIGHT = -58
local CONTENT_BOTTOM = 52

RandomSmartMountUI.Layout = {
    contentLeft = CONTENT_LEFT,
    contentTop = CONTENT_TOP,
    contentRight = CONTENT_RIGHT,
    contentBottom = CONTENT_BOTTOM,
}

function RandomSmartMountUI.CreatePageFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", CONTENT_LEFT + 20, CONTENT_TOP - 20)
    frame:SetPoint("BOTTOMRIGHT", CONTENT_RIGHT - 14, CONTENT_BOTTOM + 14)
    frame:Hide()
    return frame
end

function RandomSmartMountUI.ConfirmAction(message, onAccept)
    if type(onAccept) ~= "function" then return end

    if not StaticPopupDialogs or not StaticPopup_Show then
        onAccept()
        return
    end

    local popupKey = "RANDOM_SMART_MOUNT_CONFIRM_ACTION"

    StaticPopupDialogs[popupKey] = StaticPopupDialogs[popupKey] or {
        text = "%s",
        button1 = YES or "Yes",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            if data and data.onAccept then
                data.onAccept()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show(popupKey, message, nil, { onAccept = onAccept })
end

function RandomSmartMountUI.AddEditBoxPlaceholder(editBox, text)
    if not editBox or editBox.placeholder then return end

    local placeholder = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", editBox, "LEFT", 6, 0)
    placeholder:SetPoint("RIGHT", editBox, "RIGHT", -6, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetText(text)

    local function UpdatePlaceholder(self)
        local value = self:GetText() or ""

        if value == "" and not self:HasFocus() then
            placeholder:Show()
        else
            placeholder:Hide()
        end
    end

    editBox.placeholder = placeholder
    editBox:HookScript("OnTextChanged", UpdatePlaceholder)
    editBox:HookScript("OnEditFocusGained", UpdatePlaceholder)
    editBox:HookScript("OnEditFocusLost", UpdatePlaceholder)
    UpdatePlaceholder(editBox)

    return placeholder
end

local PAGE_ORDER = {
    { key = "general", label = "General", icon = "general" },
    { key = "groups", label = "Groups", icon = "preferred" },
    { key = "preferred", label = "Preferred", icon = "preferred" },
    { key = "service", label = "Service", icon = "service" },
    { key = "blacklist", label = "Blacklist", icon = "blacklist" },
    { key = "statistics", label = "Statistics", icon = "statistics" },
    { key = "preview", label = "Preview", icon = "statistics" },
    { key = "profiles", label = "Profiles", icon = "general" },
}

local function CreateFallbackPanel(parent, name, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", CONTENT_LEFT + 16, CONTENT_TOP - 18)
    frame:SetPoint("BOTTOMRIGHT", CONTENT_RIGHT - 16, CONTENT_BOTTOM + 16)
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(name)

    local body = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    body:SetWidth(560)
    body:SetJustifyH("LEFT")
    body:SetText(text or "This page is ready for controls.")

    frame.body = body
    return frame
end

local function CreatePage(parent, key)
    if key == "general"
        and RandomSmartMountUI.Pages
        and RandomSmartMountUI.Pages.CreateGeneralPage then
        local page = RandomSmartMountUI.Pages.CreateGeneralPage(parent)
        page:Hide()
        return page
    end

    if key == "preferred"
        and RandomSmartMountUI.Pages
        and RandomSmartMountUI.Pages.CreatePreferredPage then
        local page = RandomSmartMountUI.Pages.CreatePreferredPage(parent)
        page:Hide()
        return page
    end

    if key == "groups"
        and RandomSmartMountUI.Pages
        and RandomSmartMountUI.Pages.CreateGroupsPage then
        local page = RandomSmartMountUI.Pages.CreateGroupsPage(parent)
        page:Hide()
        return page
    end

    if key == "profiles"
        and RandomSmartMountUI.Pages
        and RandomSmartMountUI.Pages.CreateProfilesPage then
        local page = RandomSmartMountUI.Pages.CreateProfilesPage(parent)
        page:Hide()
        return page
    end

    if key == "service"
        and RandomSmartMountUI.Pages
        and RandomSmartMountUI.Pages.CreateServiceMountsPage then
        local page = RandomSmartMountUI.Pages.CreateServiceMountsPage(parent)
        page:Hide()
        return page
    end

    if key == "blacklist"
        and RandomSmartMountUI.Pages
        and RandomSmartMountUI.Pages.CreateBlacklistPage then
        local page = RandomSmartMountUI.Pages.CreateBlacklistPage(parent)
        page:Hide()
        return page
    end

    if key == "statistics"
        and RandomSmartMountUI.Pages
        and RandomSmartMountUI.Pages.CreateStatisticsPage then
        local page = RandomSmartMountUI.Pages.CreateStatisticsPage(parent)
        page:Hide()
        return page
    end

    if key == "preview"
        and RandomSmartMountUI.Pages
        and RandomSmartMountUI.Pages.CreatePreviewPage then
        local page = RandomSmartMountUI.Pages.CreatePreviewPage(parent)
        page:Hide()
        return page
    end

    if key == "general" then
        return CreateFallbackPanel(parent, "General", "General settings will live here.\n\nPlanned:\n- Druid options\n- Dracthyr options\n- Randomness behavior\n- Minimap button toggle")
    elseif key == "groups" then
        return CreateFallbackPanel(parent, "Groups", "Mount group controls will live here.")
    elseif key == "profiles" then
        return CreateFallbackPanel(parent, "Profiles", "Profile controls will live here.")
    elseif key == "preferred" then
        return CreateFallbackPanel(parent, "Preferred Mount", "Preferred Smart Mount controls will live here.")
    elseif key == "service" then
        return CreateFallbackPanel(parent, "Service Mounts", "Vendor, Auction House, and Ride-Along mount preferences will live here.")
    elseif key == "blacklist" then
        return CreateFallbackPanel(parent, "Blacklist", "Blacklist search and remove controls will live here.")
    elseif key == "preview" then
        return CreateFallbackPanel(parent, "Preview", "Smart pick preview details will live here.")
    elseif key == "statistics" then
        return CreateFallbackPanel(parent, "Statistics", "Mount usage statistics will live here.")
    end

    return CreateFallbackPanel(parent, key, "This page is ready for controls.")
end

local function ShowPage(name)
    RandomSmartMountUI.currentPage = name

    for pageName, page in pairs(pages) do
        page:SetShown(pageName == name)

        if pageName == name and page.Refresh then
            page:Refresh()
        end
    end

    for pageName, button in pairs(buttons) do
        if pageName == name then
            button.bg:SetTexture(button.selectedTexture)
            button.text:SetTextColor(1, 0.82, 0)
        else
            button.bg:SetTexture(button.normalTexture)
            button.text:SetTextColor(1, 1, 1)
        end
    end
end

local function CreateSidebarButton(parent, text, pageName, index, iconName)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SIDEBAR_BUTTON_WIDTH, SIDEBAR_BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", SIDEBAR_X, SIDEBAR_TOP - ((index - 1) * SIDEBAR_BUTTON_GAP))

    local theme = RandomSmartMountUI.Theme

    button.normalTexture = theme and theme.GetButtonTexture and theme.GetButtonTexture("normal") or "Interface\\Buttons\\UI-Panel-Button-Up"
    button.hoverTexture = theme and theme.GetButtonTexture and theme.GetButtonTexture("hover") or "Interface\\Buttons\\UI-Panel-Button-Highlight"
    button.selectedTexture = theme and theme.GetButtonTexture and theme.GetButtonTexture("selected") or "Interface\\Buttons\\UI-Panel-Button-Down"

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetTexture(button.normalTexture)

    button.hover = button:CreateTexture(nil, "HIGHLIGHT")
    button.hover:SetAllPoints()
    button.hover:SetTexture(button.hoverTexture)
    button.hover:SetBlendMode("ADD")

    if iconName and theme and theme.GetIcon then
        button.icon = button:CreateTexture(nil, "OVERLAY")
        button.icon:SetSize(24, 24)
        button.icon:SetPoint("LEFT", 10, 0)
        button.icon:SetTexture(theme.GetIcon(iconName))
    end

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("LEFT", 44, 0)
    button.text:SetText(text)

    button:SetScript("OnClick", function()
        ShowPage(pageName)
    end)

    buttons[pageName] = button
    return button
end

local function RebuildPages()
    local frame = RandomSmartMountUI.frame
    if not frame then return end

    for key, oldPage in pairs(pages) do
        oldPage:Hide()
        oldPage:SetParent(nil)
    end

    pages = {}

    for _, pageInfo in ipairs(PAGE_ORDER) do
        pages[pageInfo.key] = CreatePage(frame, pageInfo.key)
    end

    ShowPage(RandomSmartMountUI.currentPage or "general")
end

function RandomSmartMountUI.RefreshPages()
    RebuildPages()
end

local function CreateMainWindow()
    if RandomSmartMountUI.frame then
        return RandomSmartMountUI.frame
    end

    local frame = CreateFrame("Frame", "RandomSmartMountMainWindow", UIParent, "BasicFrameTemplateWithInset")
    table.insert(UISpecialFrames, "RandomSmartMountMainWindow")

    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")

    frame.customBg = frame:CreateTexture(nil, "BORDER")
    frame.customBg:SetDrawLayer("BORDER", -7)

    local bgPath = "Interface\\DialogFrame\\UI-DialogBox-Background"

    if RandomSmartMountUI.Theme and RandomSmartMountUI.Theme.GetWindowBackground then
        bgPath = RandomSmartMountUI.Theme.GetWindowBackground()
    end

    frame.customBg:SetTexture(bgPath)
    frame.customBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
    frame.customBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.customBg:SetAlpha(0.95)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.TitleText:Hide()

    local contentPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT - 10, CONTENT_TOP)
    contentPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", CONTENT_RIGHT, CONTENT_BOTTOM)
    contentPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    contentPanel:SetBackdropColor(0.02, 0.02, 0.02, 0.45)
    contentPanel:SetBackdropBorderColor(0.85, 0.65, 0.35, 0.45)
    frame.contentPanel = contentPanel

    local navTitle = frame:CreateFontString(nil, "ARTWORK")
    navTitle:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    navTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_X + 4, SIDEBAR_TOP + 22)
    navTitle:SetText("Navigation")
    navTitle:SetTextColor(1, 0.82, 0)
    navTitle:SetShadowOffset(1, -1)

    local sidebarDivider = frame:CreateTexture(nil, "ARTWORK")
    sidebarDivider:SetColorTexture(0.9, 0.65, 0.25, 0.35)
    sidebarDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT - 24, CONTENT_TOP + 2)
    sidebarDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CONTENT_LEFT - 24, CONTENT_BOTTOM + 2)
    sidebarDivider:SetWidth(1)

    local dividerGlow = frame:CreateTexture(nil, "ARTWORK")
    dividerGlow:SetColorTexture(1, 0.45, 0.1, 0.12)
    dividerGlow:SetPoint("TOPLEFT", sidebarDivider, "TOPRIGHT", 1, 0)
    dividerGlow:SetPoint("BOTTOMLEFT", sidebarDivider, "BOTTOMRIGHT", 1, 0)
    dividerGlow:SetWidth(2)
	
    RandomSmartMountUI.frame = frame

    for index, pageInfo in ipairs(PAGE_ORDER) do
        CreateSidebarButton(frame, pageInfo.label, pageInfo.key, index, pageInfo.icon)
    end

    RebuildPages()

    return frame
end

function RandomSmartMountUI.Toggle()
    local frame = CreateMainWindow()

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        ShowPage(RandomSmartMountUI.currentPage or "general")
    end
end

function RandomSmartMountUI.Show()
    local frame = CreateMainWindow()
    frame:Show()
    ShowPage(RandomSmartMountUI.currentPage or "general")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    CreateMainWindow()

    if RandomSmartMountUI.CreateMinimapButton then
        RandomSmartMountUI.CreateMinimapButton()
    end
end)

SLASH_RANDOMSMARTMOUNTUI1 = "/rsmui"
SlashCmdList["RANDOMSMARTMOUNTUI"] = function()
    RandomSmartMountUI.Toggle()
end
