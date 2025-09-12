-- CurrencyCore.lua
-- Main orchestration module for Currency Tracker functionality
-- Manages module lifecycle and coordinates between sub-components

local addonName, addonTable = ...

-- Create the main CurrencyTracker namespace
CurrencyTracker = CurrencyTracker or {}

-- Module state
local isEnabled = false
local isInitialized = false

-- Sub-module references (will be populated as modules are loaded)
-- Important: do NOT overwrite if modules were already defined by earlier files
CurrencyTracker.Constants = CurrencyTracker.Constants
CurrencyTracker.DataManager = CurrencyTracker.DataManager
CurrencyTracker.UIController = CurrencyTracker.UIController
CurrencyTracker.EventHandler = CurrencyTracker.EventHandler
CurrencyTracker.Storage = CurrencyTracker.Storage
CurrencyTracker.DisplayIntegration = CurrencyTracker.DisplayIntegration

-- Core module interface
function CurrencyTracker:Initialize()
    if isInitialized then
        return true
    end

-- Inspect raw metadata recorded for a currency: gain/lost source counts and last snapshot
function CurrencyTracker:MetaShow(sub)
    local tf, id = self:ParseShowCommand(sub) -- reuse timeframe parser; expects id at the end
    if not id then
        print("Usage: /ct meta show <timeframe> <id>")
        return
    end
    local server = _G.AC_SERVER or GetRealmName()
    local character = _G.AC_PLAYER or UnitName("player")
    local sv = _G.Accountant_ClassicSaveData
    if not (server and character and sv and sv[server] and sv[server][character]) then
        print("No saved data available")
        return
    end
    local metaRoot = sv[server][character].currencyMeta
    if not metaRoot or not metaRoot[id] then
        print("No metadata for currency "..tostring(id))
        return
    end
    local node = metaRoot[id][tf] or {}
    local gain = node.gain or {}
    local lost = node.lost or {}
    print(string.format("=== Meta Sources - %s (%d) ===", tf, id))
    local function sortedKeys(t)
        local keys = {}
        for k in pairs(t) do table.insert(keys, k) end
        table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
        return keys
    end
    local gk = sortedKeys(gain)
    print("Gain sources:")
    if #gk == 0 then
        print("  <none>")
    else
        for _, k in ipairs(gk) do
            print(string.format("  %s: %d", tostring(k), gain[k] or 0))
        end
    end
    local lk = sortedKeys(lost)
    print("Lost sources:")
    if #lk == 0 then
        print("  <none>")
    else
        for _, k in ipairs(lk) do
            print(string.format("  %s: %d", tostring(k), lost[k] or 0))
        end
    end
    if node.last then
        print(string.format("Last: gain=%s lost=%s sign=%s time=%s", tostring(node.last.gain), tostring(node.last.lost), tostring(node.last.sign), tostring(node.last.t)))
    end
    print("=========================")
end

-- True repair: remove previously recorded income/outgoing across aggregates
-- Syntax: "remove <id> <amount> <source> (income|outgoing)"
function CurrencyTracker:RepairRemove(sub)
    if not self.Storage or not self.Storage.RepairRemove then
        print("Repair not available: storage helper missing")
        return
    end
    local id, amount, source, kind = sub:match("remove%s+(%d+)%s+(%d+)%s+(%d+)%s+(%a+)")
    id = tonumber(id)
    amount = tonumber(amount)
    source = tonumber(source)
    if not id or not amount or not source or not kind then
        print("Usage: /ct repair remove <id> <amount> <source> (income|outgoing)")
        return
    end
    local ok = self.Storage:RepairRemove(id, amount, source, kind)
    if ok then
        print(string.format("Removed %d from %s for currency %d (source=%d) across periods",
            amount, string.lower(kind), id, source))
    else
        print("Removal failed")
    end
end

