# Currency Slash Commands

<cite>
**Referenced Files in This Document**   
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua)
- [CurrencyFrame.lua](file://CurrencyTracker/CurrencyFrame.lua)
- [CurrencyFrame.xml](file://CurrencyTracker/CurrencyFrame.xml)
- [CurrencyConstants.lua](file://CurrencyTracker/CurrencyConstants.lua)
- [Docs/CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md)
- [Docs/CurrencyTracker-UI-Design.md](file://Docs/CurrencyTracker-UI-Design.md)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [/ct Command Syntax and Parameters](#ct-command-syntax-and-parameters)
3. [Command Output Formats](#command-output-formats)
4. [CLI and UI Functionality Relationship](#cli-and-ui-functionality-relationship)
5. [Command Examples](#command-examples)
6. [Configuration and Settings](#configuration-and-settings)
7. [Troubleshooting and Repair Commands](#troubleshooting-and-repair-commands)
8. [Conclusion](#conclusion)

## Introduction
The Currency Tracker module provides a comprehensive system for monitoring and managing in-game currency data through slash commands. This documentation details the `/ct` command syntax, parameters, output formats, and the relationship between command-line interface (CLI) functionality and the graphical user interface (UI). The system is designed to be headless-first, with CLI commands serving as the primary interface while the UI provides a visual representation of the same data.

The Currency Tracker operates independently from the Gold tracker, focusing exclusively on currency tracking. It uses an additive approach to extend existing SavedVariables structures without modifying current gold tracking data, ensuring backward compatibility with older addon versions.

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L1321-L1405)
- [Docs/CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md#L0-L92)

## /ct Command Syntax and Parameters
The `/ct` command system provides a comprehensive interface for interacting with the Currency Tracker. Commands follow a consistent syntax pattern with specific parameters for different operations.

### Basic Command Structure
```
/ct <command> [subcommand] [parameters]
```

### Command Categories and Parameters

#### Show Commands
- **/ct show**: Display detailed data for a single currency
  - Parameters: `<timeframe>` `[currencyid]`
  - Timeframe options: `this-session`, `today`, `prv-day`, `this-week`, `prv-week`, `this-month`, `prv-month`, `this-year`, `prv-year`, `total`
  - Currency ID is optional; uses last selected currency if omitted

- **/ct show-all-currencies**: Display summary across all tracked currencies
  - Parameters: `<timeframe>`
  - Same timeframe options as `/ct show`

- **/ct meta show**: Inspect raw metadata from events
  - Parameters: `<timeframe>` `<currencyid>`
  - Shows occurrence counts of raw gain and lost/destroy source codes

#### Debug and Status Commands
- **/ct debug**: Toggle in-game debug logging
  - Parameters: `on` | `off`
  - Enables structured event logging in chat when ON

- **/ct status**: Show system status
  - No parameters
  - Displays module initialization state, version, and debug mode

#### Discovery Commands
- **/ct discover list**: List dynamically discovered currencies
  - No parameters
  - Shows all discovered currency IDs with tracking status

- **/ct discover track**: Track or untrack a discovered currency
  - Parameters: `<id>` `[on|off]`
  - Toggles tracking status for specified currency ID

- **/ct discover clear**: Clear discovered currencies
  - No parameters
  - Removes all discovered currencies for the current character

#### Repair Commands
- **/ct repair init**: Reset currency tracker storage
  - No parameters
  - Clears currency data structures and resets options

- **/ct repair adjust**: Apply signed correction across aggregates
  - Parameters: `<id>` `<delta>` `[source]`
  - Applies adjustment to all time periods

- **/ct repair remove**: Remove recorded amounts from aggregates
  - Parameters: `<id>` `<amount>` `<source>` `(income|outgoing)`
  - Removes specified amount from income or outgoing records

#### UI Command
- **/ct ui**: Open standalone Currency Tracker UI window
  - No parameters
  - Opens the graphical interface for currency tracking

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L1359-L1405)
- [Docs/CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md#L0-L92)

## Command Output Formats
The Currency Tracker commands produce standardized output formats that provide detailed information about currency tracking data.

### /ct show Output Format
The `/ct show` command displays detailed data for a single currency with the following format:
```
[Currency Name] (id=[ID]): [Income Label] [Amount] | [Outgoing Label] | [Net Label] [Signed Amount]
```
- Income and outgoing amounts are displayed as positive numbers
- Net amount is displayed with a sign (+ or -)
- If available, total maximum is displayed at the end
- Multiple rows show breakdown by source

### /ct show-all-currencies Output Format
The `/ct show-all-currencies` command displays a summary across all tracked currencies:
```
[Currency Name] (id=[ID]): [Income Label] [Amount] | [Outgoing Label] [Amount] | [Net Label] [Signed Amount] | [TotalMax Label] [Amount]
```
- One row per tracked currency
- Includes income, outgoing, net, and total maximum values
- Sorted alphabetically by currency name

### /ct meta show Output Format
The `/ct meta show` command displays raw metadata with the following structure:
```
=== Meta Sources - [Timeframe] ([Currency ID]) ===
Gain sources:
  [Source Label]: [Count]
  ...
Destroy/Lost sources:
  [Source Label]: [Count]
  ...
Last: gain=[Value] lost=[Value] sign=[Value] time=[Timestamp]
=========================
```
- Lists all gain and destroy/lost sources with occurrence counts
- Includes the last recorded snapshot information

### /ct status Output Format
The `/ct status` command displays system status information:
```
=== CurrencyTracker Status ===
[Key]: [Value]
...
=== End Status ===
```
- Displays initialization state, enabled status, version, and debug mode
- Additional status information from sub-modules if available

### Error and Confirmation Messages
Commands provide clear feedback with standardized message formats:
- Success messages: `[Action] successful` or `[Action] applied`
- Error messages: `[Command] failed` or `Usage: [Correct syntax]`
- Confirmation messages: `[Action] [details]` with specific parameters

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L1321-L1348)
- [Docs/CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md#L0-L92)

## CLI and UI Functionality Relationship
The Currency Tracker implements a strict separation between command-line interface (CLI) functionality and graphical user interface (UI) functionality, with the CLI serving as the authoritative source for all operations.

### Design Principles
The system follows several key design principles:
- **Headless-first optimization**: The core functionality is designed to work without a UI
- **Single source of truth**: CLI functions serve as the primary implementation
- **UI as renderer**: The UI only renders data and does not reimplement logic
- **Backward compatibility**: UI does not modify existing CLI functions or signatures

### Data Flow Architecture
```mermaid
graph TD
CLI[/ct Commands] --> |Direct Function Calls| Storage[Storage Module]
CLI --> |Direct Function Calls| DataManager[Data Manager]
UI[UI Interface] --> |Direct Function Calls| CLI
UI --> |Read-Only Access| Storage
UI --> |Read-Only Access| DataManager
Storage --> |Persistent Data| SavedVariables[SavedVariables]
DataManager --> |Processed Data| UI
DataManager --> |Processed Data| CLI
```

**Diagram sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L936-L972)
- [CurrencyFrame.lua](file://CurrencyTracker/CurrencyFrame.lua#L0-L799)

### Function Call Relationships
The UI strictly follows the principle of reusing existing CLI logic for operations that modify data:

#### Write Operations (UI delegates to CLI)
- **Tracking toggle**: UI calls `CurrencyTracker:DiscoverTrack(sub)` with equivalent parameters to `/ct discover track`
- **Data corrections**: UI would call repair functions through the same path as CLI commands
- **Configuration changes**: UI uses the same parameter processing as slash commands

#### Read Operations (UI uses direct data access)
- **Currency data**: UI directly calls `CurrencyTracker.DataManager:GetCurrencyData(id, timeframe)`
- **Available currencies**: UI uses `CurrencyTracker.DataManager:GetAvailableCurrencies()`
- **Currency information**: UI accesses `CurrencyTracker.DataManager:GetCurrencyInfo(id)`
- **Discovered currencies**: UI reads from `CurrencyTracker.Storage:GetDiscoveredCurrencies()`

### UI State Management
The UI maintains its own state while respecting the underlying data model:
- **Timeframe selection**: Maps UI button clicks to timeframe parameters used in CLI commands
- **Currency selection**: Translates between UI dropdown selection and currency ID parameters
- **Server and character selection**: Uses the same context variables as the CLI system
- **State persistence**: Stores UI-specific preferences in `currencyOptions` without affecting core functionality

### Command Synchronization
All `/ct` commands are required to update the help text in `CurrencyTracker:ShowHelp()` to maintain consistency between the UI and CLI interfaces. This ensures that any changes to available commands are reflected in both interfaces.

**Section sources**
- [Docs/CurrencyTracker-UI-Design.md](file://Docs/CurrencyTracker-UI-Design.md#L0-L152)
- [CurrencyFrame.lua](file://CurrencyTracker/CurrencyFrame.lua#L0-L799)

## Command Examples
This section provides practical examples of using the `/ct` commands with real-world scenarios.

### Basic Usage Examples
```
/ct show this-week 3008
```
Displays detailed tracking data for Valorstones (ID 3008) for the current week, showing income, outgoing, and net amounts with breakdown by source.

```
/ct show-all-currencies total
```
Shows a summary of all tracked currencies for the total period, listing income, outgoing, and net amounts for each currency.

```
/ct show today
```
Displays data for the currently selected currency for today's tracking period.

### Debugging and Status Examples
```
/ct debug on
```
Enables debug mode, causing the system to log detailed information about currency events in the chat window.

```
/ct status
```
Displays the current system status, including initialization state, version information, and debug mode status.

```
/ct meta show this-session 3284
```
Shows raw metadata for Weathered Ethereal Crest (ID 3284) for the current session, including gain and destroy/lost source counts.

### Discovery Management Examples
```
/ct discover list
```
Lists all discovered currencies with their IDs, names, and tracking status.

```
/ct discover track 3008 on
```
Enables tracking for Valorstones (ID 3008).

```
/ct discover clear
```
Clears all discovered currencies for the current character, requiring rediscovery on subsequent sessions.

### Repair and Maintenance Examples
```
/ct repair init
```
Resets the currency tracker storage for the current character, clearing all currency data while preserving gold tracking data.

```
/ct repair adjust 3008 -157 35
```
Applies a correction of -157 to Valorstones (ID 3008) for source 35, increasing outgoing amounts by 157 across all time periods.

```
/ct repair remove 3008 157 35 income
```
Removes 157 from recorded income for Valorstones (ID 3008) with source 35 across all time periods.

### UI Interaction Examples
```
/ct ui
```
Opens the standalone Currency Tracker UI window, displaying the same data that would be shown by CLI commands in a graphical format.

```
/ct show-all this-month verbose
```
Shows all tracked currencies for this month with verbose output, including untracked currencies in the summary.

**Section sources**
- [Docs/CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md#L0-L92)
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L1376-L1405)

## Configuration and Settings
The Currency Tracker system provides several configuration options that can be modified through slash commands.

### Whitelist Filter Settings
The whitelist filter controls which currencies are displayed in command output:
```
/ct set whitelist on|off
```
- When enabled (default), only currencies in the predefined whitelist are shown
- When disabled, all currencies are eligible for display (tracked filter still applies)
- The whitelist is defined in `CurrencyConstants.CurrencyWhitelist` and includes commonly used currencies

### Near-Cap Warning Configuration
The near-cap warning system can be configured with specific parameters:
```
/ct set-paras near-cap-warning enable=true cap_percent=0.9 time_visible_sec=3 fade_duration_sec=0.8
```
- **enable**: Toggles the near-cap warning system (true/false)
- **cap_percent**: Threshold percentage (0-1) at which to trigger warnings
- **time_visible_sec**: Duration in seconds that the warning message remains visible
- **fade_duration_sec**: Duration in seconds for the warning message fade-out effect

These settings are stored per-character in `currencyOptions.nearCapAlert` and persist across sessions.

### Default Currency Selection
The system maintains a default currency selection that is used when no currency ID is specified in commands:
- Default currency is set to Timewarped Badge (ID 1166)
- Can be changed through the UI or programmatically
- Stored in `currencyOptions.selectedCurrency`

### Tracking Enable/Disable
Currency tracking can be globally enabled or disabled:
- Controlled by `currencyOptions.trackingEnabled`
- Affects whether currency changes are recorded
- Can be modified through the UI or potentially through future CLI commands

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L1359-L1405)
- [CurrencyConstants.lua](file://CurrencyTracker/CurrencyConstants.lua#L0-L554)

## Troubleshooting and Repair Commands
The Currency Tracker includes specialized commands for troubleshooting and repairing data issues.

### Data Initialization and Reset
```
/ct repair init
```
Resets the currency tracker storage for the current character:
- Clears all currency data structures
- Resets options to default values
- Does not affect gold tracker storage
- Useful when encountering data corruption or initialization issues

### Data Correction Commands
```
/ct repair adjust <id> <delta> [source]
```
Applies a signed correction to currency aggregates:
- Positive delta increases income
- Negative delta increases outgoing
- Applies to all time periods (Session, Day, Week, Month, Year, Total)
- Source parameter is optional (defaults to "Unknown")

```
/ct repair remove <id> <amount> <source> (income|outgoing)
```
Removes previously recorded amounts:
- Removes specified amount from income or outgoing records
- Applies to all time periods
- Includes 0-clamp safety to prevent negative values
- Designed for true repairs of erroneous entries

### Baseline Repair Tools
```
/ct repair baseline preview
```
Compares the Accountant Classic - Currency Tracker (AC-CT) Total with live amounts and lists mismatches without making changes.

```
/ct repair baseline
```
Applies Total-only corrections to match live amounts, using the same checks as the preview command. This corrects discrepancies between tracked totals and actual in-game currency amounts.

### Negative Sources Cleanup
```
/ct repair negative-sources preview
```
Previews the removal of negative source keys and baseline reduction, helping identify potential data cleanup opportunities.

### Migration Utilities
```
/ct repair migrate-zero
```
Moves numeric source 0 into 'BaselinePrime' across all timeframes for cosmetic improvement, addressing legacy data formatting issues.

These repair tools are designed to correct data without affecting the gold tracker and provide both preview and apply functionality to prevent accidental data loss.

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L1391-L1405)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L0-L799)

## Conclusion
The Currency Tracker slash commands provide a comprehensive interface for managing and monitoring in-game currency data. The `/ct` command system offers a wide range of functionality from basic data display to advanced troubleshooting and repair operations. The design follows a headless-first approach with CLI commands serving as the primary interface, while the UI provides a visual representation that reuses the same underlying logic.

Key features of the system include:
- Comprehensive command set for viewing, managing, and repairing currency data
- Consistent output formats that provide detailed information
- Strict separation between CLI and UI functionality with the CLI as the authoritative source
- Backward compatibility with existing SavedVariables structures
- Extensive debugging and troubleshooting tools

The relationship between CLI and UI functionality ensures that both interfaces provide consistent results, with the UI acting as a renderer that delegates write operations to the same functions used by slash commands. This architecture maintains data integrity while providing flexibility in how users interact with the system.

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L1321-L1405)
- [Docs/CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md#L0-L92)
- [Docs/CurrencyTracker-UI-Design.md](file://Docs/CurrencyTracker-UI-Design.md#L0-L152)