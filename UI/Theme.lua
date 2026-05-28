RandomSmartMountUI = RandomSmartMountUI or {}
RandomSmartMountUI.Theme = RandomSmartMountUI.Theme or {}

local ADDON_PATH = "Interface\\AddOns\\RandomSmartMount\\Media\\"

function RandomSmartMountUI.Theme.GetFaction()
    return UnitFactionGroup("player") or "Neutral"
end

function RandomSmartMountUI.Theme.GetFactionKey()
    local faction = RandomSmartMountUI.Theme.GetFaction()

    if faction == "Alliance" then
        return "alliance"
    end

    return "horde"
end

function RandomSmartMountUI.Theme.GetWindowBackground()
    local key = RandomSmartMountUI.Theme.GetFactionKey()
    return ADDON_PATH .. "window-bg-" .. key .. ".png"
end

function RandomSmartMountUI.Theme.GetButtonTexture(state)
    local key = RandomSmartMountUI.Theme.GetFactionKey()
    return ADDON_PATH .. "button-" .. key .. "-" .. state .. ".png"
end

function RandomSmartMountUI.Theme.GetIcon(name)
    local key = RandomSmartMountUI.Theme.GetFactionKey()
    return ADDON_PATH .. "icon-" .. key .. "-" .. name .. ".png"
end

function RandomSmartMountUI.Theme.GetMinimapIcon()
    return ADDON_PATH .. "rsm-icon.png"
end