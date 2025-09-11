-- CurrencyUIController.lua
-- Manages the currency tab and UI interactions
-- Integrates with existing tab system by adding "Currencies" as the 12th tab
-- Reuses existing time period tabs (Session, Today, Week, etc.) for currency data

-- Create the UIController module
CurrencyTracker = CurrencyTracker or {}
CurrencyTracker.UIController = {}

local UIController = CurrencyTracker.UIController

-- Import LibUIDropDownMenu for dropdown functionality
local LibDD = LibStub and LibStub:GetLibrary("LibUIDropDownMenu-4.0", true)

-- Tab constants (imported from CurrencyConstants)
local GOLD_TAB_INDEX = CurrencyTracker.Constants and CurrencyTracker.Constants.UI.GOLD_TAB_INDEX or 1
local CURRENCY_TAB_INDEX = CurrencyTracker.Constants and CurrencyTracker.Constants.UI.CURRENCY_TAB_INDEX or 2

-- Module state
local isInitialized = false
local isEnabled = false
local currencyTab = nil
local currencyDropdown = nil
local selectedCurrency = 3008 -- Default to Valorstones
local goldTab = nil
local isCurrencyTabActive = false

-- Constants for UI layout
local CHARACTER_DROPDOWN_WIDTH = 150 -- Reduced from 200px
local CURRENCY_DROPDOWN_WIDTH = 140
local DROPDOWN_SPACING = 10

-- Core interface implementation
function UIController:Initialize()
    if isInitialized then
        return true
    end

    -- Verify required dependencies
    if not LibDD then
        if CurrencyTracker.LogError then
            CurrencyTracker:LogError("LibUIDropDownMenu not available")
        end
        return false
    end

    -- Load saved currency selection
    self:LoadCurrencySelection()

    -- Validate currency selection
    self:ValidateCurrencySelection()

    isInitialized = true
    return true
end

function UIController:Enable()
    if not isInitialized then
        if not self:Initialize() then
            return false
        end
    end

    if isEnabled then
        return true
    end

    -- Validate we have currencies available
    if not self:HasAvailableCurrencies() then
        if CurrencyTracker.LogError then
            CurrencyTracker:LogError("No currencies available - cannot enable currency UI")
        end
        return false
    end

    -- Create UI elements
    self:CreateTopLevelTabs()
    self:CreateCurrencyDropdown()

    -- Ensure currency selection is valid
    self:ValidateCurrencySelection()

    isEnabled = true
    return true
end

function UIController:Disable()
    if not isEnabled then
        return true
    end

    -- Hide/remove UI elements
    if goldTab then
        goldTab:Hide()
    end
    
    if currencyTab then
        currencyTab:Hide()
    end

    if currencyDropdown then
        currencyDropdown:Hide()
    end

    isEnabled = false
    return true
end

-- Create the two-tier tab system: Gold and Currencies tabs at the top
function UIController:CreateTopLevelTabs()
    local frame = _G["AccountantClassicFrame"]
    if not frame then
        if CurrencyTracker.LogError then
            CurrencyTracker:LogError("AccountantClassicFrame not found")
        end
        return false
    end

    -- Hook into existing tab system to add top-level tabs
    self:HookExistingTabSystem(frame)
    
    -- Create Gold tab (represents current functionality)
    self:CreateGoldTab(frame)
    
    -- Create Currencies tab (new functionality)
    self:CreateCurrencyTab(frame)

    -- Reposition existing time period tabs to make room for top-level tabs
    self:RepositionTimePeriodTabs(frame)

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Two-tier tab system created successfully")
    end

    return true
end

-- Hook into existing tab system to preserve functionality
function UIController:HookExistingTabSystem(frame)
    -- Store original AccountantClassic_OnShow function
    if not self.originalOnShow then
        self.originalOnShow = _G.AccountantClassic_OnShow
    end

    -- Hook AccountantClassic_OnShow to handle two-tier logic
    _G.AccountantClassic_OnShow = function(...)
        -- Call original function first
        if self.originalOnShow then
            self.originalOnShow(...)
        end
        
        -- Apply two-tier tab logic
        self:UpdateDisplayForCurrentMode()
    end

    -- Store original tab click handler
    if not self.originalTabOnClick and _G.AccountantClassicTabButtonMixin then
        self.originalTabOnClick = _G.AccountantClassicTabButtonMixin.OnClick
        
        -- Hook tab click to handle two-tier system
        _G.AccountantClassicTabButtonMixin.OnClick = function(tab)
            -- Handle time period tab clicks
            UIController:HandleTimePeriodTabClick(tab)
        end
    end
