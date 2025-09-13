--[[
    CurrencyConstants.lua
    
    Defines supported currencies, their metadata, and version comparison utilities
    for the Accountant Classic Currency Tracker module.
]]

local addonName, addonTable = ...

-- Create the CurrencyConstants namespace
local CurrencyConstants = {}

-- Version comparison utilities
CurrencyConstants.VersionUtils = {
    -- Convert version string (e.g., "11.0.0") to comparable number (e.g., 110000)
    ParseVersion = function(versionString)
        if not versionString or type(versionString) ~= "string" then
            return 0
        end
        
        local major, minor, patch = versionString:match("(%d+)%.(%d+)%.(%d+)")
        if not major or not minor or not patch then
            return 0
        end
        
        return tonumber(major) * 10000 + tonumber(minor) * 100 + tonumber(patch)
    end,
    
    -- Compare two version numbers (returns -1, 0, or 1)
    CompareVersions = function(version1, version2)
        local v1 = type(version1) == "string" and CurrencyConstants.VersionUtils.ParseVersion(version1) or version1
        local v2 = type(version2) == "string" and CurrencyConstants.VersionUtils.ParseVersion(version2) or version2
        
        if v1 < v2 then
            return -1
        elseif v1 > v2 then
            return 1
        else
            return 0
        end
    end,
    
    -- Get current WoW version as comparable number
    GetCurrentWoWVersion = function()
        local version = GetBuildInfo()
        if version then
            return CurrencyConstants.VersionUtils.ParseVersion(version)
        end
        return 0
    end,
    
    -- Check if current client supports a minimum version
    IsVersionSupported = function(minVersion)
        local currentVersion = CurrencyConstants.VersionUtils.GetCurrentWoWVersion()
        local requiredVersion = type(minVersion) == "string" and CurrencyConstants.VersionUtils.ParseVersion(minVersion) or minVersion
        return currentVersion >= requiredVersion
    end
}

-- Expansion definitions for grouping currencies
CurrencyConstants.Expansions = {
    CLASSIC = {
        name = "Classic",
        minVersion = 10000, -- 1.0.0
        order = 1
    },
    TBC = {
        name = "The Burning Crusade",
        minVersion = 20000, -- 2.0.0
        order = 2
    },
    WOTLK = {
        name = "Wrath of the Lich King",
        minVersion = 30000, -- 3.0.0
        order = 3
    },
    CATACLYSM = {
        name = "Cataclysm",
        minVersion = 40000, -- 4.0.0
        order = 4
    },
    MOP = {
        name = "Mists of Pandaria",
        minVersion = 50000, -- 5.0.0
        order = 5
    },
    WOD = {
        name = "Warlords of Draenor",
        minVersion = 60000, -- 6.0.0
        order = 6
    },
    LEGION = {
        name = "Legion",
        minVersion = 70000, -- 7.0.0
        order = 7
    },
    BFA = {
        name = "Battle for Azeroth",
        minVersion = 80000, -- 8.0.0
        order = 8
    },
    SHADOWLANDS = {
        name = "Shadowlands",
        minVersion = 90000, -- 9.0.0
        order = 9
    },
    DRAGONFLIGHT = {
        name = "Dragonflight",
        minVersion = 100000, -- 10.0.0
        order = 10
    },
    TWW = {
        name = "The War Within",
        minVersion = 110000, -- 11.0.0
        order = 11
    }
}

