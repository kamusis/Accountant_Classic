# Implementation Plan

- [x] 1. Set up Currency Tracker module structure and core interfaces

  - Create CurrencyTracker directory and main module files
  - Define core interfaces and module initialization framework
  - Establish module enable/disable functionality
  - _Requirements: 6.1, 6.2_

- [x] 2. Implement currency constants and supported currency definitions

  - Create CurrencyConstants.lua with supported currency definitions
  - Define currency metadata including patch versions and expansion groupings
  - Implement version comparison utilities for patch filtering
  - Add Valorstones (ID: 3008) as the primary test currency
  - _Requirements: 1.1, 4.5_

- [x] 3. Create currency storage system with backward compatibility

  - Implement CurrencyStorage.lua for data persistence
  - Design additive SavedVariables structure that doesn't modify existing data
  - Create safe initialization that preserves existing gold tracking data
  - Implement data migration utilities for future version upgrades
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [x] 4. Implement currency data manager with generic tracking logic

  - Create CurrencyDataManager.lua with currency tracking operations
  - Implement TrackCurrencyChange function that works with any currency ID
  - Create data retrieval methods for different time periods (Session, Day, Week, etc.)
  - Add currency filtering by patch version and expansion
  - _Requirements: 1.1, 1.2, 4.5_

- [x] 5. Create currency event handler for WoW API integration

  - Implement CurrencyEventHandler.lua for monitoring currency changes
  - Register for CURRENCY_DISPLAY_UPDATE and BAG_UPDATE events
  - Add fallback detection methods for older WoW client versions
  - Implement combat awareness and update batching for performance
  - _Requirements: 1.1, 1.3, 1.4, 5.1, 5.2, 5.3_

- [x] 6. Build currency UI controller for tab and dropdown management

  - Create CurrencyUIController.lua for UI management
  - Implement currency tab creation that integrates with existing tab system
  - Create currency dropdown with expansion and patch grouping
  - Add layout adjustments for dual dropdown display (character + currency)
  - _Requirements: 2.1, 2.2, 4.1, 4.2, 4.7_

- [x] 7. Create main CurrencyCore.lua orchestration module

  - Implement main CurrencyCore.lua that orchestrates all components
  - Add proper module loading order and dependency management
  - Ensure clean module enable/disable functionality
  - _Requirements: 6.1, 6.2_

- [x] 8. Fix UI controller implementation issues

  - Fix syntax errors in CurrencyUIController.lua (broken comment line)
  - Add missing constants for GOLD_TAB_INDEX and CURRENCY_TAB_INDEX
  - Fix undefined global variables (goldTab, isCurrencyTabActive)
  - Ensure proper local variable declarations
  - _Requirements: 2.1, 6.3_

- [x] 9. Integrate CurrencyTracker module with main addon

  - Update .toc files to include CurrencyTracker/CurrencyTracker.xml
  - Add integration hooks to existing Core files to initialize CurrencyTracker
  - Ensure proper load order and dependency management
  - Test that module loads without breaking existing functionality
  - _Requirements: 6.1, 6.4_

- [x] 10. Implement two-tier tab system integration

  - Hook into existing AccountantClassicFrame to add Gold/Currency top-level tabs
  - Ensure existing time period tabs (Session, Day, Week, etc.) work for both modes
  - Implement tab switching logic that preserves existing functionality
  - Add proper tab appearance updates to show which top-level tab is active
  - _Requirements: 2.1, 2.3, 2.4, 6.1_

-

- [x] 11. Implement currency data integration with existing display system

  - Hook into existing display refresh functions to show currency data when currency tab is active
  - Ensure currency data uses the same three-column layout (Source, Incomings, Outgoings)
  - Implement currency-specific data formatting and source attribution
  - Add currency data aggregation for time period filtering (Session, Day, Week, etc.)
  - Ensure "All Chars" functionality works for currency data across characters
  - _Requirements: 2.2, 2.5, 3.1, 3.2, 3.3_