-- Adjust aggregates manually: "adjust <id> <delta> [source]"
function CurrencyTracker:RepairAdjust(sub)
    if not self.Storage or not self.Storage.AdjustCurrencyAggregates then
        print("Repair not available: storage helper missing")
        return
    end
    local id, delta, source = sub:match("adjust%s+(%d+)%s+(-?%d+)%s*(%d*)")
    id = tonumber(id)
    delta = tonumber(delta)
    source = tonumber(source)
    if not id or not delta then
        print("Usage: /ct repair adjust <id> <delta> [source]")
        return
    end
    local ok = self.Storage:AdjustCurrencyAggregates(id, delta, source)
    if ok then
        print(string.format("Adjusted currency %d by %d (source=%s)", id, delta, tostring(source or 0)))
    else
        print("Adjustment failed")
    end
end

-- List discovered currencies
function CurrencyTracker:DiscoverList()
    if not self.Storage or not self.Storage.GetDiscoveredCurrencies then
        print("No discovery storage available")
        return
    end
    local discovered = self.Storage:GetDiscoveredCurrencies() or {}
    local count = 0
    print("=== Discovered Currencies ===")
    -- Collect and sort by id for stable output
    local ids = {}
    for id in pairs(discovered) do table.insert(ids, id) end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local meta = discovered[id]
        local tracked = (meta and meta.tracked ~= false)
        print(string.format("%d: %s (tracked=%s)", id, tostring(meta and meta.name or ("Currency "..tostring(id))), tracked and "true" or "false"))
        count = count + 1
    end
    if count == 0 then print("<none>") end
    print("=== End ===")
end

-- Track/untrack a discovered currency. Syntax: "track <id> [on|off]"; no state toggles.
function CurrencyTracker:DiscoverTrack(sub)
    if not self.Storage or not self.Storage.GetDiscoveredCurrencies then
        print("No discovery storage available")
        return
    end
    local id = tonumber(sub:match("track%s+(%d+)") or "")
    if not id then
        print("Usage: /ct discover track <id> [on|off]")
        return
    end
    local stateStr = sub:match("track%s+%d+%s+(%a+)")
    local discovered = self.Storage:GetDiscoveredCurrencies()
    discovered[id] = discovered[id] or {}
    -- If not previously saved, try to populate basic meta
    if self.Storage.SaveDiscoveredCurrency and (not discovered[id].id) then
        self.Storage:SaveDiscoveredCurrency(id)
        discovered = self.Storage:GetDiscoveredCurrencies()
    end

    local current = (discovered[id].tracked ~= false)
    local newVal
    if stateStr == nil then
        newVal = not current
    else
        stateStr = string.lower(stateStr)
        if stateStr == "on" or stateStr == "true" then
            newVal = true
        elseif stateStr == "off" or stateStr == "false" then
            newVal = false
        else
            print("Usage: /ct discover track <id> [on|off]")
            return
        end
    end
    discovered[id].tracked = newVal and true or false
    print(string.format("Discovered currency %d tracked=%s", id, newVal and "true" or "false"))
end

-- Clear all discovered currencies for the current character
function CurrencyTracker:DiscoverClear()
    if not self.Storage or not self.Storage.GetDiscoveredCurrencies then
        print("No discovery storage available")
        return
    end
    local discovered = self.Storage:GetDiscoveredCurrencies()
    local n = 0
    for k in pairs(discovered) do discovered[k] = nil; n = n + 1 end
    print(string.format("Cleared %d discovered currencies", n))
end
    
    -- Initialize sub-modules in proper order
    local success = true
    
    -- Constants module first (no initialization needed, just data)
    -- Storage must be initialized first
    if self.Storage and self.Storage.Initialize then
        success = success and self.Storage:Initialize()
    end
    
    -- Then data manager
    if self.DataManager and self.DataManager.Initialize then
        success = success and self.DataManager:Initialize()
    end
    
    -- Then event handler
    if self.EventHandler and self.EventHandler.Initialize then
        success = success and self.EventHandler:Initialize()
    end
    
    -- Headless mode: disable UI controller initialization
    -- if self.UIController and self.UIController.Initialize then
    --     success = success and self.UIController:Initialize()
    -- end
    
    -- Headless mode: disable display integration initialization
    -- if self.DisplayIntegration and self.DisplayIntegration.Initialize then
    --     success = success and self.DisplayIntegration:Initialize()
    -- end
    
    if success then
        isInitialized = true
        print("CurrencyTracker: Module initialized successfully")
        -- Diagnostics (debug only)
        if CurrencyTracker and CurrencyTracker.DEBUG_MODE then
            print(string.format("[AC CT] Core.Init: EventHandler=%s Init=%s Enable=%s",
                tostring(self.EventHandler), tostring(self.EventHandler and self.EventHandler.Initialize), tostring(self.EventHandler and self.EventHandler.Enable)))
        end
    else
        print("CurrencyTracker: Module initialization failed")
    end
    
    return success
