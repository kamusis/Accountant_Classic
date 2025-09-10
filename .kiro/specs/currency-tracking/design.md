# Design Document

## Overview

This design document outlines the implementation of currency tracking functionality for Accountant Classic. The solution adds comprehensive tracking for all in-game currencies (beyond gold) while maintaining complete separation from existing code to ensure zero impact on current functionality. The design follows a modular approach that can be easily extended and disabled without affecting the core addon.

## Architecture

### Core Design Principles

1. **Zero Impact on Existing Code**: All new functionality is implemented as separate modules that hook into existing systems without modifying core files
2. **Modular Design**: Currency tracking is implemented as a self-contained system that can be enabled/disabled independently
3. **Backward Compatibility**: New data structures are additive and don't interfere with existing SavedVariables format
4. **Performance Conscious**: Respects combat restrictions and batches updates to prevent performance issues

### System Architecture

```
Accountant Classic Core (Unchanged)
├── Core/Core.lua (UNCHANGED)
├── Core/Config.lua (UNCHANGED)  
├── Core/Constants.lua (UNCHANGED)
├── Core/MoneyFrame.lua (UNCHANGED)
├── Core/*.xml (UNCHANGED)
├── Locale/*.lua (UNCHANGED)
├── Libs/ (UNCHANGED)
├── Images/ (UNCHANGED)
└── CurrencyTracker/ (NEW)
    ├── CurrencyCore.lua
    ├── CurrencyDataManager.lua
    ├── CurrencyUIController.lua
    ├── CurrencyEventHandler.lua
    ├── CurrencyStorage.lua
    ├── CurrencyConstants.lua
    ├── CurrencyUtils.lua
    └── CurrencyTracker.xml (if needed)

Modified Files (Minimal Changes):
├── *.toc files (Add CurrencyTracker load order)
OR
├── Core/Core.xml (Add single include line)
```

## Components and Interfaces

### 1. Currency Tracker Module (`CurrencyTracker/`)

**Purpose**: Main module that orchestrates all currency tracking functionality

**Key Responsibilities**:
- Initialize currency tracking system
- Manage module lifecycle (enable/disable)
- Coordinate between sub-components
- Handle version compatibility

**Interface**:
```lua
CurrencyTracker = {
    Initialize = function() end,
    Enable = function() end,
    Disable = function() end,
    IsEnabled = function() return boolean end
}
```

### 2. Currency Data Manager (`CurrencyTracker/CurrencyDataManager.lua`)

**Purpose**: Handles all currency data operations and storage

**Key Responsibilities**:
- Track currency changes via WoW APIs using generic currency ID logic
- Store currency transaction data for any supported currency
- Provide data retrieval methods that work with any currency ID
- Handle data migration and cleanup
- Manage supported currency definitions and metadata

**Interface**:
```lua
CurrencyDataManager = {
    TrackCurrencyChange = function(currencyID, amount, source) end,
    GetCurrencyData = function(currencyID, timeframe) return data end,
    GetAvailableCurrencies = function() return currencyList end,
    GetSupportedCurrencies = function() return supportedList end,
    GetCurrenciesByExpansion = function(expansion) return currencyList end,
    GetCurrenciesByPatch = function(patch) return currencyList end,
    GetCurrenciesForCurrentVersion = function() return currencyList end,
    IsCurrencySupported = function(currencyID) return boolean end,
    GetCurrentWoWVersion = function() return version end,
    ComparePatchVersions = function(patch1, patch2) return comparison end,
    InitializeStorage = function() end
}
```

### 3. Currency UI Controller (`CurrencyTracker/CurrencyUIController.lua`)

**Purpose**: Manages the currency tab and UI interactions

**Key Responsibilities**:
- Add "Currencies" tab to existing tab structure
- Create and manage currency dropdown with expansion and patch grouping
- Filter currencies based on current WoW patch version
- Handle tab switching and data display
- Coordinate with existing UI framework

