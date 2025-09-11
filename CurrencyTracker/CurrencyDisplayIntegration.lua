-- CurrencyDisplayIntegration.lua
-- Integrates currency data with the existing display system
-- Hooks into existing display refresh functions to show currency data when currency tab is active

-- Create the DisplayIntegration module
CurrencyTracker = CurrencyTracker or {}
CurrencyTracker.DisplayIntegration = {}

local DisplayIntegration = CurrencyTracker.DisplayIntegration

-- Module state
local isInitialized = false
local isEnabled = false
local originalOnShow = nil

-- Import required modules
local UIController = nil
local DataManager = nil
local Storage = nil

-- Constants for display formatting
local CURRENCY_SOURCE_TYPES = {
    ["Quest"] = "Quest Rewards",
    ["Dungeon"] = "Dungeon Completion",
    ["Raid"] = "Raid Completion", 
    ["PvP"] = "PvP Activities",
    ["Vendor"] = "Vendor Purchases",
    ["Mail"] = "Mail Attachments",
    ["Trade"] = "Player Trading",
    ["Unknown"] = "Unknown Source"
}

-- Core interface implementation
function DisplayIntegration:Initialize()
    if isInitialized then
        return true
    end

    -- Get references to other modules
    UIController = CurrencyTracker.UIController
    DataManager = CurrencyTracker.DataManager
    Storage = CurrencyTracker.Storage

    -- Verify dependencies
    if not UIController or not DataManager then
        if CurrencyTracker.LogError then
            CurrencyTracker:LogError("DisplayIntegration: Required modules not available")
        end
        return false
    end

    isInitialized = true
    return true
end

function DisplayIntegration:Enable()
    if not isInitialized then
        if not self:Initialize() then
            return false
        end
    end

    if isEnabled then
        return true
    end

    -- Hook into the existing display system
    self:HookDisplaySystem()

    isEnabled = true
    return true
end

function DisplayIntegration:Disable()
    if not isEnabled then
        return true
    end

    -- Restore original display system
    self:UnhookDisplaySystem()

    isEnabled = false
    return true
end

-- Hook into the existing AccountantClassic_OnShow function
function DisplayIntegration:HookDisplaySystem()
    -- Store original function if not already stored
    if not originalOnShow and _G.AccountantClassic_OnShow then
        originalOnShow = _G.AccountantClassic_OnShow
    end

    -- Replace with our hooked version
    _G.AccountantClassic_OnShow = function(...)
        DisplayIntegration:HookedOnShow(...)
    end

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Display system hooked successfully")
    end
end

-- Restore original display system
function DisplayIntegration:UnhookDisplaySystem()
    if originalOnShow then
        _G.AccountantClassic_OnShow = originalOnShow
    end

    if CurrencyTracker.LogDebug then
        CurrencyTracker:LogDebug("Display system unhooked")
    end
end

-- Hooked version of AccountantClassic_OnShow
function DisplayIntegration:HookedOnShow(...)
    -- Check if currency tab is active
    if UIController and UIController:IsCurrencyTabActive() then
        -- Show currency data instead of gold data
        self:ShowCurrencyData(...)
    else
        -- Call original function for gold data
        if originalOnShow then
            originalOnShow(...)
        end
    end
end

-- Main function to display currency data using existing layout
function DisplayIntegration:ShowCurrencyData(self)
    -- Get the main frame
    local frame = _G["AccountantClassicFrame"]
    if not frame then
        return
    end

    -- Get selected currency
    local currencyID = UIController and UIController:GetSelectedCurrency() or 3008

    -- Get current time period (tab)
    local currentTab = _G.AC_CURRTAB or 1
    local timeframe = self:GetTimeframeFromTab(currentTab)

    -- Set up the frame similar to original function
    _G.createACFrames()
    _G.setLabels()

    -- Check if we're in "All Chars" mode (tab 12)
    if currentTab == _G.AC_TABS then
        self:ShowAllCharsCurrencyData(currencyID, timeframe)
    else
        self:ShowSingleCharCurrencyData(currencyID, timeframe)
    end

    -- Update portrait and tab selection
    SetPortraitTexture(_G.AccountantClassicFramePortrait, "player")
    PanelTemplates_SetTab(frame, currentTab)
end

