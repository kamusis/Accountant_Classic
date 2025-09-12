-- CurrencyEventHandler.lua
-- Monitors WoW events for currency changes
-- Handles event registration and currency change detection

local addonName = ...

-- Create the EventHandler module
CurrencyTracker = CurrencyTracker or {}
CurrencyTracker.EventHandler = {}

local EventHandler = CurrencyTracker.EventHandler

-- Module state
local isInitialized = false
local isEnabled = false
local eventFrame = nil
local registeredEvents = {}

-- Currency tracking state
local lastCurrencyAmounts = {}
local updateBatch = {}
local batchTimer = nil
local inCombat = false
local primedCurrencies = {}
local bagDebounceTimer = nil

-- Helpers: baseline priming directly via SavedVariables without changing Storage API
-- NOTE: We intentionally operate only on the Total period to avoid skewing time buckets.
local function IsCurrencyTotalEmpty(currencyID)
    if not currencyID then return false end
    if not EnsureSavedVariablesStructure or not GetCurrentServerAndCharacter then return false end
    if not EnsureSavedVariablesStructure() then return false end
    local server, character = GetCurrentServerAndCharacter()
    local sv = _G.Accountant_ClassicSaveData
    if not (sv and sv[server] and sv[server][character]) then return true end
    local charData = sv[server][character]
    charData.currencyData = charData.currencyData or {}
    if not charData.currencyData[currencyID] then return true end
    local total = charData.currencyData[currencyID].Total or {}
    for _, rec in pairs(total) do
        if type(rec) == "table" then
            local i = (rec.In or 0)
            local o = (rec.Out or 0)
            if i > 0 or o > 0 then return false end
        end
    end
    return true
end

local function PrimeBaselineTotalOnly(currencyID, amount)
    if not currencyID or not amount or amount <= 0 then return false end
    if not EnsureSavedVariablesStructure or not GetCurrentServerAndCharacter then return false end
    if not EnsureSavedVariablesStructure() then return false end
    -- Ensure structures via Storage initializer if available
    if CurrencyTracker.Storage and CurrencyTracker.Storage.InitializeCurrencyData then
        CurrencyTracker.Storage:InitializeCurrencyData(currencyID)
    end
    local server, character = GetCurrentServerAndCharacter()
    local sv = _G.Accountant_ClassicSaveData
    if not (sv and sv[server] and sv[server][character]) then return false end
    local charData = sv[server][character]
    charData.currencyData = charData.currencyData or {}
    charData.currencyData[currencyID] = charData.currencyData[currencyID] or {}
    local bucket = charData.currencyData[currencyID]
    bucket.Total = bucket.Total or {}
    -- Use source key 0 for baseline/unknown
    bucket.Total[0] = bucket.Total[0] or { In = 0, Out = 0 }
    bucket.Total[0].In = (bucket.Total[0].In or 0) + amount
    -- Touch lastUpdate if options table exists
    charData.currencyOptions = charData.currencyOptions or {}
    charData.currencyOptions.lastUpdate = time()
    return true
end

-- Core interface implementation
function EventHandler:Initialize()
    if isInitialized then
        return true
    end

    -- Create event frame
    eventFrame = CreateFrame("Frame", "CurrencyTrackerEventFrame")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        EventHandler:OnEvent(event, ...)
    end)

    isInitialized = true
    return true
end

function EventHandler:Enable()
    if not isInitialized then
        if not self:Initialize() then
            return false
        end
    end

    if isEnabled then
        return true
    end

    -- Register for events
    self:RegisterEvents()

    -- Debug-only confirmation
    if CurrencyTracker and CurrencyTracker.DEBUG_MODE then
        print("[AC CT] EventHandler enabled (events registered)")
    end

    isEnabled = true
    return true
end