**Interface**:
```lua
CurrencyUIController = {
    CreateCurrencyTab = function() end,
    CreateCurrencyDropdown = function() end,
    PopulateCurrencyDropdown = function() end, -- Groups by expansion and patch
    FilterCurrenciesByVersion = function() end,
    CreateDropdownSeparators = function() end, -- For expansion/patch headers
    UpdateDisplay = function(currencyID) end,
    HandleTabSwitch = function() end
}
```

### 4. Currency Event Handler (`CurrencyTracker/CurrencyEventHandler.lua`)

**Purpose**: Monitors WoW events for currency changes

**Key Responsibilities**:
- Register for currency-related events
- Detect currency changes
- Identify transaction sources
- Batch updates for performance

**Events to Monitor**:
- `CURRENCY_DISPLAY_UPDATE` - Fired when currency amounts change (Retail/Modern)
- `BAG_UPDATE` - May indicate currency changes in older clients
- `PLAYER_MONEY` - For cross-reference with existing money tracking
- `ADDON_LOADED` - For initialization
- `PLAYER_LOGIN` - For session start tracking

**Interface**:
```lua
CurrencyEventHandler = {
    RegisterEvents = function() end,
    OnCurrencyDisplayUpdate = function(currencyType, quantity) end,
    OnBagUpdate = function(bagID) end,
    IdentifySource = function() return source end,
    BatchUpdate = function() end
}
```

### 5. Currency Storage Manager (`CurrencyTracker/CurrencyStorage.lua`)

**Purpose**: Manages persistent storage of currency data

**Key Responsibilities**:
- Extend existing SavedVariables structure
- Ensure backward compatibility
- Handle data versioning
- Provide migration utilities

**Interface**:
```lua
CurrencyStorageManager = {
    InitializeCurrencyStorage = function() end,
    SaveCurrencyData = function(data) end,
    LoadCurrencyData = function() return data end,
    MigrateData = function(oldVersion, newVersion) end
}
```

## Data Models

### Currency Data Structure and Compatibility Strategy

#### Current Data Format (Based on TOC SavedVariables)

From the .toc files, the current addon uses these SavedVariables:
- `Accountant_ClassicSaveData` - Main character data
- `Accountant_ClassicDB` - Database settings  
- `Accountant_Classic_NewDB` - New database format
- `Accountant_ClassicZoneDB` - Zone tracking data

#### Current Structure (Inferred from Core.lua)

```lua
-- Current format (UNCHANGED)
Accountant_ClassicSaveData = {
    [server] = {
        [character] = {
            options = {
                version = "2.20.00",
                date = "dd/mm/yy",
                totalcash = number,
                faction = "Alliance/Horde",
                class = "WARRIOR",
                -- ... other existing options
            },
            data = {
                ["Session"] = { [logtype] = { in = amount, out = amount } },
                ["Day"] = { [logtype] = { in = amount, out = amount } },
                ["Week"] = { [logtype] = { in = amount, out = amount } },
                -- ... other time periods
            }
        }
    }
}
```

#### New Currency Data (Additive Approach)

**Strategy**: Add currency data to existing structure without modifying current fields

```lua
-- Extended structure (BACKWARD COMPATIBLE)
Accountant_ClassicSaveData = {
    [server] = {
        [character] = {
            options = { ... },  -- UNCHANGED - existing options
            data = { ... },     -- UNCHANGED - existing gold data
            
            -- NEW FIELDS (additive, ignored by older versions)
            currencyData = {
                [currencyID] = {
                    ["Session"] = { [source] = { in = amount, out = amount } },
                    ["Day"] = { [source] = { in = amount, out = amount } },
                    ["Week"] = { [source] = { in = amount, out = amount } },
                    ["Month"] = { [source] = { in = amount, out = amount } },
                    ["Year"] = { [source] = { in = amount, out = amount } },
                    ["Total"] = { [source] = { in = amount, out = amount } }
                }
            },
            currencyOptions = {
                selectedCurrency = currencyID,
                trackingEnabled = true,
                lastUpdate = timestamp,
                version = "3.00.00" -- Currency tracking version
            }
        }
    }
}
```

