# Addon Methods and Lifecycle

<cite>
**Referenced Files in This Document**   
- [Core.lua](file://Core/Core.lua#L1-L2306)
- [Constants.lua](file://Core/Constants.lua#L1-L261)
- [Config.lua](file://Core/Config.lua#L1-L431)
- [MoneyFrame.lua](file://Core/MoneyFrame.lua)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Lifecycle Methods](#lifecycle-methods)
   - [OnInitialize](#oninitialize)
   - [OnEnable](#onenable)
   - [OnDisable](#ondisable)
3. [Public API Methods](#public-api-methods)
   - [GetMoneyData](#getmoneydata)
   - [GetSessionEarnings](#getsessionearnings)
   - [RefreshUI](#refreshui)
4. [Integration Patterns](#integration-patterns)
5. [Versioning and Compatibility](#versioning-and-compatibility)
6. [Performance and Thread Safety](#performance-and-thread-safety)

## Introduction
Accountant_Classic is a World of Warcraft Classic addon that tracks character financial data across multiple time periods and transaction types. Built on the AceAddon-3.0 framework, it provides a comprehensive API for lifecycle management and data retrieval. This document details the addon's main object methods, focusing on initialization, enabling, disabling, and public data access functions. The addon uses event-driven architecture to monitor money changes and provides both UI and programmatic interfaces for external addons to integrate with its financial tracking system.

## Lifecycle Methods

### OnInitialize
**Method Signature**: `addon:OnInitialize()`

The `OnInitialize` method is called during the ADDON_LOADED event when the addon is first loaded into memory. This method establishes the foundational components and configurations required for the addon to function.

**Key Responsibilities**:
- Initializes the AceDB database with default profile settings
- Registers the LibDataBroker (LDB) data object for minimap integration
- Sets up chat commands (`/accountant`, `/acc`)
- Creates and configures the main UI frame and dropdown menus
- Registers event callbacks for profile changes

**Execution Order**:
1. Database initialization via AceDB:New()
2. LDB object creation and configuration
3. Minimap button registration via LibDBIcon-1.0
4. Chat command registration
5. Options panel setup
6. UI frame creation

**Side Effects**:
- Creates or loads the Accountant_ClassicDB saved variable
- Registers the addon with LibDataBroker for data display
- Establishes the minimap button if enabled in profile
- Initializes the UI frame structure in memory

**Error Conditions**:
- Returns immediately and prints an error message if database initialization fails
- Gracefully continues initialization if optional components (like MoneyFrame module) are not available

**Section sources**
- [Core.lua](file://Core/Core.lua#L1800-L1850)

### OnEnable
**Method Signature**: `addon:OnEnable()`

The `OnEnable` method is invoked after OnInitialize when the addon becomes active, typically after the PLAYER_LOGIN event has fired and character data is available.

**Key Responsibilities**:
- Copies legacy options to the current profile
- Hooks into relevant game functions (RepairAllItems, CursorHasItem)
- Loads financial data from saved variables
- Establishes the initial money baseline
- Registers for all financial tracking events
- Initializes the CurrencyTracker module if available

**Execution Order**:
1. Option migration from legacy storage
2. Secure hooking of repair-related functions
3. Financial data loading via loadData()
4. Initial money state capture
5. Event registration for money tracking
6. UI element configuration
7. CurrencyTracker module initialization

**Side Effects**:
- Begins monitoring for money changes through PLAYER_MONEY and CHAT_MSG_MONEY events
- Updates the LDB display with current financial information
- Enables the priming mechanism for accurate baseline initialization
- Activates the CurrencyTracker module for currency monitoring

**Timing Considerations**:
This method should only be called after PLAYER_LOGIN, as it requires character-specific data (AC_PLAYER, AC_SERVER, AC_FACTION) that is not available during ADDON_LOADED. Calling it earlier will result in incomplete or incorrect data initialization.

**Section sources**
- [Core.lua](file://Core/Core.lua#L1852-L1920)

### OnDisable
**Method Signature**: `addon:OnDisable()`

The `OnDisable` method handles the graceful shutdown of the addon when it is being disabled or reloaded.

**Key Responsibilities**:
- Unregisters all event listeners
- Removes secure hooks from game functions
- Cleans up UI elements
- Saves current state to persistent storage
- Disables the CurrencyTracker module

**Execution Order**:
1. Unregister all event handlers
2. Unhook secure functions
3. Hide and clean up UI components
4. Save current financial state
5. Disable auxiliary modules

**Side Effects**:
- Stops all financial data tracking
- Removes the addon from the event processing loop
- Preserves current financial state for next session
- Releases references to UI elements for garbage collection

**Note**: The Accountant_Classic addon does not explicitly define an OnDisable method in the provided codebase. The functionality described above is inferred from standard AceAddon-3.0 practices and the addon's architecture. The addon relies on WoW's normal shutdown procedures to clean up its components.

## Public API Methods

### GetMoneyData
**Method Signature**: `addon:GetMoneyData(logType, logMode) -> number`

Retrieves financial data for a specific transaction type and time period.

**Parameters**:
- `logType` (string): The type of transaction (e.g., "TRAIN", "TAXI", "AH")
- `logMode` (string): The time period ("Session", "Day", "Week", "Month", "Total")

**Return Values**:
- Returns the amount of money (in copper) for the specified transaction type and period
- Returns 0 if no data exists for the specified parameters

**Error Conditions**:
- Returns 0 if logType or logMode is invalid or not found in the data structure
- No explicit error throwing; fails silently with default return value

**Usage Example**:
```lua
-- Get today's repair costs
local repairCosts = Accountant_Classic:GetMoneyData("REPAIRS", "Day")
print("Today's repair costs: " .. Accountant_Classic:GetFormattedValue(repairCosts))
```

**Section sources**
- [Core.lua](file://Core/Core.lua#L1600-L1700)

### GetSessionEarnings
**Method Signature**: `addon:GetSessionEarnings() -> number`

Calculates the net earnings for the current session.

**Parameters**: None

**Return Values**:
- Returns the net profit (positive) or loss (negative) in copper for the current session
- Returns 0 if no financial activity has occurred this session

**Implementation Details**:
This method iterates through all transaction types and calculates the difference between total income and total expenses for the "Session" log mode.

**Usage Example**:
```lua
-- Display session earnings in chat
local earnings = Accountant_Classic:GetSessionEarnings()
if earnings > 0 then
    print("Session profit: " .. Accountant_Classic:GetFormattedValue(earnings))
elseif earnings < 0 then
    print("Session loss: " .. Accountant_Classic:GetFormattedValue(math.abs(earnings)))
else
    print("No net change this session")
end
```

**Section sources**
- [Core.lua](file://Core/Core.lua#L1950-L1970)

### RefreshUI
**Method Signature**: `addon:Refresh()`

Forces a complete refresh of the addon's user interface components.

**Parameters**: None

**Key Responsibilities**:
- Updates the main financial tracking frame
- Rearranges the money information frame based on current settings
- Refreshes the LibDataBroker display text
- Applies current profile settings to UI elements

**Execution Order**:
1. Updates profile reference
2. Shows or hides the money info frame based on settings
3. Rearranges money info frame positioning
4. Refreshes the main accountant frame display
5. Updates the minimap button position and appearance
6. Refreshes the LDB display text

**Usage Example**:
```lua
-- Force UI refresh after changing settings
Accountant_Classic.db.profile.scale = 1.2
Accountant_Classic.db.profile.alpha = 0.8
Accountant_Classic:Refresh() -- Apply changes to UI
```

**Section sources**
- [Core.lua](file://Core/Core.lua#L1930-L1950)

## Integration Patterns

### Retrieving Character Gold Totals
External addons can retrieve the current character's gold total by accessing the saved variables directly or using the addon's formatting methods:

```lua
-- Method 1: Direct access to saved data
local server = GetRealmName()
local player = UnitName("player")
local totalGold = Accountant_ClassicSaveData[server][player].options.totalcash or 0

-- Method 2: Using addon's formatting utility
local formattedGold = Accountant_Classic:GetFormattedValue(totalGold)
print(player .. " has " .. formattedGold)

-- Method 3: Getting session-specific data
Accountant_Classic:PopulateCharacterList()
local sessionEarnings = Accountant_Classic:GetSessionEarnings()
```

### Forcing UI Refresh
When external addons modify Accountant_Classic's settings, they should call Refresh() to ensure the UI reflects the changes:

```lua
-- External addon modifying Accountant settings
local accountant = LibStub("AceAddon-3.0"):GetAddon("Accountant_Classic", true)
if accountant then
    -- Change a setting
    accountant.db.profile.showmoneyonbutton = false
    
    -- Force UI update
    accountant:Refresh()
    
    print("Accountant settings updated and UI refreshed")
end
```

### Safe Function Calling
External addons should verify the addon is loaded and initialized before calling its methods:

```lua
local function safeAccountantCall()
    -- Check if addon is available
    local accountant = LibStub("AceAddon-3.0"):GetAddon("Accountant_Classic", true)
    if not accountant then
        print("Accountant_Classic not available")
        return
    end
    
    -- Wait for PLAYER_LOGIN if called too early
    if not IsLoggedIn() then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_LOGIN")
        frame:SetScript("OnEvent", function()
            frame:UnregisterAllEvents()
            -- Now safe to call methods
            local earnings = accountant:GetSessionEarnings()
            print("Session earnings: " .. accountant:GetFormattedValue(earnings))
        end)
        return
    end
    
    -- Safe to call methods
    local earnings = accountant:GetSessionEarnings()
    print("Session earnings: " .. accountant:GetFormattedValue(earnings))
end
```

## Versioning and Compatibility

### WoW Classic Patch Compatibility
Accountant_Classic maintains backward compatibility across WoW Classic patches through conditional code paths based on the game version:

```lua
-- Determined at load time from GetBuildInfo()
local WoWClassicEra, WoWClassicTBC, WoWWOTLKC, WoWCataC, WoWRetail

-- Different event sets for different expansions
if (WoWClassicEra or WoWClassicTBC or WoWWOTLKC) then 
    constants.events = { /* Classic-era events */ }
else
    constants.events = { /* TBC+ events including Garrison, Barber shop */ }
end
```

**Compatibility Features**:
- Uses version detection to enable expansion-specific features
- Maintains separate event lists for different game versions
- Provides fallback mechanisms for currency tracking
- Preserves data structure compatibility across versions

**Breaking Changes**:
- No breaking API changes in recent versions
- Data structure maintains backward compatibility
- Settings are preserved across updates
- Legacy data migration handled automatically in initOptions()

## Performance and Thread Safety

### Performance Implications
Frequent calls to Accountant_Classic methods have the following performance characteristics:

**High-Frequency Methods**:
- `GetFormattedValue()`: Moderate cost due to string formatting and icon handling
- `RefreshUI()`: High cost due to complete UI rebuild
- `GetMoneyData()`: Low cost, direct table lookup

**Optimization Recommendations**:
- Cache results of frequent calls rather than calling repeatedly
- Batch UI updates and call Refresh() once instead of multiple times
- Use direct table access for performance-critical code paths
- Avoid calling methods in OnUpdate handlers

### Thread Safety
**Thread Safety Considerations**:
- The addon is not designed for multi-threaded access
- All operations occur on the main UI thread
- Saved variables are accessed synchronously
- Event handlers are serialized by the WoW client

**Safe Usage Patterns**:
- All method calls are safe from the main UI thread
- No asynchronous operations that could cause race conditions
- Data access is atomic at the Lua level
- Event-driven architecture prevents concurrent modification

**Unsafe Usage Patterns**:
- Calling methods from coroutine contexts (not applicable in WoW)
- Concurrent access from multiple addons (not possible in WoW's execution model)
- Modifying saved variables directly without proper synchronization

The addon's design follows WoW's single-threaded execution model, making thread safety concerns minimal in practice. The primary consideration is avoiding excessive CPU usage in event handlers that could impact game performance.