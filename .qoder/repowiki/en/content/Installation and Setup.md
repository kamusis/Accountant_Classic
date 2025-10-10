# Installation and Setup

<cite>
**Referenced Files in This Document**   
- [README.md](file://README.md)
- [Core/Core.lua](file://Core/Core.lua)
- [Core/Constants.lua](file://Core/Constants.lua)
- [Libs/AceDB-3.0/AceDB-3.0.lua](file://Libs/AceDB-3.0/AceDB-3.0.lua)
- [Core/Config.lua](file://Core/Config.lua)
- [Core/MoneyFrame.lua](file://Core/MoneyFrame.lua)
</cite>

## Table of Contents
1. [Download and Folder Placement](#download-and-folder-placement)
2. [Enable the Addon](#enable-the-addon)
3. [First-Time Initialization](#first-time-initialization)
4. [Verify Successful Installation](#verify-successful-installation)
5. [Troubleshooting Common Issues](#troubleshooting-common-issues)
6. [Post-Installation Verification](#post-installation-verification)

## Download and Folder Placement

To install Accountant_Classic, follow these steps:

1. Close the World of Warcraft client completely.
2. Locate your World of Warcraft installation directory. This is typically found in one of the following locations:
   - Windows: `C:\Program Files\World of Warcraft\`
   - macOS: `/Applications/World of Warcraft/`
3. Navigate to the appropriate AddOns folder based on your WoW client version:
   - **WoW Classic Era, Hardcore, or Season of Discovery**: `_classic_/Interface/AddOns/`
   - **Wrath of the Lich King Classic or Cataclysm Classic**: `_classic_*/Interface/AddOns/`
   - **Retail WoW**: `_retail_/Interface/AddOns/`
4. Copy the entire `Accountant_Classic` folder from the downloaded archive into the AddOns directory.
5. Ensure the folder structure is correct: `AddOns\Accountant_Classic\` should contain subfolders like `Core`, `Libs`, and `Locale`.

**Section sources**
- [README.md](file://README.md#L45-L52)

## Enable the Addon

After placing the addon folder, you can enable Accountant_Classic through either the WoW Launcher or the in-game interface:

**Via WoW Launcher:**
1. Launch the Battle.net application.
2. Select your World of Warcraft installation.
3. Click on "Options" and ensure the correct game version is selected (Classic or Retail).
4. Click "Launch" to start the game.
5. On the character selection screen, click the "AddOns" button in the lower-left corner.
6. In the AddOns window, find "Accountant Classic" in the list.
7. Check the box next to it to enable the addon.
8. Click "Close" and then select your character to enter the game.

**Via In-Game Interface:**
1. Launch World of Warcraft and log in to your character.
2. Type `/addons` in the chat window or navigate to the main menu (Esc) > "AddOns".
3. Find "Accountant Classic" in the list and ensure it is enabled.
4. Reload the UI with `/reload` if necessary.

**Section sources**
- [README.md](file://README.md#L54-L56)

## First-Time Initialization

When you first load Accountant_Classic on a character, the addon performs an automatic initialization process:

1. **AceDB Initialization**: The addon uses AceDB-3.0 to manage its saved variables. On first load, it checks for the existence of `Accountant_ClassicSaveData` and `Accountant_ClassicZoneDB` in the SavedVariables file.
2. **Profile Creation**: If no saved data exists for the current character, Accountant_Classic creates a new profile using default settings defined in `AccountantClassicDefaultOptions`. This includes setting the current date, week start day, and faction/class information.
3. **Baseline Priming**: To prevent the addon from incorrectly logging your current gold amount as income, it implements a "priming" mechanism. The first time the addon detects a money change (via `PLAYER_MONEY` or `CHAT_MSG_MONEY` event), it sets this amount as the baseline. Subsequent changes are then tracked as actual income or expenses.
4. **One-Time Alert**: After priming, the addon displays a yellow chat message: "Accountant Classic: Baseline primed. Subsequent money changes will be tracked." This only appears once per session.

This initialization ensures that your gold tracking starts accurately without including your existing balance as earned income.

**Section sources**
- [Core/Core.lua](file://Core/Core.lua#L150-L200)
- [Core/Core.lua](file://Core/Core.lua#L290-L330)
- [README.md](file://README.md#L72-L80)

## Verify Successful Installation

After installation and initialization, verify that Accountant_Classic is working correctly:

1. **Minimap Button**: Look for a small button near the minimap. By default, this should be visible unless disabled in settings.
2. **Slash Commands**: Type `/accountant` or `/acc` in the chat window. This should open the main Accountant Classic window.
3. **Data Tracking**: Perform a money transaction (e.g., sell an item to a vendor) and check if the amount is reflected in the addon's tracking.
4. **Main Window**: The main window should display categories like "Merchants," "Taxi Fares," and "Training Costs" with corresponding income and expense amounts.
5. **LDB Support**: If you use a DataBroker display (like Titan Panel), Accountant_Classic should appear as a data source showing your current gold or session earnings.

**Section sources**
- [README.md](file://README.md#L82-L88)

## Troubleshooting Common Issues

### Addon Fails to Load
**Symptoms**: The addon does not appear in the AddOns list, or you receive a "Load out of date" warning.

**Causes and Solutions**:
- **Missing Dependencies**: Accountant_Classic includes all required libraries (Ace3, LibStub, etc.) in its `Libs` folder. Ensure the entire `Accountant_Classic` folder was copied correctly.
- **File Permission Errors**: On some systems, extracted files may have restricted permissions. Ensure the addon folder and all contents are readable by the WoW client.
- **Conflicting Addons**: Another addon named "Accountant" may conflict. The installation process should detect this and disable the conflicting addon.

**Section sources**
- [README.md](file://README.md#L110-L113)
- [Core/Core.lua](file://Core/Core.lua#L45-L55)

### UI Does Not Appear
**Symptoms**: The minimap button is missing, and slash commands do not open the window.

**Solutions**:
1. Check if the addon is enabled on the character selection screen.
2. Type `/console reloadui` to reload the interface.
3. Verify that the `showbutton` profile setting is enabled. You can reset settings with `/accountant reset`.
4. Check for Lua errors by enabling `/console scriptErrors 1` and looking for red error messages.

### Data Not Being Tracked
**Symptoms**: Transactions are not recorded in the appropriate categories.

**Causes and Solutions**:
- **Event Registration**: The addon listens to specific WoW events (like `MERCHANT_SHOW`, `PLAYER_MONEY`) to determine context. If these events are blocked by another addon, tracking may fail.
- **Priming Issues**: If the baseline priming fails, no tracking will occur. Log out and back in to reset the priming state.
- **Zone Tracking**: If "Track location" is enabled but not working, ensure you have the latest version, as zone tracking uses specific API calls that may vary by game version.

**Section sources**
- [Core/Core.lua](file://Core/Core.lua#L100-L120)
- [Core/Constants.lua](file://Core/Constants.lua#L40-L100)

### Ace3 Libraries and LibStub
Accountant_Classic uses the Ace3 framework and LibStub for dependency management:

- **LibStub**: This library handles version control for embedded libraries. It ensures that only the newest version of each library is loaded, even if multiple addons include different versions.
- **AceDB-3.0**: Manages the addon's saved variables, providing profile support and data persistence.
- **Automatic Updates**: You do not need to manually update Ace3 libraries. They are bundled with the addon, and LibStub ensures compatibility.

If you encounter library-related errors, completely remove and reinstall the addon to ensure all library files are present and up to date.

**Section sources**
- [Libs/AceDB-3.0/AceDB-3.0.lua](file://Libs/AceDB-3.0/AceDB-3.0.lua#L1-L50)
- [Libs/LibStub/LibStub.lua](file://Libs/LibStub/LibStub.lua#L1-L20)

## Post-Installation Verification

After installation and troubleshooting, verify the addon is functioning as expected:

1. **Expected Behaviors**:
   - The minimap button should be visible and interactive.
   - Slash commands `/accountant` and `/acc` should open the main window.
   - The main window should display accurate totals for income and expenses.
   - Category breakdowns (Merchants, Taxi, etc.) should update after relevant transactions.
   - The "All Chars" tab should show data from all your characters if cross-server tracking is enabled.

2. **Configuration**:
   - Access settings via right-click on the minimap button or through the Interface Options menu.
   - Customize display options, such as showing session earnings on the button tooltip.
   - Adjust the scale and transparency of the main frame and floating money display.

3. **Data Persistence**:
   - Log out and back in to confirm that your tracked data persists.
   - Verify that the `Accountant_ClassicSaveData.lua` file in your SavedVariables directory is being updated.

By following these steps, you can ensure Accountant_Classic is properly installed and configured for accurate gold tracking in World of Warcraft Classic.

**Section sources**
- [README.md](file://README.md#L82-L88)
- [Core/Config.lua](file://Core/Config.lua#L1-L50)
- [Core/MoneyFrame.lua](file://Core/MoneyFrame.lua#L1-L20)