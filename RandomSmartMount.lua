-- Random Smart Mount
-- Bind from: Options > Keybindings > Random Smart Mount

BINDING_HEADER_RANDOMSMARTMOUNT = "Random Smart Mount"
BINDING_CATEGORY_RANDOMSMARTMOUNT = "Random Smart Mount"
_G["BINDING_NAME_CLICK RandomSmartMountButton:LeftButton"] = "Summon Smart Mount"
_G["BINDING_NAME_CLICK RandomSmartMountVendorButton:LeftButton"] = "Summon Vendor Mount"
_G["BINDING_NAME_CLICK RandomSmartMountAuctionHouseButton:LeftButton"] = "Summon Auction House Mount"
_G["BINDING_NAME_CLICK RandomSmartMountRideAlongButton:LeftButton"] = "Summon Ride-Along Mount"
_G["BINDING_NAME_RANDOMSMARTMOUNT_MATCH_TARGET"] = "Match Target Mount"

RandomSmartMountDB = RandomSmartMountDB or {}
RandomSmartMountAPI = RandomSmartMountAPI or {}

local RSM = {}
RSM.debug = false

local PROFILE_SCOPE_ACCOUNT = "account"
local PROFILE_SCOPE_CHARACTER = "character"
local PROFILE_SCOPE_CLASS = "class"

local PROFILE_DEFAULTS = {
    enabled = true,
    useDruidTravelForm = true,
    useDracthyrSoar = true,
    preferGroundWhenNotFlyable = true,
    randomFavoritesOnly = false,
    excludeServiceMountsFromRandom = true,
    recentAvoidCount = 3,
    useDragonridingMounts = true,
    showMinimapButton = true,
    showMountMatchButton = true,
    mountMatchButtonSize = 46,

    druidTravelSpellID = 783,      -- Travel Form
	druidCatFormSpellID = 768,	   -- Cat Form
    dracthyrSoarSpellID = 369536,  -- Soar

    blacklist = {},
    mountUsage = {},
    mountGroups = {},
    activeMountGroup = nil,
    recentMounts = {},
    lastMountID = nil,
	preferredMount = nil,

    preferredServiceMounts = {
        vendor = nil,
        auctionHouse = nil,
        rideAlong = nil,
    },
}

