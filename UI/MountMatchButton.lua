RandomSmartMountUI = RandomSmartMountUI or {}

local BUTTON_NAME = "RandomSmartMountMatchTargetButton"
local DEFAULT_ICON = "Interface\\Icons\\Ability_Mount_RidingHorse"
local DEFAULT_BUTTON_SIZE = 46
local MIN_BUTTON_SIZE = 32
local MAX_BUTTON_SIZE = 72

local function Print(msg)
    if RandomSmartMountAPI and RandomSmartMountAPI.Print then
        RandomSmartMountAPI.Print(msg)
    else
        print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
    end
end

local function GetDB()
    if RandomSmartMountAPI and RandomSmartMountAPI.GetDB then
        return RandomSmartMountAPI.GetDB()
    end

    RandomSmartMountDB = RandomSmartMountDB or {}
    return RandomSmartMountDB
end

local function GetPositionDB()
    RandomSmartMountDB = RandomSmartMountDB or {}
    RandomSmartMountDB.matchButton = RandomSmartMountDB.matchButton or {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 260,
        y = -120,
    }

    return RandomSmartMountDB.matchButton
end

local function SavePosition(button)
    local point, _, relativePoint, x, y = button:GetPoint()
    local position = GetPositionDB()

    position.point = point or "CENTER"
    position.relativePoint = relativePoint or "CENTER"
    position.x = x or 0
    position.y = y or 0
end

local function RestorePosition(button)
    local position = GetPositionDB()

    button:ClearAllPoints()
    button:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.relativePoint or "CENTER",
        position.x or 0,
        position.y or 0
    )
end

local function GetMatch()
    if RandomSmartMountAPI and RandomSmartMountAPI.GetTargetMountMatch then
        return RandomSmartMountAPI.GetTargetMountMatch()
    end

    return {
        available = false,
        status = "Target mount matching unavailable.",
    }
end

local function ClampButtonSize(value)
    value = tonumber(value) or DEFAULT_BUTTON_SIZE

    if value < MIN_BUTTON_SIZE then
        return MIN_BUTTON_SIZE
    elseif value > MAX_BUTTON_SIZE then
        return MAX_BUTTON_SIZE
    end

    return value
end

local function ApplyButtonSize(button)
    local db = GetDB()
    local size = ClampButtonSize(db.mountMatchButtonSize)

    db.mountMatchButtonSize = size
    button:SetSize(size, size)
end

local function SetButtonShown(button)
    local db = GetDB()

    if db.showMountMatchButton == false then
        button:Hide()
    else
        button:Show()
    end
end

function RandomSmartMountUI.UpdateMountMatchButton()
    local button = RandomSmartMountUI.mountMatchButton
    if not button then return end

    local match = GetMatch()
    local icon = match and match.icon or DEFAULT_ICON

    ApplyButtonSize(button)
    button.match = match
    button.icon:SetTexture(icon or DEFAULT_ICON)

    if match and match.available then
        button.icon:SetDesaturated(false)
        button:SetAlpha(1)
    else
        button.icon:SetDesaturated(true)
        button:SetAlpha(0.55)
    end

    SetButtonShown(button)
end

function RandomSmartMountUI.UpdateMountMatchButtonVisibility()
    local button = RandomSmartMountUI.mountMatchButton

    if not button and RandomSmartMountUI.CreateMountMatchButton then
        button = RandomSmartMountUI.CreateMountMatchButton()
    end

    if button then
        SetButtonShown(button)
        RandomSmartMountUI.UpdateMountMatchButton()
    end
end

function RandomSmartMountUI.CreateMountMatchButton()
    if RandomSmartMountUI.mountMatchButton then
        return RandomSmartMountUI.mountMatchButton
    end

    local button = CreateFrame("Button", BUTTON_NAME, UIParent, "BackdropTemplate")
    button:SetSize(DEFAULT_BUTTON_SIZE, DEFAULT_BUTTON_SIZE)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0.02, 0.02, 0.02, 0.75)
    button:SetBackdropBorderColor(0.85, 0.65, 0.35, 0.85)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 6, -6)
    button.icon:SetPoint("BOTTOMRIGHT", -6, 6)
    button.icon:SetTexture(DEFAULT_ICON)

    RestorePosition(button)

    button:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    button:SetScript("OnClick", function()
        if RandomSmartMountAPI and RandomSmartMountAPI.MatchTargetMount then
            RandomSmartMountAPI.MatchTargetMount()
        else
            Print("Target mount matching unavailable.")
        end

        if RandomSmartMountUI.UpdateMountMatchButton then
            RandomSmartMountUI.UpdateMountMatchButton()
        end
    end)

    button:SetScript("OnEnter", function(self)
        local match = self.match or GetMatch()

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Match Target Mount")
        GameTooltip:AddLine(match.status or "Select a mounted target.", 1, 1, 1, true)
        GameTooltip:AddLine("Click: summon the target's mount if you own it.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Drag: move this button.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and unit ~= "target" then
            return
        end

        RandomSmartMountUI.UpdateMountMatchButton()
    end)

    button:RegisterEvent("PLAYER_TARGET_CHANGED")
    button:RegisterEvent("PLAYER_ENTERING_WORLD")
    button:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
    button:RegisterEvent("UNIT_AURA")

    RandomSmartMountUI.mountMatchButton = button
    ApplyButtonSize(button)
    RandomSmartMountUI.UpdateMountMatchButton()

    return button
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    RandomSmartMountUI.CreateMountMatchButton()
end)