end

-- Create the Gold tab (top-level)
function UIController:CreateGoldTab(frame)
    local tabName = "AccountantClassicGoldTab"
    goldTab = _G[tabName]

    if not goldTab then
        -- Create new tab using a simple button (not the tab template to avoid conflicts)
        goldTab = CreateFrame("Button", tabName, frame)
        goldTab:SetSize(60, 24)
        
        -- Create tab appearance
        goldTab:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTab-BGLeft")
        goldTab:SetHighlightTexture("Interface\\ChatFrame\\ChatFrameTab-BGLeft")
        
        -- Create text
        goldTab.text = goldTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        goldTab.text:SetPoint("CENTER")
        goldTab.text:SetText("Gold")
        
        -- Set properties
        goldTab:SetID(GOLD_TAB_INDEX)
    end

    -- Position at top of frame, above existing tabs
    goldTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -45)
    goldTab:Show()

    -- Set click handler
    goldTab:SetScript("OnClick", function()
        UIController:HandleTopLevelTabSwitch("Gold")
    end)

    -- Set initial state (Gold tab active by default)
    isCurrencyTabActive = false
    self:UpdateTabAppearance(goldTab, currencyTab)

    return true
end

-- Create the Currency tab (top-level)
function UIController:CreateCurrencyTab(frame)
    local tabName = "AccountantClassicCurrencyTab"
    currencyTab = _G[tabName]

    if not currencyTab then
        -- Create new tab using a simple button (not the tab template to avoid conflicts)
        currencyTab = CreateFrame("Button", tabName, frame)
        currencyTab:SetSize(80, 24)
        
        -- Create tab appearance
        currencyTab:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTab-BGLeft")
        currencyTab:SetHighlightTexture("Interface\\ChatFrame\\ChatFrameTab-BGLeft")
        
        -- Create text
        currencyTab.text = currencyTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        currencyTab.text:SetPoint("CENTER")
        currencyTab.text:SetText("Currencies")
        
        -- Set properties
        currencyTab:SetID(CURRENCY_TAB_INDEX)
    end

    -- Position to the right of Gold tab
    currencyTab:SetPoint("LEFT", goldTab, "RIGHT", 5, 0)
    currencyTab:Show()

    -- Set click handler
    currencyTab:SetScript("OnClick", function()
        UIController:HandleTopLevelTabSwitch("Currencies")
    end)

    return true
end

-- Reposition existing time period tabs to accommodate top-level tabs
function UIController:RepositionTimePeriodTabs(frame)
    -- The existing tabs (Session, Day, Week, etc.) need to be moved down
    -- to make room for the Gold/Currency tabs at the top
    
    -- Find the first existing tab to use as reference
    local firstTab = _G["AccountantClassicFrameTab1"]
    if firstTab then
        -- Move all existing tabs down by 30 pixels to make room for top-level tabs
        local originalPoint, originalRelativeTo, originalRelativePoint, originalX, originalY = firstTab:GetPoint()
        if originalY then
            -- Adjust Y position to move tabs down
            firstTab:ClearAllPoints()
            firstTab:SetPoint(originalPoint, originalRelativeTo, originalRelativePoint, originalX, originalY - 30)
        end
    end
    
    return true
end