function EventHandler:Disable()
    if not isEnabled then
        return true
    end

    -- Unregister events
    self:UnregisterEvents()

    -- Cancel any pending batch updates
    if batchTimer then
        batchTimer:Cancel()
        batchTimer = nil
    end

    isEnabled = false
    return true
end

-- Register for currency-related events
function EventHandler:RegisterEvents()
    if not eventFrame then
        return false
    end

    local events = {
        "ADDON_LOADED",
        "PLAYER_LOGIN",
        "PLAYER_LOGOUT",
        "PLAYER_REGEN_DISABLED", -- Entering combat
        "PLAYER_REGEN_ENABLED",  -- Leaving combat
    }

    -- Debug-only marker to verify this function is reached
    if CurrencyTracker and CurrencyTracker.DEBUG_MODE then
        print(string.format("[AC CT] RegisterEvents begin (eventFrame=%s, C_CurrencyInfo=%s)", tostring(eventFrame and eventFrame:GetName() or "nil"), tostring(not not C_CurrencyInfo)))
    end

    -- Register modern currency events if available
    if C_CurrencyInfo then
        table.insert(events, "CURRENCY_DISPLAY_UPDATE")
    end

    -- Register legacy fallback only if modern API is not available
    if not C_CurrencyInfo then
        table.insert(events, "BAG_UPDATE")
    end

    -- Debug summary
    CurrencyTracker:LogDebug("Preparing to register %d events (C_CurrencyInfo=%s)", #events, tostring(not not C_CurrencyInfo))

    for _, event in ipairs(events) do
        eventFrame:RegisterEvent(event)
        registeredEvents[event] = true
        CurrencyTracker:LogDebug("Registered event: %s", event)
        if event == "CURRENCY_DISPLAY_UPDATE" and CurrencyTracker and CurrencyTracker.DEBUG_MODE then
            print("[AC CT] Registered CURRENCY_DISPLAY_UPDATE")
        end
    end

    return true
end

-- Unregister all events
function EventHandler:UnregisterEvents()
    if not eventFrame then
        return
    end

    for event in pairs(registeredEvents) do
        eventFrame:UnregisterEvent(event)
        CurrencyTracker:LogDebug("Unregistered event: %s", event)
    end

    registeredEvents = {}
end

-- Main event handler
function EventHandler:OnEvent(event, ...)
    local arg1, arg2 = ...

    -- Debug-only dispatch confirmation
    if event == "CURRENCY_DISPLAY_UPDATE" and CurrencyTracker and CurrencyTracker.DEBUG_MODE then
        print("[AC CT] OnEvent: CURRENCY_DISPLAY_UPDATE")
    end

    if event == "ADDON_LOADED" and arg1 == addonName then
        self:OnAddonLoaded()
    elseif event == "PLAYER_LOGIN" then
        self:OnPlayerLogin()
    elseif event == "PLAYER_LOGOUT" then
        self:OnPlayerLogout()
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:OnEnterCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:OnLeaveCombat()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- Forward all available args: currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource
        self:OnCurrencyDisplayUpdate(...)
    elseif event == "BAG_UPDATE" then
        self:OnBagUpdate(arg1)
    end
end

-- Handle addon loaded
function EventHandler:OnAddonLoaded()
    CurrencyTracker:LogDebug("Addon loaded, initializing currency tracking")
    -- Initialize currency amounts for tracking changes
    self:InitializeCurrencyAmounts()
end

-- Handle player login
function EventHandler:OnPlayerLogin()
    CurrencyTracker:LogDebug("Player login, starting session tracking")
    -- Start new session tracking
    self:InitializeCurrencyAmounts()
    -- Parity with gold: perform rollover on login
    if CurrencyTracker.Storage and CurrencyTracker.Storage.ShiftCurrencyLogs then
        CurrencyTracker.Storage:ShiftCurrencyLogs()
    end
end

-- Handle player logout
function EventHandler:OnPlayerLogout()
    CurrencyTracker:LogDebug("Player logout, saving session data")
    -- Process any pending batch updates
    self:ProcessBatchUpdates()
end

-- Handle entering combat
function EventHandler:OnEnterCombat()
    inCombat = true
    CurrencyTracker:LogDebug("Entered combat, deferring currency operations")
end

-- Handle leaving combat
function EventHandler:OnLeaveCombat()
    inCombat = false
    CurrencyTracker:LogDebug("Left combat, resuming currency operations")
    -- Process any deferred updates
    self:ProcessBatchUpdates()
end

-- Handle currency display update (modern clients)
function EventHandler:OnCurrencyDisplayUpdate(currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource, ...)
    -- Some clients include a leading table payload (seen in /etrace as 'CR: table: ...').
    -- Normalize by shifting arguments if the first parameter is a table.
    local raw1, raw2, raw3, raw4, raw5 = currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource
    if type(currencyType) == "table" then
        -- Shift left by one: drop the leading table payload
        currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource =
            quantity, quantityChange, quantityGainSource, quantityLostSource, nil
    end

    -- Early debug: always log event receipt and arguments when debug is ON,
    -- even if the computed change later is zero. This helps verify event flow.
    if CurrencyTracker and CurrencyTracker.DEBUG_MODE then
        print("[AC CT][Event] CURRENCY_DISPLAY_UPDATE received")
        print(string.format("  Args(raw): %s | %s | %s | %s | %s",
            tostring(raw1), tostring(raw2), tostring(raw3), tostring(raw4), tostring(raw5)))
        print(string.format("  Args(norm): id=%s new=%s chg=%s gain=%s lost=%s",
            tostring(currencyType), tostring(quantity), tostring(quantityChange), tostring(quantityGainSource), tostring(quantityLostSource)))
    end

    if inCombat then
        -- Defer update during combat
        self:AddToBatch("CURRENCY_UPDATE", currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource)
        return
    end

    self:ProcessCurrencyChange(currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource)
end

-- Handle bag update (fallback for older clients)
function EventHandler:OnBagUpdate(bagID)
    if inCombat then
        -- Defer update during combat
        self:AddToBatch("BAG_UPDATE", bagID)
        return
    end

    -- Debounce legacy bag updates to coalesce bursts
    if bagDebounceTimer then
        bagDebounceTimer:Cancel()
        bagDebounceTimer = nil
    end
    bagDebounceTimer = C_Timer.NewTimer(0.3, function()
        bagDebounceTimer = nil
        -- Check for currency changes in bags
        EventHandler:CheckBagCurrencies()
    end)
end

-- Process currency change
function EventHandler:ProcessCurrencyChange(currencyID, newQuantity, quantityChange, quantityGainSource, quantityLostSource)
    if not currencyID then return end

    -- Parity with gold: ensure rollover before logging changes
    if CurrencyTracker.Storage and CurrencyTracker.Storage.ShiftCurrencyLogs then
        CurrencyTracker.Storage:ShiftCurrencyLogs()
    end

    -- Dynamic discovery: if this currency isn't supported yet, save basic metadata so
    -- downstream DataManager can surface it. Only attempt when Storage is available.
    if CurrencyTracker.DataManager and not CurrencyTracker.DataManager:IsCurrencySupported(currencyID) then
        if CurrencyTracker.Storage and CurrencyTracker.Storage.SaveDiscoveredCurrency then
            CurrencyTracker.Storage:SaveDiscoveredCurrency(currencyID)
            CurrencyTracker:LogDebug("Discovered new currency id=%s; saved basic metadata", tostring(currencyID))
        end
    end

    local old = lastCurrencyAmounts[currencyID] or 0
    local change = quantityChange
    if change == nil then
        change = (newQuantity or 0) - old
    end

    -- Enhanced baseline priming on first sighting
    if not primedCurrencies[currencyID] then
        if quantityChange == nil then
            -- Legacy path: no explicit change provided, just prime in-memory and skip logging
            lastCurrencyAmounts[currencyID] = newQuantity or 0
            primedCurrencies[currencyID] = true
            CurrencyTracker:LogDebug("Primed currency %s at %s (no transaction recorded)", tostring(currencyID), tostring(lastCurrencyAmounts[currencyID]))
            return
        else
            -- Modern path: first event comes with a change value; infer baseline and prime Total once if empty
            local inferredBaseline = (newQuantity or 0) - (quantityChange or 0)
            if inferredBaseline and inferredBaseline > 0 and IsCurrencyTotalEmpty(currencyID) then
                if PrimeBaselineTotalOnly(currencyID, inferredBaseline) then
                    CurrencyTracker:LogDebug("Primed Total baseline for id=%s amount=%s (inferred)", tostring(currencyID), tostring(inferredBaseline))
                end
            end
            -- Update in-memory snapshot so subsequent diffs are correct; proceed to log this delta below
            lastCurrencyAmounts[currencyID] = newQuantity or 0
            primedCurrencies[currencyID] = true
        end
    end

    if change ~= 0 then
        -- Determine signed numeric source key
        local sourceKey
        if change > 0 and quantityGainSource then
            sourceKey = tonumber(quantityGainSource)
        elseif change < 0 and quantityLostSource then
            sourceKey = -tonumber(quantityLostSource)
        else
            sourceKey = 0 -- Unknown
        end

        -- Record raw event metadata (both gain and lost sources) for analysis
        if CurrencyTracker.Storage and CurrencyTracker.Storage.RecordEventMetadata then
            local sign = (change > 0) and 1 or -1
            CurrencyTracker.Storage:RecordEventMetadata(currencyID, quantityGainSource, quantityLostSource, sign)
        end

        -- Track the change using DataManager
        if CurrencyTracker.DataManager then
            CurrencyTracker.DataManager:TrackCurrencyChange(currencyID, change, sourceKey)
        end

        -- Structured debug output (when enabled)
        if CurrencyTracker and CurrencyTracker.DEBUG_MODE then
            local incomeAdd = change > 0 and change or 0
            local outgoingAdd = change < 0 and -change or 0
            local rawNew = (newQuantity ~= nil) and tostring(newQuantity) or "nil"
            local rawChg = (quantityChange ~= nil) and tostring(quantityChange) or "nil"
            local rawGain = (quantityGainSource ~= nil) and tostring(quantityGainSource) or "nil"
            local rawLost = (quantityLostSource ~= nil) and tostring(quantityLostSource) or "nil"

            print("[AC CT][Event]")
            print(string.format("  Raw: id=%s new=%s chg=%s gainSrc=%s lostSrc=%s",
                tostring(currencyID), rawNew, rawChg, rawGain, rawLost))
            print(string.format("  Calc: old=%s delta=%s srcKey=%s",
                tostring(old), tostring(change), tostring(sourceKey)))
            print(string.format("  Save: path=currencyData[%s][Session|Day|Week|Month|Year|Total][%s] In+=%d Out+=%d",
                tostring(currencyID), tostring(sourceKey), incomeAdd, outgoingAdd))
        end

        -- Update stored amount
        if newQuantity ~= nil then
            lastCurrencyAmounts[currencyID] = newQuantity
        else
            lastCurrencyAmounts[currencyID] = old + change
        end

        -- Mark as primed after first processed change
        primedCurrencies[currencyID] = true
        
        CurrencyTracker:LogDebug("CURRENCY_DISPLAY_UPDATE id=%d new=%s chg=%s gainSrc=%s lostSrc=%s srcKey=%s",
            currencyID, tostring(newQuantity), tostring(change), tostring(quantityGainSource), tostring(quantityLostSource), tostring(sourceKey))
    end
end

-- Initialize currency amounts for change tracking
function EventHandler:InitializeCurrencyAmounts()
    lastCurrencyAmounts = {}
    primedCurrencies = {}

    -- Get supported currencies and initialize their amounts
    if CurrencyTracker.DataManager then
        local supported = CurrencyTracker.DataManager:GetSupportedCurrencies()

        for currencyID in pairs(supported) do
            local currentAmount = self:GetCurrentCurrencyAmount(currencyID)
            -- Prime baseline without recording a transaction
            lastCurrencyAmounts[currencyID] = currentAmount or 0
            primedCurrencies[currencyID] = true
            -- If storage has no Total data yet and the live amount is positive, prime Total once
            if (currentAmount or 0) > 0 and IsCurrencyTotalEmpty(currencyID) then
                PrimeBaselineTotalOnly(currencyID, currentAmount)
                CurrencyTracker:LogDebug("Primed Total baseline at login for id=%s amount=%s", tostring(currencyID), tostring(currentAmount))
            end
        end
    end
end

-- Get current amount of a currency
function EventHandler:GetCurrentCurrencyAmount(currencyID)
    -- Try modern API first
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            return info.quantity or 0
        end
    end

    -- Try legacy API (may not exist in all client versions)
    local success, name, amount = pcall(function()
        if _G.GetCurrencyInfo then
            return _G.GetCurrencyInfo(currencyID)
        end
        return nil, 0
    end)

    if success and name then
        return amount or 0
    end

    return 0
end

-- Check currencies in bags (fallback method)
function EventHandler:CheckBagCurrencies()
    -- This is a fallback method for older clients
    -- Check if any tracked currencies have changed
    if CurrencyTracker.DataManager then
        local supported = CurrencyTracker.DataManager:GetSupportedCurrencies()

        for currencyID in pairs(supported) do
            local currentAmount = self:GetCurrentCurrencyAmount(currencyID)
            local lastAmount = lastCurrencyAmounts[currencyID]

            if lastAmount == nil then
                -- First sighting after login: prime only
                lastCurrencyAmounts[currencyID] = currentAmount or 0
                primedCurrencies[currencyID] = true
            elseif currentAmount ~= lastAmount then
                self:ProcessCurrencyChange(currencyID, currentAmount, nil, nil, nil)
            end
        end
    end
end

-- Identify the source of currency change
function EventHandler:IdentifySource()
    -- Basic source identification
    -- This can be enhanced with more sophisticated detection

    if inCombat then
        return "Combat"
    end

    -- Check for common UI frames that might indicate source
    if QuestFrame and QuestFrame:IsShown() then
        return "Quest"
    end

    if MerchantFrame and MerchantFrame:IsShown() then
        return "Vendor"
    end

    if TradeFrame and TradeFrame:IsShown() then
        return "Trade"
    end

    if MailFrame and MailFrame:IsShown() then
        return "Mail"
    end

    return "Unknown"
end

-- Add update to batch for processing later
function EventHandler:AddToBatch(updateType, ...)
    table.insert(updateBatch, {
        type = updateType,
        args = {...},
        timestamp = time()
    })

    -- Schedule batch processing if not already scheduled
    if not batchTimer then
        batchTimer = C_Timer.NewTimer(1.0, function()
            EventHandler:ProcessBatchUpdates()
        end)
    end
end

-- Process batched updates
function EventHandler:ProcessBatchUpdates()
    if #updateBatch == 0 then
        return
    end

    CurrencyTracker:LogDebug("Processing %d batched updates", #updateBatch)

    for _, update in ipairs(updateBatch) do
        if update.type == "CURRENCY_UPDATE" then
            -- args: currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource
            self:ProcessCurrencyChange(update.args[1], update.args[2], update.args[3], update.args[4], update.args[5])
        elseif update.type == "BAG_UPDATE" then
            self:CheckBagCurrencies()
        end
    end

    -- Clear batch
    updateBatch = {}
    batchTimer = nil
end