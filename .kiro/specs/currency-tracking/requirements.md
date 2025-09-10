# Requirements Document

## Introduction

This feature extends Accountant Classic to track all in-game currencies beyond gold, providing comprehensive financial tracking for World of Warcraft players. The system will record gains and expenditures of various currencies (Emblems, Badges, Tokens, etc.) similar to the existing money tracking functionality, while maintaining complete separation from the existing codebase to ensure no disruption to current functionality.

## Requirements

### Requirement 1

**User Story:** As a World of Warcraft player, I want to track all my currency gains and losses (beyond gold), so that I can monitor my financial progress across all currency types.

#### Acceptance Criteria

1. WHEN a player gains or loses any trackable currency THEN the system SHALL record the transaction with source attribution
2. WHEN the system detects a currency change THEN it SHALL store the amount, currency type, timestamp, and source information
3. IF the currency API is available for the client version THEN the system SHALL use official APIs (C_CurrencyInfo)
4. IF the currency API is not available THEN the system SHALL degrade gracefully without errors

### Requirement 2

**User Story:** As a player reviewing my financial history, I want to see currency breakdowns in a dedicated "Currencies" tab, so that I can understand my complete financial picture without cluttering the existing gold display.

#### Acceptance Criteria

1. WHEN viewing the addon interface THEN there SHALL be a new "Currencies" tab added to the existing tab structure
2. WHEN clicking the Currencies tab THEN it SHALL display currency data using the same three-column layout (Source, Incomings, Outgoings) as the gold tabs
3. WHEN displaying currency data THEN it SHALL show Session, Day, Week, Month, Year, and Total breakdowns matching the existing gold interface structure
4. WHEN the Currencies tab is active THEN all existing time period tabs SHALL work with currency data instead of gold data
5. IF no currency data exists THEN the display SHALL show appropriate empty state messages

### Requirement 3

**User Story:** As a player who wants detailed tracking, I want optional per-zone and per-activity attribution for currency transactions, so that I can see where I earned or spent different currencies.

#### Acceptance Criteria

1. WHEN zone tracking is enabled THEN the system SHALL record the zone/subzone where currency transactions occur
2. WHEN activity tracking is feasible THEN the system SHALL attempt to identify the source activity (dungeon, raid, quest, etc.)
3. IF zone information is unavailable THEN the system SHALL record "Unknown Location"
4. WHEN displaying currency details THEN zone and activity information SHALL be shown in tooltips or detailed views

### Requirement 4

**User Story:** As a player managing multiple currency types, I want a currency selection dropdown alongside the existing character dropdown, so that I can easily switch between tracking different currency types.

#### Acceptance Criteria

1. WHEN the currency tab is displayed THEN it SHALL include a currency selection dropdown positioned alongside the existing character dropdown
2. WHEN adding the currency dropdown THEN the existing character dropdown width SHALL be appropriately reduced to accommodate both dropdowns
3. WHEN the currency dropdown is opened THEN it SHALL show all available/trackable currency types
4. WHEN a currency is selected from the dropdown THEN the display SHALL update to show data for that currency type
5. WHEN switching between currencies THEN the selection SHALL be remembered across sessions
6. WHEN implementing initially THEN the system SHALL support at least one currency type with the framework for adding more
7. WHEN both dropdowns are displayed THEN they SHALL have proper spacing and alignment for a clean UI layout

### Requirement 5

**User Story:** As a player concerned about addon performance, I want currency tracking to avoid performance-heavy operations during combat and rapid updates, so that my gameplay is not impacted.

#### Acceptance Criteria

1. WHEN the player is in combat THEN currency tracking SHALL defer non-critical operations
2. WHEN rapid currency updates occur THEN the system SHALL batch updates to prevent performance issues
3. WHEN SavedVariables size grows large THEN the system SHALL provide settings to cap retention
4. IF performance thresholds are exceeded THEN the system SHALL automatically optimize or disable features

### Requirement 6

**User Story:** As a player using the existing Accountant Classic features, I want the new currency tracking to not interfere with current functionality, so that my existing workflows remain unchanged.

#### Acceptance Criteria

1. WHEN currency tracking is installed THEN existing gold tracking SHALL continue to function identically
2. WHEN currency features are disabled THEN no currency-related code SHALL execute
3. IF currency tracking encounters errors THEN it SHALL not affect gold tracking functionality
4. WHEN upgrading the addon THEN existing saved data SHALL remain intact and accessible

### Requirement 7

**User Story:** As a player upgrading from a previous version, I want my existing saved data to remain compatible and accessible, so that I don't lose my historical financial records.

#### Acceptance Criteria

1. WHEN the addon loads existing SavedVariables files THEN it SHALL read all existing gold data without modification
2. WHEN adding currency data storage THEN it SHALL use a separate data structure that doesn't interfere with existing gold data format
3. WHEN the addon saves data THEN existing gold data SHALL be written in the same format as before
4. IF currency data doesn't exist in saved files THEN the system SHALL initialize empty currency structures without affecting gold data
5. WHEN currency data is added THEN it SHALL be stored in a way that older addon versions can safely ignore it
6. IF an older addon version loads the file THEN it SHALL continue to work normally with gold data, ignoring unknown currency fields