-- Create the currency dropdown (only visible when Currencies tab is active)
function UIController:CreateCurrencyDropdown()
    if not LibDD then
        return false
    end

    local frame = _G["AccountantClassicFrame"]
    if not frame then
        return false
    end

    -- Adjust character dropdown width first
    self:AdjustCharacterDropdownLayout()

    -- Create currency dropdown
    local dropdownName = "AccountantClassicFrameCurrencyDropDown"
    currencyDropdown = _G[dropdownName]

    if not currencyDropdown then
        currencyDropdown = LibDD:Create_UIDropDownMenu(dropdownName, frame)
    end

    -- Position currency dropdown to the right of character dropdown
    local characterDropdown = frame.CharacterDropDown
    if characterDropdown then
        currencyDropdown:SetPoint("TOPLEFT", characterDropdown, "TOPRIGHT", DROPDOWN_SPACING, 0)
    else
        -- Fallback positioning
        currencyDropdown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -62)
    end

    -- Set dropdown properties
    LibDD:UIDropDownMenu_SetWidth(currencyDropdown, CURRENCY_DROPDOWN_WIDTH)
    currencyDropdown:SetScript("OnShow", function(self)
        UIController:PopulateCurrencyDropdown()
    end)

    -- Create icon frame for the dropdown button if it doesn't exist
    if not currencyDropdown.Icon then
        currencyDropdown.Icon = currencyDropdown:CreateTexture(nil, "ARTWORK")
        currencyDropdown.Icon:SetSize(16, 16)
        currencyDropdown.Icon:SetPoint("LEFT", currencyDropdown.Text, "LEFT", -20, 0)
    end

    -- Create dropdown label
    if not currencyDropdown.Label then
        currencyDropdown.Label = currencyDropdown:CreateFontString(dropdownName .. "Label", "BACKGROUND", "GameFontNormalSmall")
        currencyDropdown.Label:SetPoint("BOTTOMLEFT", currencyDropdown, "TOPLEFT", 16, 3)
        currencyDropdown.Label:SetText("Currency:")
    end

    -- Initially hide the dropdown (show only when currency tab is active)
    currencyDropdown:Hide()

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Currency dropdown created successfully")
    end

    return true
end

-- Adjust character dropdown layout to accommodate currency dropdown
function UIController:AdjustCharacterDropdownLayout()
    local frame = _G["AccountantClassicFrame"]
    if not frame or not frame.CharacterDropDown then
        return false
    end

    -- Reduce character dropdown width to make room for currency dropdown
    LibDD:UIDropDownMenu_SetWidth(frame.CharacterDropDown, CHARACTER_DROPDOWN_WIDTH)

    return true
end

-- Populate currency dropdown with expansion and patch grouping
function UIController:PopulateCurrencyDropdown()
    if not currencyDropdown or not LibDD then
        return false
    end

    -- Initialize dropdown
    LibDD:UIDropDownMenu_Initialize(currencyDropdown, function()
        UIController:CurrencyDropdown_Initialize()
    end)

    -- Set selected value and update display text
    LibDD:UIDropDownMenu_SetSelectedValue(currencyDropdown, selectedCurrency)
    self:UpdateDropdownDisplayText()

    -- Ensure dropdown width is correct
    LibDD:UIDropDownMenu_SetWidth(currencyDropdown, CURRENCY_DROPDOWN_WIDTH)

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Currency dropdown populated with selected currency: %d", selectedCurrency)
    end

    return true
end