-- Show currency data for single character or selected character
function DisplayIntegration:ShowSingleCharCurrencyData(currencyID, timeframe)
    local frame = _G["AccountantClassicFrame"]
    
    -- Hide character-related dropdowns for Session mode
    if timeframe == "Session" then
        _G.AccountantClassicFrameCharacterDropDown:Hide()
    else
        _G.AccountantClassicFrameCharacterDropDown:Show()
    end

    -- Hide server/faction dropdowns and scroll bar (not needed for single char)
    _G.AccountantClassicFrameServerDropDown:Hide()
    _G.AccountantClassicFrameFactionDropDown:Hide()
    _G.AccountantClassicScrollBar:Hide()

    -- Hide character entry frames
    for i = 1, 18 do
        local entryFrame = _G["AccountantClassicCharacterEntry"..i]
        if entryFrame then
            entryFrame:Hide()
        end
    end

    -- Get currency data for the timeframe
    local currencyData = self:GetCurrencyDataForTimeframe(currencyID, timeframe)
    
    -- Display currency data in the three-column layout
    self:PopulateCurrencyRows(currencyData)
    
    -- Update totals
    self:UpdateCurrencyTotals(currencyData)
    
    -- Update extra info (date/period information)
    self:UpdateExtraInfo(timeframe)
end

-- Show currency data for all characters
function DisplayIntegration:ShowAllCharsCurrencyData(currencyID, timeframe)
    local frame = _G["AccountantClassicFrame"]
    
    -- Show server/faction dropdowns for character filtering
    _G.AccountantClassicFrameServerDropDown:Show()
    _G.AccountantClassicFrameFactionDropDown:Show()
    _G.AccountantClassicFrameCharacterDropDown:Hide()
    
    -- Populate character list (reuse existing function)
    if _G.addon and _G.addon.PopulateCharacterList then
        _G.addon:PopulateCharacterList(_G.AC_SELECTED_SERVER, _G.AC_SELECTED_FACTION)
    end
    
    -- Get aggregated currency data across all characters
    local allCharsData = self:GetAllCharsCurrencyData(currencyID, timeframe)
    
    -- Update scroll bar for character list display
    self:UpdateCharacterScrollDisplay(allCharsData)
    
    -- Update totals for all characters
    self:UpdateAllCharsTotals(allCharsData)
    
    -- Clear extra info for all chars mode
    self:ClearExtraInfo()
end

-- Get currency data for specific timeframe
function DisplayIntegration:GetCurrencyDataForTimeframe(currencyID, timeframe)
    if not DataManager then
        return self:GetEmptyCurrencyData()
    end

    -- Get data from DataManager
    local rawData = DataManager:GetCurrencyData(currencyID, timeframe)
    if not rawData then
        return self:GetEmptyCurrencyData()
    end

    -- Convert to display format with source breakdown
    return self:ConvertToDisplayFormat(rawData)
end

-- Convert raw currency data to display format matching gold system
function DisplayIntegration:ConvertToDisplayFormat(rawData)
    local displayData = {}
    
    -- Group transactions by source type
    local sourceGroups = {}
    
    if rawData.transactions then
        for _, transaction in ipairs(rawData.transactions) do
            local sourceType = self:ClassifySource(transaction.source)
            
            if not sourceGroups[sourceType] then
                sourceGroups[sourceType] = {
                    income = 0,
                    outgoing = 0,
                    title = CURRENCY_SOURCE_TYPES[sourceType] or sourceType
                }
            end
            
            -- Use the income/outgoing values directly from the transaction
            sourceGroups[sourceType].income = sourceGroups[sourceType].income + (transaction.income or 0)
            sourceGroups[sourceType].outgoing = sourceGroups[sourceType].outgoing + (transaction.outgoing or 0)
        end
    end
    
    -- Convert to format expected by display system
    local rowIndex = 1
    for sourceType, data in pairs(sourceGroups) do
        displayData[sourceType] = {
            Title = data.title,
            InPos = rowIndex,
            income = data.income,
            outgoing = data.outgoing
        }
        rowIndex = rowIndex + 1
    end
    
    -- Add totals
    displayData.totals = {
        income = rawData.income or 0,
        outgoing = rawData.outgoing or 0,
        net = rawData.net or 0
    }
    
    return displayData
end