-- Supported currencies with metadata
-- Organized by expansion and patch for easy filtering and dropdown grouping
CurrencyConstants.SupportedCurrencies = {
    -- The War Within currencies
    [3008] = { -- Valorstones (PRIMARY TEST CURRENCY)
        id = 3008,
        name = "Valorstones",
        icon = "Interface\\Icons\\inv_10_gearupgrade_valorstones",
        expansion = "TWW",
        expansionName = "The War Within",
        patch = "11.0.0",
        minVersion = 110000,
        maxQuantity = 2000,
        isTracked = true,
        description = "Used to upgrade gear in The War Within",
        category = "Upgrade Materials"
    },
    
    [3089] = { -- Residual Memories
        id = 3089,
        name = "Residual Memories",
        icon = "Interface\\Icons\\inv_misc_enchantedscroll",
        expansion = "TWW",
        expansionName = "The War Within",
        patch = "11.0.0",
        minVersion = 110000,
        maxQuantity = 1000,
        isTracked = false, -- Not tracked by default, but available
        description = "Memories from the depths of Khaz Algar",
        category = "Special"
    },
    
    [3056] = { -- Kej
        id = 3056,
        name = "Kej",
        icon = "Interface\\Icons\\inv_misc_coin_01",
        expansion = "TWW",
        expansionName = "The War Within",
        patch = "11.0.0",
        minVersion = 110000,
        maxQuantity = 0, -- No limit
        isTracked = false,
        description = "Currency of the earthen",
        category = "Faction"
    },
    
    [3220] = { -- Vintage Kaja'Cola Can
        id = 3220,
        name = "Vintage Kaja'Cola Can",
        icon = "Interface\\Icons\\inv_drink_24",
        expansion = "TWW",
        expansionName = "The War Within",
        patch = "11.1.0",
        minVersion = 110100,
        maxQuantity = 100,
        isTracked = false,
        description = "Collectible vintage cola cans",
        category = "Collectible"
    },
    
    [2803] = { -- Undercoin
        id = 2803,
        name = "Undercoin",
        icon = "Interface\\Icons\\inv_misc_coin_02",
        expansion = "TWW",
        expansionName = "The War Within",
        patch = "11.2.0",
        minVersion = 110200,
        maxQuantity = 0,
        isTracked = false,
        description = "Currency of the underground markets",
        category = "Faction"
    },
    
    [3284] = { -- Weathered Ethereal Crest
        id = 3284,
        name = "Weathered Ethereal Crest",
        icon = "Interface\\Icons\\inv_misc_enchantedscroll",
        expansion = "TWW",
        expansionName = "The War Within",
        patch = "11.2.0",
        minVersion = 110200,
        maxQuantity = 90,
        isTracked = false,
        description = "Upgrade material for high-level gear",
        category = "Upgrade Materials"
    },
    
    -- Dragonflight currencies (for testing cross-expansion support)
    [2815] = { -- Resonance Crystals
        id = 2815,
        name = "Resonance Crystals",
        icon = "Interface\\Icons\\inv_misc_gem_pearl_13",
        expansion = "DRAGONFLIGHT",
        expansionName = "Dragonflight",
        patch = "10.0.0",
        minVersion = 100000,
        maxQuantity = 2000,
        isTracked = false,
        description = "Crystals that resonate with dragon magic",
        category = "Upgrade Materials"
    }
}

-- Currency categories for organization
CurrencyConstants.Categories = {
    UPGRADE_MATERIALS = "Upgrade Materials",
    FACTION = "Faction",
    SPECIAL = "Special",
    COLLECTIBLE = "Collectible",
    SEASONAL = "Seasonal"
}

-- Utility functions for currency management
CurrencyConstants.Utils = {
    -- Get all currencies for a specific expansion
    GetCurrenciesByExpansion = function(expansionKey)
        local currencies = {}
        for id, currency in pairs(CurrencyConstants.SupportedCurrencies) do
            if currency.expansion == expansionKey then
                currencies[id] = currency
            end
        end
        return currencies
    end,
    
    -- Get currencies available for current WoW version
    GetCurrenciesForCurrentVersion = function()
        local currentVersion = CurrencyConstants.VersionUtils.GetCurrentWoWVersion()
        local availableCurrencies = {}
        
        for id, currency in pairs(CurrencyConstants.SupportedCurrencies) do
            if currentVersion >= currency.minVersion then
                availableCurrencies[id] = currency
            end
        end
        
        return availableCurrencies
    end,
    
    -- Get currencies by patch version
    GetCurrenciesByPatch = function(patchVersion)
        local currencies = {}
        for id, currency in pairs(CurrencyConstants.SupportedCurrencies) do
            if currency.patch == patchVersion then
                currencies[id] = currency
            end
        end
        return currencies
    end,
    
    -- Check if a currency is supported
    IsCurrencySupported = function(currencyID)
        return CurrencyConstants.SupportedCurrencies[currencyID] ~= nil
    end,
    
    -- Get currency info by ID
    GetCurrencyInfo = function(currencyID)
        return CurrencyConstants.SupportedCurrencies[currencyID]
    end,
    
    -- Get all tracked currencies (enabled by default)
    GetTrackedCurrencies = function()
        local trackedCurrencies = {}
        for id, currency in pairs(CurrencyConstants.SupportedCurrencies) do
            if currency.isTracked then
                trackedCurrencies[id] = currency
            end
        end
        return trackedCurrencies
    end,
    
    -- Get currencies grouped by expansion for dropdown display
    GetCurrenciesGroupedByExpansion = function()
        local grouped = {}
        local currentVersion = CurrencyConstants.VersionUtils.GetCurrentWoWVersion()
        
        -- Initialize expansion groups
        for expKey, expData in pairs(CurrencyConstants.Expansions) do
            if currentVersion >= expData.minVersion then
                grouped[expKey] = {
                    expansion = expData,
                    patches = {}
                }
            end
        end
        
        -- Group currencies by expansion and patch
        for id, currency in pairs(CurrencyConstants.SupportedCurrencies) do
            if currentVersion >= currency.minVersion and grouped[currency.expansion] then
                local patch = currency.patch
                if not grouped[currency.expansion].patches[patch] then
                    grouped[currency.expansion].patches[patch] = {}
                end
                table.insert(grouped[currency.expansion].patches[patch], currency)
            end
        end
        
        return grouped
    end
}