-- Initialize currency dropdown with grouped currencies
function UIController:CurrencyDropdown_Initialize()
    if not CurrencyTracker.DataManager then
        return
    end

    -- Get currencies grouped by expansion and patch
    local grouped = CurrencyTracker.DataManager:GetCurrenciesGroupedByExpansion()

    -- Check if we have any currencies to display
    local hasCurrencies = false
    for _, expData in pairs(grouped) do
        for _, currencies in pairs(expData.patches) do
            if #currencies > 0 then
                hasCurrencies = true
                break
            end
        end
        if hasCurrencies then break end
    end

    -- Handle empty state
    if not hasCurrencies then
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.text = "No currencies available"
        info.disabled = true
        info.notCheckable = true
        LibDD:UIDropDownMenu_AddButton(info)
        return
    end

    -- Sort expansions by order
    local expansionOrder = {}
    for expKey, expData in pairs(grouped) do
        table.insert(expansionOrder, {key = expKey, data = expData})
    end

    table.sort(expansionOrder, function(a, b)
        local orderA = a.data.expansion.order or 999
        local orderB = b.data.expansion.order or 999
        return orderA > orderB -- Reverse order (newest first)
    end)

    -- Add currencies to dropdown
    for _, expEntry in ipairs(expansionOrder) do
        local expData = expEntry.data

        -- Add expansion header
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.text = expData.expansion.name
        info.isTitle = true
        info.notCheckable = true
        LibDD:UIDropDownMenu_AddButton(info)

        -- Sort patches within expansion
        local patchOrder = {}
        for patch, currencies in pairs(expData.patches) do
            table.insert(patchOrder, {patch = patch, currencies = currencies})
        end

        table.sort(patchOrder, function(a, b)
            return a.patch > b.patch -- Newest patch first
        end)

        -- Add currencies for each patch
        for _, patchEntry in ipairs(patchOrder) do
            local patch = patchEntry.patch
            local currencies = patchEntry.currencies

            -- Add patch subheader if multiple patches
            if #patchOrder > 1 then
                local patchInfo = LibDD:UIDropDownMenu_CreateInfo()
                patchInfo.text = "  Patch " .. patch
                patchInfo.isTitle = true
                patchInfo.notCheckable = true
                LibDD:UIDropDownMenu_AddButton(patchInfo)
            end

            -- Sort currencies by name
            table.sort(currencies, function(a, b)
                return a.name < b.name
            end)

            -- Add individual currencies
            for _, currency in ipairs(currencies) do
                local currencyInfo = LibDD:UIDropDownMenu_CreateInfo()
                currencyInfo.text = "    " .. currency.name
                currencyInfo.value = currency.id
                currencyInfo.func = function(self)
                    UIController:OnCurrencySelected(self.value)
                end
                
                -- Add currency icon if available
                if currency.icon then
                    currencyInfo.icon = currency.icon
                    currencyInfo.tCoordLeft = 0.1
                    currencyInfo.tCoordRight = 0.9
                    currencyInfo.tCoordTop = 0.1
                    currencyInfo.tCoordBottom = 0.9
                end
                
                -- Create detailed tooltip
                currencyInfo.tooltipTitle = currency.name
                currencyInfo.tooltipText = self:CreateCurrencyTooltipText(currency)
                currencyInfo.tooltipOnButton = true
                
                LibDD:UIDropDownMenu_AddButton(currencyInfo)
            end
        end

        -- Add separator between expansions (only if not the last expansion)
        if expEntry ~= expansionOrder[#expansionOrder] then
            local separator = LibDD:UIDropDownMenu_CreateInfo()
            separator.text = ""
            separator.disabled = true
            separator.notCheckable = true
            LibDD:UIDropDownMenu_AddButton(separator)
        end
    end
end

-- Create detailed tooltip text for currency
function UIController:CreateCurrencyTooltipText(currency)
    if not currency then
        return "No information available"
    end

    local tooltipLines = {}
    
    -- Add description if available
    if currency.description then
        table.insert(tooltipLines, currency.description)
        table.insert(tooltipLines, "") -- Empty line for spacing
    end
    
    -- Add expansion and patch information
    if currency.expansionName then
        table.insert(tooltipLines, "|cFFFFD700Expansion:|r " .. currency.expansionName)
    end
    
    if currency.patch then
        table.insert(tooltipLines, "|cFFFFD700Patch:|r " .. currency.patch)
    end
    
    -- Add category if available
    if currency.category then
        table.insert(tooltipLines, "|cFFFFD700Category:|r " .. currency.category)
    end
    
    -- Add maximum quantity if applicable
    if currency.maxQuantity and currency.maxQuantity > 0 then
        table.insert(tooltipLines, "|cFFFFD700Max Quantity:|r " .. currency.maxQuantity)
    end
    
    -- Add current amount if we have data
    if CurrencyTracker.DataManager then
        local currentData = CurrencyTracker.DataManager:GetCurrencyData(currency.id, "Session")
        if currentData and (currentData.income > 0 or currentData.outgoing > 0) then
            table.insert(tooltipLines, "") -- Empty line for spacing
            table.insert(tooltipLines, "|cFF00FF00Session Income:|r " .. currentData.income)
            table.insert(tooltipLines, "|cFFFF0000Session Outgoing:|r " .. currentData.outgoing)
            table.insert(tooltipLines, "|cFFFFFFFFNet Change:|r " .. currentData.net)
        end
    end
    
    return table.concat(tooltipLines, "\n")
end

-- Handle currency selection from dropdown
function UIController:OnCurrencySelected(currencyID)
    if not currencyID then
        return
    end

    -- Validate that the currency is supported
    if CurrencyTracker.DataManager and not CurrencyTracker.DataManager:IsCurrencySupported(currencyID) then
        if CurrencyTracker.LogError then
            CurrencyTracker:LogError("Attempted to select unsupported currency: %d", currencyID)
        end
        return
    end

    -- Update selected currency
    LibDD:UIDropDownMenu_SetSelectedValue(currencyDropdown, currencyID)
    selectedCurrency = currencyID

    -- Update dropdown display text
    self:UpdateDropdownDisplayText()

    -- Update display
    self:UpdateDisplay(currencyID)

    -- Save selection
    self:SaveCurrencySelection(currencyID)

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Currency selected: %d", currencyID)
    end
end

-- Update the dropdown display text to show selected currency
function UIController:UpdateDropdownDisplayText()
    if not currencyDropdown or not LibDD then
        return false
    end

    local currencyInfo = nil
    if CurrencyTracker.DataManager then
        currencyInfo = CurrencyTracker.DataManager:GetCurrencyInfo(selectedCurrency)
    end

    if currencyInfo then
        -- Set the dropdown text to show the selected currency name
        LibDD:UIDropDownMenu_SetText(currencyDropdown, currencyInfo.name)
        
        -- Update dropdown icon if available
        if currencyInfo.icon and currencyDropdown.Icon then
            currencyDropdown.Icon:SetTexture(currencyInfo.icon)
            currencyDropdown.Icon:Show()
        elseif currencyDropdown.Icon then
            currencyDropdown.Icon:Hide()
        end
    else
        -- Fallback text for unknown currency
        LibDD:UIDropDownMenu_SetText(currencyDropdown, "Currency " .. tostring(selectedCurrency))
        
        -- Hide icon for unknown currency
        if currencyDropdown.Icon then
            currencyDropdown.Icon:Hide()
        end
    end

    return true
end

-- Handle top-level tab switching between Gold and Currencies
function UIController:HandleTopLevelTabSwitch(tabName)
    if tabName == "Currencies" then
        -- Switch to currency display mode
        isCurrencyTabActive = true
        
        -- Show currency UI elements
        self:ShowCurrencyUI()
        
        -- Ensure we have a valid currency selected
        if not selectedCurrency or (CurrencyTracker.DataManager and not CurrencyTracker.DataManager:IsCurrencySupported(selectedCurrency)) then
            -- Try to select the first available currency
            local availableCurrencies = CurrencyTracker.DataManager and CurrencyTracker.DataManager:GetCurrenciesForCurrentVersion() or {}
            local firstCurrency = nil
            for currencyID, _ in pairs(availableCurrencies) do
                firstCurrency = currencyID
                break
            end
            
            if firstCurrency then
                selectedCurrency = firstCurrency
                self:SaveCurrencySelection(selectedCurrency)
            else
                -- No currencies available - use default
                selectedCurrency = 3008 -- Valorstones
            end
        end
        
        -- Update display
        self:UpdateDisplay(selectedCurrency)
        
        -- Update tab appearance
        self:UpdateTabAppearance(currencyTab, goldTab)

        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("Switched to currency tab (currency: %d)", selectedCurrency)
        end
    else
        -- Switch back to gold display mode
        isCurrencyTabActive = false
        
        -- Hide currency UI elements
        self:HideCurrencyUI()
        
        -- Update tab appearance
        self:UpdateTabAppearance(goldTab, currencyTab)

        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("Switched to gold tab")
        end
    end

    -- Refresh the display for the new mode
    self:RefreshTimePeriodTabs()

    return true
end

-- Handle time period tab clicks (Session, Day, Week, etc.)
function UIController:HandleTimePeriodTabClick(tab)
    -- Call original tab click logic first
    if self.originalTabOnClick then
        self.originalTabOnClick(tab)
    end
    
    -- Update display based on current mode (gold vs currency)
    self:UpdateDisplayForCurrentMode()
end

-- Update display based on current mode (gold or currency)
function UIController:UpdateDisplayForCurrentMode()
    if isCurrencyTabActive then
        -- We're in currency mode - the display should show currency data
        -- This will be implemented in task 11 when we integrate with the display system
        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("Display updated for currency mode, currency: %d", selectedCurrency)
        end
    else
        -- We're in gold mode - display should show gold data (existing functionality)
        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("Display updated for gold mode")
        end
    end
end

-- Update tab appearance to show which is active
function UIController:UpdateTabAppearance(activeTab, inactiveTab)
    if activeTab and activeTab.text then
        -- Make active tab look selected
        activeTab:SetAlpha(1.0)
        activeTab.text:SetTextColor(1, 1, 1) -- White text for active
        
        -- Set active texture
        activeTab:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTab-BGSelected")
    end
    
    if inactiveTab and inactiveTab.text then
        -- Make inactive tab look unselected
        inactiveTab:SetAlpha(0.8)
        inactiveTab.text:SetTextColor(0.7, 0.7, 0.7) -- Gray text for inactive
        
        -- Set inactive texture
        inactiveTab:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTab-BGLeft")
    end
end

-- Refresh the time period tabs (bottom tier) for current mode
function UIController:RefreshTimePeriodTabs()
    -- The existing 11 time period tabs (Session, Today, Week, etc.) should work
    -- for both Gold and Currencies modes. This function ensures they display
    -- the correct data based on the current top-level tab selection.
    
    if CurrencyTracker.LogDebug then
        local mode = isCurrencyTabActive and "currency" or "gold"
        CurrencyTracker:LogDebug("Refreshing time period tabs for %s mode", mode)
    end

    -- Update display for current mode
    self:UpdateDisplayForCurrentMode()
end

-- Update display for selected currency
function UIController:UpdateDisplay(currencyID)
    if not currencyID then
        currencyID = selectedCurrency
    end

    selectedCurrency = currencyID

    -- Update the main display area to show currency data
    if isCurrencyTabActive then
        -- Check if we have data for this currency
        local hasData = self:CheckCurrencyHasData(currencyID)
        
        if not hasData then
            -- Handle empty state
            self:HandleEmptyState(currencyID)
        end
        
        self:RefreshCurrencyDisplay()
        
        -- Trigger display integration refresh if available
        if CurrencyTracker.DisplayIntegration and CurrencyTracker.DisplayIntegration.RefreshDisplay then
            CurrencyTracker.DisplayIntegration:RefreshDisplay()
        end
    end

    return true
end

-- Check if a currency has any data
function UIController:CheckCurrencyHasData(currencyID)
    if not currencyID or not CurrencyTracker.DataManager then
        return false
    end

    -- Check all time periods for any data
    local timePeriods = {"Session", "Day", "Week", "Month", "Year", "Total"}
    
    for _, period in ipairs(timePeriods) do
        local data = CurrencyTracker.DataManager:GetCurrencyData(currencyID, period)
        if data and (data.income > 0 or data.outgoing > 0) then
            return true
        end
    end

    return false
end

-- Handle empty state when no currency data is available
function UIController:HandleEmptyState(currencyID)
    if not currencyID then
        return
    end

    local currencyInfo = nil
    if CurrencyTracker.DataManager then
        currencyInfo = CurrencyTracker.DataManager:GetCurrencyInfo(currencyID)
    end

    local currencyName = currencyInfo and currencyInfo.name or ("Currency " .. tostring(currencyID))

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Handling empty state for %s (ID: %d)", currencyName, currencyID)
    end

    -- The actual empty state display will be handled by the display integration
    -- For now, we just log that we're in an empty state
    return true
end

-- Refresh the currency display in the main area
function UIController:RefreshCurrencyDisplay()
    -- This will be called to update the main display area with currency data
    -- It should reuse the existing three-column layout (Source, Incomings, Outgoings)
    -- The bottom-level time period tabs will filter this data appropriately

    if not selectedCurrency then
        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("No currency selected for display refresh")
        end
        return false
    end

    -- Check if we have any data for the selected currency
    local hasData = false
    if CurrencyTracker.DataManager then
        local currencyData = CurrencyTracker.DataManager:GetCurrencyData(selectedCurrency, "Total")
        if currencyData and (currencyData.income > 0 or currencyData.outgoing > 0) then
            hasData = true
        end
    end

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Refreshing currency display for currency: %d (hasData: %s)", 
            selectedCurrency, tostring(hasData))
    end

    -- Update dropdown text to show selected currency name
    self:UpdateDropdownDisplayText()

    -- The actual display refresh will be implemented when we integrate with
    -- the existing display system in a future task
    return true
