RandomSmartMountUI = RandomSmartMountUI or {}

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

local function GetMinimapDB()
    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.minimap = RandomSmartMountDB.minimap or {
        hide = false,
        minimapPos = 225,
    }

    local activeDB =
        RandomSmartMountAPI
        and RandomSmartMountAPI.GetDB
        and RandomSmartMountAPI.GetDB()
        or RandomSmartMountDB

    if activeDB.showMinimapButton == nil then
        activeDB.showMinimapButton = RandomSmartMountDB.minimap.hide ~= true
    end

    RandomSmartMountDB.minimap.hide = activeDB.showMinimapButton == false

    return RandomSmartMountDB.minimap
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

    local minimapDB = GetMinimapDB()

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

    DBIcon:Register("RandomSmartMount", launcher, minimapDB)
	RandomSmartMountUI.UpdateMinimapButtonVisibility()
    RandomSmartMountUI.minimapRegistered = true
end

function RandomSmartMountUI.UpdateMinimapButtonVisibility()
    if not LibStub then return end

    local DBIcon = LibStub("LibDBIcon-1.0", true)
    if not DBIcon then return end

    local minimapDB = GetMinimapDB()
    local isRegistered = DBIcon.IsRegistered and DBIcon:IsRegistered("RandomSmartMount")

    if not isRegistered then
        return
    end

    if DBIcon.Refresh then
        DBIcon:Refresh("RandomSmartMount", minimapDB)
    end

    local activeDB =
        RandomSmartMountAPI
        and RandomSmartMountAPI.GetDB
        and RandomSmartMountAPI.GetDB()
        or RandomSmartMountDB

    if activeDB.showMinimapButton then
        DBIcon:Show("RandomSmartMount")
    else
        DBIcon:Hide("RandomSmartMount")
    end
end
