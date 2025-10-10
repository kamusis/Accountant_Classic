# 内部Lua API

<cite>
**本文档中引用的文件**  
- [Core.lua](file://Core/Core.lua)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua)
</cite>

## 目录
1. [简介](#简介)
2. [核心API方法](#核心api方法)
3. [货币数据访问API](#货币数据访问api)
4. [跨角色数据聚合API](#跨角色数据聚合api)
5. [线程安全与调用时机](#线程安全与调用时机)
6. [错误处理机制](#错误处理机制)
7. [插件实例引用示例](#插件实例引用示例)

## 简介
Accountant Classic为其他插件提供了一套安全的Lua API接口，允许外部插件访问金币和货币数据。本文档详细说明了这些公共接口的使用方法、参数类型、返回值格式和使用注意事项。

**Section sources**
- [Core.lua](file://Core/Core.lua#L1-L50)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1-L50)

## 核心API方法

### GetFormattedValue()
格式化金币显示值。

**函数签名**
```lua
function addon:GetFormattedValue(amount)
```

**参数说明**
- `amount` (number): 以铜币为单位的金额

**返回值**
- (string): 格式化后的金币字符串，包含金、银、铜图标

**使用示例**
```lua
local formatted = Accountant_Classic:GetFormattedValue(12345)
-- 返回 "1g 23s 45c" 格式的带图标的字符串
```

**Section sources**
- [Core.lua](file://Core/Core.lua#L1327-L1350)

### ShowSessionToolTip()
生成会话统计工具提示。

**函数签名**
```lua
function addon:ShowSessionToolTip()
```

**参数说明**
- 无参数

**返回值**
- 无返回值，直接在界面上显示工具提示

**使用示例**
```lua
Accountant_Classic:ShowSessionToolTip()
-- 在鼠标位置显示当前会话的金币收支统计
```

**Section sources**
- [Core.lua](file://Core/Core.lua#L2036-L2050)

### GetDataByServerAndCharacter()
查询特定角色的数据。

**函数签名**
```lua
function addon:GetDataByServerAndCharacter(server, character, logmode, logtype)
```

**参数说明**
- `server` (string): 服务器名称
- `character` (string): 角色名称
- `logmode` (string): 日志模式
- `logtype` (string): 日志类型

**返回值**
- (table): 包含角色数据的表格，包含收支信息

**使用示例**
```lua
local data = Accountant_Classic:GetDataByServerAndCharacter("服务器名", "角色名", "SESSION", "INCOME")
```

**Section sources**
- [Core.lua](file://Core/Core.lua#L691-L722)

## 货币数据访问API

### GetCurrencyInfo()
获取货币信息。

**函数签名**
```lua
function DataManager:GetCurrencyInfo(currencyID)
```

**参数说明**
- `currencyID` (number): 货币ID

**返回值**
- (table): 包含货币信息的表格，结构如下：
  - `id` (number): 货币ID
  - `name` (string): 货币名称（已本地化）
  - `icon` (number): 图标文件ID
  - `expansion` (string): 所属资料片
  - `patch` (string): 引入的补丁版本

**使用示例**
```lua
local info = Accountant_Classic.DataManager:GetCurrencyInfo(1166)
-- 获取时光徽章的信息
```

**Section sources**
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L268-L320)

### GetAllCurrencies()
获取所有货币信息。

**函数签名**
```lua
function DataManager:GetAllCurrencies()
```

**参数说明**
- 无参数

**返回值**
- (table): 包含所有货币信息的表格，键为货币ID，值为货币信息表格

**使用示例**
```lua
local allCurrencies = Accountant_Classic.DataManager:GetAllCurrencies()
for id, info in pairs(allCurrencies) do
    print(id, info.name)
end
```

**Section sources**
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L322-L393)

## 跨角色数据聚合API

### GetCharacterCurrencyData()
获取特定角色的货币数据用于跨角色显示。

**函数签名**
```lua
function Storage:GetCharacterCurrencyData(server, character, currencyID, timeframe)
```

**参数说明**
- `server` (string): 服务器名称
- `character` (string): 角色名称
- `currencyID` (number): 货币ID
- `timeframe` (string): 时间范围，默认为"Total"

**返回值**
- (table): 包含角色货币数据的表格，结构如下：
  - `income` (number): 总收入
  - `outgoing` (number): 总支出
  - `net` (number): 净收益
  - `lastUpdate` (string): 最后更新时间

**使用示例**
```lua
local data = Accountant_Classic.CurrencyTracker.Storage:GetCharacterCurrencyData(
    "服务器名", "角色名", 1166, "Total"
)
```

**性能注意事项**
- 该API用于"所有角色"视图，可能涉及大量数据查询
- 建议缓存结果以避免频繁调用
- 在角色选择器中使用时，应限制同时查询的角色数量

**Section sources**
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1130-L1179)

## 线程安全与调用时机

### 线程安全性
Accountant Classic的API是线程安全的，所有数据访问都通过受保护的SavedVariables进行。

### 调用时机限制
- 大多数API需要在`PLAYER_LOGIN`事件之后才能安全调用
- 在`PLAYER_LOGIN`之前调用可能导致数据不完整或返回nil
- 建议在插件的`PLAYER_LOGIN`事件处理程序中初始化对Accountant Classic的引用

**推荐的调用流程**
1. 监听`PLAYER_LOGIN`事件
2. 在事件处理程序中获取Accountant Classic实例
3. 调用所需API方法

**Section sources**
- [Core.lua](file://Core/Core.lua#L1-L50)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1-L50)

## 错误处理机制

### 参数验证
所有公共API方法都会验证输入参数：
- 无效参数将导致方法静默返回或返回默认值
- 必需参数缺失时返回nil
- 类型错误的参数可能导致不可预测的结果

### 数据完整性检查
- API会检查SavedVariables结构的完整性
- 缺失的数据结构会自动初始化
- 旧版本数据会自动迁移

### 异常处理
- 使用pcall保护对WoW API的调用
- 错误信息会记录到聊天框和控制台
- 关键操作失败时会返回false

**Section sources**
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L523-L547)

## 插件实例引用示例

### 正确引用Accountant Classic实例
```lua
-- 方法1: 直接引用全局变量
local accountant = Accountant_Classic
if accountant then
    local formatted = accountant:GetFormattedValue(10000)
end

-- 方法2: 使用LibStub获取实例
local accountant = LibStub("AceAddon-3.0"):GetAddon("Accountant_Classic", true)
if accountant then
    accountant:ShowSessionToolTip()
end

-- 方法3: 安全的条件引用
if Accountant_Classic and Accountant_Classic.DataManager then
    local info = Accountant_Classic.DataManager:GetCurrencyInfo(1166)
end
```

### 完整使用示例
```lua
-- 创建一个监听PLAYER_LOGIN的插件
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceEvent-3.0")

function MyAddon:OnInitialize()
    -- 注册PLAYER_LOGIN事件
    self:RegisterEvent("PLAYER_LOGIN")
end

function MyAddon:PLAYER_LOGIN()
    -- 确保Accountant Classic已加载
    if Accountant_Classic then
        -- 获取当前角色的金币数据
        local gold = GetMoney()
        local formatted = Accountant_Classic:GetFormattedValue(gold)
        
        -- 显示货币信息
        if Accountant_Classic.DataManager then
            local info = Accountant_Classic.DataManager:GetCurrencyInfo(1166)
            print("时光徽章:", info.name)
        end
    end
end
```

**Section sources**
- [Core.lua](file://Core/Core.lua#L1-L50)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L1-L50)