end

-- Show currency-specific UI elements
function UIController:ShowCurrencyUI()
    if currencyDropdown then
        currencyDropdown:Show()
        
        -- Update dropdown label visibility
        if currencyDropdown.Label then
            currencyDropdown.Label:Show()
        end
        
        -- Refresh dropdown content to ensure it's up to date
        self:PopulateCurrencyDropdown()
        
        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("Currency UI elements shown")
        end
    end
end

-- Hide currency-specific UI elements
function UIController:HideCurrencyUI()
    if currencyDropdown then
        currencyDropdown:Hide()
        
        -- Hide dropdown label as well
        if currencyDropdown.Label then
            currencyDropdown.Label:Hide()
        end
        
        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("Currency UI elements hidden")
        end
    end
end

-- Check if currency tab is currently active
function UIController:IsCurrencyTabActive()
    return isCurrencyTabActive
end

-- Check if two-tier tab system is enabled
function UIController:IsTwoTierSystemActive()
    return isEnabled and goldTab and currencyTab
end

-- Get currently selected currency
function UIController:GetSelectedCurrency()
    return selectedCurrency
end

-- Set selected currency
function UIController:SetSelectedCurrency(currencyID)
    if not currencyID then
        return false
    end

    -- Validate currency is supported
    if CurrencyTracker.DataManager and not CurrencyTracker.DataManager:IsCurrencySupported(currencyID) then
        if CurrencyTracker.LogError then
            CurrencyTracker:LogError("Cannot select unsupported currency: %d", currencyID)
        end
        return false
    end

    selectedCurrency = currencyID
    
    -- Update display
    self:UpdateDisplay(currencyID)

    -- Update dropdown selection and display text if visible
    if currencyDropdown and LibDD then
        LibDD:UIDropDownMenu_SetSelectedValue(currencyDropdown, currencyID)
        self:UpdateDropdownDisplayText()
    end

    -- Save the selection
    self:SaveCurrencySelection(currencyID)

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Currency selection updated to: %d", currencyID)
    end

    return true