#### Compatibility Guarantees

1. **Older Addon Versions**: Will ignore `currencyData` and `currencyOptions` fields completely
2. **Existing Data**: All current gold tracking data remains in exact same format and location
3. **New Installation**: Creates both gold and currency structures from scratch
4. **Upgrade Path**: Adds currency fields without touching existing data

#### Migration Strategy

```lua
-- Safe initialization that doesn't break existing data
local function InitializeCurrencyData()
    -- Only add currency fields if they don't exist
    if not Accountant_ClassicSaveData[server][character].currencyData then
        Accountant_ClassicSaveData[server][character].currencyData = {}
    end
    if not Accountant_ClassicSaveData[server][character].currencyOptions then
        Accountant_ClassicSaveData[server][character].currencyOptions = {
            selectedCurrency = 3008, -- Default to Valorstones
            trackingEnabled = true,
            lastUpdate = time(),
            version = "3.00.00"
        }
    end
end
```

### Currency Information Model

```lua
CurrencyInfo = {
    id = number,           -- Currency ID from WoW API
    name = string,         -- Display name
    icon = string,         -- Icon texture path
    maxQuantity = number,  -- Maximum amount (if applicable)
    isTracked = boolean,   -- Whether we're tracking this currency
    minVersion = number,   -- Minimum WoW version (e.g., 110200 for 11.2.0)
    expansion = string,    -- Expansion name
    patch = string         -- Specific patch version (primary identifier)
}

-- Example currency definitions
SupportedCurrencies = {
    [3008] = { -- Valorstones
        id = 3008,
        name = "Valorstones",
        minVersion = 110000, -- 11.0.0
        expansion = "The War Within",
        patch = "11.0.0"
    },
    [3010] = { -- Weathered Ethereal Crest (example)
        id = 3010,
        name = "Weathered Ethereal Crest",
        minVersion = 110200, -- 11.2.0
        expansion = "The War Within", 
        patch = "11.2.0"
    },
    [2815] = { -- Resonance Crystals
        id = 2815,
        name = "Resonance Crystals", 
        minVersion = 100000, -- 10.0.0
        expansion = "Dragonflight",
        patch = "10.0.0"
    }
}
```

### Supported Currencies (Grouped by Expansion and Patch)

The currencies will be organized by expansion and patch version in the dropdown menu:

**The War Within**
- *Patch 11.0.0*
  - **Valorstones** (ID: 3008) - **FIRST IMPLEMENTATION**
  - **Residual Memories** (ID: 3089)
  - **Kej** (ID: 3056)
- *Patch 11.1.0*
  - **Vintage Kaja'Cola Can** (ID: 3220)
- *Patch 11.2.0*
  - **Undercoin** (ID: 2803)
  - **Weathered Ethereal Crest** (ID: 3284)

**Dragonflight**
- *Patch 10.0.0*
  - **Resonance Crystals** (ID: 2815)

**Future Expansions/Patches**
- Additional currencies can be added with their specific patch version requirements

**Implementation Strategy**: 

The system is designed with **generic currency logic** that works with any currency ID. This means:

1. **Single Implementation**: All currencies use the same tracking, storage, and display logic
2. **Currency ID Parameter**: Functions accept `currencyID` parameter to handle different currencies
3. **No Currency-Specific Code**: No need for separate Valorstones, Undercoin, or Kej-specific functions
4. **Scalable Design**: Adding new currencies only requires adding their ID and metadata to the supported list

**Testing Approach**: Implement and test with Valorstones (ID: 3008) first. Once Valorstones tracking works correctly, all other currencies will automatically work by simply adding their IDs to the supported currency list.

## Error Handling

### Graceful Degradation Strategy

1. **API Unavailability**: If currency APIs are not available (older clients), disable currency tracking gracefully
2. **Data Corruption**: Implement data validation and recovery mechanisms
3. **Performance Issues**: Automatic throttling and batching of updates
4. **UI Errors**: Fallback to basic display modes if advanced features fail

### Error Recovery

