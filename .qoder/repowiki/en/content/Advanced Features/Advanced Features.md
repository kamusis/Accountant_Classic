# Advanced Features

<cite>
**Referenced Files in This Document**   
- [MoneyFrame.lua](file://Core/MoneyFrame.lua)
- [Bindings.xml](file://Bindings.xml)
- [LibDataBroker-1.1.lua](file://Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua)
- [Core.lua](file://Core/Core.lua)
</cite>

## Table of Contents
1. [Floating Money Frame Module](#floating-money-frame-module)
2. [Key Binding Functionality](#key-binding-functionality)
3. [LibDataBroker Integration](#libdatabroker-integration)
4. [Zone-Level Breakdown System](#zone-level-breakdown-system)
5. [Performance Considerations](#performance-considerations)
6. [Advanced Feature Use Cases](#advanced-feature-use-cases)

## Floating Money Frame Module

The floating money frame module is implemented as a separate Ace3 module in MoneyFrame.lua that displays real-time gold changes. This module creates a movable, persistent UI element that shows the player's current gold amount and provides contextual tooltips with session financial data.

The module is initialized as an Ace3 module named "MoneyFrame" that inherits from AceEvent-3.0, enabling it to respond to in-game events:

```lua
local MoneyFrame = addon:NewModule("MoneyFrame", "AceEvent-3.0")
```

The frame is created through the `createMoneyFrame()` function, which generates a UI frame anchored to UIParent with specific positioning and styling:

```lua
local function createMoneyFrame()
    local f = CreateFrame("Frame", "AccountantClassicMoneyInfoFrame", UIParent)
    f:SetWidth(160)
    f:SetHeight(21)
    f:SetPoint(point or "TOPLEFT", UIParent, relativePoint or "TOPLEFT", ofsx or 10, ofsy or -80)
    -- Additional frame configuration
end
```

The module uses an OnUpdate script to continuously monitor and update the displayed gold amount. The `frame_OnUpdate()` function checks for changes in the player's money and updates the text accordingly:

```lua
local function frame_OnUpdate(self)
    local frametxt = "|cFFFFFFFF"..addon:GetFormattedValue(GetMoney())
    if (frametxt ~= AC_MNYSTR) then
        self.Text:SetText(frametxt)
        AC_MNYSTR = frametxt
        local width = self.Text:GetStringWidth()
        self:SetWidth(width)
    end
end
```

When the player hovers over the frame, a tooltip appears showing detailed session financial information, including total incoming and outgoing gold. This is handled by the `frame_OnEnter()` function which retrieves session data from the addon's core functionality:

```lua
local function frame_OnEnter(self)
    if (isInLockdown) then
        return
    end
    
    local tooltip = GameTooltip
    if (not tooltip:IsShown()) then
        local amoney_str = addon:ShowSessionToolTip()
        tooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", -10, 0)
        GameTooltip_SetTitle(tooltip, "|cFFFFFFFF"..L["Accountant Classic"].." - "..L["This Session"])
        GameTooltip_AddNormalLine(tooltip, amoney_str, true)
        tooltip:Show()
    end
end
```

The module also handles player interaction, allowing the frame to be moved by left-click dragging and opening the main addon interface on right-click:

```lua
local function frame_OnMouseDown(self, button)    
    if (button == "LeftButton") then
        self:StartMoving()
    elseif (button == "RightButton") then
        AccountantClassic_ButtonOnClick()
    end
end
```

The module responds to combat lockdown status by disabling movement functionality when the player is in combat, preventing UI manipulation during combat:

```lua
function MoneyFrame:PLAYER_REGEN_DISABLED()
    isInLockdown = true
end

function MoneyFrame:PLAYER_REGEN_ENABLED()
    isInLockdown = false
end
```

Configuration options for the frame's visibility, scale, and transparency are stored in the addon's database and applied when the module is enabled:

```lua
function MoneyFrame:OnEnable()
    if (profile.showmoneyinfo == true) then
        self.frame:Show()
        self:ArrangeMoneyInfoFrame()
    else
        self.frame:Hide()
    end
end
```

**Section sources**
- [MoneyFrame.lua](file://Core/MoneyFrame.lua#L1-L169)

## Key Binding Functionality

The key binding functionality is defined in Bindings.xml, which establishes a custom keybind that allows players to toggle the Accountant Classic interface. This keybind is integrated with the World of Warcraft key binding system, making it configurable through the game's interface options.

The binding is defined with a unique name and category, allowing it to appear in the AddOns section of the key binding interface:

```xml
<Bindings>
    <Binding name="ACCOUNTANT_CLASSIC_TOGGLE" header="ACCOUNTANT_CLASSIC_TITLE" category="ADDONS">
        AccountantClassic_ButtonOnClick();
    </Binding>
</Bindings>
```

The binding executes the `AccountantClassic_ButtonOnClick()` function, which toggles the visibility of the main addon frame:

```lua
function AccountantClassic_ButtonOnClick()
    if AccountantClassicFrame:IsVisible() then
        AccountantClassicFrame:Hide();
    else
        AccountantClassicFrame:Show();
    end
end
```

This keybind can be set in-game through the key binding interface under the "AddOns" category. Players can assign any key combination to this function, providing flexibility in how they access the addon's interface.

The binding is registered with the addon during initialization, ensuring it's available when the addon loads. The function it calls is also used for other interface interactions, such as clicking the minimap button, creating a consistent user experience across different access methods.

**Section sources**
- [Bindings.xml](file://Bindings.xml#L1-L9)
- [Core.lua](file://Core/Core.lua#L1000-L1010)

## LibDataBroker Integration

The addon integrates with LibDataBroker-1.1 to enable data sharing with other addons and display through various LDB consumers. This integration allows the addon's financial data to be displayed in popular data broker displays like Titan Panel, ChocolateBar, or other LDB-compatible addons.

The integration is established in the addon's OnInitialize function, where a new data object is created using LibDataBroker:

```lua
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(private.addon_name);
```

The data object is configured with essential properties that define how it appears in LDB displays:

```lua
LDB.type = "data source";
LDB.text = L["Accountant Classic"];
LDB.label = L["Accountant Classic"];
LDB.icon = "Interface\\AddOns\\Accountant_Classic\\Images\\AccountantClassicButton-Up";
```

The data object includes an OnClick handler that responds to mouse clicks on the LDB display:

```lua
LDB.OnClick = (function(self, button)
    if button == "LeftButton" then
        AccountantClassic_ButtonOnClick();
    elseif button == "RightButton" then
        addon:OpenOptions();
    end
end);
```

The OnTooltipShow function provides rich tooltip information when the player hovers over the LDB display:

```lua
LDB.OnTooltipShow = (function(tooltip)
    local title = "|cffffffff"..L["Accountant Classic"];
    if (profile.showmoneyonbutton) then
        title = title.." - "..addon:GetFormattedValue(GetMoney());
    end
    tooltip:AddLine(title);
    if (profile.showsessiononbutton == true) then
        tooltip:AddLine(addon:ShowSessionToolTip());
    end
end);
```

The text displayed by the LDB consumer is dynamically updated based on the player's configuration, showing either the current gold amount or net profit/loss for the selected time period:

```lua
LDB.text = addon:ShowNetMoney(private.constants.ldbDisplayTypes[profile.ldbDisplayType]) or ""
```

This integration allows players to customize how financial information is displayed in their UI, choosing between various presentation options and locations based on their preferred LDB display addon.

**Section sources**
- [LibDataBroker-1.1.lua](file://Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua#L1-L91)
- [Core.lua](file://Core/Core.lua#L150-L180)

## Zone-Level Breakdown System

The zone-level breakdown system provides detailed location context for financial transactions, allowing players to analyze where money was earned or spent. This system maintains transaction data organized by zone and subzone, enabling detailed geographical analysis of financial activities.

The system is implemented through the Accountant_ClassicZoneDB global table, which stores financial data hierarchically by server, player, log mode, log type, and zone:

```lua
local function AccountantClassic_InitZoneDB()
    if (Accountant_ClassicZoneDB == nil) then
        Accountant_ClassicZoneDB = { }
    end
    if (Accountant_ClassicZoneDB[AC_SERVER] == nil) then
        Accountant_ClassicZoneDB[AC_SERVER] = { }
    end
    if (Accountant_ClassicZoneDB[AC_SERVER][AC_PLAYER] == nil) then
        Accountant_ClassicZoneDB[AC_SERVER][AC_PLAYER] = { 
            data = { }
        }
    end
    -- Initialize data structures for all log modes and types
end
```

When a money transaction occurs, the system records the transaction in the appropriate zone context. The zone text is obtained from the game's API and optionally includes subzone information based on user preferences:

```lua
local zoneText = GetZoneText();
if ( not IsInInstance() ) then
    if (profile.tracksubzone == true and GetSubZoneText() ~= "" ) then
        zoneText = format("%s - %s", GetZoneText(), GetSubZoneText());
    end
end
```

Financial transactions are recorded in the zone database with separate tracking for income and expenditures:

```lua
-- For income
Accountant_ClassicZoneDB[AC_SERVER][AC_PLAYER]["data"][logmode][logtype][zoneText].In = 
    Accountant_ClassicZoneDB[AC_SERVER][AC_PLAYER]["data"][logmode][logtype][zoneText].In + diff;

-- For expenditures
Accountant_ClassicZoneDB[AC_SERVER][AC_PLAYER]["data"][logmode][logtype][zoneText].Out = 
    Accountant_ClassicZoneDB[AC_SERVER][AC_PLAYER]["data"][logmode][logtype][zoneText].Out + diff;
```

The system supports tooltips that display zone-specific financial data when hovering over transaction rows in the interface:

```lua
function AccountantClassic_LogTypeOnShow(self)
    if (profile.trackzone == true and self.logType and self.cashflow) then
        local logmode = private.constants.logmodes[AC_CURRTAB];
        local logType = self.logType;
        local cashflow = self.cashflow;
        
        if (logmode == "Session") then
            for k_zone, v_zone in orderedpairs(Accountant_ClassicZoneDB[serverkey][charkey]["data"][logmode][logType]) do
                mIn = Accountant_ClassicZoneDB[serverkey][charkey]["data"][logmode][logType][k_zone]["In"];
                mOut = Accountant_ClassicZoneDB[serverkey][charkey]["data"][logmode][logType][k_zone]["Out"];
                -- Format tooltip text with zone and amounts
            end
        end
    end
end
```

The zone database is initialized and reset appropriately for different time periods, ensuring data is properly segmented:

```lua
-- Reset session DB
Accountant_ClassicZoneDB[AC_SERVER][AC_PLAYER]["data"]["Session"] = { };
for k_logtype, v_logtype in pairs(private.constants.logtypes) do
    Accountant_ClassicZoneDB[AC_SERVER][AC_PLAYER]["data"]["Session"][v_logtype] = { };
end
```

This system enables players to analyze their farming efficiency by location, identify profitable zones, and track expenditures in specific areas, providing valuable insights for gold-making strategies.

**Section sources**
- [Core.lua](file://Core/Core.lua#L239-L265)
- [Core.lua](file://Core/Core.lua#L1122-L1148)
- [Core.lua](file://Core/Core.lua#L2050-L2074)

## Performance Considerations

The floating frame feature is designed with performance optimization in mind to prevent UI clutter and minimize resource usage. The implementation includes several strategies to ensure smooth gameplay while providing real-time financial information.

The frame update mechanism uses change detection to minimize unnecessary UI updates. Instead of updating on every frame, it only updates when the displayed gold amount has actually changed:

```lua
local function frame_OnUpdate(self)
    local frametxt = "|cFFFFFFFF"..addon:GetFormattedValue(GetMoney())
    if (frametxt ~= AC_MNYSTR) then
        self.Text:SetText(frametxt)
        AC_MNYSTR = frametxt
        local width = self.Text:GetStringWidth()
        self:SetWidth(width)
    end
end
```

This approach prevents constant UI refreshes, reducing CPU usage and preventing frame rate drops. The comparison with the previous text value ensures updates only occur when necessary.

The module properly manages event registration and unregistration to prevent memory leaks and unnecessary event processing:

```lua
function MoneyFrame:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    -- Show frame if enabled in settings
end

function MoneyFrame:OnDisable()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:Hide()
end
```

The combat lockdown detection prevents players from moving the frame during combat, which could lead to accidental UI manipulation and potential gameplay disruption:

```lua
function MoneyFrame:PLAYER_REGEN_DISABLED()
    isInLockdown = true
end
```

The frame is created only once and reused, rather than being recreated each time it's shown. This reduces memory allocation and garbage collection overhead:

```lua
local function createMoneyFrame()
    local f
    if not f then f = CreateFrame("Frame", "AccountantClassicMoneyInfoFrame", UIParent) end
    -- Configure existing frame
end
```

Configuration options allow players to disable the floating frame entirely if they prefer a cleaner UI or are experiencing performance issues:

```lua
if (profile.showmoneyinfo == true) then
    self.frame:Show()
else
    self.frame:Hide()
end
```

These performance considerations ensure that the floating frame feature provides valuable information without negatively impacting game performance or creating UI clutter.

**Section sources**
- [MoneyFrame.lua](file://Core/MoneyFrame.lua#L1-L169)

## Advanced Feature Use Cases

The advanced features of Accountant Classic can be combined in powerful ways to optimize gameplay and financial management. These use cases demonstrate how players can leverage multiple features together for enhanced functionality.

### Farming Optimization with Floating Frame and Zone Analysis

Players can use the floating money frame alongside the zone-level breakdown system to optimize farming routes. The real-time gold display allows immediate feedback on income, while the zone analysis provides detailed post-session review:

1. Enable the floating money frame to monitor real-time gold changes during farming
2. Set the LDB display to show net profit for the current session
3. After farming, review the zone breakdown to identify the most profitable locations
4. Use this data to refine farming routes and focus on high-yield areas

This combination provides both immediate feedback and long-term analysis capabilities, enabling data-driven decisions about where to farm for maximum efficiency.

### Key Binding and Data Broker Integration for Quick Access

Players can configure custom keybinds in conjunction with LDB displays for rapid access to financial information:

1. Set a keybind to toggle the Accountant Classic interface
2. Configure an LDB display (like Titan Panel) to show current gold or session profit
3. Use the keybind to quickly open the detailed interface when more information is needed
4. Use the LDB display for at-a-glance monitoring during gameplay

This setup provides both quick access to detailed information and continuous monitoring without cluttering the main UI.

### Comprehensive Financial Management

By combining all advanced features, players can create a comprehensive financial management system:

1. Use the floating frame to monitor real-time changes
2. Configure the LDB display to show relevant financial metrics
3. Use custom keybinds for quick interface access
4. Analyze zone-level data to optimize gold-making activities
5. Review session data to track progress toward financial goals

This integrated approach transforms Accountant Classic from a simple tracking tool into a powerful financial management system that supports strategic decision-making in the game.

**Section sources**
- [MoneyFrame.lua](file://Core/MoneyFrame.lua#L1-L169)
- [Bindings.xml](file://Bindings.xml#L1-L9)
- [Core.lua](file://Core/Core.lua#L1-L2306)