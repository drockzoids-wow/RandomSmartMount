-- Random Smart Mount
-- Bind from: Options > Keybindings > Random Smart Mount

BINDING_HEADER_RANDOMSMARTMOUNT = "Random Smart Mount"
_G["BINDING_NAME_CLICK RandomSmartMountButton:LeftButton"] = "Summon Smart Mount"
_G["BINDING_NAME_CLICK RandomSmartMountVendorButton:LeftButton"] = "Summon Vendor Mount"
_G["BINDING_NAME_CLICK RandomSmartMountAuctionHouseButton:LeftButton"] = "Summon Auction House Mount"
_G["BINDING_NAME_CLICK RandomSmartMountRideAlongButton:LeftButton"] = "Summon Ride-Along Mount"

RandomSmartMountDB = RandomSmartMountDB or {}
RandomSmartMountAPI = RandomSmartMountAPI or {}

local RSM = {}
RSM.debug = false

local DEFAULTS = {
    enabled = true,
    useDruidTravelForm = true,
    useDracthyrSoar = true,
    preferGroundWhenNotFlyable = true,
    randomFavoritesOnly = false,
    useDragonridingMounts = true,

    druidTravelSpellID = 783,      -- Travel Form
	druidCatFormSpellID = 768,	   -- Cat Form
    dracthyrSoarSpellID = 369536,  -- Soar

    blacklist = {},
    mountUsage = {},
    lastMountID = nil,
	preferredMount = nil,

    preferredServiceMounts = {
        vendor = nil,
        auctionHouse = nil,
        rideAlong = nil,
    },
}

local FLYING_MOUNT_TYPES = {
    [247] = true,
    [248] = true,
    [254] = true,
    [269] = true,
    [398] = true,
    [402] = true,
    [407] = true,
    [412] = true,
    [424] = true,
    [426] = true,
    [436] = true,
}

local WATER_MOUNT_TYPES = {
    [231] = true,
    [232] = true,
    [254] = true,
    [407] = true,
    [408] = true,
    [412] = true,
}

RSM_SERVICE_MOUNT_PRIORITY = {
    vendor = {
        "mighty caravan brutosaur",
        "grand expedition yak",
        "grizzly hills packmaster",
        "traveler's tundra mammoth",
        "traveller's tundra mammoth",
    },

    auctionHouse = {
        "mighty caravan brutosaur",
        "trader's gilded brutosaur",
    },

    rideAlong = {
        "sandstone drake",
        "vial of the sands",
        "x-53 touring rocket",
        "heart of the nightwing",
        "obsidian nightwing",
        "rocket",
    },
}

local FALLING_RESCUE_BY_CLASS = {
    PRIEST = {
        { spellID = 1706, name = "Levitate", unit = "player" },
    },

    MAGE = {
        { spellID = 130, name = "Slow Fall", unit = "player" },
    },

    EVOKER = {
        { spellID = 358733, name = "Glide" },
    },

    DEMONHUNTER = {
        { spellID = 131347, name = "Glide" },
    },

    DRUID = {
        { spellID = 164862, name = "Flap" },
    },

    MONK = {
        { spellID = 125883, name = "Zen Flight" },
    },
}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end

    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end

    return dst
end

local function GetDB()
    RandomSmartMountDB = CopyDefaults(DEFAULTS, RandomSmartMountDB)
    return RandomSmartMountDB
end

local function Print(msg)
    print("|cff33ccffRandomSmartMount:|r " .. tostring(msg))
end

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end

    return GetSpellInfo and GetSpellInfo(spellID)
end

