# 数据访问API

<cite>
**本文档引用的文件**
- [Core.lua](file://Core/Core.lua)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua)
</cite>

## 目录
1. [简介](#简介)
2. [核心数据访问函数](#核心数据访问函数)
3. [跨角色数据聚合](#跨角色数据聚合)
4. [性能特征分析](#性能特征分析)
5. [事件时序问题与解决方案](#事件时序问题与解决方案)
6. [错误处理示例](#错误处理示例)

## 简介
本API文档详细描述了Accountant_Classic插件中的数据访问功能，重点介绍金币和货币数据的查询接口。文档涵盖`GetDataByServerAndCharacter()`函数和`GetCurrencyInfo()`、`GetAllCurrencies()`方法的参数要求、返回值结构和使用示例。通过这些API，用户可以实现跨角色的数据聚合分析，监控货币交易历史，并处理各种边界情况。

## 核心数据访问函数

### GetDataByServerAndCharacter() 函数
该函数用于从指定服务器和角色获取金币数据，是实现跨角色数据分析的核心接口。

**参数要求：**
- `server` (字符串): 服务器名称，必须与SavedVariables中的键名完全匹配
- `character` (字符串): 角色名称，区分大小写
- `logmode` (可选，字符串): 日志模式，如"Session"、"Day"、"Week"等，默认为"Session"

**返回值结构：**
```lua
{
    income = 0,           -- 总收入，数值类型
    outgoing = 0,         -- 总支出，数值类型
    net = 0,              -- 净收益，数值类型（收入-支出）
    transactions = {      -- 交易记录列表，表类型
        {
            source = "Unknown",  -- 来源标识，字符串类型
            income = 0,          -- 该来源收入，数值类型
            outgoing = 0,        -- 该来源支出，数值类型
            net = 0              -- 该来源净收益，数值类型
        }
    }
}
```

当指定的角色或服务器数据不存在时，函数返回包含默认值的表，所有数值字段初始化为0。

**Section sources**
- [Core.lua](file://Core/Core.lua#L15-L2335)

### GetCurrencyInfo() 和 GetAllCurrencies() 方法
这两个方法属于CurrencyTracker模块，用于访问货币数据。

**GetCurrencyInfo() 参数要求：**
- `currencyID` (数值): 货币的唯一标识符，如1166代表"时光扭曲徽章"
- `timeframe` (可选，字符串): 时间范围，支持"Session"、"Day"、"Week"、"Month"、"Year"、"Total"等，默认为"Session"

**GetAllCurrencies() 参数要求：**
- `server` (字符串): 服务器名称
- `character` (字符串): 角色名称
- `timeframe` (可选，字符串): 时间范围，默认为"Total"

**返回值结构：**
两个方法返回相同的数据结构：
```lua
{
    income = 0,           -- 指定时间段内的总收入
    outgoing = 0,         -- 指定时间段内的总支出
    net = 0,              -- 净变化量
    lastUpdate = "Never"  -- 最后更新时间，字符串格式"dd/mm/yy"
}
```

对于`GetAllCurrencies()`，当查询"Total"时间段时，还会包含`lastUpdate`字段，显示数据最后更新的日期。

**Section sources**
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L661-L713)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1130-L1179)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L100-L150)

## 跨角色数据聚合

### 实现示例
以下示例展示如何从多个角色获取并合并金币和货币数据：

```lua
-- 获取所有角色的货币数据并进行聚合
function AggregateCurrencyData(currencyID, timeframe)
    local totalIncome = 0
    local totalOutgoing = 0
    local characters = {}
    
    -- 遍历所有服务器和角色
    for server, serverData in pairs(Accountant_ClassicSaveData) do
        for character, charData in pairs(serverData) do
            -- 获取单个角色的货币数据
            local currencyData = CurrencyTracker.Storage:GetCharacterCurrencyData(
                server, 
                character, 
                currencyID, 
                timeframe
            )
            
            if currencyData then
                totalIncome = totalIncome + currencyData.income
                totalOutgoing = totalOutgoing + currencyData.outgoing
                
                -- 存储每个角色的详细数据
                table.insert(characters, {
                    server = server,
                    character = character,
                    income = currencyData.income,
                    outgoing = currencyData.outgoing,
                    net = currencyData.net,
                    lastUpdate = currencyData.lastUpdate
                })
            end
        end
    end
    
    return {
        totalIncome = totalIncome,
        totalOutgoing = totalOutgoing,
        net = totalIncome - totalOutgoing,
        characters = characters
    }
end

-- 使用示例
local aggregated = AggregateCurrencyData(1166, "Total")
print("总货币收入:", aggregated.totalIncome)
print("总货币支出:", aggregated.totalOutgoing)
print("净收益:", aggregated.net)

for _, char in ipairs(aggregated.characters) do
    print(char.server .. "-" .. char.character .. 
          ": " .. char.net .. " (" .. char.lastUpdate .. ")")
end
```

此实现通过遍历`Accountant_ClassicSaveData`全局表，收集所有服务器和角色的数据，然后进行汇总计算。结果包含总体统计和每个角色的详细信息，便于进一步分析。

**Section sources**
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1130-L1179)
- [Core.lua](file://Core/Core.lua#L1500-L1600)

## 性能特征分析

### 时间复杂度
- **GetDataByServerAndCharacter()**: O(n)，其中n是该角色在指定时间段内的交易来源数量。函数需要遍历所有来源以计算总收入和支出。
- **GetCurrencyInfo()**: O(m)，其中m是该货币在指定时间段内的来源数量。与金币查询类似，需要遍历所有来源进行汇总。
- **GetAllCurrencies()**: O(k)，其中k是账户中所有角色的总数。函数需要检查每个角色是否存在指定货币的数据。

### 潜在性能瓶颈
1. **大规模角色数据**: 当用户拥有大量角色时，跨角色聚合操作的性能会显著下降，因为需要遍历整个`Accountant_ClassicSaveData`结构。
2. **频繁的数据访问**: 在短时间内多次调用这些API可能导致性能问题，特别是在UI更新循环中。
3. **内存占用**: 保存所有角色的完整交易历史可能导致SavedVariables文件过大，影响加载性能。

### 优化建议
- 使用`timeframe`参数限制查询范围，避免不必要的数据处理
- 对于频繁访问的数据，考虑实现客户端缓存机制
- 在非必要情况下，避免在战斗中或高频率事件中调用这些API
- 定期清理不再需要的历史数据以控制文件大小

**Section sources**
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L661-L713)
- [Core.lua](file://Core/Core.lua#L15-L2335)

## 事件时序问题与解决方案

### 问题描述
在`PLAYER_LOGIN`事件之前调用这些API可能导致以下问题：
1. **数据未初始化**: SavedVariables结构可能尚未完全加载，导致查询返回nil或错误数据
2. **角色信息不可用**: `AC_SERVER`和`AC_PLAYER`全局变量可能为空，无法确定当前角色
3. **模块未就绪**: CurrencyTracker模块可能尚未初始化，相关方法不可用

### 解决方案
```lua
-- 安全的数据访问包装器
local function SafeGetData(currencyID, timeframe)
    -- 检查必要的全局变量
    if not AC_SERVER or not AC_PLAYER then
        return nil, "服务器或角色信息不可用"
    end
    
    -- 检查SavedVariables结构
    if not Accountant_ClassicSaveData or 
       not Accountant_ClassicSaveData[AC_SERVER] or 
       not Accountant_ClassicSaveData[AC_SERVER][AC_PLAYER] then
        return nil, "数据存储未初始化"
    end
    
    -- 检查CurrencyTracker模块是否就绪
    if not CurrencyTracker or 
       not CurrencyTracker.Storage or 
       not CurrencyTracker.Storage:IsInitialized() then
        return nil, "CurrencyTracker模块未就绪"
    end
    
    -- 执行安全的数据查询
    local data = CurrencyTracker.Storage:GetCurrencyData(currencyID, timeframe)
    return data, nil
end

-- 使用延迟执行确保在正确时机调用
local function DelayedDataAccess()
    if IsLoggedIn() then
        local data, err = SafeGetData(1166, "Session")
        if data then
            -- 处理数据
            print("成功获取数据:", data.net)
        else
            print("数据获取失败:", err)
        end
    else
        -- 延迟到玩家登录后执行
        C_Timer.After(1, DelayedDataAccess)
    end
end

-- 注册事件监听器
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    DelayedDataAccess()
end)

-- 或者直接检查登录状态
if IsLoggedIn() then
    DelayedDataAccess()
end
```

通过实现安全检查和延迟执行机制，可以确保API调用在正确的时机进行，避免因时序问题导致的数据访问错误。

**Section sources**
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L661-L713)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1130-L1179)
- [Core.lua](file://Core/Core.lua#L15-L2335)

## 错误处理示例

### 处理不存在的角色或服务器数据
```lua
-- 增强的错误处理版本
local function GetSafeCurrencyData(server, character, currencyID, timeframe)
    -- 参数验证
    if not server or not character or not currencyID then
        return nil, "参数缺失: server="..tostring(server)..", character="..tostring(character)..", currencyID="..tostring(currencyID)
    end
    
    -- 检查SavedVariables是否存在
    if not Accountant_ClassicSaveData then
        return nil, "SavedVariables未加载"
    end
    
    -- 检查服务器是否存在
    if not Accountant_ClassicSaveData[server] then
        local availableServers = {}
        for s in pairs(Accountant_ClassicSaveData) do
            table.insert(availableServers, s)
        end
        return nil, string.format("服务器'%s'不存在。可用服务器: %s", 
                                 server, table.concat(availableServers, ", "))
    end
    
    -- 检查角色是否存在
    if not Accountant_ClassicSaveData[server][character] then
        local availableCharacters = {}
        for c in pairs(Accountant_ClassicSaveData[server]) do
            table.insert(availableCharacters, c)
        end
        return nil, string.format("角色'%s'在服务器'%s'上不存在。可用角色: %s", 
                                 character, server, table.concat(availableCharacters, ", "))
    end
    
    -- 检查货币数据是否存在
    local charData = Accountant_ClassicSaveData[server][character]
    if not charData.currencyData or not charData.currencyData[currencyID] then
        -- 返回默认值而不是nil，保持接口一致性
        return {
            income = 0,
            outgoing = 0,
            net = 0,
            lastUpdate = "Never"
        }, nil
    end
    
    -- 执行正常查询
    local currencyData = charData.currencyData[currencyID][timeframe or "Total"] or {}
    local totalIncome = 0
    local totalOutgoing = 0
    
    for source, data in pairs(currencyData) do
        if type(data) == "table" and data.In and data.Out then
            totalIncome = totalIncome + (data.In or 0)
            totalOutgoing = totalOutgoing + (data.Out or 0)
        end
    end
    
    local lastUpdate = "Never"
    if charData.currencyOptions and charData.currencyOptions.lastUpdate then
        lastUpdate = date("%d/%m/%y", charData.currencyOptions.lastUpdate)
    end
    
    return {
        income = totalIncome,
        outgoing = totalOutgoing,
        net = totalIncome - totalOutgoing,
        lastUpdate = lastUpdate
    }, nil
end

-- 使用示例
local data, error = GetSafeCurrencyData("MyServer", "MyCharacter", 1166, "Total")
if data then
    print(string.format("角色数据: 收入=%d, 支出=%d, 净值=%d, 更新于=%s", 
                       data.income, data.outgoing, data.net, data.lastUpdate))
else
    print("数据获取失败:", error)
end
```

此实现提供了全面的错误处理，包括参数验证、结构检查和友好的错误消息，确保API调用的健壮性。

**Section sources**
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1130-L1179)
- [Core.lua](file://Core/Core.lua#L15-L2335)