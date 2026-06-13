RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Pages = RandomSmartMountUI.Pages or {}

local function GetDB()
    if RandomSmartMountAPI and RandomSmartMountAPI.GetDB then
        return RandomSmartMountAPI.GetDB()
    end

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

    if RandomSmartMountDB.excludeServiceMountsFromRandom == nil then
        RandomSmartMountDB.excludeServiceMountsFromRandom = true
    end

    if RandomSmartMountDB.recentAvoidCount == nil then
        RandomSmartMountDB.recentAvoidCount = 3
    end

    if RandomSmartMountDB.useDragonridingMounts == nil then
        RandomSmartMountDB.useDragonridingMounts = true
    end

    if RandomSmartMountDB.showMinimapButton == nil then
        RandomSmartMountDB.showMinimapButton = true
    end

    if RandomSmartMountDB.showMountMatchButton == nil then
        RandomSmartMountDB.showMountMatchButton = true
    end

    if RandomSmartMountDB.mountMatchButtonSize == nil then
        RandomSmartMountDB.mountMatchButtonSize = 46
    end

    if RandomSmartMountDB.showChatMessages == nil then
        RandomSmartMountDB.showChatMessages = false
    end

    return RandomSmartMountDB
end

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
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

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 26)
    button:SetText(text)
    return button
end