local function IsSpellKnownByPlayer(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    elseif IsPlayerSpell then
        return IsPlayerSpell(spellID)
    elseif IsSpellKnown then
        return IsSpellKnown(spellID)
    end

    return GetSpellName(spellID) ~= nil
end

local function SpellUsable(spellID)
    local spellName = GetSpellName(spellID)
    if not spellName then return false end

    local usable, noMana
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noMana = C_Spell.IsSpellUsable(spellID)
    else
        usable, noMana = IsUsableSpell(spellName)
    end

    if not usable or noMana then
        return false
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd and cd.startTime and cd.duration and cd.duration > 0 then
            return false
        end
    else
        local start, duration = GetSpellCooldown(spellName)
        if start and duration and duration > 0 then
            return false
        end
    end

    return true
end

local function PlayerClass()
    local _, classFile = UnitClass("player")
    return classFile
end

local function PlayerRace()
    local _, raceFile = UnitRace("player")
    return raceFile
end

local function IsPlayerMounted()
    if IsMounted and IsMounted() then
        return true
    end

    return C_MountJournal and C_MountJournal.IsMounted and C_MountJournal.IsMounted()
end

local function GetMountName(mountID)
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        return name
    end

    return nil
end

local function IsMountBlacklisted(mountID)
    local db = GetDB()
    return db.blacklist and (db.blacklist[mountID] == true or db.blacklist[tostring(mountID)] == true)
end

local function SetMountBlacklisted(mountID, isBlacklisted)
    mountID = tonumber(mountID)
    if not mountID then return end

    local db = GetDB()
    db.blacklist = db.blacklist or {}

    if isBlacklisted then
        db.blacklist[mountID] = true
    else
        db.blacklist[mountID] = nil
        db.blacklist[tostring(mountID)] = nil
    end
end

local function GetBlacklistedMountIDs()
    local db = GetDB()
    local ids = {}
    local seen = {}

    for mountID, value in pairs(db.blacklist or {}) do
        local numericID = tonumber(mountID)

        if value and numericID and not seen[numericID] then
            seen[numericID] = true
            table.insert(ids, numericID)
        end
    end

    table.sort(ids, function(a, b)
        local nameA = GetMountName(a) or ""
        local nameB = GetMountName(b) or ""

        if nameA == nameB then
            return a < b
        end

        return nameA < nameB
    end)

    return ids
end

local function GetMountTypeID(mountID)
    if not C_MountJournal or not C_MountJournal.GetMountInfoExtraByID then
        return nil
    end

    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    return mountTypeID
end

local function IsFlyingMount(mountID)
    local mountTypeID = GetMountTypeID(mountID)
    return FLYING_MOUNT_TYPES[mountTypeID] == true
end

local function IsWaterMount(mountID)
    local mountTypeID = GetMountTypeID(mountID)
    return WATER_MOUNT_TYPES[mountTypeID] == true
end

local function GetBreathTimerScale()
    if not GetMirrorTimerInfo then
        return nil
    end

    local timerCount = MIRRORTIMER_NUMTIMERS or 3

    for i = 1, timerCount do
        local timer, _, _, scale = GetMirrorTimerInfo(i)
        if timer == "BREATH" then
            return scale
        end
    end

    return nil
end

local function IsPlayerSwimmingAtSurface()
    if not IsSwimming or not IsSwimming() then
        return false
    end

    local breathScale = GetBreathTimerScale()

    if breathScale and breathScale < 0 then
        return false
    end

    return IsFlyableArea and IsFlyableArea()
end

local function IsPlayerUnderwaterForMounts()
    if not IsSubmerged or not IsSubmerged() then
        return false
    end

    return not IsPlayerSwimmingAtSurface()
end

local function CanFlyHere()
    return IsFlyableArea and IsFlyableArea()
end

local function RandomIndex(max)
    if math and math.random then
        return math.random(max)
    end

    return random(max)
end

local function NormalizeMountName(name)
    if not name then return "" end

    name = string.lower(name)
    name = name:gsub("’", "'")
    name = name:gsub("reins of the ", "")
    name = name:gsub("reins of ", "")

    return name
end

local function GetMountUsage(mountID)
    local db = GetDB()
    db.mountUsage = db.mountUsage or {}

    return db.mountUsage[mountID] or db.mountUsage[tostring(mountID)] or 0
end

local function RecordMountUsage(mountID)
    if not mountID then return end

    local db = GetDB()
    db.mountUsage = db.mountUsage or {}

    db.mountUsage[mountID] = GetMountUsage(mountID) + 1
    db.mountUsage[tostring(mountID)] = nil
end

local function ClearMountUsage()
    local db = GetDB()
    db.mountUsage = {}
end

local function CountUsageEntries()
    local db = GetDB()
    local count = 0

    for _, _ in pairs(db.mountUsage or {}) do
        count = count + 1
    end

    return count
end

local function GetTotalMountUses()
    local db = GetDB()
    local total = 0

    for _, value in pairs(db.mountUsage or {}) do
        total = total + tonumber(value or 0)
    end

    return total
end

local function GetSortedUsageMounts(descending)
    local db = GetDB()
    local entries = {}
    local seen = {}

    for mountID, count in pairs(db.mountUsage or {}) do
        local numericID = tonumber(mountID)

        if numericID and not seen[numericID] then
            seen[numericID] = true

            table.insert(entries, {
                mountID = numericID,
                name = GetMountName(numericID) or ("Mount " .. numericID),
                count = tonumber(count or 0),
            })
        end
    end

    table.sort(entries, function(a, b)
        if a.count == b.count then
            return a.name < b.name
        end

        if descending then
            return a.count > b.count
        end

        return a.count < b.count
    end)

    return entries
end

local function PickLeastUsedMount(mountIDs)
    if not mountIDs or #mountIDs == 0 then return nil end

    local weighted = {}
    local totalWeight = 0

    for _, mountID in ipairs(mountIDs) do
        local used = GetMountUsage(mountID)
        local weight = 1 / ((used + 1) ^ 1.5)

        weighted[#weighted + 1] = {
            mountID = mountID,
            weight = weight,
        }

        totalWeight = totalWeight + weight
    end

    local roll = math.random() * totalWeight
    local running = 0

    for _, entry in ipairs(weighted) do
        running = running + entry.weight
        if roll <= running then
            return entry.mountID
        end
    end

    return mountIDs[RandomIndex(#mountIDs)]
end

local function FindServiceMountByName(wantedName)
    if not wantedName or wantedName == "" then
        return nil
    end

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil
    end

    local normalizedWanted = NormalizeMountName(wantedName)

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, isUsable, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)

        if isCollected
            and isUsable
            and not IsMountBlacklisted(mountID)
            and NormalizeMountName(name) == normalizedWanted then

            return mountID, name
        end
    end

    return nil
end

local function GetPriorityServiceMountID(serviceType)
    local db = GetDB()
    db.preferredServiceMounts = db.preferredServiceMounts or {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil
    end

    local preferredName = db.preferredServiceMounts[serviceType]
    if preferredName and preferredName ~= "" then
        local preferredMountID, preferredMountName = FindServiceMountByName(preferredName)
        if preferredMountID then
            return preferredMountID, preferredMountName
        end
    end

    local priorityList = RSM_SERVICE_MOUNT_PRIORITY[serviceType]
    if not priorityList then
        return nil
    end

    for _, wantedName in ipairs(priorityList) do
        local mountID, mountName = FindServiceMountByName(wantedName)
        if mountID then
            return mountID, mountName
        end
    end

    return nil
end

local function EnsureMountJournalLoaded()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_Collections")
    end
end

local function PickRandomMountID()
    local db = GetDB()

    EnsureMountJournalLoaded()

    local allMounts = {}
    local groundMounts = {}
    local flyingMounts = {}
    local surfaceFlyingMounts = {}
    local waterMounts = {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil, 0
    end

    local isSurface = IsPlayerSwimmingAtSurface()
    local isUnderwater = IsPlayerUnderwaterForMounts()

	for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
		local name, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected =
			C_MountJournal.GetMountInfoByID(mountID)

		if name and isCollected and not IsMountBlacklisted(mountID) then
			if not db.randomFavoritesOnly or isFavorite then
				allMounts[#allMounts + 1] = mountID

				if IsFlyingMount(mountID) then
					flyingMounts[#flyingMounts + 1] = mountID

					if isSurface then
						surfaceFlyingMounts[#surfaceFlyingMounts + 1] = mountID
					end
				else
					groundMounts[#groundMounts + 1] = mountID
				end

				if IsWaterMount(mountID) then
					waterMounts[#waterMounts + 1] = mountID
				end
			end
		end
	end

	if db.randomFavoritesOnly and #allMounts == 0 then
		Print("Favorites Only is enabled, but no favorite mounts are selected.")
		return nil, 0
	end

    if isSurface and #surfaceFlyingMounts > 0 then
        return PickLeastUsedMount(surfaceFlyingMounts), #allMounts
    end

    if isUnderwater and #waterMounts > 0 then
        return PickLeastUsedMount(waterMounts), #allMounts
    end

    if CanFlyHere() and #flyingMounts > 0 then
        return PickLeastUsedMount(flyingMounts), #allMounts
    end
	  
    if db.preferGroundWhenNotFlyable and #groundMounts > 0 then
        return PickLeastUsedMount(groundMounts), #allMounts
    end

    if #allMounts > 0 then
        return PickLeastUsedMount(allMounts), #allMounts
    end

    return nil, 0
end

local function GetFallingRescueAction()
    if not IsFalling or not IsFalling() then
        return nil
    end

    local class = PlayerClass()
    local rescues = FALLING_RESCUE_BY_CLASS[class]
    if not rescues then
        return nil
    end

    for _, rescue in ipairs(rescues) do
        if IsSpellKnownByPlayer(rescue.spellID) then
            local spellName = GetSpellName(rescue.spellID)

            if spellName then
                if rescue.spellID == 131347 or rescue.spellID == 358733 then
                    return {
                        type = "spell",
                        spell = spellName,
                        unit = rescue.unit,
                    }
                end

                if SpellUsable(rescue.spellID) then
                    return {
                        type = "spell",
                        spell = spellName,
                        unit = rescue.unit,
                    }
                end
            end
        end
    end

    return nil
end

local function FindUsableMountByName(wantedName)
    if not wantedName or wantedName == "" then
        return nil
    end

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil
    end

    local normalizedWanted = NormalizeMountName(wantedName)

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, isUsable, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)

        if name
            and isCollected
            and isUsable
            and not IsMountBlacklisted(mountID)
            and NormalizeMountName(name) == normalizedWanted then

            return mountID, name
        end
    end

    return nil
end

local function BuildSmartMountMacro()
    local db = GetDB()

    if IsPlayerMounted() then
        return "/dismount"
    end

	if db.enabled == false then
		return "/run print('RandomSmartMount: Smart mounting is disabled.')"
	end

    local class = PlayerClass()
    local race = PlayerRace()

	if not IsOutdoors() then
		if db.useDruidTravelForm and class == "DRUID" then
            local catFormName = GetSpellName(db.druidCatFormSpellID)

            if catFormName and IsSpellKnownByPlayer(db.druidCatFormSpellID) and SpellUsable(db.druidCatFormSpellID) then
                return "/cast " .. catFormName
            end
        end

        return "/run print('RandomSmartMount: You are indoors.')"
    end

    if db.useDruidTravelForm and class == "DRUID" then
        local spellName = GetSpellName(db.druidTravelSpellID)
        if spellName and IsSpellKnownByPlayer(db.druidTravelSpellID) and SpellUsable(db.druidTravelSpellID) then
            return "/cast " .. spellName
        end
    end

    if IsPlayerUnderwaterForMounts() then
        local mountID = PickRandomMountID()
        if mountID then
            db.lastMountID = mountID
            return "/run C_MountJournal.SummonByID(" .. mountID .. "); RandomSmartMountAPI.RecordMountUsage(" .. mountID .. ")"
        end
    end

    if db.useDracthyrSoar and race == "Dracthyr" and not IsPlayerUnderwaterForMounts() then
        local spellName = GetSpellName(db.dracthyrSoarSpellID)
        if CanFlyHere() and spellName and IsSpellKnownByPlayer(db.dracthyrSoarSpellID) and SpellUsable(db.dracthyrSoarSpellID) then
            return "/cast " .. spellName
        end
    end

	-- Preferred Smart Mount
	-- If selected, try this mount before random selection.
	if db.preferredMount and db.preferredMount ~= "" then
		local preferredMountID = FindUsableMountByName(db.preferredMount)

		if preferredMountID then
			db.lastMountID = preferredMountID

			return "/run C_MountJournal.SummonByID(" .. preferredMountID .. "); RandomSmartMountAPI.RecordMountUsage(" .. preferredMountID .. ")"
		end
	end

    local mountID, availableCount = PickRandomMountID()

    if mountID then
        db.lastMountID = mountID
        return "/run C_MountJournal.SummonByID(" .. mountID .. "); RandomSmartMountAPI.RecordMountUsage(" .. mountID .. ")"
    end

    if availableCount > 0 then
        return "/run print('RandomSmartMount: Mounting is not allowed here right now.')"
    end

    return "/run print('RandomSmartMount: No usable mounts found.')"
end

local function SummonServiceMount(serviceType)
    if InCombatLockdown() then
        Print("Cannot summon a mount while in combat.")
        return
    end

    local mountID = GetPriorityServiceMountID(serviceType)

    if mountID then
        local db = GetDB()
        db.lastMountID = mountID
        RecordMountUsage(mountID)
        C_MountJournal.SummonByID(mountID)
        return
    end

    if serviceType == "auctionHouse" then
        Print("No usable auction house mount found.")
    elseif serviceType == "rideAlong" then
        Print("No usable ride-along mount found.")
    else
        Print("No usable vendor mount found.")
    end
end

local smartButton = CreateFrame("Button", "RandomSmartMountButton", UIParent, "SecureActionButtonTemplate")
smartButton:RegisterForClicks("AnyDown", "AnyUp")
smartButton:SetAttribute("type", nil)

local function ClearSmartButtonAttributes()
    smartButton:SetAttribute("type", nil)
    smartButton:SetAttribute("spell", nil)
    smartButton:SetAttribute("item", nil)
    smartButton:SetAttribute("unit", nil)
    smartButton:SetAttribute("macrotext", nil)
end

local function SetupCombatSafeButton()
    if not smartButton then return end

    ClearSmartButtonAttributes()

    smartButton:SetAttribute("type", "macro")
    smartButton:SetAttribute("macrotext", "/dismount [mounted]\n/stopmacro [mounted]")
end

local function UpdateSmartButton()
    if InCombatLockdown() then return end

    ClearSmartButtonAttributes()

    local fallingAction = GetFallingRescueAction()
    if fallingAction then
        smartButton:SetAttribute("type", fallingAction.type)
        smartButton:SetAttribute("spell", fallingAction.spell)

        if fallingAction.unit then
            smartButton:SetAttribute("unit", fallingAction.unit)
        end

        return
    end

    smartButton:SetAttribute("type", "macro")
    smartButton:SetAttribute("macrotext", BuildSmartMountMacro())
end

smartButton:SetScript("PreClick", function()
    if not InCombatLockdown() then
        UpdateSmartButton()
    end
end)

smartButton:SetScript("PostClick", function()
    if not InCombatLockdown() then
        ClearSmartButtonAttributes()
    end
end)

local vendorButton = CreateFrame("Button", "RandomSmartMountVendorButton", UIParent, "SecureActionButtonTemplate")
vendorButton:RegisterForClicks("AnyDown")
vendorButton:HookScript("OnClick", function()
    SummonServiceMount("vendor")
end)

local auctionHouseButton = CreateFrame("Button", "RandomSmartMountAuctionHouseButton", UIParent, "SecureActionButtonTemplate")
auctionHouseButton:RegisterForClicks("AnyDown")
auctionHouseButton:HookScript("OnClick", function()
    SummonServiceMount("auctionHouse")
end)

local rideAlongButton = CreateFrame("Button", "RandomSmartMountRideAlongButton", UIParent, "SecureActionButtonTemplate")
rideAlongButton:RegisterForClicks("AnyDown")
rideAlongButton:HookScript("OnClick", function()
    SummonServiceMount("rideAlong")
end)

RandomSmartMountAPI.GetDB = GetDB
RandomSmartMountAPI.Print = Print
RandomSmartMountAPI.GetMountName = GetMountName
RandomSmartMountAPI.GetMountUsage = GetMountUsage
RandomSmartMountAPI.GetTotalMountUses = GetTotalMountUses
RandomSmartMountAPI.CountUsageEntries = CountUsageEntries
RandomSmartMountAPI.GetSortedUsageMounts = GetSortedUsageMounts
RandomSmartMountAPI.ClearMountUsage = ClearMountUsage
RandomSmartMountAPI.RecordMountUsage = RecordMountUsage
RandomSmartMountAPI.IsMountBlacklisted = IsMountBlacklisted
RandomSmartMountAPI.SetMountBlacklisted = SetMountBlacklisted
RandomSmartMountAPI.GetBlacklistedMountIDs = GetBlacklistedMountIDs
RandomSmartMountAPI.GetLastMountID = function()
    return GetDB().lastMountID
end
RandomSmartMountAPI.NormalizeMountName = NormalizeMountName

RandomSmartMountAPI.ClickSmartMount = function()
	if UpdateSmartButton then
		UpdateSmartButton()
	end

    if RandomSmartMountButton then
        RandomSmartMountButton:Click("LeftButton")
    else
        Print("Smart mount button not found.")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")

frame:SetScript("OnEvent", function(_, event)
    GetDB()

    if event == "PLAYER_LOGIN" then
        if math and math.randomseed and time then
            math.randomseed(time())
        end

        UpdateSmartButton()
        Print("Loaded. Bind it under Options > Keybindings > Random Smart Mount.")
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        SetupCombatSafeButton()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        UpdateSmartButton()
        return
    end

    UpdateSmartButton()
end)

SLASH_RANDOMSMARTMOUNT1 = "/rsm"
SLASH_RANDOMSMARTMOUNT2 = "/randomsmartmount"

SlashCmdList["RANDOMSMARTMOUNT"] = function(msg)
    msg = string.lower(msg or "")
    local db = GetDB()

    if msg == "debug" then
        local fallingAction = GetFallingRescueAction()

        Print("Class: " .. tostring(PlayerClass()))
        Print("Race: " .. tostring(PlayerRace()))
        Print("Outdoors: " .. tostring(IsOutdoors()))
        Print("Falling: " .. tostring(IsFalling and IsFalling()))
        Print("FallingAction: " .. tostring(fallingAction and fallingAction.spell))
        Print("Swimming: " .. tostring(IsSwimming and IsSwimming()))
        Print("Submerged: " .. tostring(IsSubmerged and IsSubmerged()))
        Print("BreathScale: " .. tostring(GetBreathTimerScale()))
        Print("SurfaceWater: " .. tostring(IsPlayerSwimmingAtSurface()))
        Print("UnderwaterForMounts: " .. tostring(IsPlayerUnderwaterForMounts()))
        Print("Flyable: " .. tostring(CanFlyHere()))
        Print("UsageEntries: " .. tostring(CountUsageEntries()))
        Print("TotalUses: " .. tostring(GetTotalMountUses()))
        Print("Macro: " .. BuildSmartMountMacro())
        return
    end

    if msg == "macro" then
        Print(BuildSmartMountMacro())
        return
    end

    if msg == "last" then
        Print("Last mount ID: " .. tostring(db.lastMountID))
        return
    end

    if msg == "usage" then
        Print("Tracked mount usage entries: " .. tostring(CountUsageEntries()))
        Print("Total tracked mount uses: " .. tostring(GetTotalMountUses()))
        return
    end

    if msg == "resetusage" then
        ClearMountUsage()
        Print("Mount usage history reset.")
        return
    end

    if msg == "blacklistlast" then
        if db.lastMountID then
            SetMountBlacklisted(db.lastMountID, true)
            Print("Blacklisted last mount: " .. tostring(GetMountName(db.lastMountID) or db.lastMountID))
        else
            Print("No last mount found.")
        end
        return
    end

    if msg == "clearblacklist" then
        db.blacklist = {}
        Print("Blacklist cleared.")
        return
    end

    if msg == "vendor" then
        SummonServiceMount("vendor")
        return
    end

    if msg == "ah" or msg == "auctionhouse" then
        SummonServiceMount("auctionHouse")
        return
    end

    if msg == "ridealong" or msg == "ride" then
        SummonServiceMount("rideAlong")
        return
    end

    Print("/rsm debug - show current state")
    Print("/rsm macro - show current smart mount macro")
    Print("/rsm vendor - summon best owned vendor mount")
    Print("/rsm ah - summon best owned auction house mount")
    Print("/rsm ride - summon best owned ride-along mount")
    Print("/rsm last - show last summoned mount ID")
    Print("/rsm usage - show mount usage tracking count")
    Print("/rsm resetusage - reset weighted usage tracking")
    Print("/rsm blacklistlast - blacklist last summoned mount")
    Print("/rsm clearblacklist - clear blacklist")
end