-- UI Constants
CurrencyConstants.UI = {
    GOLD_TAB_INDEX = 1,
    CURRENCY_TAB_INDEX = 2
}

-- Default currency settings
CurrencyConstants.Defaults = {
    PRIMARY_CURRENCY = 3008, -- Valorstones as primary test currency
    TRACKING_ENABLED = true,
    MAX_HISTORY_DAYS = 365, -- Keep 1 year of history by default
    UPDATE_THROTTLE_MS = 100 -- Minimum time between updates in milliseconds
}

-- Export the module to CurrencyTracker namespace
CurrencyTracker = CurrencyTracker or {}
CurrencyTracker.Constants = CurrencyConstants

-- Source code tokens map
-- Numeric codes from CURRENCY_DISPLAY_UPDATE mapped to stable tokens.
-- Keys should be absolute values; direction is represented by sign at usage site.
CurrencyTracker.SourceCodeTokens = CurrencyTracker.SourceCodeTokens or {
    -- Official names mirrored from Enum.CurrencySource
    [0]  = "ConvertOldItem",
    [1]  = "ConvertOldPvPCurrency",
    [2]  = "ItemRefund",
    [3]  = "QuestReward",
    [4]  = "Cheat",
    [5]  = "Vendor",
    [6]  = "PvPKillCredit",
    [7]  = "PvPMetaCredit",
    [8]  = "PvPScriptedAward",
    [9]  = "Loot",
    [10] = "UpdatingVersion",
    [11] = "LFGReward",
    [12] = "Trade",
    [13] = "Spell",
    [14] = "ItemDeletion",
    [15] = "RatedBattleground",
    [16] = "RandomBattleground",
    [17] = "Arena",
    [18] = "ExceededMaxQty",
    [19] = "PvPCompletionBonus",
    [20] = "Script",
    [21] = "GuildBankWithdrawal",
    [22] = "Pushloot",
    [23] = "GarrisonBuilding",
    [24] = "PvPDrop",
    [25] = "GarrisonFollowerActivation",
    [26] = "GarrisonBuildingRefund",
    [27] = "GarrisonMissionReward",
    [28] = "GarrisonResourceOverTime",
    [29] = "QuestRewardIgnoreCapsDeprecated",
    [30] = "GarrisonTalent",
    [31] = "GarrisonWorldQuestBonus",
    [32] = "PvPHonorReward",
    [33] = "BonusRoll",
    [34] = "AzeriteRespec",
    [35] = "WorldQuestReward",
    [36] = "WorldQuestRewardIgnoreCapsDeprecated",
    [37] = "FactionConversion",
    [38] = "DailyQuestReward",
    [39] = "DailyQuestWarModeReward",
    [40] = "WeeklyQuestReward",
    [41] = "WeeklyQuestWarModeReward",
    [42] = "AccountCopy",
    [43] = "WeeklyRewardChest",
    [44] = "GarrisonTalentTreeReset",
    [45] = "DailyReset",
    [46] = "AddConduitToCollection",
    [47] = "Barbershop",
    [48] = "ConvertItemsToCurrencyValue",
    [49] = "PvPTeamContribution",
    [50] = "Transmogrify",
    [51] = "AuctionDeposit",
    [52] = "PlayerTrait",
    [53] = "PhBuffer_53",
    [54] = "PhBuffer_54",
    [55] = "RenownRepGain",
    [56] = "CraftingOrder",
    [57] = "CatalystBalancing",
    [58] = "CatalystCraft",
    [59] = "ProfessionInitialAward",
    [60] = "PlayerTraitRefund",
    [61] = "AccountHwmUpdate",
    [62] = "ConvertItemsToCurrencyAndReputation",
    [63] = "PhBuffer_63",
    [64] = "SpellSkipLinkedCurrency",
    [65] = "AccountTransfer",
}

-- Destroy reason tokens map (loss side)
-- Official names mirrored from Enum.CurrencyDestroyReason (WoW 11.0.2+)
-- Keys are absolute enum values; direction is represented by sign at usage site (negative for loss)
CurrencyTracker.DestroyReasonTokens = CurrencyTracker.DestroyReasonTokens or {
    [0]  = "Cheat",
    [1]  = "Spell",
    [2]  = "VersionUpdate",
    [3]  = "QuestTurnin",
    [4]  = "Vendor",
    [5]  = "Trade",
    [6]  = "Capped",
    [7]  = "Garrison",
    [8]  = "DroppedToCorpse",
    [9]  = "BonusRoll",
    [10] = "FactionConversion",
    [11] = "FulfillCraftingOrder",
    [12] = "Script",
    [13] = "ConcentrationCast",
    [14] = "AccountTransfer",
}

-- Also export to addon table and global if available
if addonTable then
    addonTable.CurrencyConstants = CurrencyConstants
else
    _G.CurrencyConstants = CurrencyConstants
end

return CurrencyConstants