end

-- Force switch to gold tab (for external calls)
function UIController:SwitchToGoldTab()
    if goldTab then
        self:HandleTopLevelTabSwitch("Gold")
        return true
    end
    return false
end

-- Force switch to currency tab (for external calls)
function UIController:SwitchToCurrencyTab()
    if currencyTab then
        self:HandleTopLevelTabSwitch("Currencies")
        return true
    end
    return false
end

-- Save currency selection for persistence
function UIController:SaveCurrencySelection(currencyID)
    if CurrencyTracker.Storage then
        CurrencyTracker.Storage:SaveCurrencySelection(currencyID)
    end
end

-- Load currency selection from SavedVariables
function UIController:LoadCurrencySelection()
    if CurrencyTracker.Storage then
        local saved = CurrencyTracker.Storage:LoadCurrencySelection()
        if saved then
            selectedCurrency = saved
        end
    end
    return selectedCurrency
end

-- Get available currencies for current version
function UIController:GetAvailableCurrencies()
    if CurrencyTracker.DataManager then
        return CurrencyTracker.DataManager:GetCurrenciesForCurrentVersion()
    end
    return {}
end

-- Check if any currencies are available
function UIController:HasAvailableCurrencies()
    local available = self:GetAvailableCurrencies()
    for _ in pairs(available) do
        return true
    end
    return false
