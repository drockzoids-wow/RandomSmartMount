RandomSmartMountUI = RandomSmartMountUI or {}

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

function RandomSmartMountUI.CreateMinimapButton()
    if RandomSmartMountUI.minimapRegistered then
        return
    end

    if not LibStub then
        Print("LibStub not found. Minimap button unavailable.")
        return
    end

    local LDB = LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub("LibDBIcon-1.0", true)

    if not LDB or not DBIcon then
        Print("LibDataBroker or LibDBIcon not found. Minimap button unavailable.")
        return
    end

    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.minimap = RandomSmartMountDB.minimap or {
        hide = false,
        minimapPos = 225,
    }

    local iconPath = "Interface\\Icons\\Ability_Mount_RidingHorse"

    if RandomSmartMountUI.Theme and RandomSmartMountUI.Theme.GetMinimapIcon then
        iconPath = RandomSmartMountUI.Theme.GetMinimapIcon()
    end

    local launcher = LDB:NewDataObject("RandomSmartMount", {
        type = "launcher",
        text = "Random Smart Mount",
        icon = iconPath,

        OnClick = function(_, button)
			if RandomSmartMountUI and RandomSmartMountUI.Toggle then
				RandomSmartMountUI.Toggle()
			end
		end,

        OnTooltipShow = function(tooltip)
			tooltip:AddLine("Random Smart Mount")
			tooltip:AddLine("Click: Open Control Center", 1, 1, 1)
			tooltip:AddLine("Drag: Move minimap button", 0.8, 0.8, 0.8)
        end,
    })

    DBIcon:Register("RandomSmartMount", launcher, RandomSmartMountDB.minimap)
	RandomSmartMountUI.UpdateMinimapButtonVisibility()
    RandomSmartMountUI.minimapRegistered = true
end

function RandomSmartMountUI.UpdateMinimapButtonVisibility()
    if not LibStub then return end

    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if not DBIcon then return end

    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.showMinimapButton = RandomSmartMountDB.showMinimapButton ~= false

    if RandomSmartMountDB.showMinimapButton then
        DBIcon:Show("RandomSmartMount")
    else
        DBIcon:Hide("RandomSmartMount")
    end
end