-- CurrencyEventHandler.lua
-- Monitors WoW events for currency changes
-- Handles event registration and currency change detection

local addonName = ...

-- Bind localization table for display labels/messages (lazy: safe if AceLocale not present)
local L = LibStub and LibStub("AceLocale-3.0", true) and LibStub("AceLocale-3.0"):GetLocale("Accountant_Classic", true) or nil

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
    -- Use a string key for baseline priming to avoid colliding with Enum 0 (ConvertOldItem)
    bucket.Total["BaselinePrime"] = bucket.Total["BaselinePrime"] or { In = 0, Out = 0 }
    bucket.Total["BaselinePrime"].In = (bucket.Total["BaselinePrime"].In or 0) + amount
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
        -- 11.0.2: quantityLostSource renamed to destroyReason. Keep dual-label for clarity in debug.
        local is1102 = CurrencyTracker and CurrencyTracker.Constants and CurrencyTracker.Constants.VersionUtils
            and CurrencyTracker.Constants.VersionUtils.IsVersionSupported
            and CurrencyTracker.Constants.VersionUtils.IsVersionSupported("11.0.2")
        local lossLabel = is1102 and "destroyReason" or "lostSource"
        local norm = string.format("  Args(norm): id=%s new=%s chg=%s gain=%s %s=%s",
            tostring(currencyType), tostring(quantity), tostring(quantityChange), tostring(quantityGainSource), lossLabel, tostring(quantityLostSource))
        print(norm)
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

    -- Sign-correction guard:
    -- On pre-11.0.2 clients, quantityChange could be absolute (always positive).
    -- Use the authoritative direction from (new - old) when both are available and magnitudes match but sign differs.
    if quantityChange ~= nil and newQuantity ~= nil then
        local diff = (newQuantity or 0) - old
        if diff ~= 0 and math.abs(diff) == math.abs(change) then
            local changePos = change > 0
            local diffPos = diff > 0
            if changePos ~= diffPos then
                change = diff
            end
        end
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
            -- Some clients omit the post-gain total ('quantity' is nil). In that case, fetch live amount.
            local effectiveNew = newQuantity
            if effectiveNew == nil then
                effectiveNew = self:GetCurrentCurrencyAmount(currencyID)
            end
            local inferredBaseline = (effectiveNew or 0) - (quantityChange or 0)
            if inferredBaseline and inferredBaseline > 0 and IsCurrencyTotalEmpty(currencyID) then
                if PrimeBaselineTotalOnly(currencyID, inferredBaseline) then
                    CurrencyTracker:LogDebug("Primed Total baseline for id=%s amount=%s (inferred)", tostring(currencyID), tostring(inferredBaseline))
                end
            end
            -- Update in-memory snapshot so subsequent diffs are correct; proceed to log this delta below
            lastCurrencyAmounts[currencyID] = effectiveNew or 0
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
            sourceKey = "Unknown" -- Unknown
        end

        -- Record raw event metadata (both gain and lost/destroy sources) for analysis
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

            local is1102 = CurrencyTracker and CurrencyTracker.Constants and CurrencyTracker.Constants.VersionUtils
                and CurrencyTracker.Constants.VersionUtils.IsVersionSupported
                and CurrencyTracker.Constants.VersionUtils.IsVersionSupported("11.0.2")
            local lossLabel = is1102 and "destroyReason" or "lostSrc"

            print("[AC CT][Event]")
            print(string.format("  Raw: id=%s new=%s chg=%s gainSrc=%s %s=%s",
                tostring(currencyID), rawNew, rawChg, rawGain, lossLabel, rawLost))
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
        
        do
            local is1102 = CurrencyTracker and CurrencyTracker.Constants and CurrencyTracker.Constants.VersionUtils
                and CurrencyTracker.Constants.VersionUtils.IsVersionSupported
                and CurrencyTracker.Constants.VersionUtils.IsVersionSupported("11.0.2")
            local lossLabel = is1102 and "destroyReason" or "lostSrc"
            CurrencyTracker:LogDebug("CURRENCY_DISPLAY_UPDATE id=%d new=%s chg=%s gainSrc=%s %s=%s srcKey=%s",
                currencyID, tostring(newQuantity), tostring(change), tostring(quantityGainSource), lossLabel, tostring(quantityLostSource), tostring(sourceKey))
        end

        -- Near-cap warning on gains: threshold and durations configurable per character
        if change > 0 and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local ok, ci = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
            if ok and type(ci) == "table" then
                local cap = (ci.maxQuantity ~= nil and ci.maxQuantity) or ci.totalMax
                if cap and cap > 0 then
                    -- Load per-character settings (defaults: enable=true, cap_percent=0.90, time=3.0, fade=0.8)
                    local enable, threshold, tVisible, tFade = true, 0.90, 3.0, 0.8
                    if EnsureSavedVariablesStructure and GetCurrentServerAndCharacter and EnsureSavedVariablesStructure() then
                        local server, character = GetCurrentServerAndCharacter()
                        local sv = _G.Accountant_ClassicSaveData
                        if sv and sv[server] and sv[server][character] then
                            local co = sv[server][character].currencyOptions
                            if co and co.nearCapAlert then
                                local o = co.nearCapAlert
                                if type(o.enable) == "boolean" then enable = o.enable end
                                if tonumber(o.cap_percent) then threshold = tonumber(o.cap_percent) end
                                if tonumber(o.time_visible_sec) then tVisible = tonumber(o.time_visible_sec) end
                                if tonumber(o.fade_duration_sec) then tFade = tonumber(o.fade_duration_sec) end
                            end
                        end
                    end

                    if enable then
                        local afterAmt = (newQuantity ~= nil) and newQuantity or (old + change)
                        local ratio = afterAmt / cap
                        if ratio >= threshold then
                            local name = ci.name or ("Currency " .. tostring(currencyID))
                            -- Localize name via AceLocale if available
                            if L and L[name] then name = L[name] end
                            -- Localized warning template (fallback to English)
                            local tmpl = (L and L["CT_WarnNearCap"]) or "Warning: %s has reached or exceeded 90%% of total cap (%d)"
                            local msg = string.format(tmpl, tostring(name), cap)
                            if UIErrorsFrame and UIErrorsFrame.AddMessage then
                                -- Apply configured timings
                                if UIErrorsFrame.SetTimeVisible then UIErrorsFrame:SetTimeVisible(tVisible or 3.0) end
                                if UIErrorsFrame.SetFadeDuration then UIErrorsFrame:SetFadeDuration(tFade or 0.8) end
                                UIErrorsFrame:AddMessage(msg, 1.0, 0.2, 0.2, 1.0)
                            else
                                -- Fallback: red colored chat message
                                print("|cffff2020" .. msg .. "|r")
                            end
                        end
                    end
                end
            end
        end
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