end

-- Get the first available currency ID
function UIController:GetFirstAvailableCurrency()
    local available = self:GetAvailableCurrencies()
    for currencyID, _ in pairs(available) do
        return currencyID
    end
    return nil
end

-- Validate and fix currency selection if needed
function UIController:ValidateCurrencySelection()
    -- Check if current selection is valid
    if selectedCurrency and CurrencyTracker.DataManager and CurrencyTracker.DataManager:IsCurrencySupported(selectedCurrency) then
        return true
    end

    -- Try to select the first available currency
    local firstAvailable = self:GetFirstAvailableCurrency()
    if firstAvailable then
        selectedCurrency = firstAvailable
        self:SaveCurrencySelection(selectedCurrency)
        
        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("Currency selection fixed to: %d", selectedCurrency)
        end
        return true
    end

    -- No currencies available
    if CurrencyTracker.LogError then
        CurrencyTracker:LogError("No currencies available for current WoW version")
    end
    return false
end

-- Get currency dropdown reference
function UIController:GetCurrencyDropdown()
    return currencyDropdown
end

-- Get currency tab reference
function UIController:GetCurrencyTab()
    return currencyTab
end

-- Get gold tab reference
function UIController:GetGoldTab()
    return goldTab
end

-- Utility function to count currencies
function UIController:CountCurrencies(currencies)
    local count = 0
    for _ in pairs(currencies) do
        count = count + 1
    end
    return count
