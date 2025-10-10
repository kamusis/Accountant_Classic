# Technical Workflows and Process Flows

<cite>
**Referenced Files in This Document**   
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua)
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua)
- [CurrencyConstants.lua](file://CurrencyTracker/CurrencyConstants.lua)
- [CurrencyFrame.lua](file://CurrencyTracker/CurrencyFrame.lua)
- [CurrencyFrame.xml](file://CurrencyTracker/CurrencyFrame.xml)
- [CharacterLogin-Process-Flow.md](file://Docs/CharacterLogin-Process-Flow.md)
- [Traders-Tender-Process-Flow.md](file://Docs/Traders-Tender-Process-Flow.md)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Character Login Process Flow](#character-login-process-flow)
3. [Currency Handling Workflow](#currency-handling-workflow)
4. [Trader's Tender Special Case](#traders-tender-special-case)
5. [Error Handling and Edge Cases](#error-handling-and-edge-cases)
6. [State Management](#state-management)
7. [Component Interaction](#component-interaction)
8. [Conclusion](#conclusion)

## Introduction
This document provides a comprehensive analysis of the technical workflows and process flows within the Accountant_Classic addon, focusing specifically on character login procedures and currency handling mechanisms. The documentation details the sequence of operations, state transitions, error handling procedures, and interactions between system components. The analysis is based on the provided codebase and documentation files, with emphasis on the CurrencyTracker module's functionality.

## Character Login Process Flow

The character login process in Accountant_Classic follows a well-defined sequence of initialization and enabling phases, ensuring proper setup of currency tracking functionality. The process begins with module initialization and progresses through enabling and event registration.

```mermaid
flowchart TD
%% 子图：模块初始化与启用
subgraph INIT["Initialization and Enable Phase"]
A1["Load Module: CurrencyTracker:Initialize()"] --> A2["Storage:Initialize() (if exists)"]
A2 --> A3["DataManager:Initialize() (if exists)"]
A3 --> A4["EventHandler:Initialize()"]
A4 --> A5["CurrencyTracker:Enable()"]
A5 --> A6["EventHandler:Enable()"]
A6 --> A7["EventHandler:RegisterEvents()"]
A7 --> |Registers| A7a["ADDON_LOADED / PLAYER_LOGIN / PLAYER_ENTERING_WORLD / ..."]
A7 --> |If C_CurrencyInfo exists| A7b["CURRENCY_DISPLAY_UPDATE"]
A7 --> |Otherwise| A7c["BAG_UPDATE (legacy fallback)"]
end
%% 子图：登录阶段直到世界载入完毕
subgraph LOGIN["Login to Entering World"]
B1["Received: PLAYER_LOGIN"] --> B2["EventHandler:OnPlayerLogin()"]
B2 --> B2a["InitializeCurrencyAmounts()"]
B2 --> B2b["Storage:ShiftCurrencyLogs() (align aggregation periods)"]
B2 --> B2c["didLoginPrime ← false"]
B3["Received: PLAYER_ENTERING_WORLD(isInitialLogin=true, isReloadingUi=false)"] --> B4["EventHandler:OnPlayerEnteringWorld(...)"]
B4 --> |First login and not reloading| B5["PrimeDiscoveredCurrenciesOnLogin()"]
B5 --> B5a["Iterate through discovered currency ids"]
B5a --> B5b["Read live amount + Total.net"]
B5b --> |delta ≠ 0| B5c["Storage:ApplyTotalOnlyBaselineDelta(delta)"]
B5b --> |delta = 0| B5d["Storage:InitializeCurrencyData(id)"]
B5c --> B5e["seed: lastCurrencyAmounts[id] = live; primedCurrencies[id] = true"]
B5d --> B5e
end
%% 子图：第一次货币变动事件
subgraph FIRST_EVENT["First Currency Change Event Arrival"]
C1["Received: CURRENCY_DISPLAY_UPDATE(...)"] --> C2["EventHandler:OnCurrencyDisplayUpdate(...)"]
C2 --> |inCombat = true| C2a["AddToBatch(...) and defer processing"]
C2 --> |inCombat = false| C3["Parameter normalization (remove table prefix etc.)"]
C3 --> C4["EventHandler:ProcessCurrencyChange(currencyID, newQty, qtyChange, gainSrc, lostSrc)"]
%% Legacy fallback path
D1["Received: BAG_UPDATE(bagID)"] --> D2["EventHandler:OnBagUpdate(bagID)"]
D2 --> |inCombat = true| D2a["AddToBatch('BAG_UPDATE', bagID)"]
D2 --> |inCombat = false| D3["0.3s debounce then CheckBagCurrencies()"]
D3 --> D4["When change detected call ProcessCurrencyChange(...)"]
end
%% Connection phase
A7a --> B1
A7a --> B3
A7b --> C1
A7c --> D1
```

**Diagram sources**
- [CharacterLogin-Process-Flow.md](file://Docs/CharacterLogin-Process-Flow.md)

**Section sources**
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L100-L200)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L500-L600)

## Currency Handling Workflow

The currency handling workflow in Accountant_Classic is designed to capture and process currency changes efficiently while maintaining data integrity. The system uses a modular approach with distinct components handling different aspects of currency tracking.

```mermaid
flowchart TD
A["Currency Change Event"] --> B{In Combat?}
B --> |Yes| C["Add to Batch Queue"]
B --> |No| D["Process Immediately"]
C --> E["Wait for Combat End"]
E --> F["Process Batched Updates"]
D --> G["Normalize Parameters"]
G --> H["Dynamic Discovery Check"]
H --> I{Currency Supported?}
I --> |No| J["Save Discovered Currency Metadata"]
I --> |Yes| K["Handle Special Cases (e.g., Trader's Tender)"]
K --> L["Determine Previous Snapshot"]
L --> M["Compute Change Amount"]
M --> N["Safety Baseline Guard"]
N --> O["Enhanced Baseline Priming"]
O --> P{Change ≠ 0?}
P --> |Yes| Q["Determine Source Key"]
Q --> R["Record Raw Event Metadata"]
R --> S["Track Currency Change via DataManager"]
S --> T["Update Stored Amount"]
T --> U["Mark as Primed"]
P --> |No| V["Update Snapshot Only"]
V --> W["End Processing"]
U --> W
```

The workflow begins when a currency change event is detected, either through the modern CURRENCY_DISPLAY_UPDATE event or the legacy BAG_UPDATE event for older clients. The system first checks if the player is in combat, as processing is deferred during combat to avoid performance issues. If not in combat, the event parameters are normalized to ensure consistent data format.

The system then performs dynamic discovery to identify new currencies that the player has encountered. If a currency is not previously supported, its metadata is saved for future reference. Special handling is applied to certain currencies like Trader's Tender (ID 2032) which have unreliable change values in the API.

The core processing involves determining the previous snapshot of the currency amount, computing the change amount, and applying safety checks to maintain data integrity. If a significant change is detected, the system records the transaction details including the source of the change, updates the stored amounts across various time periods (Session, Day, Week, etc.), and marks the currency as "primed" to indicate it has been properly initialized.

**Diagram sources**
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L500-L800)

**Section sources**
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L400-L900)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L100-L200)

## Trader's Tender Special Case

The Trader's Tender currency (ID 2032) requires special handling due to its unreliable API reporting. The system implements a dedicated handler that accounts for the currency's unique behavior, particularly its tendency to report zero changes even when the actual amount has changed.

```mermaid
flowchart TD
%% Trader's Tender (2032) Lifecycle
subgraph LOGIN_PRIME[Post-Login Baseline Check]
LP1[PrimeDiscoveredCurrenciesOnLogin] --> LP2{2032?}
LP2 --> |No| LP3[Continue to next]
LP2 --> |Yes| LP4[Read liveAmt and Total]
LP4 --> LP5{Difference between liveAmt and Total?}
LP5 --> |Yes| LP6[ApplyTotalOnlyBaselineDelta]
LP6 --> LP7[Update lastCurrencyAmounts]
LP5 --> |No| LP8[InitializeCurrencyData]
LP8 --> LP7
LP7 --> LP9[primedCurrencies = true]
end
subgraph FIRST_EVENT[First CURRENCY_DISPLAY_UPDATE]
FE1[Receive event parameters] --> FE2{2032?}
FE2 --> |No| FE3[Follow general flow]
FE2 --> |Yes| FE4[HandleZeroChangeCurrency]
FE4 --> FE5{Already primed?}
FE5 --> |Yes| SE1
FE5 --> |No| FE6{quantityChange non-zero?}
FE6 --> |Yes| FE7[pre = new - quantityChange]
FE7 --> FE8[base = Total or 0]
FE8 --> FE9[ApplyTotalOnlyBaselineDelta]
FE9 --> FE10[TrackCurrencyChange quantityChange]
FE6 --> |No| FE11[base = Total or 0]
FE11 --> FE12[ApplyTotalOnlyBaselineDelta]
FE12 --> FE13[Update snapshot]
FE10 --> FE13
FE13 --> FE14[primedCurrencies = true]
end
subgraph SUBSEQUENT_EVENT[Subsequent CURRENCY_DISPLAY_UPDATE]
SE1[HandleZeroChangeCurrency already primed] --> SE2{quantityChange == 0?}
SE2 --> |Yes| SE3[delta = new - last]
SE3 --> SE4{delta == 0?}
SE4 --> |Yes| SE5[Only update snapshot]
SE4 --> |No| SE6[Record metadata]
SE6 --> SE7[TrackCurrencyChange delta]
SE7 --> SE8[Update snapshot]
SE2 --> |No| SE9[delta = new - last]
SE9 --> SE10[Record metadata]
SE10 --> SE11[TrackCurrencyChange delta]
SE11 --> SE8
end
LP9 --> FE1
FE14 --> SE1
```

**Diagram sources**
- [Traders-Tender-Process-Flow.md](file://Docs/Traders-Tender-Process-Flow.md)

**Section sources**
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L200-L400)

## Error Handling and Edge Cases

The system implements comprehensive error handling to manage various edge cases and potential failure points. This includes combat state management, legacy client support, and data integrity validation.

```mermaid
flowchart TD
A["Error Handling and Edge Cases"] --> B["Combat State Management"]
A --> C["Legacy Client Support"]
A --> D["Data Integrity Validation"]
A --> E["Event Parameter Normalization"]
A --> F["Currency Discovery and Initialization"]
B --> B1["Defer processing during combat"]
B --> B2["Batch updates for later processing"]
B --> B3["Process batch on combat exit"]
C --> C1["Fallback to BAG_UPDATE events"]
C --> C2["Debounce bag updates (0.3s)"]
C --> C3["Check bag currencies on update"]
D --> D1["Validate SavedVariables structure"]
D --> D2["Ensure server and character data"]
D --> D3["Validate currency data types"]
D --> D4["Repair negative source keys"]
E --> E1["Handle table payload prefix"]
E --> E2["Normalize currency ID to numeric"]
E --> E3["Resolve nil parameters"]
F --> F1["Dynamic currency discovery"]
F --> F2["Initialize metadata for new currencies"]
F --> F3["Ensure proper data structures"]
B --> G["Error Logging"]
C --> G
D --> G
E --> G
F --> G
G --> H["LogDebug messages"]
H --> I["Console output for errors"]
I --> J["User notifications for critical issues"]
```

The error handling system is designed to be robust and resilient, ensuring that the addon continues to function correctly even in challenging circumstances. Combat state management prevents performance issues by deferring non-essential processing during combat, using a batching system to collect updates and process them when the player exits combat.

For legacy client support, the system provides a fallback mechanism using BAG_UPDATE events when the modern CURRENCY_DISPLAY_UPDATE API is not available. This ensures compatibility across different WoW client versions. The legacy path includes debouncing to coalesce rapid bag updates and prevent excessive processing.

Data integrity validation is performed at multiple levels, from ensuring the SavedVariables structure exists to validating the types and contents of currency data. The system includes repair functions to handle corrupted data, such as negative source keys, and maintains detailed logging for debugging purposes.

Event parameter normalization handles various edge cases in the event data, such as the occasional table payload prefix in CURRENCY_DISPLAY_UPDATE events. The system also manages currency discovery and initialization, ensuring that newly encountered currencies are properly tracked and their metadata is preserved.

**Section sources**
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L800-L900)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1000-L1200)

## State Management

The system maintains several state variables to track the current status of currency tracking and processing. These states ensure proper initialization, prevent duplicate processing, and maintain data consistency across sessions.

```mermaid
stateDiagram-v2
[*] --> Uninitialized
Uninitialized --> Initialized : Initialize()
Initialized --> Enabled : Enable()
Enabled --> Disabled : Disable()
Disabled --> Enabled : Enable()
state Enabled {
[*] --> Idle
Idle --> ProcessingBatch : ProcessBatchUpdates()
ProcessingBatch --> Idle
Idle --> InCombat : PLAYER_REGEN_DISABLED
InCombat --> Idle : PLAYER_REGEN_ENABLED
InCombat --> QueuingEvents : Event received
QueuingEvents --> InCombat
Idle --> ProcessingEvent : Event received
ProcessingEvent --> Idle
Idle --> Priming : PrimeDiscoveredCurrenciesOnLogin()
Priming --> Idle
}
class Uninitialized {
isInitialized = false
isEnabled = false
}
class Initialized {
isInitialized = true
isEnabled = false
}
class Enabled {
isEnabled = true
inCombat = boolean
didLoginPrime = boolean
lastCurrencyAmounts = map
primedCurrencies = set
updateBatch = list
}
```

The state management system follows a clear progression from uninitialized to initialized to enabled states. The uninitialized state represents the addon's condition before any setup has occurred. During initialization, the system creates necessary data structures and prepares the event handling framework.

Once initialized, the system can be enabled, which registers for relevant events and begins monitoring for currency changes. The enabled state contains several sub-states that reflect the current processing context, including idle, processing batch, in combat, and priming states.

Key state variables include:
- `isInitialized`: Indicates whether the core modules have been initialized
- `isEnabled`: Indicates whether event processing is active
- `inCombat`: Tracks whether the player is currently in combat
- `didLoginPrime`: Prevents duplicate baseline priming during login
- `lastCurrencyAmounts`: Maintains the most recent known amount for each currency
- `primedCurrencies`: Tracks which currencies have been properly initialized
- `updateBatch`: Stores events that need to be processed after combat

This state management approach ensures that the system behaves predictably and consistently, preventing race conditions and duplicate processing that could compromise data integrity.

**Section sources**
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L50-L100)
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L50-L100)

## Component Interaction

The Accountant_Classic addon is structured as a modular system with clear separation of concerns between components. Each component has a specific responsibility and interacts with others through well-defined interfaces.

```mermaid
graph TD
A[CurrencyCore] --> B[CurrencyEventHandler]
A --> C[CurrencyDataManager]
A --> D[CurrencyStorage]
A --> E[CurrencyFrame]
B --> |Handles| F[CURRENCY_DISPLAY_UPDATE]
B --> |Handles| G[BAG_UPDATE]
B --> |Delegates| C
B --> |Uses| D
C --> |Processes| H[Currency Changes]
C --> |Stores| D
C --> |Retrieves| D
C --> |Uses| I[CurrencyConstants]
D --> |Persists| J[SavedVariables]
D --> |Manages| K[Data Structure]
D --> |Provides| L[Data Access]
E --> |Displays| M[Currency Data]
E --> |Triggers| C
E --> |Configures| D
I --> |Provides| N[Currency Metadata]
I --> |Defines| O[Supported Currencies]
A --> |Orchestrates| B
A --> |Orchestrates| C
A --> |Orchestrates| D
A --> |Orchestrates| E
style A fill:#f9f,stroke:#333
style B fill:#bbf,stroke:#333
style C fill:#bbf,stroke:#333
style D fill:#bbf,stroke:#333
style E fill:#bbf,stroke:#333
style I fill:#bbf,stroke:#333
```

The component interaction follows a clear hierarchy with CurrencyCore serving as the orchestrator that manages the lifecycle of other components. CurrencyEventHandler acts as the event processor, receiving currency change notifications from the game and coordinating their processing.

CurrencyDataManager serves as the business logic layer, containing the core algorithms for processing currency changes and determining how they should be recorded. It interacts with CurrencyStorage, which is responsible for persistent data storage and retrieval, ensuring that currency tracking data survives between game sessions.

CurrencyFrame provides the user interface component, displaying currency data to the player and allowing configuration of tracking options. It interacts with the DataManager to retrieve data for display and with Storage to save user preferences.

CurrencyConstants provides static data and configuration, defining the supported currencies, their metadata, and various system constants. This separation allows for easy updates to currency information without modifying the core logic.

The interaction between components is designed to be loosely coupled, with each component having a single responsibility. This modular design makes the system easier to maintain, test, and extend. The clear interfaces between components also facilitate debugging and troubleshooting, as issues can be isolated to specific components.

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L100-L300)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L1-L50)

## Conclusion

The Accountant_Classic addon implements a sophisticated system for tracking currency changes in World of Warcraft. The technical workflows and process flows are carefully designed to handle the complexities of currency tracking while maintaining performance and data integrity.

The character login process ensures proper initialization of currency tracking, with a phased approach that separates module initialization from enabling and event registration. This allows for a clean setup sequence that prevents race conditions and ensures all components are ready before processing begins.

The currency handling workflow is robust and comprehensive, accounting for various edge cases and special scenarios. The system's ability to handle both modern and legacy clients ensures broad compatibility, while the special handling for currencies like Trader's Tender demonstrates attention to detail in addressing specific gameplay mechanics.

Error handling and state management are implemented thoroughly, with mechanisms to handle combat states, validate data integrity, and manage the various states of the tracking system. The modular component architecture promotes maintainability and extensibility, with clear separation of concerns between the different parts of the system.

Overall, the Accountant_Classic addon provides a reliable and feature-rich solution for tracking currency changes, with well-documented workflows and processes that ensure accurate and consistent data collection across different gameplay scenarios.