```lua
-- Example error handling pattern
local function SafeCurrencyOperation(operation)
    local success, result = pcall(operation)
    if not success then
        -- Log error without breaking existing functionality
        CurrencyTracker:LogError(result)
        return nil
    end
    return result
end
```

## Testing Strategy

### Unit Testing Approach

1. **Data Manager Tests**: Verify currency tracking accuracy and data integrity
2. **UI Controller Tests**: Ensure proper tab creation and dropdown functionality
3. **Storage Tests**: Validate backward compatibility and data migration
4. **Event Handler Tests**: Confirm proper event registration and handling

### Integration Testing

1. **Existing Functionality**: Verify gold tracking remains unaffected
2. **UI Integration**: Ensure new tab integrates seamlessly with existing tabs
3. **Performance Testing**: Validate no performance regression in combat or high-activity scenarios
4. **Cross-Version Testing**: Test compatibility across different WoW client versions

### Test Data Scenarios

1. **Fresh Installation**: New user with no existing data
2. **Upgrade Scenario**: Existing user upgrading to currency-enabled version
3. **Multiple Characters**: Cross-character and cross-server functionality
4. **Edge Cases**: Maximum currency amounts, rapid changes, API failures

## Implementation Details

### Tab Integration Strategy

The new "Currencies" tab will be added using the existing tab framework:

1. **Tab Creation**: Extend the existing `AC_TABS` constant and tab creation logic
2. **Tab Positioning**: Position as the 12th tab (after "All Chars")
3. **Tab Behavior**: Reuse existing time period tabs (Session, Day, Week, etc.) but display currency data

### Dropdown Implementation

The currency dropdown will be positioned alongside the existing character dropdown:

1. **Layout Adjustment**: Reduce character dropdown width from 200px to 150px
2. **Currency Dropdown**: Add new dropdown at 140px width
3. **Positioning**: Place currency dropdown to the right of character dropdown with 10px spacing

### Event Monitoring

Currency changes will be detected through:

1. **Primary Events**:
   - `CURRENCY_DISPLAY_UPDATE` - Main currency change event (Retail/Cataclysm+)
   - `BAG_UPDATE` - Backup detection for currency items in bags (All versions)
   
2. **Supporting Events**:
   - `PLAYER_MONEY` - Cross-reference with existing money tracking
   - `ADDON_LOADED` - Initialize currency tracking system
   - `PLAYER_LOGIN` - Start session tracking
   - `PLAYER_LOGOUT` - Save session data

3. **API Functions**:
   - `C_CurrencyInfo.GetCurrencyInfo(currencyID)` - Modern clients
   - `GetCurrencyInfo(currencyID)` - Legacy function
   - `C_CurrencyInfo.GetBackpackCurrencyInfo(index)` - Backpack currencies
   
4. **Fallback Strategy**: Periodic scanning for clients without currency events
5. **Source Detection**: Context-aware identification based on active UI frames and recent events

### Performance Optimizations

1. **Combat Awareness**: Defer non-critical operations during combat
2. **Update Batching**: Batch multiple currency updates into single operations
3. **Lazy Loading**: Load currency data only when currency tab is accessed
4. **Memory Management**: Implement data retention limits and cleanup routines



## Integration Points

### Hooking Strategy

The currency tracker will hook into existing systems without modification:

1. **Tab System**: Hook `PanelTemplates_SetNumTabs` to add currency tab
2. **Event System**: Register additional events without affecting existing handlers
3. **Data Display**: Hook display update functions to show currency data when appropriate
4. **UI Creation**: Hook frame creation to add currency dropdown

### Initialization Sequence

1. **Addon Load**: Check if currency tracker should be enabled
2. **Storage Init**: Initialize currency storage structures
3. **UI Setup**: Create currency tab and dropdown (if enabled)
4. **Event Registration**: Register for currency-related events
5. **Data Migration**: Migrate any existing data if needed

This design ensures that the currency tracking feature can be implemented without touching any existing code while providing a seamless user experience that feels native to the existing addon.