-- Classify transaction source into display categories
function DisplayIntegration:ClassifySource(source)
    if not source or source == "" then
        return "Unknown"
    end
    
    local lowerSource = string.lower(source)
    
    -- Quest-related sources
    if string.find(lowerSource, "quest") or string.find(lowerSource, "reward") then
        return "Quest"
    end
    
    -- Dungeon-related sources  
    if string.find(lowerSource, "dungeon") or string.find(lowerSource, "instance") then
        return "Dungeon"
    end
    
    -- Raid-related sources
    if string.find(lowerSource, "raid") then
        return "Raid"
    end
    
    -- PvP-related sources
    if string.find(lowerSource, "pvp") or string.find(lowerSource, "battleground") or string.find(lowerSource, "arena") then
        return "PvP"
    end
    
    -- Vendor-related sources
    if string.find(lowerSource, "vendor") or string.find(lowerSource, "purchase") or string.find(lowerSource, "buy") then
        return "Vendor"
    end
    
    -- Mail-related sources
    if string.find(lowerSource, "mail") or string.find(lowerSource, "attachment") then
        return "Mail"
    end
    
    -- Trade-related sources
    if string.find(lowerSource, "trade") or string.find(lowerSource, "player") then
        return "Trade"
    end
    
    return "Unknown"
end

-- Populate currency data rows in the existing three-column layout
function DisplayIntegration:PopulateCurrencyRows(currencyData)
    -- Clear all rows first
    for i = 1, 18 do
        local titleElement = _G["AccountantClassicFrameRow"..i.."Title".."_Text"]
        local inElement = _G["AccountantClassicFrameRow"..i.."In".."_Text"]
        local outElement = _G["AccountantClassicFrameRow"..i.."Out".."_Text"]
        
        if titleElement then titleElement:SetText("") end
        if inElement then inElement:SetText("") end
        if outElement then outElement:SetText("") end
        
        -- Clear logType properties
        local titleFrame = _G["AccountantClassicFrameRow"..i.."Title"]
        local inFrame = _G["AccountantClassicFrameRow"..i.."In"]
        local outFrame = _G["AccountantClassicFrameRow"..i.."Out"]
        
        if titleFrame then titleFrame.logType = "" end
        if inFrame then inFrame.logType = "" end
        if outFrame then outFrame.logType = "" end
    end
    
    -- Populate with currency data
    for sourceType, data in pairs(currencyData) do
        if sourceType ~= "totals" and data.InPos and data.InPos <= 18 then
            local rowIndex = data.InPos
            
            -- Set row data
            local titleElement = _G["AccountantClassicFrameRow"..rowIndex.."Title".."_Text"]
            local inElement = _G["AccountantClassicFrameRow"..rowIndex.."In".."_Text"]
            local outElement = _G["AccountantClassicFrameRow"..rowIndex.."Out".."_Text"]
            
            if titleElement then
                titleElement:SetText(data.Title or sourceType)
            end
            
            if inElement then
                inElement:SetText(self:FormatCurrencyValue(data.income or 0))
            end
            
            if outElement then
                outElement:SetText(self:FormatCurrencyValue(data.outgoing or 0))
            end
            
            -- Set logType for tooltips/interactions
            local titleFrame = _G["AccountantClassicFrameRow"..rowIndex.."Title"]
            local inFrame = _G["AccountantClassicFrameRow"..rowIndex.."In"]
            local outFrame = _G["AccountantClassicFrameRow"..rowIndex.."Out"]
            
            if titleFrame then titleFrame.logType = sourceType end
            if inFrame then 
                inFrame.logType = sourceType
                inFrame.cashflow = "In"
            end
            if outFrame then 
                outFrame.logType = sourceType
                outFrame.cashflow = "Out"
            end
        end
    end
end

-- Update currency totals in the display
function DisplayIntegration:UpdateCurrencyTotals(currencyData)
    local frame = _G["AccountantClassicFrame"]
    if not frame or not currencyData.totals then
        return
    end
    
    local totalIn = currencyData.totals.income or 0
    local totalOut = currencyData.totals.outgoing or 0
    local net = currencyData.totals.net or (totalIn - totalOut)
    
    -- Update total values
    frame.TotalInValue:SetText("|cFFFFFFFF"..self:FormatCurrencyValue(totalIn))
    frame.TotalOutValue:SetText("|cFFFFFFFF"..self:FormatCurrencyValue(totalOut))
    
    -- Update net profit/loss with appropriate coloring
    if totalOut > totalIn then
        local loss = totalOut - totalIn
        frame.TotalFlow:SetText("|cFFFF3333Net Loss:")
        frame.TotalFlowValue:SetText("|cFFFF3333"..self:FormatCurrencyValue(loss))
    elseif totalIn > totalOut then
        local profit = totalIn - totalOut
        frame.TotalFlow:SetText("|cFF00FF00Net Profit:")
        frame.TotalFlowValue:SetText("|cFF00FF00"..self:FormatCurrencyValue(profit))
    else
        frame.TotalFlow:SetText("Net Profit / Loss:")
        frame.TotalFlowValue:SetText("")
    end
