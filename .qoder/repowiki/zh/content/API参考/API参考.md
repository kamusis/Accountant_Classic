# API参考

<cite>
**本文档引用的文件**   
- [Core.lua](file://Core/Core.lua)
- [Constants.lua](file://Core/Constants.lua)
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua)
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua)
- [CurrencyConstants.lua](file://CurrencyTracker/CurrencyConstants.lua)
</cite>

## 目录
1. [Slash命令API](#slash命令api)
2. [LibDataBroker-1.0数据代理](#libdatabroker-10数据代理)
3. [LibDBIcon-1.0集成点](#libdbicon-10集成点)
4. [内部Lua API](#内部lua-api)
5. [数据访问API](#数据访问api)

## Slash命令API

### /accountant 和 /acc 命令
`/accountant` 和 `/acc` 命令用于打开Accountant Classic主界面。这些命令不接受参数，其行为是显示或隐藏主窗口。

- **语法**: `/accountant` 或 `/acc`
- **行为**: 打开Accountant Classic主窗口。如果窗口已打开，则隐藏它。

**Section sources**
- [Core.lua](file://Core/Core.lua#L1520-L1551)

### /ct 命令族
`/ct` 命令族用于与Currency Tracker模块交互，提供数据查询、调试和管理功能。

#### /ct show
显示单个货币在指定时间段的详细数据。

- **语法**: `/ct show <timeframe> [currencyid]`
- **时间段**: `this-session`, `today`, `prv-day`, `this-week`, `prv-week`, `this-month`, `prv-month`, `this-year`, `prv-year`, `total`
- **示例**: `/ct show this-week 3008`

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L100-L150)

#### /ct show-all-currencies
显示所有追踪货币在指定时间段的摘要。

- **语法**: `/ct show-all-currencies <timeframe>`
- **示例**: `/ct show-all-currencies this-session`

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L152-L200)

#### /ct meta show
检查为货币记录的原始元数据。

- **语法**: `/ct meta show <timeframe> <currencyid>`
- **示例**: `/ct meta show today 3008`

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L202-L250)

#### /ct debug
切换结构化事件日志记录。

- **语法**: `/ct debug on` 或 `/ct debug off`
- **示例**: `/ct debug on`

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L252-L300)

#### /ct status
打印内部状态。

- **语法**: `/ct status`
- **示例**: `/ct status`

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L302-L350)

#### /ct discover
管理动态发现的货币。

- **语法**: `/ct discover list`, `/ct discover track <id> [on|off]`, `/ct discover clear`
- **示例**: `/ct discover list`

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L352-L400)

#### /ct repair
修复工具，用于纠正数据或重新初始化货币存储。

- **语法**: `/ct repair init`, `/ct repair adjust <id> <delta> [source]`, `/ct repair remove <id> <amount> <source> (income|outgoing)`
- **示例**: `/ct repair init`

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L402-L450)

## LibDataBroker-1.0数据代理

LibDataBroker-1.0数据代理的实现提供了name, type, text, label等字段，这些字段被LDB显示面板消费。

- **name**: 数据代理的名称，用于标识。
- **type**: 数据类型，用于确定如何处理数据。
- **text**: 显示的文本，通常为当前货币数量。
- **label**: 标签，用于描述数据代理。

**Section sources**
- [Core.lua](file://Core/Core.lua#L220-L230)

## LibDBIcon-1.0集成点

LibDBIcon-1.0集成点包括图标注册、菜单回调和状态管理。

- **图标注册**: 使用`Register`方法注册最小地图按钮。
- **菜单回调**: 右键点击打开配置选项。
- **状态管理**: 通过`minimap.hide`配置设置控制按钮可见性。

**Section sources**
- [Core.lua](file://Core/Core.lua#L1025-L1060)

## 内部Lua API

### Core模块
Core模块提供了核心功能，包括初始化、事件处理和数据管理。

- **Initialize**: 初始化模块。
- **OnEnable**: 启用模块。
- **OnDisable**: 禁用模块。

**Section sources**
- [Core.lua](file://Core/Core.lua#L1520-L1551)

### CurrencyTracker模块
CurrencyTracker模块提供了货币追踪功能，包括初始化、启用和禁用。

- **Initialize**: 初始化CurrencyTracker模块。
- **Enable**: 启用CurrencyTracker模块。
- **Disable**: 禁用CurrencyTracker模块。

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L100-L150)

## 数据访问API

### 安全查询跨角色金币总额
通过`Accountant_ClassicSaveData`结构安全地查询跨角色金币总额。

- **方法**: 遍历`Accountant_ClassicSaveData`中的所有服务器和角色，累加`totalcash`值。
- **示例**: 
  ```lua
  local totalGold = 0
  for server, characters in pairs(Accountant_ClassicSaveData) do
    for character, data in pairs(characters) do
      totalGold = totalGold + (data.options.totalcash or 0)
    end
  end
  ```

**Section sources**
- [Core.lua](file://Core/Core.lua#L1042-L1078)