- [x] 12. Complete currency UI functionality

  - Implement currency dropdown show/hide logic based on active top-level tab
  - Add currency selection change handling that refreshes display appropriately
  - Create currency-specific tooltips with expansion, patch, and description information
  - Implement proper empty state handling when no currency data is available
  - Add currency icon display in dropdown and relevant UI elements
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.6_

- [x] 13. Validate Valorstones tracking with existing framework






  - Verify Valorstones (ID: 3008) is properly configured in constants
  - Test end-to-end workflow: detection → storage → display using existing generic logic
  - Validate that existing generic currency framework handles Valorstones correctly
  - Create test scenarios for Valorstones transactions to prove framework works
  - Document any gaps or issues found in the generic implementation
  - _Requirements: 1.1, 1.2, 4.5_
  - _Note: No new currency-specific code needed - testing existing generic framework_

- [ ] 14. Enhance zone and activity source detection

  - Add zone tracking using GetZoneText()/GetSubZoneText() APIs to existing IdentifySource() function
  - Enhance activity detection beyond basic UI frame checking (dungeon, raid, battleground detection)
  - Add more sophisticated source classification to existing EventHandler logic
  - Extend existing source attribution without rewriting core logic
  - Ensure enhanced tracking respects existing user preferences
  - _Requirements: 3.1, 3.2, 3.3, 3.4_
  - _Note: Extending existing IdentifySource() function, not implementing from scratch_

- [ ] 15. Add advanced error recovery mechanisms

  - Implement SavedVariables corruption detection and recovery (extends existing storage validation)
  - Add configurable logging levels to existing LogError/LogDebug system
  - Create data integrity validation and repair functions for currency data
  - Add performance monitoring and automatic throttling to existing batch processing
  - Ensure advanced error recovery doesn't affect existing gold tracking
  - _Requirements: 1.4, 6.3, 7.6_
  - _Note: Basic error handling already extensively implemented - adding advanced recovery only_

- [ ] 16. Create comprehensive testing and validation suite
  - Test backward compatibility with existing SavedVariables structure
  - Validate that existing gold tracking remains completely unaffected
  - Test currency tracking across different WoW client versions (Classic, TBC, Wrath, Retail)
  - Verify UI integration doesn't break existing functionality
  - Create automated test scenarios for all currency operations
  - Test complete addon functionality with currency tracking enabled and disabled
  - Validate cross-character and cross-server currency data functionality
  - Test performance impact and memory usage with large currency datasets
  - _Requirements: 6.1, 6.4, 7.1, 7.2, 7.3, 7.4_

## Implementation Status Summary

### ✅ **Core Framework Complete (Tasks 1-12)**

The following functionality is **already fully implemented**:

- **Generic Currency Tracking**: Framework supports any currency ID without currency-specific code
- **Event Detection**: Universal event handling for all supported currencies via `CurrencyEventHandler`
- **Data Management**: Generic storage and retrieval for any currency via `CurrencyDataManager`
- **UI Framework**: Complete two-tier tab system with currency dropdown via `CurrencyUIController`
- **Storage System**: Backward-compatible SavedVariables integration via `CurrencyStorage`
- **Display Integration**: Currency data display using existing three-column layout
- **Error Handling**: Extensive error handling, logging, and fallback mechanisms throughout
- **API Compatibility**: Support for modern and legacy WoW APIs with graceful degradation

### 🔧 **Remaining Work (Tasks 13-16)**

The remaining tasks focus on **validation, enhancement, and testing**:

- **Task 13**: Test existing framework with Valorstones (no new implementation needed)
- **Task 14**: Enhance existing source detection with zone/activity details
- **Task 15**: Add advanced error recovery to existing error handling system
- **Task 16**: Comprehensive testing of complete system

### 🚫 **What Does NOT Need Implementation**

- Currency-specific tracking logic (generic framework handles all currencies)
- Basic error handling (extensively implemented)
- API fallback mechanisms (already implemented)
- Core UI components (two-tier tabs, dropdown, display integration complete)
- Basic source identification (already implemented)
- Storage structures (backward-compatible system complete)