end

-- Get currency data aggregated across all characters
function DisplayIntegration:GetAllCharsCurrencyData(currencyID, timeframe)
    if not Storage then
        return {}
    end
    
    local allCharsData = {}
    local totalIncome = 0
    local totalOutgoing = 0
    
    -- Get character list (reuse existing logic)
    local charList = _G.AC_CHARSCROLL_LIST or {}
    
    for i, charInfo in ipairs(charList) do
        local serverKey = charInfo[1]
        local charKey = charInfo[2]
        
        -- Get currency data for this character
        local charData = Storage:GetCharacterCurrencyData(serverKey, charKey, currencyID, timeframe)
        
        if charData then
            allCharsData[i] = {
                server = serverKey,
                character = charKey,
                income = charData.income or 0,
                outgoing = charData.outgoing or 0,
                net = (charData.income or 0) - (charData.outgoing or 0),
                lastUpdate = charData.lastUpdate or "Never"
            }
            
            totalIncome = totalIncome + (charData.income or 0)
            totalOutgoing = totalOutgoing + (charData.outgoing or 0)
        end
    end
    
    -- Add totals
    allCharsData.totals = {
        income = totalIncome,
        outgoing = totalOutgoing,
        net = totalIncome - totalOutgoing
    }
    
    return allCharsData
end

