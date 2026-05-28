local PANEL_TITLE = "Random Smart Mount"

RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local pages = {}
local buttons = {}

local PAGE_ORDER = {
    { key = "general", label = "General", icon = "general" },
    { key = "preferred", label = "Preferred", icon = "preferred" },
    { key = "service", label = "Service", icon = "service" },
    { key = "blacklist", label = "Blacklist", icon = "blacklist" },
    { key = "statistics", label = "Statistics", icon = "statistics" },
}

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

local function CreateFallbackPanel(parent, name, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", 260, -126)
    frame:SetPoint("BOTTOMRIGHT", -30, 30)
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

    if key == "general" then
        return CreateFallbackPanel(parent, "General", "General settings will live here.\n\nPlanned:\n• Druid options\n• Dracthyr options\n• Randomness behavior\n• Minimap button toggle")
    elseif key == "preferred" then
        return CreateFallbackPanel(parent, "Preferred Mount", "Preferred Smart Mount controls will live here.")
    elseif key == "service" then
        return CreateFallbackPanel(parent, "Service Mounts", "Vendor, Auction House, and Ride-Along mount preferences will live here.")
    elseif key == "blacklist" then
        return CreateFallbackPanel(parent, "Blacklist", "Blacklist search and remove controls will live here.")
    elseif key == "statistics" then
        return CreateFallbackPanel(parent, "Statistics", "Mount usage statistics will live here.")
    end

    return CreateFallbackPanel(parent, key, "This page is ready for controls.")
end

local function ShowPage(name)
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
    button:SetSize(170, 40)
    button:SetPoint("TOPLEFT", 52, -210 - ((index - 1) * 48))

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
        button.icon:SetSize(26, 26)
        button.icon:SetPoint("LEFT", 10, 0)
        button.icon:SetTexture(theme.GetIcon(iconName))
    end

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("LEFT", 48, 0)
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

    frame:SetSize(840, 580)
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

	-- Main Title
	local mainTitle = frame:CreateFontString(nil, "ARTWORK")

	mainTitle:SetFont(
		"Fonts\\FRIZQT__.TTF",
		28,
		"OUTLINE"
	)

	mainTitle:SetPoint("TOP", frame, "TOP", 0, -65)
	mainTitle:SetText("Random Smart Mount")
	mainTitle:SetTextColor(1.0, 0.82, 0)

	-- Subtitle
	local subTitle = frame:CreateFontString(nil, "ARTWORK")

	subTitle:SetFont(
		"Fonts\\FRIZQT__.TTF",
		16,
		"OUTLINE"
	)

	subTitle:SetPoint("TOP", mainTitle, "BOTTOM", 0, -2)
	subTitle:SetText("Control Center")
	subTitle:SetTextColor(1.0, 0.82, 0)

	local sidebarDivider = frame:CreateTexture(nil, "ARTWORK")
	sidebarDivider:SetColorTexture(0.9, 0.65, 0.25, 0.35)
	sidebarDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 250, -170)
	sidebarDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 250, 88)
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

    Print("UI loaded. Use /rsmui or right-click the minimap button.")
end)

SLASH_RANDOMSMARTMOUNTUI1 = "/rsmui"
SlashCmdList["RANDOMSMARTMOUNTUI"] = function()
    RandomSmartMountUI.Toggle()
end