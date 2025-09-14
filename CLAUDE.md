# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Accountant Classic is a World of Warcraft addon that tracks gold income/expenses by source across multiple time ranges. Built on ACE3 framework with Lua 5.1.

## Key Architecture Components

### Gold Tracker Module, Core System (`Core/`)
- **Core.lua**: Main logic - event handling, money tracking, UI rendering
- **Constants.lua**: Version detection, configuration defaults, category constants
- **Config.lua**: ACE3 configuration interface
- **MoneyFrame.lua**: Currency formatting utilities

### Currency Tracker Module (`CurrencyTracker/`)
- **CurrencyCore.lua**: Main currency tracking logic
- **CurrencyDataManager.lua**: Data storage and retrieval
- **CurrencyEventHandler.lua**: Event processing
- **CurrencyStorage.lua**: SavedVariables management
- **CurrencyUIController.lua**: UI integration

### Localization (`Locale/`)
- Multiple language files (en, de, fr, es, cn, etc.)
- Uses AceLocale-3.0 for localization

### Libraries (`Libs/`)
- ACE3 framework (AceAddon, AceEvent, AceDB, AceConfig, etc.)
- LibDataBroker-1.1 for minimap/LDB support
- LibDBIcon-1.0 for minimap button
- LibStub for library management

## Development Workflow

### Testing
Since this is a WoW addon, testing is done in-game. Key testing approaches:
- Manual testing with different WoW client versions
- Testing money events: merchant transactions, repairs, quest rewards, etc.
- Cross-character and cross-realm data validation

### Build Process
No traditional build system - files are directly loaded by WoW client. Key files:
- **Accountant_Classic.toc**: Main table of contents file
- **Accountant_Classic-*.toc**: Version-specific TOC files for different WoW clients
- XML files define UI frames and templates

### Code Style
- Lua 5.1 syntax with WoW API conventions
- ACE3 addon patterns with proper namespace management
- Localized strings using AceLocale
- Consistent indentation (spaces, not tabs)

## Key Patterns & Conventions

### Event Handling
- Uses ACE3 event system (`AceEvent-3.0`)
- Core events: `PLAYER_MONEY`, `CHAT_MSG_MONEY`, various UI events for context

### Data Storage
- SavedVariables: `Accountant_ClassicSaveData` (per character)
- Optional: `Accountant_ClassicZoneDB` for zone-level breakdown
- Uses AceDB for profile management

### Money Tracking
- Categorizes transactions by source (MERCH, REPAIR, TAXI, QUEST, etc.)
- Tracks across time windows: Session, Day, Week, Month, Year, Total
- Uses priming system to avoid first-session baseline issues

## Common Development Tasks

### Adding New Currency Sources
1. Add constant in `Core/Constants.lua` under appropriate category
2. Update event handling in `Core/Core.lua:updateLog()`
3. Add localization strings in relevant locale files

### UI Modifications
- Main UI defined in XML templates (`Core/Template.xml`)
- Rendering logic in `Core/Core.lua:AccountantClassic_OnShow()`
- Uses Blizzard UI templates and ACE3 config system

### Localization Updates
- Edit corresponding `Locale/localization.xx.lua` file
- Follow existing pattern for string keys and values
- Test with different client language settings

## Important Notes

- **WoW Version Compatibility**: Code uses version detection in `Constants.lua`
- **Performance**: Avoid heavy operations during combat or rapid money updates
- **SavedVariables**: Be mindful of data size for long-term character profiles
- **Backwards Compatibility**: Maintain existing data structure when modifying storage