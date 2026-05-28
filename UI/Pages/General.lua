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

function RandomSmartMountUI.Pages.CreateGeneralPage(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", 220, -82)
    frame:SetPoint("BOTTOMRIGHT", -30, 30)
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("General")

    local description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText("Configure core Random Smart Mount behavior.")

    local checkboxes = {}

    local function AddSection(text, anchor, offsetY)
        local section = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        section:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
        section:SetText(text)
        return section
    end

    local function AddCheckbox(label, tooltip, key, anchor, offsetY)
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

        checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
        table.insert(checkboxes, checkbox)

        return checkbox
    end

    local coreSection = AddSection("Core Behavior", description, -24)

    local enabledBox = AddCheckbox(
        "Enable Random Smart Mount",
        "Turns Random Smart Mount behavior on or off.",
        "enabled",
        coreSection,
        -10
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
        "Limits normal random selection to mounts marked as favorites in your mount journal.",
        "randomFavoritesOnly",
        groundBox,
        -8
    )

    local dragonBox = AddCheckbox(
        "Use skyriding / dragonriding mounts when possible",
        "Allows smart random selection to use skyriding-capable mounts when appropriate.",
        "useDragonridingMounts",
        favoritesBox,
        -8
    )

    local classSection = AddSection("Class and Race Support", dragonBox, -24)

    local druidBox = AddCheckbox(
        "Use Druid Travel Form support",
        "Druids use Travel Form outdoors and Cat Form indoors when appropriate.",
        "useDruidTravelForm",
        classSection,
        -10
    )

    local dracthyrBox = AddCheckbox(
        "Use Dracthyr Soar support",
        "Allows Dracthyr characters to use Soar behavior when appropriate.",
        "useDracthyrSoar",
        druidBox,
        -8
    )

    local uiSection = AddSection("Interface", dracthyrBox, -24)

    AddCheckbox(
        "Show minimap button",
        "Shows or hides the Random Smart Mount minimap launcher.",
        "showMinimapButton",
        uiSection,
        -10
    )

    local function Refresh()
        GetDB()

        for _, checkbox in ipairs(checkboxes) do
            checkbox.Refresh()
        end
    end

    frame.Refresh = Refresh
    frame:SetScript("OnShow", Refresh)

    return frame
end

if RandomSmartMountUI and RandomSmartMountUI.RefreshPages then
    RandomSmartMountUI.RefreshPages()
end