end

-- Debug function to verify two-tier system status
function UIController:GetSystemStatus()
    return {
        isInitialized = isInitialized,
        isEnabled = isEnabled,
        isCurrencyTabActive = isCurrencyTabActive,
        hasGoldTab = goldTab ~= nil,
        hasCurrencyTab = currencyTab ~= nil,
        hasCurrencyDropdown = currencyDropdown ~= nil,
        selectedCurrency = selectedCurrency,
        originalOnShowHooked = self.originalOnShow ~= nil,
        originalTabOnClickHooked = self.originalTabOnClick ~= nil
    }
end

-- Refresh UI when currency availability changes
function UIController:RefreshCurrencyAvailability()
    if not isEnabled then
        return false
    end

    -- Check if we still have available currencies
    if not self:HasAvailableCurrencies() then
        -- No currencies available - disable currency tab
        if currencyTab then
            currencyTab:Hide()
        end
        
        -- Switch to gold tab if we were on currency tab
        if isCurrencyTabActive then
            self:SwitchToGoldTab()
        end
        
        if CurrencyTracker.LogDebug then
            CurrencyTracker:LogDebug("No currencies available - currency tab disabled")
        end
        return false
    end

    -- Ensure currency tab is visible
    if currencyTab then
        currencyTab:Show()
    end

    -- Validate current selection
    if not self:ValidateCurrencySelection() then
        return false
    end

    -- Refresh dropdown if visible
    if isCurrencyTabActive and currencyDropdown then
        self:PopulateCurrencyDropdown()
    end

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Currency availability refreshed")
    end

    return true
end

-- Get currency information for display
function UIController:GetCurrencyDisplayInfo(currencyID)
    if not currencyID then
        currencyID = selectedCurrency
    end

    local info = {
        id = currencyID,
        name = "Unknown Currency",
        icon = nil,
        hasData = false,
        isEmpty = true
    }

    if CurrencyTracker.DataManager then
        local currencyInfo = CurrencyTracker.DataManager:GetCurrencyInfo(currencyID)
        if currencyInfo then
            info.name = currencyInfo.name
            info.icon = currencyInfo.icon
        end

        info.hasData = self:CheckCurrencyHasData(currencyID)
        info.isEmpty = not info.hasData
    end

    return info
end

-- Test function to verify integration
function UIController:TestTwoTierSystem()
    local status = self:GetSystemStatus()
    
    print("=== CurrencyTracker Two-Tier Tab System Status ===")
    for key, value in pairs(status) do
        print(string.format("%s: %s", key, tostring(value)))
    end
    
    -- Additional currency-specific status
    print("=== Currency Status ===")
    print(string.format("Available currencies: %d", self:CountCurrencies(self:GetAvailableCurrencies())))
    print(string.format("Has available currencies: %s", tostring(self:HasAvailableCurrencies())))
    print(string.format("Selected currency valid: %s", tostring(CurrencyTracker.DataManager and CurrencyTracker.DataManager:IsCurrencySupported(selectedCurrency))))
    
    local displayInfo = self:GetCurrencyDisplayInfo()
    print(string.format("Current currency: %s (ID: %d)", displayInfo.name, displayInfo.id))
    print(string.format("Currency has data: %s", tostring(displayInfo.hasData)))
    print("=== End Status ===")
    
    return status
end