end

function CurrencyTracker:Enable()
    if not isInitialized then
        if not self:Initialize() then
            return false
        end
    end
    
    if isEnabled then
        return true
    end
    
    -- Enable sub-modules
    local success = true
    
    -- Diagnostics before enabling EventHandler (debug only)
    if CurrencyTracker and CurrencyTracker.DEBUG_MODE then
        print(string.format("[AC CT] Core.Enable: about to enable EventHandler (exists=%s, hasEnable=%s)",
            tostring(self.EventHandler ~= nil), tostring(self.EventHandler and (type(self.EventHandler.Enable) == "function"))))
    end

    if self.EventHandler and self.EventHandler.Enable then
        local ok = self.EventHandler:Enable()
        success = success and ok
        if CurrencyTracker and CurrencyTracker.DEBUG_MODE then
            print(string.format("[AC CT] Core.Enable: EventHandler:Enable() returned %s", tostring(ok)))
        end
    else
        if CurrencyTracker and CurrencyTracker.DEBUG_MODE then
            print("[AC CT] Core.Enable: EventHandler missing or no Enable()")
        end
    end
    
    -- Headless mode: do not enable UI or display integration
    -- if self.UIController and self.UIController.Enable then
    --     success = success and self.UIController:Enable()
    -- end
    
    -- if self.DisplayIntegration and self.DisplayIntegration.Enable then
    --     success = success and self.DisplayIntegration:Enable()
    -- end
    
    if success then
        isEnabled = true
        print("CurrencyTracker: Module enabled")
    else
        print("CurrencyTracker: Module enable failed")
    end
    
    return success
end

function CurrencyTracker:Disable()
    if not isEnabled then
        return true
    end
    
    -- Disable sub-modules in reverse order
    local success = true
    
    if self.DisplayIntegration and self.DisplayIntegration.Disable then
        success = success and self.DisplayIntegration:Disable()
    end
    
    if self.UIController and self.UIController.Disable then
        success = success and self.UIController:Disable()
    end
    
    if self.EventHandler and self.EventHandler.Disable then
        success = success and self.EventHandler:Disable()
    end
    
    if success then
        isEnabled = false
        print("CurrencyTracker: Module disabled")
    else
        print("CurrencyTracker: Module disable failed")
    end
    
    return success
end

function CurrencyTracker:IsEnabled()
    return isEnabled
end

function CurrencyTracker:IsInitialized()
    return isInitialized
end

-- Version information
CurrencyTracker.VERSION = "1.0.0"
CurrencyTracker.MIN_ADDON_VERSION = "2.20.00"

-- Internal helpers for baseline preview/apply
-- Fetch live quantity for a currency id using modern or legacy API.
local function CT_GetRealCurrencyAmount(currencyID)
    if not currencyID then return nil end
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
        if ok and type(info) == "table" then
            return info.quantity or 0
        end
    end
    if _G.GetCurrencyInfo then
        local ok, name, amount = pcall(_G.GetCurrencyInfo, currencyID)
        if ok and name then
            return amount or 0
        end
    end
    return nil
end

-- Adjust Total-only by a signed delta without touching other periods.
-- Positive delta increases Total.In; negative delta increases Total.Out.
local function CT_ApplyTotalOnlyDelta(currencyID, delta)
    if not currencyID or not delta or delta == 0 then return false end
    if not EnsureSavedVariablesStructure or not GetCurrentServerAndCharacter then return false end
    if not EnsureSavedVariablesStructure() then return false end
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
    bucket.Total[0] = bucket.Total[0] or { In = 0, Out = 0 }
    if delta > 0 then
        bucket.Total[0].In = (bucket.Total[0].In or 0) + delta
    else
        bucket.Total[0].Out = (bucket.Total[0].Out or 0) + (-delta)
    end
    charData.currencyOptions = charData.currencyOptions or {}
    charData.currencyOptions.lastUpdate = time()
    return true
