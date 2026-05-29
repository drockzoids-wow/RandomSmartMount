RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local function GetDB()
    RandomSmartMountDB = RandomSmartMountDB or {}

    if RandomSmartMountDB.enabled == nil then
        RandomSmartMountDB.enabled = true
    end

    if RandomSmartMountDB.useDruidTravelForm == nil then
        RandomSmartMountDB.useDruidTravelForm = true
    end

    if RandomSmartMountDB.useDracthyrSoar == nil then
        RandomSmartMountDB.useDracthyrSoar = true
    end

    if RandomSmartMountDB.preferGroundWhenNotFlyable == nil then
        RandomSmartMountDB.preferGroundWhenNotFlyable = true
    end

    if RandomSmartMountDB.randomFavoritesOnly == nil then
        RandomSmartMountDB.randomFavoritesOnly = false
    end

    if RandomSmartMountDB.useDragonridingMounts == nil then
        RandomSmartMountDB.useDragonridingMounts = true
    end

    if RandomSmartMountDB.showMinimapButton == nil then
        RandomSmartMountDB.showMinimapButton = true
    end

    return RandomSmartMountDB
end

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

local function CreateCheckbox(parent, label, tooltip, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    checkbox.Text:SetText(label)

    checkbox.tooltip = tooltip

    checkbox:SetScript("OnEnter", function(self)
        if not self.tooltip then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() == true)
    end)

    checkbox.Refresh = function()
        checkbox:SetChecked(getter() == true)
    end

    return checkbox
end

local function CountFavoriteMounts()
    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return 0
    end

    local count = 0

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, _, _, isFavorite, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)

        if name and isCollected and isFavorite then
            count = count + 1
        end
    end

    return count
end

function RandomSmartMountUI.Pages.CreateGeneralPage(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", 285, -140)
    frame:SetPoint("BOTTOMRIGHT", -30, 30)
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("General")

    local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 14, -14)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText("Configure core Random Smart Mount behavior.")

    local checkboxes = {}

	local function AddSection(text, anchor, offsetY)

		local sectionAnchor = CreateFrame("Frame", nil, frame)
		sectionAnchor:SetSize(440, 24)
		sectionAnchor:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)

		local section = sectionAnchor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		section:SetPoint("LEFT", 0, 0)
		section:SetText(text)

		local divider = sectionAnchor:CreateTexture(nil, "ARTWORK")
		divider:SetColorTexture(1, 0.82, 0, 0.18)

		divider:SetPoint("LEFT", section, "RIGHT", 12, 0)
		divider:SetPoint("RIGHT", sectionAnchor, "RIGHT", 0, 0)
		divider:SetHeight(1)

		return sectionAnchor
	end

    local function AddCheckbox(label, tooltip, key, anchor, offsetY, indent)
        local checkbox = CreateCheckbox(
            frame,
            label,
            tooltip,
            function()
                return GetDB()[key]
            end,
            function(value)
                GetDB()[key] = value

                if key == "showMinimapButton"
                    and RandomSmartMountUI.UpdateMinimapButtonVisibility then
                    RandomSmartMountUI.UpdateMinimapButtonVisibility()
                end

                Print(label .. ": " .. (value and "enabled" or "disabled"))
            end
        )

        checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, offsetY)
        table.insert(checkboxes, checkbox)

        return checkbox
    end

    local coreSection = AddSection("Core Behavior", description, -22)

    local enabledBox = AddCheckbox(
        "Enable Random Smart Mount",
        "Turns Random Smart Mount behavior on or off.",
        "enabled",
        coreSection,
        -4, 18
    )

    local groundBox = AddCheckbox(
        "Prefer ground mounts when flying is unavailable",
        "When you cannot fly, the addon prefers usable ground mounts instead of trying flying-only choices.",
        "preferGroundWhenNotFlyable",
        enabledBox,
        -8
    )

    local favoritesBox = AddCheckbox(
        "Randomize favorite mounts only",
        "Limits normal random selection to mounts marked as favorites in your mount journal. If greyed out, make sure favorite mounts are selected.",
        "randomFavoritesOnly",
        groundBox,
        -8
    )

	favoritesBox.requiresFavorites = true

--    local dragonBox = AddCheckbox(
--       "Use skyriding / dragonriding mounts when possible",
--        "Allows smart random selection to use skyriding-capable mounts when appropriate.",
--        "useDragonridingMounts",
--        favoritesBox,
--        -8
--    )

	local classSection = AddSection("Class and Race Support", description, -150)

    local druidBox = AddCheckbox(
        "Use Druid Travel Form support",
        "Druids use Travel Form outdoors and Cat Form indoors when appropriate.",
        "useDruidTravelForm",
        classSection,
        -4, 18
    )

    local dracthyrBox = AddCheckbox(
        "Use Dracthyr Soar support",
        "Allows Dracthyr characters to use Soar behavior when appropriate.",
        "useDracthyrSoar",
        druidBox,
        -8
    )

    local uiSection = AddSection("Interface", description, -250)

    AddCheckbox(
        "Show minimap button",
        "Shows or hides the Random Smart Mount minimap launcher.",
        "showMinimapButton",
        uiSection,
        -4, 18
    )

    local function Refresh()
        GetDB()

		local favoriteCount = CountFavoriteMounts()

		for _, checkbox in ipairs(checkboxes) do
			checkbox.Refresh()

			if checkbox.requiresFavorites then
				if favoriteCount == 0 then
					checkbox:SetChecked(false)
					checkbox:Disable()
					checkbox.Text:SetTextColor(0.5, 0.5, 0.5)
					GetDB().randomFavoritesOnly = false
				else
					checkbox:Enable()
					checkbox.Text:SetTextColor(1, 1, 1)
				end
			end
		end
    end

    frame.Refresh = Refresh
    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end