local function ClampNumber(value, minValue, maxValue)
    value = tonumber(value) or minValue

    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end

    return value
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
    local frame = RandomSmartMountUI.CreatePageFrame(parent)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("General")

    local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    description:SetWidth(520)
    description:SetJustifyH("LEFT")
    description:SetText("Configure core Random Smart Mount behavior.")

    local checkboxes = {}

    local function AddSection(text, anchor, offsetY, offsetX, width)
        local sectionAnchor = CreateFrame("Frame", nil, frame)
        sectionAnchor:SetSize(width or 520, 24)
        sectionAnchor:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX or 0, offsetY)

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

                if key == "showMountMatchButton"
                    and RandomSmartMountUI.UpdateMountMatchButtonVisibility then
                    RandomSmartMountUI.UpdateMountMatchButtonVisibility()
                end

                Print(label .. ": " .. (value and "enabled" or "disabled"))
            end
        )

        checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, offsetY)
        table.insert(checkboxes, checkbox)

        return checkbox
    end

    local coreSection = AddSection("Core Behavior", description, -22, 0, 540)

    local enabledBox = AddCheckbox(
        "Enable Random Smart Mount",
        "Turns Random Smart Mount behavior on or off.",
        "enabled",
        coreSection,
        -4, 18
    )

    local groundBox = AddCheckbox(
        "Prefer ground when not flyable",
        "When you cannot fly, the addon prefers usable ground mounts instead of trying flying-only choices.",
        "preferGroundWhenNotFlyable",
        coreSection,
        -4, 330
    )

    local favoritesBox = AddCheckbox(
        "Randomize favorite mounts only",
        "Limits normal random selection to mounts marked as favorites in your mount journal. If greyed out, make sure favorite mounts are selected.",
        "randomFavoritesOnly",
        enabledBox,
        -8, 0
    )

    favoritesBox.requiresFavorites = true

    local serviceBox = AddCheckbox(
        "Exclude service mounts",
        "Keeps vendor, auction house, and ride-along mounts out of the normal smart random pool. Dedicated service keybinds can still use them.",
        "excludeServiceMountsFromRandom",
        groundBox,
        -8, 0
    )

    local recentLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    recentLabel:SetPoint("TOPLEFT", favoritesBox, "BOTTOMLEFT", 0, -12)
    recentLabel:SetText("Avoid recent mounts:")

    local recentBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    recentBox:SetSize(45, 24)
    recentBox:SetPoint("LEFT", recentLabel, "RIGHT", 12, 0)
    recentBox:SetAutoFocus(false)
    recentBox:SetNumeric(true)
    recentBox.tooltip = "Number of recent mounts to skip when another eligible mount is available. Set 0 to disable."

    recentBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Avoid recently used mounts")
        GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    recentBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local function SaveRecentAvoidCount()
        local value = ClampNumber(recentBox:GetNumber(), 0, 20)
        GetDB().recentAvoidCount = value
        recentBox:SetText(tostring(value))
        recentBox:ClearFocus()
        Print("Recent mount cooldown set to " .. tostring(value) .. ".")
    end

    recentBox:SetScript("OnEnterPressed", SaveRecentAvoidCount)
    recentBox:SetScript("OnEditFocusLost", SaveRecentAvoidCount)

    local clearRecentButton = CreateButton(frame, "Clear Recent", 95)
    clearRecentButton:SetPoint("LEFT", recentBox, "RIGHT", 8, 0)
    clearRecentButton:SetScript("OnClick", function()
        RandomSmartMountUI.ConfirmAction("Clear recent mount history?", function()
            if RandomSmartMountAPI and RandomSmartMountAPI.ClearRecentMounts then
                RandomSmartMountAPI.ClearRecentMounts()
            else
                GetDB().recentMounts = {}
            end

            Print("Recent mount history cleared.")
        end)
    end)

    local classSection = AddSection("Class and Race Support", recentLabel, -34, -18, 540)

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
        classSection,
        -4, 330
    )

    local uiSection = AddSection("Interface", druidBox, -34, -18, 540)

    local minimapBox = AddCheckbox(
        "Show minimap button",
        "Shows or hides the Random Smart Mount minimap launcher.",
        "showMinimapButton",
        uiSection,
        -4, 18
    )

    local chatMessagesBox = AddCheckbox(
        "Show chat messages",
        "Shows normal Random Smart Mount chat feedback for clicks and UI actions. Slash command output still appears when requested.",
        "showChatMessages",
        minimapBox,
        -8, 0
    )

    local matchButtonBox = AddCheckbox(
        "Show target match button",
        "Shows or hides the movable button for matching your target's mount.",
        "showMountMatchButton",
        uiSection,
        -4, 330
    )

    local matchSizeLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    matchSizeLabel:SetPoint("TOPLEFT", matchButtonBox, "BOTTOMLEFT", 0, -10)
    matchSizeLabel:SetText("Match button size")

    local matchSizeValue = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    matchSizeValue:SetPoint("LEFT", matchSizeLabel, "RIGHT", 10, 0)

    local matchSizeSlider = CreateFrame("Slider", "RandomSmartMountMatchButtonSizeSlider", frame, "OptionsSliderTemplate")
    matchSizeSlider:SetPoint("TOPLEFT", matchSizeLabel, "BOTTOMLEFT", 2, -6)
    matchSizeSlider:SetSize(150, 16)
    matchSizeSlider:SetMinMaxValues(32, 72)
    matchSizeSlider:SetValueStep(2)

    if matchSizeSlider.SetObeyStepOnDrag then
        matchSizeSlider:SetObeyStepOnDrag(true)
    end

    local sliderLow = _G[matchSizeSlider:GetName() .. "Low"]
    local sliderHigh = _G[matchSizeSlider:GetName() .. "High"]
    local sliderText = _G[matchSizeSlider:GetName() .. "Text"]

    if sliderLow then
        sliderLow:SetText("")
    end

    if sliderHigh then
        sliderHigh:SetText("")
    end

    if sliderText then
        sliderText:SetText("")
    end

    matchSizeSlider:SetScript("OnValueChanged", function(_, value)
        value = ClampNumber(math.floor((value or 46) + 0.5), 32, 72)
        GetDB().mountMatchButtonSize = value
        matchSizeValue:SetText(tostring(value))

        if RandomSmartMountUI.UpdateMountMatchButton then
            RandomSmartMountUI.UpdateMountMatchButton()
        end
    end)

    local function Refresh()
        GetDB()

        local favoriteCount = CountFavoriteMounts()
        recentBox:SetText(tostring(ClampNumber(GetDB().recentAvoidCount, 0, 20)))
        matchSizeSlider:SetValue(ClampNumber(GetDB().mountMatchButtonSize, 32, 72))
        matchSizeValue:SetText(tostring(ClampNumber(GetDB().mountMatchButtonSize, 32, 72)))

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