end

-- Build baseline discrepancy list using a single logic path.
-- Returns an array of { id, name, ac, real, delta } for mismatches only.
function CurrencyTracker:BuildBaselineDiscrepancies()
    local results = {}
    local ids = {}
    if self.Storage and self.Storage.GetAvailableCurrencies then
        ids = self.Storage:GetAvailableCurrencies() or {}
    elseif self.DataManager and self.DataManager.GetAvailableCurrencies then
        ids = self.DataManager:GetAvailableCurrencies() or {}
    end

    for _, cid in ipairs(ids) do
        local data = self.Storage and self.Storage:GetCurrencyData(cid, "Total") or nil
        local acNet = (data and data.net) or 0
        local real = CT_GetRealCurrencyAmount(cid)
        if real ~= nil then
            local info = self.DataManager and self.DataManager:GetCurrencyInfo(cid) or nil
            local name = (info and info.name) or ("Currency " .. tostring(cid))
            if L and L[name] then name = L[name] end
            if acNet ~= real then
                table.insert(results, {
                    id = cid,
                    name = name,
                    ac = acNet,
                    real = real,
                    delta = (real - acNet),
                })
            end
        end
    end
    table.sort(results, function(a,b)
        if a.name == b.name then return a.id < b.id end
        return tostring(a.name) < tostring(b.name)
    end)
    return results
end

-- Preview baseline discrepancies: print only; no writes.
function CurrencyTracker:RepairBaselinePreview()
    local diffs = self:BuildBaselineDiscrepancies()
    if #diffs == 0 then
        print("Baseline preview: all totals match live values.")
        return
    end
    print("=== Baseline Preview (Total vs Live) ===")
    for _, d in ipairs(diffs) do
        print(string.format("%s (id=%d): AC-CT amount=%d | Real amount=%d | Delta=%+d",
            tostring(d.name), d.id, d.ac, d.real, d.delta))
    end
    print("=== End Preview ===")
end

-- Apply baseline corrections: reuse preview logic; write Total-only delta.
function CurrencyTracker:RepairBaselineApply()
    local diffs = self:BuildBaselineDiscrepancies()
    if #diffs == 0 then
        print("Baseline apply: nothing to change (all totals already match).")
        return
    end
    print("=== Baseline Apply (Total-only adjustments) ===")
    for _, d in ipairs(diffs) do
        local ok = CT_ApplyTotalOnlyDelta(d.id, d.delta)
        if ok then
            print(string.format("Fixed %s (id=%d): AC-CT %d -> %d (applied %+d)",
                tostring(d.name), d.id, d.ac, d.real, d.delta))
        else
            print(string.format("Failed to fix %s (id=%d)", tostring(d.name), d.id))
        end
    end
    print("=== End Apply ===")
end

-- Utility function to check if the main addon version is compatible
function CurrencyTracker:IsCompatibleVersion()
    -- This will be implemented when we integrate with the main addon
    -- For now, assume compatibility
    return true
end

-- Error logging function
function CurrencyTracker:LogError(message, ...)
    local formattedMessage = string.format(message, ...)
    print("CurrencyTracker ERROR: " .. formattedMessage)
end

-- Debug logging function (can be disabled in production)
function CurrencyTracker:LogDebug(message, ...)
    if self.DEBUG_MODE then
        local formattedMessage = string.format(message, ...)
        print("CurrencyTracker DEBUG: " .. formattedMessage)
    end
end

-- Set debug mode (can be controlled by user settings later)
-- Debug mode defaults to OFF; can be toggled via '/ct debug on|off'
CurrencyTracker.DEBUG_MODE = false