local GLOBAL_DEFAULTS = {
    profileScope = PROFILE_SCOPE_ACCOUNT,
    profiles = {
        account = {},
        characters = {},
        classes = {},
    },
    minimap = {
        hide = false,
        minimapPos = 225,
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

RSM_RIDE_ALONG_MOUNT_POOLS = {
    flying = {
        "renewed proto-drake",
        "windborne velocidrake",
        "highland drake",
        "cliffside wylderdrake",
        "winding slitherdrake",
        "grotto netherwing drake",
        "flourishing whimsydrake",
        "sandstone drake",
        "vial of the sands",
        "x-53 touring rocket",
        "heart of the nightwing",
        "obsidian nightwing",
        "stormwind skychaser",
        "orgrimmar interceptor",
        "the hivemind",
    },

    ground = {
        "mechano-hog",
        "mekgineer's chopper",
    },

    lowLevelGround = {
        "chauffeured mechano-hog",
        "chauffeured mekgineer's chopper",
    },
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

    rideAlong = {},
}

for _, poolKey in ipairs({ "flying", "ground", "lowLevelGround" }) do
    for _, mountName in ipairs(RSM_RIDE_ALONG_MOUNT_POOLS[poolKey]) do
        table.insert(RSM_SERVICE_MOUNT_PRIORITY.rideAlong, mountName)
    end
end

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

local function CopyTable(src)
    if type(src) ~= "table" then
        return src
    end

    local dst = {}

    for key, value in pairs(src) do
        dst[key] = CopyTable(value)
    end

    return dst
end

local function NormalizeProfileScope(scope)
    if scope == PROFILE_SCOPE_CHARACTER or scope == PROFILE_SCOPE_CLASS then
        return scope
    end

    return PROFILE_SCOPE_ACCOUNT
end

local function GetCharacterProfileKey()
    local name = UnitName and UnitName("player") or nil
    local realm =
        GetNormalizedRealmName
        and GetNormalizedRealmName()
        or (GetRealmName and GetRealmName())
        or nil

    name = name or "Unknown"
    realm = realm or "UnknownRealm"
    realm = tostring(realm):gsub("%s+", "")

    if realm == "" then
        realm = "UnknownRealm"
    end

    return tostring(name) .. "-" .. realm
end

local function GetClassProfileKey()
    local classFile

    if UnitClass then
        _, classFile = UnitClass("player")
    end

    return classFile or "UNKNOWN"
end

local function CopyLegacySettingsToProfile(root, profile)
    profile = profile or {}

    for key in pairs(PROFILE_DEFAULTS) do
        if root[key] ~= nil then
            profile[key] = CopyTable(root[key])
        end
    end

    return CopyDefaults(PROFILE_DEFAULTS, profile)
end

local function EnsureProfileRoot()
    RandomSmartMountDB = RandomSmartMountDB or {}

    local root = RandomSmartMountDB
    local hadProfiles = type(root.profiles) == "table"

    root.minimap = CopyDefaults(GLOBAL_DEFAULTS.minimap, root.minimap)
    root.profiles = root.profiles or CopyTable(GLOBAL_DEFAULTS.profiles)
    root.profiles.account = root.profiles.account or {}
    root.profiles.characters = root.profiles.characters or {}
    root.profiles.classes = root.profiles.classes or {}

    if not hadProfiles then
        root.profiles.account = CopyLegacySettingsToProfile(root, root.profiles.account)
    end

    root.profiles.account = CopyDefaults(PROFILE_DEFAULTS, root.profiles.account)
    root.profileScope = NormalizeProfileScope(root.profileScope)

    return root
end

local function GetProfileDB(scope)
    local root = EnsureProfileRoot()
    scope = NormalizeProfileScope(scope or root.profileScope)

    if scope == PROFILE_SCOPE_CHARACTER then
        local key = GetCharacterProfileKey()
        root.profiles.characters[key] = CopyDefaults(PROFILE_DEFAULTS, root.profiles.characters[key])
        return root.profiles.characters[key]
    end

    if scope == PROFILE_SCOPE_CLASS then
        local key = GetClassProfileKey()
        root.profiles.classes[key] = CopyDefaults(PROFILE_DEFAULTS, root.profiles.classes[key])
        return root.profiles.classes[key]
    end

    root.profiles.account = CopyDefaults(PROFILE_DEFAULTS, root.profiles.account)
    return root.profiles.account
end

local function GetDB()
    local root = EnsureProfileRoot()
    return GetProfileDB(root.profileScope)
end

local function GetProfileDisplayName(scope)
    scope = NormalizeProfileScope(scope or EnsureProfileRoot().profileScope)

    if scope == PROFILE_SCOPE_CHARACTER then
        return "Character: " .. GetCharacterProfileKey()
    end

    if scope == PROFILE_SCOPE_CLASS then
        local className, classFile

        if UnitClass then
            className, classFile = UnitClass("player")
        end

        return "Class: " .. tostring(className or classFile or "Unknown")
    end

    return "Account-wide"
end

local function GetProfileScope()
    return EnsureProfileRoot().profileScope
end

local function SetProfileScope(scope)
    local root = EnsureProfileRoot()
    root.profileScope = NormalizeProfileScope(scope)
    GetProfileDB(root.profileScope)
    return root.profileScope
end

local function GetProfileScopeOptions()
    return {
        { key = PROFILE_SCOPE_ACCOUNT, label = "Account-wide", detail = "Shared by every character." },
        { key = PROFILE_SCOPE_CHARACTER, label = "This Character", detail = GetCharacterProfileKey() },
        { key = PROFILE_SCOPE_CLASS, label = "This Class", detail = GetProfileDisplayName(PROFILE_SCOPE_CLASS) },
    }
end

local function CopyProfile(sourceScope, targetScope)
    sourceScope = NormalizeProfileScope(sourceScope)
    targetScope = NormalizeProfileScope(targetScope)

    if sourceScope == targetScope then
        return false
    end

    local source = GetProfileDB(sourceScope)
    local target = GetProfileDB(targetScope)

    for key in pairs(target) do
        target[key] = nil
    end

    for key in pairs(PROFILE_DEFAULTS) do
        target[key] = CopyTable(source[key])
    end

    CopyDefaults(PROFILE_DEFAULTS, target)
    return true
end

local function ResetProfile(scope)
    local profile = GetProfileDB(scope)

    for key in pairs(profile) do
        profile[key] = nil
    end

    CopyDefaults(PROFILE_DEFAULTS, profile)
    return true
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

local function PlayerLevel()
    if UnitLevel then
        return UnitLevel("player")
    end

    return nil
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

local function GetMountDetails(mountID)
    mountID = tonumber(mountID)
    if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoByID then
        return nil
    end

    local name, spellID, icon, isActive, isUsable, sourceType, isFavorite,
        isFactionSpecific, faction, shouldHideOnChar, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)

    return {
        mountID = mountID,
        name = name,
        spellID = spellID,
        icon = icon,
        isActive = isActive,
        isUsable = isUsable,
        sourceType = sourceType,
        isFavorite = isFavorite,
        isFactionSpecific = isFactionSpecific,
        faction = faction,
        shouldHideOnChar = shouldHideOnChar,
        isCollected = isCollected,
    }
end

local function FindMountIDBySpellID(spellID)
    spellID = tonumber(spellID)
    if not spellID or not C_MountJournal then
        return nil
    end

    if C_MountJournal.GetMountFromSpell then
        local ok, mountID = pcall(C_MountJournal.GetMountFromSpell, spellID)

        if ok and mountID then
            return tonumber(mountID)
        end
    end

    if not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then
        return nil
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local _, mountSpellID = C_MountJournal.GetMountInfoByID(mountID)

        if tonumber(mountSpellID) == spellID then
            return mountID
        end
    end

    return nil
end

local function GetHelpfulAuraData(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")

        if aura then
            return {
                name = aura.name,
                icon = aura.icon,
                spellID = aura.spellId or aura.spellID,
            }
        end
    end

    if UnitAura then
        local name, icon, _, _, _, _, _, _, _, spellID = UnitAura(unit, index, "HELPFUL")

        if name then
            return {
                name = name,
                icon = icon,
                spellID = spellID,
            }
        end
    end

    return nil
end

local function GetActiveMountID()
    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local details = GetMountDetails(mountID)

        if details and details.isActive then
            return mountID
        end
    end

    return nil
end

local function GetTargetMountMatch()
    if not UnitExists or not UnitExists("target") then
        return {
            available = false,
            status = "No target selected.",
        }
    end

    local detectedMountName
    local detectedButUnavailable

    for index = 1, 40 do
        local aura = GetHelpfulAuraData("target", index)

        if not aura then
            break
        end

        local mountID = FindMountIDBySpellID(aura.spellID)

        if mountID then
            local details = GetMountDetails(mountID)
            local mountName = details and details.name or aura.name or ("Mount " .. tostring(mountID))

            detectedMountName = detectedMountName or mountName

            if details and details.isCollected and details.isUsable then
                return {
                    available = true,
                    mountID = mountID,
                    mountName = mountName,
                    icon = details.icon or aura.icon,
                    status = "Match target: " .. tostring(mountName),
                }
            end

            if details and details.isCollected then
                detectedButUnavailable = "You own " .. tostring(mountName) .. ", but it is not usable here."
            else
                detectedButUnavailable = "Target is using " .. tostring(mountName) .. ", which is not collected."
            end
        end
    end

    if detectedButUnavailable then
        return {
            available = false,
            mountName = detectedMountName,
            status = detectedButUnavailable,
        }
    end

    return {
        available = false,
        status = "Target has no matchable mounted aura.",
    }
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

local function TrimText(text)
    if not text then return "" end

    return tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetMountGroupsTable()
    local db = GetDB()
    db.mountGroups = db.mountGroups or {}
    return db.mountGroups
end

local function GetMountGroupNames()
    local names = {}

    for groupName, mounts in pairs(GetMountGroupsTable()) do
        if type(groupName) == "string" and type(mounts) == "table" then
            names[#names + 1] = groupName
        end
    end

    table.sort(names)
    return names
end

local function MountGroupExists(groupName)
    groupName = TrimText(groupName)
    return groupName ~= "" and type(GetMountGroupsTable()[groupName]) == "table"
end

local function CreateMountGroup(groupName)
    groupName = TrimText(groupName)
    if groupName == "" then return false end

    local groups = GetMountGroupsTable()
    groups[groupName] = groups[groupName] or {}

    return true, groupName
end

local function DeleteMountGroup(groupName)
    groupName = TrimText(groupName)
    if groupName == "" then return false end

    local db = GetDB()
    local groups = GetMountGroupsTable()

    groups[groupName] = nil

    if db.activeMountGroup == groupName then
        db.activeMountGroup = nil
    end

    return true
end

local function GetActiveMountGroup()
    local db = GetDB()

    if MountGroupExists(db.activeMountGroup) then
        return db.activeMountGroup
    end

    db.activeMountGroup = nil
    return nil
end

local function SetActiveMountGroup(groupName)
    groupName = TrimText(groupName)

    local db = GetDB()
    if groupName == "" then
        db.activeMountGroup = nil
        return true
    end

    if not MountGroupExists(groupName) then
        return false
    end

    db.activeMountGroup = groupName
    return true
end

local function AddMountToGroup(groupName, mountID)
    groupName = TrimText(groupName)
    mountID = tonumber(mountID)

    if groupName == "" or not mountID then return false end

    local groups = GetMountGroupsTable()
    groups[groupName] = groups[groupName] or {}
    groups[groupName][mountID] = true
    groups[groupName][tostring(mountID)] = nil

    return true
end

local function RemoveMountFromGroup(groupName, mountID)
    groupName = TrimText(groupName)
    mountID = tonumber(mountID)

    if groupName == "" or not mountID then return false end

    local group = GetMountGroupsTable()[groupName]
    if not group then return false end

    group[mountID] = nil
    group[tostring(mountID)] = nil

    return true
end

local function MountIsInGroup(groupName, mountID)
    groupName = TrimText(groupName)
    mountID = tonumber(mountID)

    if groupName == "" or not mountID then return false end

    local group = GetMountGroupsTable()[groupName]
    return group and (group[mountID] == true or group[tostring(mountID)] == true) or false
end

local function MountPassesActiveGroup(mountID)
    local activeGroup = GetActiveMountGroup()
    if not activeGroup then return true end

    return MountIsInGroup(activeGroup, mountID)
end

local function GetMountGroupMountIDs(groupName)
    groupName = TrimText(groupName)

    local ids = {}
    local seen = {}
    local group = GetMountGroupsTable()[groupName]

    if not group then return ids end

    for mountID, value in pairs(group) do
        local numericID = tonumber(mountID)
        if value and numericID and not seen[numericID] then
            seen[numericID] = true
            ids[#ids + 1] = numericID
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

local serviceMountNameLookup

local function GetServiceMountNameLookup()
    if serviceMountNameLookup then
        return serviceMountNameLookup
    end

    serviceMountNameLookup = {}

    for _, priorityList in pairs(RSM_SERVICE_MOUNT_PRIORITY) do
        for _, mountName in ipairs(priorityList) do
            serviceMountNameLookup[NormalizeMountName(mountName)] = true
        end
    end

    return serviceMountNameLookup
end

local function IsServiceMountName(name)
    if not name then return false end

    return GetServiceMountNameLookup()[NormalizeMountName(name)] == true
end

local rideAlongMountPoolLookup

local function GetRideAlongMountPoolLookup()
    if rideAlongMountPoolLookup then
        return rideAlongMountPoolLookup
    end

    rideAlongMountPoolLookup = {}

    for poolKey, mountNames in pairs(RSM_RIDE_ALONG_MOUNT_POOLS) do
        for _, mountName in ipairs(mountNames) do
            rideAlongMountPoolLookup[NormalizeMountName(mountName)] = poolKey
        end
    end

    return rideAlongMountPoolLookup
end

local function GetRideAlongMountPool(name)
    if not name then return nil end

    return GetRideAlongMountPoolLookup()[NormalizeMountName(name)]
end

local function IsBelowNormalMountLevel()
    local level = PlayerLevel()
    return level and level < 10
end

local function PreferFlyingRideAlongMount()
    return CanFlyHere() and not IsBelowNormalMountLevel()
end

local function IsRideAlongMountAllowed(name)
    local poolKey = GetRideAlongMountPool(name)
    if not poolKey then return false end

    if poolKey == "flying" then
        return PreferFlyingRideAlongMount()
    end

    if poolKey == "ground" then
        return not PreferFlyingRideAlongMount() and not IsBelowNormalMountLevel()
    end

    if poolKey == "lowLevelGround" then
        return IsBelowNormalMountLevel()
    end

    return false
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

local PickLeastUsedMount

local function GetRecentAvoidCount()
    local count = tonumber(GetDB().recentAvoidCount) or 0

    if count < 0 then
        count = 0
    elseif count > 20 then
        count = 20
    end

    GetDB().recentAvoidCount = count
    return count
end

local function RecordRecentMount(mountID)
    mountID = tonumber(mountID)
    if not mountID then return end

    local db = GetDB()
    db.recentMounts = db.recentMounts or {}

    for index = #db.recentMounts, 1, -1 do
        if tonumber(db.recentMounts[index]) == mountID then
            table.remove(db.recentMounts, index)
        end
    end

    table.insert(db.recentMounts, 1, mountID)

    while #db.recentMounts > 20 do
        table.remove(db.recentMounts)
    end
end

local function ClearRecentMounts()
    GetDB().recentMounts = {}
end

local function GetRecentMountIDs(limit)
    local db = GetDB()
    db.recentMounts = db.recentMounts or {}

    local ids = {}
    limit = tonumber(limit) or #db.recentMounts

    for index, mountID in ipairs(db.recentMounts) do
        if index > limit then break end
        ids[#ids + 1] = tonumber(mountID)
    end

    return ids
end

local function BuildRecentMountSet()
    local avoidCount = GetRecentAvoidCount()
    local recentSet = {}

    if avoidCount <= 0 then
        return recentSet, avoidCount
    end

    for _, mountID in ipairs(GetRecentMountIDs(avoidCount)) do
        if mountID then
            recentSet[mountID] = true
        end
    end

    return recentSet, avoidCount
end

local function ApplyRecentAvoidance(mountIDs)
    if not mountIDs or #mountIDs == 0 then
        return mountIDs or {}, 0, false
    end

    local recentSet = BuildRecentMountSet()
    local filtered = {}
    local removed = 0

    for _, mountID in ipairs(mountIDs) do
        if recentSet[mountID] then
            removed = removed + 1
        else
            filtered[#filtered + 1] = mountID
        end
    end

    if #filtered == 0 then
        return mountIDs, 0, false
    end

    return filtered, removed, removed > 0
end

local randomPreviewReservation

local function MountIDInList(mountID, mountIDs)
    mountID = tonumber(mountID)
    if not mountID or not mountIDs then return false end

    for _, candidateID in ipairs(mountIDs) do
        if tonumber(candidateID) == mountID then
            return true
        end
    end

    return false
end

local function BuildRecentSignaturePart()
    local recentIDs = GetRecentMountIDs(GetRecentAvoidCount())
    local parts = {}

    for _, mountID in ipairs(recentIDs) do
        parts[#parts + 1] = tostring(mountID)
    end

    return table.concat(parts, ",")
end

local function BuildRandomSelectionSignature(pools, poolKey, poolMounts, filteredMounts)
    local db = GetDB()
    local counts = pools.counts or {}

    return table.concat({
        tostring(poolKey or ""),
        tostring(pools.canFly),
        tostring(pools.isSurface),
        tostring(pools.isUnderwater),
        tostring(pools.activeGroup or ""),
        tostring(db.randomFavoritesOnly),
        tostring(db.excludeServiceMountsFromRandom),
        tostring(db.preferGroundWhenNotFlyable),
        tostring(GetRecentAvoidCount()),
        BuildRecentSignaturePart(),
        tostring(pools.all and #pools.all or 0),
        tostring(poolMounts and #poolMounts or 0),
        tostring(filteredMounts and #filteredMounts or 0),
        tostring(counts.blacklisted or 0),
        tostring(counts.serviceExcluded or 0),
        tostring(counts.groupExcluded or 0),
        tostring(counts.favoritesExcluded or 0),
    }, "|")
end

local function PickMountFromPool(mountIDs)
    local filteredMounts, recentExcluded, usedRecentAvoidance = ApplyRecentAvoidance(mountIDs)

    return PickLeastUsedMount(filteredMounts), {
        originalCount = mountIDs and #mountIDs or 0,
        filteredCount = filteredMounts and #filteredMounts or 0,
        recentExcluded = recentExcluded,
        usedRecentAvoidance = usedRecentAvoidance,
    }
end

local function SummonTrackedMount(mountID)
    mountID = tonumber(mountID)
    if not mountID then return end

    local db = GetDB()
    db.lastMountID = mountID

    RecordMountUsage(mountID)
    RecordRecentMount(mountID)
    randomPreviewReservation = nil

    if C_MountJournal and C_MountJournal.SummonByID then
        C_MountJournal.SummonByID(mountID)
    end

    if RandomSmartMountUI and RandomSmartMountUI.RefreshPreview then
        RandomSmartMountUI.RefreshPreview()
    end

    if RandomSmartMountUI and RandomSmartMountUI.UpdateMountMatchButton then
        RandomSmartMountUI.UpdateMountMatchButton()
    end
end

local function MatchTargetMount()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        Print("Cannot match target mount while in combat.")
        return false
    end

    local match = GetTargetMountMatch()

    if not match or not match.available or not match.mountID then
        Print(match and match.status or "No target mount match found.")
        return false
    end

    local activeMountID = GetActiveMountID()

    if activeMountID and tonumber(activeMountID) == tonumber(match.mountID) then
        Print("Already using target mount: " .. tostring(match.mountName or match.mountID) .. ".")
        return true
    end

    if IsPlayerMounted() then
        if Dismount then
            Dismount()
        end

        Print("Dismounted. Click Match Target Mount again to summon " .. tostring(match.mountName or match.mountID) .. ".")
        return false
    end

    SummonTrackedMount(match.mountID)
    Print("Matching target mount: " .. tostring(match.mountName or match.mountID) .. ".")
    return true
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

function PickLeastUsedMount(mountIDs)
    if not mountIDs or #mountIDs == 0 then return nil end

    local weighted = {}
    local totalWeight = 0

    for _, mountID in ipairs(mountIDs) do
        local used = GetMountUsage(mountID)
        local weight = 1 / math.sqrt(used + 1)

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

local function GetRideAlongMountCandidates()
    local candidates = {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return candidates
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, isUsable, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)

        if name
            and isCollected
            and isUsable
            and not IsMountBlacklisted(mountID)
            and IsRideAlongMountAllowed(name) then

            candidates[#candidates + 1] = mountID
        end
    end

    return candidates
end

local function GetRideAlongMountID()
    local db = GetDB()
    db.preferredServiceMounts = db.preferredServiceMounts or {}

    local preferredName = db.preferredServiceMounts.rideAlong
    if preferredName and preferredName ~= "" and IsRideAlongMountAllowed(preferredName) then
        local preferredMountID, preferredMountName = FindServiceMountByName(preferredName)
        if preferredMountID then
            return preferredMountID, preferredMountName
        end
    end

    local candidates = GetRideAlongMountCandidates()
    if #candidates == 0 then
        return nil
    end

    local mountID = PickMountFromPool(candidates)
    return mountID, GetMountName(mountID)
end

local function GetPriorityServiceMountID(serviceType)
    local db = GetDB()
    db.preferredServiceMounts = db.preferredServiceMounts or {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil
    end

    if serviceType == "rideAlong" then
        return GetRideAlongMountID()
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

local function AddMountToRandomPools(pools, mountID)
    pools.all[#pools.all + 1] = mountID

    local isFlyingMount = IsFlyingMount(mountID)
    local isWaterMount = IsWaterMount(mountID)

    if isWaterMount then
        pools.water[#pools.water + 1] = mountID
    end

    if isFlyingMount then
        pools.flying[#pools.flying + 1] = mountID

        if pools.isSurface then
            pools.surfaceFlying[#pools.surfaceFlying + 1] = mountID
        end
    elseif not isWaterMount then
        pools.ground[#pools.ground + 1] = mountID
    end
end

local function BuildRandomMountPools()
    local db = GetDB()

    EnsureMountJournalLoaded()

    local pools = {
        all = {},
        ground = {},
        flying = {},
        surfaceFlying = {},
        water = {},
        isSurface = IsPlayerSwimmingAtSurface(),
        isUnderwater = IsPlayerUnderwaterForMounts(),
        canFly = CanFlyHere(),
        activeGroup = GetActiveMountGroup(),
        counts = {
            scanned = 0,
            collectedUsable = 0,
            blacklisted = 0,
            serviceExcluded = 0,
            groupExcluded = 0,
            favoritesExcluded = 0,
            unusableOrUncollected = 0,
        },
    }

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        pools.unavailable = true
        return pools
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)

        pools.counts.scanned = pools.counts.scanned + 1

        if not name or not isCollected or not isUsable then
            pools.counts.unusableOrUncollected = pools.counts.unusableOrUncollected + 1
        elseif IsMountBlacklisted(mountID) then
            pools.counts.blacklisted = pools.counts.blacklisted + 1
        elseif db.excludeServiceMountsFromRandom ~= false and IsServiceMountName(name) then
            pools.counts.serviceExcluded = pools.counts.serviceExcluded + 1
        elseif not MountPassesActiveGroup(mountID) then
            pools.counts.groupExcluded = pools.counts.groupExcluded + 1
        elseif db.randomFavoritesOnly and not isFavorite then
            pools.counts.favoritesExcluded = pools.counts.favoritesExcluded + 1
        else
            pools.counts.collectedUsable = pools.counts.collectedUsable + 1
            AddMountToRandomPools(pools, mountID)
        end
    end

    return pools
end

local function GetPreferredRandomPool(pools)
    if pools.isSurface and #pools.surfaceFlying > 0 then
        return "surfaceFlying", "surface flying", pools.surfaceFlying
    end

    if pools.isUnderwater and #pools.water > 0 then
        return "water", "underwater", pools.water
    end

    if pools.canFly and #pools.flying > 0 then
        return "flying", "flying", pools.flying
    end

    if GetDB().preferGroundWhenNotFlyable and #pools.ground > 0 then
        return "ground", "ground", pools.ground
    end

    if #pools.all > 0 then
        return "all", "all eligible", pools.all
    end

    return nil, nil, {}
end

local function BuildRandomMountSelection(options)
    options = options or {}

    local pools = BuildRandomMountPools()
    local poolKey, poolLabel, poolMounts = GetPreferredRandomPool(pools)

    local selection = {
        pools = pools,
        poolKey = poolKey,
        poolLabel = poolLabel,
        poolSize = poolMounts and #poolMounts or 0,
        availableCount = #pools.all,
    }

    if pools.unavailable then
        selection.message = "Mount journal is unavailable."
        return selection
    end

    if GetDB().randomFavoritesOnly and #pools.all == 0 then
        selection.message = "Favorites Only is enabled, but no favorite mounts are selected."
        return selection
    end

    if not poolKey or not poolMounts or #poolMounts == 0 then
        selection.message = "No eligible mounts found."
        return selection
    end

    local filteredMounts, recentExcluded, usedRecentAvoidance = ApplyRecentAvoidance(poolMounts)
    local filterInfo = {
        originalCount = poolMounts and #poolMounts or 0,
        filteredCount = filteredMounts and #filteredMounts or 0,
        recentExcluded = recentExcluded,
        usedRecentAvoidance = usedRecentAvoidance,
    }
    local signature = BuildRandomSelectionSignature(pools, poolKey, poolMounts, filteredMounts)
    local mountID

    if options.useReservation
        and randomPreviewReservation
        and randomPreviewReservation.signature == signature
        and MountIDInList(randomPreviewReservation.mountID, filteredMounts) then

        mountID = randomPreviewReservation.mountID
        selection.usedPreviewReservation = true
    else
        if options.useReservation and randomPreviewReservation then
            randomPreviewReservation = nil
        end

        mountID = PickLeastUsedMount(filteredMounts)
    end

    selection.mountID = mountID
    selection.mountName = GetMountName(mountID)
    selection.filterInfo = filterInfo
    selection.signature = signature

    if options.reserveSelection and mountID then
        randomPreviewReservation = {
            mountID = mountID,
            signature = signature,
        }

        selection.reservedForNext = true
    end

    return selection
end

local function PickRandomMountID()
    local selection = BuildRandomMountSelection({ useReservation = true })

    if selection.message == "Favorites Only is enabled, but no favorite mounts are selected." then
        Print(selection.message)
    end

    return selection.mountID, selection.availableCount or 0
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

local function BoolText(value)
    return value and "yes" or "no"
end

local function AddPreviewLine(preview, text)
    preview.lines[#preview.lines + 1] = text
end

local function AddRandomSelectionPreviewLines(preview, selection)
    local pools = selection.pools or {}
    local counts = pools.counts or {}
    local activeGroup = pools.activeGroup
    local filterInfo = selection.filterInfo or {}

    AddPreviewLine(preview, "Flyable area: " .. BoolText(pools.canFly))
    AddPreviewLine(preview, "Swimming at surface: " .. BoolText(pools.isSurface))
    AddPreviewLine(preview, "Underwater: " .. BoolText(pools.isUnderwater))
    AddPreviewLine(preview, "Active group: " .. (activeGroup or "All eligible mounts"))
    AddPreviewLine(preview, "Eligible after filters: " .. tostring(selection.availableCount or 0))

    if selection.poolLabel then
        AddPreviewLine(preview, "Selected pool: " .. selection.poolLabel .. " (" .. tostring(selection.poolSize or 0) .. ")")
    end

    if GetRecentAvoidCount() > 0 then
        AddPreviewLine(
            preview,
            "Recent cooldown: avoiding last " .. tostring(GetRecentAvoidCount())
                .. " mount(s), skipped " .. tostring(filterInfo.recentExcluded or 0)
        )
    else
        AddPreviewLine(preview, "Recent cooldown: off")
    end

    if selection.reservedForNext then
        AddPreviewLine(preview, "Reserved next random pick: yes")
    elseif selection.usedPreviewReservation then
        AddPreviewLine(preview, "Using reserved preview pick: yes")
    end

    AddPreviewLine(preview, "Excluded by blacklist: " .. tostring(counts.blacklisted or 0))
    AddPreviewLine(preview, "Excluded service mounts: " .. tostring(counts.serviceExcluded or 0))
    AddPreviewLine(preview, "Excluded by active group: " .. tostring(counts.groupExcluded or 0))
    AddPreviewLine(preview, "Excluded by Favorites Only: " .. tostring(counts.favoritesExcluded or 0))
end

local function GetSmartMountPreview()
    local db = GetDB()
    local preview = {
        lines = {},
        summary = "No action selected.",
    }

    local fallingAction = GetFallingRescueAction()
    if fallingAction then
        preview.summary = "Would cast falling rescue: " .. tostring(fallingAction.spell)
        AddPreviewLine(preview, preview.summary)
        return preview
    end

    if IsPlayerMounted() then
        preview.summary = "Would dismount."
        AddPreviewLine(preview, preview.summary)
        return preview
    end

    if db.enabled == false then
        preview.summary = "Smart mounting is disabled."
        AddPreviewLine(preview, preview.summary)
        return preview
    end

    local class = PlayerClass()
    local race = PlayerRace()

    if not IsOutdoors() then
        if db.useDruidTravelForm and class == "DRUID" then
            local catFormName = GetSpellName(db.druidCatFormSpellID)

            if catFormName and IsSpellKnownByPlayer(db.druidCatFormSpellID) and SpellUsable(db.druidCatFormSpellID) then
                preview.summary = "Would cast: " .. catFormName
                AddPreviewLine(preview, preview.summary)
                return preview
            end
        end

        preview.summary = "No mount: indoors."
        AddPreviewLine(preview, preview.summary)
        return preview
    end

    if db.useDruidTravelForm and class == "DRUID" then
        local spellName = GetSpellName(db.druidTravelSpellID)
        if spellName and IsSpellKnownByPlayer(db.druidTravelSpellID) and SpellUsable(db.druidTravelSpellID) then
            preview.summary = "Would cast: " .. spellName
            AddPreviewLine(preview, preview.summary)
            return preview
        end
    end

    if IsPlayerUnderwaterForMounts() then
        local selection = BuildRandomMountSelection({ reserveSelection = true })
        preview.selection = selection
        preview.mountID = selection.mountID
        preview.mountName = selection.mountName

        if selection.mountID then
            preview.summary = "Would summon underwater mount: " .. tostring(selection.mountName or selection.mountID)
        else
            preview.summary = selection.message or "No underwater mount found."
        end

        AddPreviewLine(preview, preview.summary)
        AddRandomSelectionPreviewLines(preview, selection)
        return preview
    end

    if db.useDracthyrSoar and race == "Dracthyr" and not IsPlayerUnderwaterForMounts() then
        local spellName = GetSpellName(db.dracthyrSoarSpellID)
        if CanFlyHere() and spellName and IsSpellKnownByPlayer(db.dracthyrSoarSpellID) and SpellUsable(db.dracthyrSoarSpellID) then
            preview.summary = "Would cast: " .. spellName
            AddPreviewLine(preview, preview.summary)
            return preview
        end
    end

    if db.preferredMount and db.preferredMount ~= "" then
        local preferredMountID, preferredMountName = FindUsableMountByName(db.preferredMount)

        if preferredMountID then
            preview.summary = "Would summon preferred mount: " .. tostring(preferredMountName)
            preview.mountID = preferredMountID
            preview.mountName = preferredMountName
            AddPreviewLine(preview, preview.summary)
            return preview
        end

        AddPreviewLine(preview, "Preferred mount unavailable: " .. tostring(db.preferredMount))
    end

    local selection = BuildRandomMountSelection({ reserveSelection = true })
    preview.selection = selection
    preview.mountID = selection.mountID
    preview.mountName = selection.mountName

    if selection.mountID then
        preview.summary = "Would summon: " .. tostring(selection.mountName or selection.mountID)
    else
        preview.summary = selection.message or "No eligible mount found."
    end

    AddPreviewLine(preview, preview.summary)
    AddRandomSelectionPreviewLines(preview, selection)

    return preview
end

local SMART_MOUNT_MACRO_PREFIX = "/dismount [mounted]\n/stopmacro [mounted]\n/stopmacro [combat]\n"

local function BuildSummonMountMacro(mountID)
    return SMART_MOUNT_MACRO_PREFIX .. "/run RandomSmartMountAPI.SummonMount(" .. tostring(mountID) .. ")"
end

local function BuildSmartMountMacro()
    local db = GetDB()

    if IsPlayerMounted() then
        return "/dismount [mounted]\n/stopmacro [mounted]"
    end

	if db.enabled == false then
		return SMART_MOUNT_MACRO_PREFIX .. "/run print('RandomSmartMount: Smart mounting is disabled.')"
	end

    local class = PlayerClass()
    local race = PlayerRace()

	if not IsOutdoors() then
		if db.useDruidTravelForm and class == "DRUID" then
            local catFormName = GetSpellName(db.druidCatFormSpellID)

            if catFormName and IsSpellKnownByPlayer(db.druidCatFormSpellID) and SpellUsable(db.druidCatFormSpellID) then
                return SMART_MOUNT_MACRO_PREFIX .. "/cast " .. catFormName
            end
        end

        return SMART_MOUNT_MACRO_PREFIX .. "/run print('RandomSmartMount: You are indoors.')"
    end

    if db.useDruidTravelForm and class == "DRUID" then
        local spellName = GetSpellName(db.druidTravelSpellID)
        if spellName and IsSpellKnownByPlayer(db.druidTravelSpellID) and SpellUsable(db.druidTravelSpellID) then
            return SMART_MOUNT_MACRO_PREFIX .. "/cast " .. spellName
        end
    end

    if IsPlayerUnderwaterForMounts() then
        local mountID = PickRandomMountID()
        if mountID then
            return BuildSummonMountMacro(mountID)
        end
    end

    if db.useDracthyrSoar and race == "Dracthyr" and not IsPlayerUnderwaterForMounts() then
        local spellName = GetSpellName(db.dracthyrSoarSpellID)
        if CanFlyHere() and spellName and IsSpellKnownByPlayer(db.dracthyrSoarSpellID) and SpellUsable(db.dracthyrSoarSpellID) then
            return SMART_MOUNT_MACRO_PREFIX .. "/cast " .. spellName
        end
    end

	-- Preferred Smart Mount
	-- If selected, try this mount before random selection.
	if db.preferredMount and db.preferredMount ~= "" then
		local preferredMountID = FindUsableMountByName(db.preferredMount)

		if preferredMountID then
			return BuildSummonMountMacro(preferredMountID)
		end
	end

    local mountID, availableCount = PickRandomMountID()

    if mountID then
        return BuildSummonMountMacro(mountID)
    end

    if availableCount > 0 then
        return SMART_MOUNT_MACRO_PREFIX .. "/run print('RandomSmartMount: Mounting is not allowed here right now.')"
    end

    return SMART_MOUNT_MACRO_PREFIX .. "/run print('RandomSmartMount: No usable mounts found.')"
end

local function SummonServiceMount(serviceType)
    if InCombatLockdown() then
        Print("Cannot summon a mount while in combat.")
        return
    end

    local mountID = GetPriorityServiceMountID(serviceType)

    if mountID then
        SummonTrackedMount(mountID)
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
        C_Timer.After(0, function()
            UpdateSmartButton()
        end)
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
RandomSmartMountAPI.GetProfileScope = GetProfileScope
RandomSmartMountAPI.SetProfileScope = SetProfileScope
RandomSmartMountAPI.GetProfileDisplayName = GetProfileDisplayName
RandomSmartMountAPI.GetProfileScopeOptions = GetProfileScopeOptions
RandomSmartMountAPI.CopyProfile = CopyProfile
RandomSmartMountAPI.ResetProfile = ResetProfile
RandomSmartMountAPI.GetMountName = GetMountName
RandomSmartMountAPI.GetMountDetails = GetMountDetails
RandomSmartMountAPI.GetTargetMountMatch = GetTargetMountMatch
RandomSmartMountAPI.MatchTargetMount = MatchTargetMount
RandomSmartMountAPI.GetMountUsage = GetMountUsage
RandomSmartMountAPI.GetTotalMountUses = GetTotalMountUses
RandomSmartMountAPI.CountUsageEntries = CountUsageEntries
RandomSmartMountAPI.GetSortedUsageMounts = GetSortedUsageMounts
RandomSmartMountAPI.ClearMountUsage = ClearMountUsage
RandomSmartMountAPI.RecordMountUsage = RecordMountUsage
RandomSmartMountAPI.ClearRecentMounts = ClearRecentMounts
RandomSmartMountAPI.GetRecentMountIDs = GetRecentMountIDs
RandomSmartMountAPI.GetRecentAvoidCount = GetRecentAvoidCount
RandomSmartMountAPI.SummonMount = SummonTrackedMount
RandomSmartMountAPI.IsMountBlacklisted = IsMountBlacklisted
RandomSmartMountAPI.SetMountBlacklisted = SetMountBlacklisted
RandomSmartMountAPI.GetBlacklistedMountIDs = GetBlacklistedMountIDs
RandomSmartMountAPI.GetMountGroupNames = GetMountGroupNames
RandomSmartMountAPI.CreateMountGroup = CreateMountGroup
RandomSmartMountAPI.DeleteMountGroup = DeleteMountGroup
RandomSmartMountAPI.GetActiveMountGroup = GetActiveMountGroup
RandomSmartMountAPI.SetActiveMountGroup = SetActiveMountGroup
RandomSmartMountAPI.AddMountToGroup = AddMountToGroup
RandomSmartMountAPI.RemoveMountFromGroup = RemoveMountFromGroup
RandomSmartMountAPI.MountIsInGroup = MountIsInGroup
RandomSmartMountAPI.GetMountGroupMountIDs = GetMountGroupMountIDs
RandomSmartMountAPI.GetLastMountID = function()
    return GetDB().lastMountID
end
RandomSmartMountAPI.NormalizeMountName = NormalizeMountName
RandomSmartMountAPI.GetSmartMountPreview = GetSmartMountPreview

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

    if msg == "resetrecent" then
        ClearRecentMounts()
        Print("Recent mount history reset.")
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

	if msg == "pickdebug" then
		local mountID, availableCount = PickRandomMountID()

		Print("Pick Debug")
		Print("Available pool size: " .. tostring(availableCount))

		if mountID then
			Print("Selected mount: " .. tostring(GetMountName(mountID)) .. " (" .. tostring(mountID) .. ")")
			Print("Usage count: " .. tostring(GetMountUsage(mountID)))
			Print("Weight: " .. tostring(1 / math.sqrt(GetMountUsage(mountID) + 1)))
		else
			Print("No mount selected.")
		end

		return
	end

    if msg == "preview" or msg == "pickpreview" then
        local preview = GetSmartMountPreview()

        Print(preview.summary or "Preview unavailable.")

        for _, line in ipairs(preview.lines or {}) do
            if line ~= preview.summary then
                Print(line)
            end
        end

        return
    end

    if msg == "match" or msg == "targetmatch" then
        MatchTargetMount()
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
	Print("/rsm pickdebug - show next smart mount pick and weighting")
    Print("/rsm macro - show current smart mount macro")
    Print("/rsm vendor - summon best owned vendor mount")
    Print("/rsm ah - summon best owned auction house mount")
    Print("/rsm ride - summon best owned ride-along mount")
    Print("/rsm match - match your target's mount if owned")
    Print("/rsm last - show last summoned mount ID")
    Print("/rsm usage - show mount usage tracking count")
    Print("/rsm resetusage - reset weighted usage tracking")
    Print("/rsm resetrecent - reset recent mount cooldown history")
    Print("/rsm preview - show what smart mount would pick now")
    Print("/rsm blacklistlast - blacklist last summoned mount")
    Print("/rsm clearblacklist - clear blacklist")
end
