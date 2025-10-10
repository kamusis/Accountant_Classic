# Currency Tracking Configuration

<cite>
**Referenced Files in This Document**   
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua)
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua)
- [CurrencyConstants.lua](file://CurrencyTracker/CurrencyConstants.lua)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Near-Cap Warning System](#near-cap-warning-system)
3. [Verbose Display Settings](#verbose-display-settings)
4. [Per-Character Settings Storage](#per-character-settings-storage)
5. [Slash Command Configuration](#slash-command-configuration)
6. [Currency-Specific Options](#currency-specific-options)

## Introduction
The Accountant_Classic Currency Tracker provides comprehensive tracking of in-game currencies across multiple timeframes. This documentation details the configuration options available for customizing the tracking behavior, display settings, and user interface interactions. The system supports per-character persistent settings, slash command configuration, and dynamic currency discovery with backward compatibility.

## Near-Cap Warning System

The near-cap warning system alerts players when a currency approaches its maximum limit. This feature is configurable through slash commands and stores settings per character.

### Configuration Parameters
The following parameters control the near-cap warning behavior:

| Parameter | Default Value | Description |
|---------|---------------|-------------|
| `enable` | `true` | Enables or disables the near-cap warning system |
| `cap_percent` | `0.90` | Threshold percentage (0-1) at which to trigger the warning |
| `time_visible_sec` | `3.0` | Duration in seconds that the warning message remains visible |
| `fade_duration_sec` | `0.8` | Duration in seconds for the warning message fade-out animation |

### Configuration Commands
The system uses the `/ct set-paras near-cap-warning` command to configure these parameters:

```
/ct set-paras near-cap-warning enable=true cap_percent=0.9 time_visible_sec=3 fade_duration_sec=0.8
```

Individual parameters can be modified without affecting others. The system accepts various input formats including decimal points, unit suffixes (s, sec), and boolean values (true/false, on/off, 1/0).

### Warning Display
When a currency reaches or exceeds the configured threshold, a warning message appears in the UI error frame with the following format:
```
Warning: [Currency Name] has reached or exceeded 90% of total cap ([Cap Amount])
```

If the UI error frame is unavailable, the warning falls back to a red-colored chat message.

**Section sources**
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L750-L850)
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L450-L550)

## Verbose Display Settings

The currency tracking system provides verbose display options for detailed analysis of currency transactions across different timeframes.

### Timeframe Options
The system tracks currency data across multiple time periods:

- **Session**: Current login session
- **Day**: Daily tracking (resets daily)
- **Week**: Weekly tracking (resets weekly)
- **Month**: Monthly tracking (resets monthly)
- **Year**: Yearly tracking (resets annually)
- **Total**: Lifetime tracking
- **PrvDay/PrvWeek/PrvMonth/PrvYear**: Previous period rollover data

### Display Commands
The `/ct show` command family controls verbose display:

```
/ct show [timeframe] [currency_id] [verbose]
/ct show-all-currencies [timeframe] [verbose]
```

When verbose mode is enabled, the system displays detailed transaction sources and amounts for each currency.

### Data Presentation
The verbose display shows:
- Income and outgoing amounts
- Net change (income minus outgoing)
- Transaction sources categorized by gain/loss reason
- Historical comparisons across time periods

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L300-L400)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L150-L200)

## Per-Character Settings Storage

The currency tracking system stores configuration options on a per-character basis using the SavedVariables system.

### Storage Structure
Settings are stored in the `Accountant_ClassicSaveData` table with the following structure:

```lua
Accountant_ClassicSaveData[server][character].currencyOptions = {
    selectedCurrency = 1166,
    trackingEnabled = true,
    lastUpdate = time(),
    version = "3.00.00",
    whitelistFilter = true,
    nearCapAlert = {
        enable = true,
        cap_percent = 0.90,
        time_visible_sec = 3.0,
        fade_duration_sec = 0.8,
    }
}
```

### Key Settings
The following settings are stored per character:

- **selectedCurrency**: The currently selected currency for detailed viewing
- **trackingEnabled**: Global toggle for currency tracking
- **whitelistFilter**: Controls whether to filter currencies by the allowlist
- **nearCapAlert**: Configuration for the near-cap warning system
- **lastUpdate**: Timestamp of the last update for data integrity

### Initialization
The storage system initializes these structures automatically when a character first uses the currency tracker, ensuring backward compatibility with existing SavedVariables.

**Section sources**
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L500-L600)
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L500-L600)

## Slash Command Configuration

The currency tracker provides a comprehensive set of slash commands for configuration and interaction.

### Command Structure
All commands are accessed through the `/ct` prefix:

```
/ct [command] [parameters]
```

### Core Commands
The following commands are available:

| Command | Parameters | Description |
|--------|------------|-------------|
| `show` | `[timeframe] [currency_id] [verbose]` | Display currency data for a specific currency |
| `show-all-currencies` | `[timeframe] [verbose]` | Display summary for all tracked currencies |
| `debug` | `on|off` | Enable or disable debug mode |
| `status` | | Display system status information |
| `ui` | | Open the standalone currency tracking UI |
| `set whitelist` | `on|off` | Enable or disable the currency allowlist filter |
| `set-paras near-cap-warning` | `key=value` | Configure near-cap warning parameters |

### Advanced Commands
Additional commands for maintenance and diagnostics:

```
/ct repair remove <id> <amount> <source> (income|outgoing)
/ct repair adjust <id> <delta> [source]
/ct discover track <id> [on|off]
/ct discover list
/ct discover clear
```

These commands allow administrators to repair data, adjust currency amounts, and manage discovered currencies.

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L600-L800)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L300-L400)

## Currency-Specific Options

The system provides specialized handling for different currency types with various configuration options.

### Currency Allowlist
The system maintains a curated whitelist of currencies to display by default:

```lua
CurrencyConstants.CurrencyWhitelist = {
    81,   -- Epicurean Award
    515,  -- Darkmoon Prize Ticket
    2588, -- Riders of Azeroth Badge
    -- ... additional currencies
}
```

This filter can be toggled on or off using the `/ct set whitelist` command.

### Special Currency Handling
Certain currencies have special metadata for enhanced tracking:

```lua
CurrencyConstants.SpecialCurrency = {
    [1129] = { -- Seal of Tempered Fate
        weeklyMax = 3,
        earnByQuest = { /* quest IDs */ },
    },
    [1273] = { -- Seal of Broken Fate
        weeklyMax = 3,
        earnByQuest = { /* quest IDs */ },
    },
}
```

This metadata enables features like weekly cap tracking and quest-based income analysis.

### Dynamic Discovery
The system automatically discovers new currencies when encountered:

- Records basic metadata (name, icon, expansion)
- Tracks whether the currency should be displayed
- Maintains backward compatibility with older SavedVariables
- Supports both account-wide and character-specific discovery

**Section sources**
- [CurrencyConstants.lua](file://CurrencyTracker/CurrencyConstants.lua#L400-L500)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L250-L300)