-- Event handler wrapper functions for main addon integration
function CurrencyTracker:OnCurrencyDisplayUpdate(currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource)
    if not isInitialized or not isEnabled then
        return
    end
    
    if self.EventHandler and self.EventHandler.OnCurrencyDisplayUpdate then
        -- Forward all parameters if handler supports them; legacy handlers will ignore extras
        self.EventHandler:OnCurrencyDisplayUpdate(currencyType, quantity, quantityChange, quantityGainSource, quantityLostSource)
    end
end

function CurrencyTracker:OnBagUpdate(bagID)
    if not isInitialized or not isEnabled then
        return
    end
    
    if self.EventHandler and self.EventHandler.OnBagUpdate then
        self.EventHandler:OnBagUpdate(bagID)
    end
end

-- Test function retained for compatibility (no-op in headless mode)
function CurrencyTracker:TestTwoTierSystem()
    print("CurrencyTracker: TestTwoTierSystem is not applicable in headless mode")
    return nil
end

-- Function to get system status
function CurrencyTracker:GetStatus()
    local status = {
        isInitialized = isInitialized,
        isEnabled = isEnabled,
        version = self.VERSION,
        debugMode = self.DEBUG_MODE
    }
    
if self.UIController and self.UIController.GetSystemStatus then
        status.uiController = self.UIController:GetSystemStatus()
    end
    
    return status
end

-- Register production slash commands (headless mode)
SLASH_CURRENCYTRACKER1 = "/ct"
SlashCmdList["CURRENCYTRACKER"] = function(msg)
    local command = string.lower(msg or "")
    local cmd = command:match("^%s*(.*)$") or command

    -- Prefer the more specific 'show-all-currencies' before generic 'show'
    if cmd:find("^show%-all%-currencies") then
        local timeframe = select(1, CurrencyTracker:ParseShowCommand(cmd))
        local verbose = cmd:find("verbose") ~= nil
        CurrencyTracker:PrintMultipleCurrencies(timeframe, verbose)
    elseif cmd:find("^show%-all") then
        -- Alias for show-all-currencies; execute the exact same path
        local timeframe = select(1, CurrencyTracker:ParseShowCommand(cmd))
        local verbose = cmd:find("verbose") ~= nil
        CurrencyTracker:PrintMultipleCurrencies(timeframe, verbose)
    elseif cmd:find("^show") then
        CurrencyTracker:ShowCurrencyData(cmd)
    elseif cmd:find("^debug") then
        -- /ct debug on|off
        local sub = cmd:gsub("^debug%s*", "")
        sub = sub:gsub("^%s+", "")
        if sub == "on" then
            CurrencyTracker.DEBUG_MODE = true
            print("CurrencyTracker debug: ON")
        elseif sub == "off" then
            CurrencyTracker.DEBUG_MODE = false
            print("CurrencyTracker debug: OFF")
        else
            print("Usage: /ct debug on | /ct debug off")
            print("Current: "..(CurrencyTracker.DEBUG_MODE and "ON" or "OFF"))
        end
    elseif cmd:find("^status%s*$") then
        CurrencyTracker:ShowStatus()
    elseif cmd:find("^discover") then
        -- /ct discover list | track <id> [on|off] | clear
        local sub = cmd:gsub("^discover%s*", "")
        sub = sub:gsub("^%s+", "")
        if sub == "list" then
            CurrencyTracker:DiscoverList()
        elseif sub:find("^track") then
            CurrencyTracker:DiscoverTrack(sub)
        elseif sub == "clear" then
            CurrencyTracker:DiscoverClear()
        else
            print("Usage: /ct discover list | track <id> [on|off] | clear")
        end
    elseif cmd:find("^repair") then
        -- /ct repair init
        -- /ct repair adjust <id> <delta> [source]
        -- /ct repair remove <id> <amount> <source> (income|outgoing)
        -- /ct repair baseline preview
        -- /ct repair baseline
        local sub = cmd:gsub("^repair%s*", "")
        sub = sub:gsub("^%s+", "")
        if sub == "init" then
            if CurrencyTracker.Storage and CurrencyTracker.Storage.ResetAllData then
                local ok = CurrencyTracker.Storage:ResetAllData()
                if ok then
                    print("CurrencyTracker: storage reset complete for current character (gold data untouched)")
                else
                    print("CurrencyTracker: storage reset failed")
                end
            else
                print("CurrencyTracker: storage reset helper unavailable")
            end
        elseif sub:find("^adjust") then
            CurrencyTracker:RepairAdjust(sub)
        elseif sub:find("^remove") then
            CurrencyTracker:RepairRemove(sub)
        elseif sub:find("^baseline") then
            local rest = sub:gsub("^baseline%s*", "")
            rest = rest:gsub("^%s+", "")
            if rest == "preview" then
                CurrencyTracker:RepairBaselinePreview()
            elseif rest == "" then
                CurrencyTracker:RepairBaselineApply()
            else
                print("Usage: /ct repair baseline preview")
                print("       /ct repair baseline")
            end
        else
            print("Usage: /ct repair init")
            print("       /ct repair adjust <id> <delta> [source]")
            print("       /ct repair remove <id> <amount> <source> (income|outgoing)")
            print("       /ct repair baseline preview")
            print("       /ct repair baseline")
        end
    elseif cmd:find("^meta") then
        -- /ct meta show <timeframe> <id>
        local sub = cmd:gsub("^meta%s*", "")
        sub = sub:gsub("^%s+", "")
        if sub:find("^show") then
            CurrencyTracker:MetaShow(sub)
        else
            print("Usage: /ct meta show <timeframe> <id>")
        end
    else
        CurrencyTracker:ShowHelp()
    end