-- Update character scroll display for all chars mode
function DisplayIntegration:UpdateCharacterScrollDisplay(allCharsData)
    -- This function updates the scrollable character list with currency data
    -- Similar to how gold data is displayed in "All Chars" mode
    
    local charList = _G.AC_CHARSCROLL_LIST or {}
    
    for i = 1, math.min(#charList, 17) do -- Row 18 is reserved for totals
        local entryFrame = _G["AccountantClassicCharacterEntry"..i]
        if not entryFrame then
            -- Create entry frame if it doesn't exist
            entryFrame = CreateFrame("Frame", "AccountantClassicCharacterEntry"..i, 
                                   _G.AccountantClassicFrame, "AccountantClassicRowTemplate")
            if i == 1 then
                entryFrame:SetPoint("TOPLEFT", "AccountantClassicScrollBar", "TOPLEFT", 0, 0)
            else
                entryFrame:SetPoint("TOPLEFT", "AccountantClassicCharacterEntry"..(i-1), "BOTTOMLEFT", 0, -1)
            end
        end
        
        entryFrame:Show()
        
        -- Update character data
        local charData = allCharsData[i]
        if charData then
            local titleText = entryFrame:GetName().."Title_Text"
            local inText = entryFrame:GetName().."In_Text"
            local outText = entryFrame:GetName().."Out_Text"
            
            local titleElement = _G[titleText]
            local inElement = _G[inText]
            local outElement = _G[outText]
            
            if titleElement then
                titleElement:SetText(charData.server.." - "..charData.character)
            end
            
            if inElement then
                inElement:SetText(self:FormatCurrencyValue(charData.income))
            end
            
            if outElement then
                outElement:SetText(charData.lastUpdate)
            end
        end
    end
    
    -- Hide unused entry frames
    for i = #charList + 1, 17 do
        local entryFrame = _G["AccountantClassicCharacterEntry"..i]
        if entryFrame then
            entryFrame:Hide()
        end
    end
end

-- Update totals for all characters mode
function DisplayIntegration:UpdateAllCharsTotals(allCharsData)
    local frame = _G["AccountantClassicFrame"]
    if not frame or not allCharsData.totals then
        return
    end
    
    local totalIn = allCharsData.totals.income
    local totalOut = allCharsData.totals.outgoing
    local net = allCharsData.totals.net
    
    -- Update main totals
    frame.TotalInValue:SetText("|cFFFFFFFF"..self:FormatCurrencyValue(totalIn))
    frame.TotalOutValue:SetText("|cFFFFFFFF"..self:FormatCurrencyValue(totalOut))
    
    -- Update net profit/loss
    if totalOut > totalIn then
        local loss = totalOut - totalIn
        frame.TotalFlow:SetText("|cFFFF3333Net Loss:")
        frame.TotalFlowValue:SetText("|cFFFF3333"..self:FormatCurrencyValue(loss))
    elseif totalIn > totalOut then
        local profit = totalIn - totalOut
        frame.TotalFlow:SetText("|cFF00FF00Net Profit:")
        frame.TotalFlowValue:SetText("|cFF00FF00"..self:FormatCurrencyValue(profit))
    else
        frame.TotalFlow:SetText("Net Profit / Loss:")
        frame.TotalFlowValue:SetText("")
    end
    
    -- Update row 18 with sum total (similar to gold display)
    local row18Title = _G["AccountantClassicFrameRow18Title"]
    local row18In = _G["AccountantClassicFrameRow18In"]
    
    if row18Title and row18Title.Text then
        row18Title.Text:SetText("Sum Total")
    end
    
    if row18In and row18In.Text then
        row18In.Text:SetText("|cFFFFFFFF"..self:FormatCurrencyValue(net))
    end
end

-- Update extra info display (date/period information)
function DisplayIntegration:UpdateExtraInfo(timeframe)
    local fs = _G["AccountantClassicFrameExtra"]
    local fsv = _G["AccountantClassicFrameExtraValue"]
    
    if not fs or not fsv then
        return
    end
    
    -- Clear extra info for currency display (can be enhanced later)
    fs:SetText("")
    fsv:SetText("")
    
    -- Could add currency-specific info here, like:
    -- - Current currency amount
    -- - Currency cap information
    -- - Last update time
end

-- Clear extra info display
function DisplayIntegration:ClearExtraInfo()
    local fs = _G["AccountantClassicFrameExtra"]
    local fsv = _G["AccountantClassicFrameExtraValue"]
    
    if fs then fs:SetText("") end
    if fsv then fsv:SetText("") end
end

-- Convert tab number to timeframe string
function DisplayIntegration:GetTimeframeFromTab(tabNumber)
    -- Map tab numbers to timeframe strings
    local timeframes = {
        [1] = "Session",
        [2] = "Day", 
        [3] = "PrvDay",
        [4] = "Week",
        [5] = "PrvWeek", 
        [6] = "Month",
        [7] = "PrvMonth",
        [8] = "Year",
        [9] = "PrvYear",
        [10] = "Total",
        [11] = "AllChars" -- Special case
    }
    
    return timeframes[tabNumber] or "Session"
end

-- Format currency values for display
function DisplayIntegration:FormatCurrencyValue(value)
    if not value or value == 0 then
        return "0"
    end
    
    -- Use existing addon formatting if available
    if _G.addon and _G.addon.GetFormattedValue then
        return _G.addon:GetFormattedValue(value)
    end
    
    -- Fallback formatting
    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    else
        return tostring(value)
    end
end

-- Get empty currency data structure
function DisplayIntegration:GetEmptyCurrencyData()
    return {
        totals = {
            income = 0,
            outgoing = 0,
            net = 0
        }
    }
end

-- Check if display integration is active
function DisplayIntegration:IsActive()
    return isEnabled and UIController and UIController:IsCurrencyTabActive()
end

-- Force refresh of currency display
function DisplayIntegration:RefreshDisplay()
    if self:IsActive() then
        -- Trigger a display refresh
        local frame = _G["AccountantClassicFrame"]
        if frame and frame:IsVisible() then
            self:ShowCurrencyData(frame)
        end
    end
end

-- Get display statistics for debugging
function DisplayIntegration:GetDisplayStats()
    return {
        isInitialized = isInitialized,
        isEnabled = isEnabled,
        isActive = self:IsActive(),
        hasOriginalOnShow = originalOnShow ~= nil,
        currentCurrency = UIController and UIController:GetSelectedCurrency() or nil
    }
end

-- Test function to verify currency display integration
function DisplayIntegration:TestCurrencyDisplay()
    print("=== Currency Display Integration Test ===")
    
    local stats = self:GetDisplayStats()
    for key, value in pairs(stats) do
        print(string.format("%s: %s", key, tostring(value)))
    end
    
    -- Test currency data formatting
    local testData = {
        income = 1500,
        outgoing = 300,
        net = 1200,
        transactions = {
            {source = "Quest Reward", income = 500, outgoing = 0},
            {source = "Dungeon Completion", income = 1000, outgoing = 0},
            {source = "Vendor Purchase", income = 0, outgoing = 300}
        }
    }
    
    local displayData = self:ConvertToDisplayFormat(testData)
    print("Test data conversion:")
    for sourceType, data in pairs(displayData) do
        if sourceType ~= "totals" then
            print(string.format("  %s: In=%d, Out=%d", data.Title, data.income, data.outgoing))
        end
    end
    
    print("=== End Test ===")
    return true
end