end

-- Show system status
function CurrencyTracker:ShowStatus()
    local status = self:GetStatus()
    print("=== CurrencyTracker Status ===")
    for key, value in pairs(status) do
        if type(value) == "table" then
            print(string.format("%s: [table]", key))
        else
            print(string.format("%s: %s", key, tostring(value)))
        end
    end
    print("=== End Status ===")
end

-- Parse timeframe and optional currencyID from a show command
-- Returns: timeframe (string), currencyID (number|nil)
function CurrencyTracker:ParseShowCommand(command)
    -- Extract parts and detect trailing numeric currency ID
    local currencyID = nil
    local parts = {}
    for part in string.gmatch(string.lower(command or ""), "%S+") do
        table.insert(parts, part)
    end

    if #parts > 0 then
        local lastPart = parts[#parts]
        local num = tonumber(lastPart)
        if num and num > 0 then
            currencyID = num
            parts[#parts] = nil
        end
    end

    -- Remove leading verb tokens to normalize timeframe detection
    if #parts > 0 and (parts[1] == "show" or parts[1] == "show-all-currencies" or parts[1] == "show-all" or parts[1] == "meta") then
        table.remove(parts, 1)
    end

    local timeframe = "Session" -- default
    local tfMap = {
        ["this-session"] = "Session",
        ["session"] = "Session",
        ["today"] = "Day",
        ["prv-day"] = "PrvDay",
        ["this-week"] = "Week",
        ["week"] = "Week",
        ["prv-week"] = "PrvWeek",
        ["this-month"] = "Month",
        ["month"] = "Month",
        ["prv-month"] = "PrvMonth",
        ["this-year"] = "Year",
        ["year"] = "Year",
        ["prv-year"] = "PrvYear",
        ["total"] = "Total",
    }

    if #parts > 0 then
        local key = parts[1]
        if tfMap[key] then
            timeframe = tfMap[key]
        else
            -- Fallback: substring search across remaining text
            local joined = table.concat(parts, " ")
            for k, v in pairs(tfMap) do
                if string.find(joined, k, 1, true) then
                    timeframe = v
                    break
                end
            end
        end
    end

    return timeframe, currencyID
end

-- Handle /ct show* commands
function CurrencyTracker:ShowCurrencyData(command)
    local timeframe, currencyID = self:ParseShowCommand(command)

    if (command or ""):find("^%s*show%-all%-currencies") then
        local verbose = (command or ""):find("verbose") ~= nil
        self:PrintMultipleCurrencies(timeframe, verbose)
        return
    end

    if not currencyID then
        if self.DataManager and self.DataManager.LoadCurrencySelection then
            currencyID = self.DataManager:LoadCurrencySelection()
        end
    end

    if not currencyID then
        print("No currency selected. Usage: /ct show <timeframe> [currencyid]")
        return
    end

    local data = nil
    if self.Storage and self.Storage.GetCurrencyData then
        data = self.Storage:GetCurrencyData(currencyID, timeframe)
    elseif self.DataManager and self.DataManager.GetCurrencyData then
        data = self.DataManager:GetCurrencyData(currencyID, timeframe)
    end

    self:PrintCurrencyData(currencyID, timeframe, data or { income = 0, outgoing = 0, net = 0, transactions = {} })
end

-- Print a single currency's data, resolving localized names and source labels
function CurrencyTracker:PrintCurrencyData(currencyID, timeframe, data)
    local currencyInfo = self.DataManager and self.DataManager:GetCurrencyInfo(currencyID) or nil
    local currencyName = (currencyInfo and currencyInfo.name) or ("Currency " .. tostring(currencyID))

    -- Localization for currency name
    if L and L[currencyName] then
        currencyName = L[currencyName]
    end

    print(string.format("=== %s - %s ===", currencyName, tostring(timeframe)))
    print(string.format("Total Income: %d", (data and data.income) or 0))
    print(string.format("Total Outgoing: %d", (data and data.outgoing) or 0))
    print(string.format("Net Change: %d", (data and data.net) or 0))

    -- Prefer a map of sources if available; fall back to transactions list
    if data and data.sources and next(data.sources) then
        print("Transactions by Source:")
        for source, amounts in pairs(data.sources) do
            local income = (amounts and amounts.income) or (amounts and amounts.In) or 0
            local outgoing = (amounts and amounts.outgoing) or (amounts and amounts.Out) or 0
            local net = income - outgoing

            local sourceLabel = tostring(source)
            if type(source) == "number" then
                local code = source
                local token = CurrencyTracker.SourceCodeTokens and CurrencyTracker.SourceCodeTokens[math.abs(code)]
                if token then
                    sourceLabel = (L and L[token]) or token
                else
                    sourceLabel = "S:" .. tostring(code)
                end
            end

            print(string.format("  %s: +%d | -%d (net: %s%d)",
                sourceLabel,
                income,
                outgoing,
                (net >= 0 and "+" or ""),
                net))
        end
    elseif data and data.transactions and #data.transactions > 0 then
        print("Transactions by Source:")
        for _, transaction in ipairs(data.transactions) do
            local income = transaction.income or 0
            local outgoing = transaction.outgoing or 0
            local net = income - outgoing
            local label = tostring(transaction.source)
            print(string.format("  %s: +%d | -%d (net: %s%d)",
                label,
                income,
                outgoing,
                (net >= 0 and "+" or ""),
                net))
        end
    else
        print("No transactions recorded.")
    end
    print("=========================")
end

-- Print a summary across all currencies for a timeframe
function CurrencyTracker:PrintMultipleCurrencies(timeframe, verbose)
    local currencies = {}
    if self.Storage and self.Storage.GetAvailableCurrencies then
        currencies = self.Storage:GetAvailableCurrencies() or {}
    elseif self.DataManager and self.DataManager.GetAvailableCurrencies then
        currencies = self.DataManager:GetAvailableCurrencies() or {}
    end

    if not currencies or #currencies == 0 then
        print("No currency data available.")
        return
    end

    print(string.format("=== All Currencies - %s ===", tostring(timeframe)))
    -- Default behavior: hide currencies explicitly marked as tracked=false in discovery metadata.
    -- Use 'verbose' option to include all currencies regardless of tracked flag.
    local discovered = {}
    if self.Storage and self.Storage.GetDiscoveredCurrencies then
        discovered = self.Storage:GetDiscoveredCurrencies() or {}
    end

    for _, cid in ipairs(currencies) do
        local meta = discovered[cid]
        local isTracked = (meta == nil) or (meta.tracked ~= false)
        if verbose or isTracked then
            local data = self.Storage and self.Storage:GetCurrencyData(cid, timeframe) or nil
            local info = self.DataManager and self.DataManager:GetCurrencyInfo(cid) or nil
            local name = (info and info.name) or ("Currency " .. tostring(cid))
            if L and L[name] then name = L[name] end
            local net = (data and data.net) or 0
            print(string.format("%s (id=%d): Income %d | Outgoing %d | Net %s%d",
                name,
                cid,
                (data and data.income) or 0,
                (data and data.outgoing) or 0,
                (net >= 0 and "+" or ""),
                net))
        end
    end
    print("=========================")
end

-- Print help for commands
function CurrencyTracker:ShowHelp()
    print("CurrencyTracker Commands:")
    print("  /ct show this-session [currencyid] - Show currency data for current session")
    print("  /ct show today [currencyid] - Show currency data for today")
    print("  /ct show prv-day [currencyid] - Show currency data for previous day")
    print("  /ct show this-week [currencyid] - Show currency data for this week")
    print("  /ct show prv-week [currencyid] - Show currency data for previous week")
    print("  /ct show this-month [currencyid] - Show currency data for this month")
    print("  /ct show prv-month [currencyid] - Show currency data for previous month")
    print("  /ct show this-year [currencyid] - Show currency data for this year")
    print("  /ct show prv-year [currencyid] - Show currency data for previous year")
    print("  /ct show total [currencyid] - Show currency data for total period")
    print("  /ct show-all-currencies this-session - Show all tracked currencies summary for current session")
    print("  /ct show-all-currencies today - Show all tracked currencies summary for today")
    print("  /ct show-all-currencies prv-day - Show all tracked currencies summary for previous day")
    print("  /ct show-all-currencies this-week - Show all tracked currencies summary for this week")
    print("  /ct show-all-currencies prv-week - Show all tracked currencies summary for previous week")
    print("  /ct show-all-currencies this-month - Show all tracked currencies summary for this month")
    print("  /ct show-all-currencies prv-month - Show all tracked currencies summary for previous month")
    print("  /ct show-all-currencies this-year - Show all tracked currencies summary for this year")
    print("  /ct show-all-currencies prv-year - Show all tracked currencies summary for previous year")
    print("  /ct show-all-currencies total - Show all tracked currencies summary for total period")
    print("  /ct show-all this-session - Alias of show-all-currencies for current session")
    print("  /ct show-all today - Alias of show-all-currencies for today")
    print("  /ct show-all prv-day - Alias of show-all-currencies for previous day")
    print("  /ct show-all this-week - Alias of show-all-currencies for this week")
    print("  /ct show-all prv-week - Alias of show-all-currencies for previous week")
    print("  /ct show-all this-month - Alias of show-all-currencies for this month")
    print("  /ct show-all prv-month - Alias of show-all-currencies for previous month")
    print("  /ct show-all this-year - Alias of show-all-currencies for this year")
    print("  /ct show-all prv-year - Alias of show-all-currencies for previous year")
    print("  /ct show-all total - Alias of show-all-currencies for total period")
    print("  Tip: append 'verbose' to include untracked currencies in the summary (e.g., /ct show-all total verbose)")
    print("  /ct debug on|off - Toggle in-game debug logging for currency events")
    print("  /ct status - Show system status")
    print("  /ct discover list - List dynamically discovered currencies")
    print("  /ct discover track <id> [on|off] - Track or untrack a discovered currency")
    print("  /ct discover clear - Clear discovered currencies")
    print("  /ct repair init - Reset currency tracker storage for this character (does not touch gold)")
    print("  /ct repair adjust <id> <delta> [source] - Apply a signed correction across aggregates")
    print("  /ct repair remove <id> <amount> <source> (income|outgoing) - Remove recorded amounts across aggregates")
    print("  /ct repair baseline preview - Compare AC-CT Total with live amounts and list mismatches")
    print("  /ct repair baseline - Apply Total-only corrections to match live amounts (same checks as preview)")
    print("  /ct meta show <timeframe> <id> - Inspect raw gain/lost source counts for a currency")
end