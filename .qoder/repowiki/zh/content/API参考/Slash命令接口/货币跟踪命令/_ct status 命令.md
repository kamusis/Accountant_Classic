# /ct status 命令

<cite>
**本文档中引用的文件**  
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua)
- [CurrencyConstants.lua](file://CurrencyTracker/CurrencyConstants.lua)
</cite>

## 目录
1. [简介](#简介)
2. [信息收集机制](#信息收集机制)
3. [状态报告格式化](#状态报告格式化)
4. [诊断价值](#诊断价值)
5. [输出示例与解释](#输出示例与解释)
6. [结论](#结论)

## 简介
`/ct status` 命令是 Accountant Classic 插件中 CurrencyTracker 模块提供的一个诊断工具，用于显示模块的内部运行状态。该命令通过聚合多个核心组件的状态信息，为用户提供一个简洁的系统健康状况概览。此文档详细说明了该命令的信息收集机制、数据聚合方式、格式化输出以及其在问题诊断中的价值。

## 信息收集机制

`/ct status` 命令通过调用 `CurrencyTracker:GetStatus()` 方法来聚合模块的内部运行状态。该方法从多个子模块中收集关键信息，包括模块的启用状态、初始化状态、版本信息和调试模式状态。

状态信息的来源包括：
- **启用状态 (IsEnabled)**: 通过 `CurrencyTracker:IsEnabled()` 方法获取，该方法返回一个布尔值，指示模块当前是否处于启用状态。
- **初始化状态 (IsInitialized)**: 通过 `CurrencyTracker:IsInitialized()` 方法获取，该方法返回一个布尔值，指示模块是否已成功初始化。
- **当前 WoW 客户端版本**: 通过 `CurrencyDataManager:GetCurrentWoWVersion()` 方法获取。该方法首先尝试从 `CurrencyConstants.VersionUtils.GetCurrentWoWVersion()` 获取版本信息，如果失败则使用 WoW API `GetBuildInfo()` 作为后备方案。版本号被转换为一个可比较的数字（例如，11.0.0 转换为 110000）。
- **货币发现总数**: 通过 `CurrencyDataManager:GetAvailableCurrencies()` 方法获取。该方法调用 `CurrencyStorage:GetAvailableCurrencies()` 来检索已记录货币交易的所有货币 ID 列表，并返回其数量。
- **数据存储版本号**: 从 `CurrencyStorage` 模块的 `CURRENCY_VERSION` 常量获取，该常量定义了当前数据结构的版本（例如 "3.00.00"）。
- **事件监听器注册情况**: 通过检查 `CurrencyTracker.EventHandler` 模块的存在和状态来间接确定。在 `GetStatus()` 的返回值中，如果 UI 控制器存在，其状态也会被包含。

这些信息的收集是通过模块间的协调完成的。`CurrencyCore` 作为主控模块，持有对 `DataManager`、`Storage` 等子模块的引用，并在需要时调用它们的公共接口来获取实时数据。

**本节来源**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L937-L950)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L216-L250)
- [CurrencyDataManager.lua](file://CurrencyTracker/CurrencyDataManager.lua#L92-L110)
- [CurrencyStorage.lua](file://CurrencyTracker/CurrencyStorage.lua#L100-L105)

## 状态报告格式化

`/ct status` 命令将收集到的原始数据格式化为一个简洁、易读的状态报告。格式化过程在 `CurrencyTracker:ShowStatus()` 方法中实现。

该方法首先调用 `GetStatus()` 获取一个包含所有状态信息的 Lua 表。然后，它使用 `print()` 函数将这些信息逐行输出到游戏聊天窗口。输出格式如下：
- 以 `=== CurrencyTracker Status ===` 开头，作为报告的标题。
- 每个状态项以 `键: 值` 的形式打印，例如 `isInitialized: true`。
- 对于布尔值，直接输出 `true` 或 `false`。
- 对于字符串和数字，直接输出其值。
- 对于表（table）类型的值，输出 `[table]` 以避免冗长的输出。
- 以 `=== End Status ===` 结尾，作为报告的结束标记。

这种格式化方式确保了报告的清晰性和一致性，使用户能够快速扫描并理解模块的当前状态。

**本节来源**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L937-L950)

## 诊断价值

`/ct status` 命令作为一个强大的诊断工具，在用户报告问题时具有极高的价值。它帮助开发者和高级用户快速判断环境配置和模块的健康状况，从而加速问题排查过程。

其诊断价值体现在以下几个方面：
- **快速健康检查**: 用户可以通过一个简单的命令立即了解模块是否已正确初始化和启用。如果 `isInitialized` 或 `isEnabled` 为 `false`，则表明模块存在严重问题。
- **版本兼容性验证**: 报告中的 `version` 和 `debugMode` 字段可以帮助开发者确认用户运行的插件版本，这对于复现和修复特定版本的问题至关重要。
- **环境配置确认**: `GetCurrentWoWVersion()` 返回的客户端版本号可以用来验证模块是否在预期的 WoW 版本下运行，这对于处理版本特定的兼容性问题非常有用。
- **数据完整性初步判断**: 虽然报告不直接显示数据，但 `currenciesTracked` 的数量（如果包含在状态中）可以提供一个关于数据存储是否正常的初步印象。一个异常低或为零的数值可能表明数据存储初始化失败或数据丢失。
- **调试模式状态**: `debugMode` 字段的值可以指导用户是否需要开启调试日志来获取更详细的信息，这对于追踪难以复现的错误非常有帮助。

总而言之，`/ct status` 命令提供了一个“仪表盘”式的视图，使支持人员能够从宏观上快速评估模块的运行状况，而无需深入分析日志文件或代码。

## 输出示例与解释

以下是 `/ct status` 命令的典型输出示例：

```
=== CurrencyTracker Status ===
isInitialized: true
isEnabled: true
version: 1.0.0
debugMode: false
=== End Status ===
```

每个状态项的含义及其潜在的异常指示如下：

- **`isInitialized: true`**
  - **含义**: 模块已成功完成初始化流程，所有子模块（如存储、数据管理器）都已准备就绪。
  - **异常指示**: 如果为 `false`，表示模块初始化失败。这可能是由于 SavedVariables 结构损坏、依赖的库（如 Ace3）缺失或加载顺序问题导致的。这是最严重的错误之一，通常意味着模块无法正常工作。

- **`isEnabled: true`**
  - **含义**: 模块当前处于启用状态，正在监听事件并记录货币变化。
  - **异常指示**: 如果为 `false`，表示模块被手动禁用或在启用过程中失败。用户应检查是否执行了 `/ct disable` 命令，或者查看是否有错误阻止了 `Enable()` 方法的执行。

- **`version: 1.0.0`**
  - **含义**: 当前加载的 CurrencyTracker 模块的版本号。
  - **异常指示**: 这个值本身很少异常，但将其与预期版本进行比较可以确认用户是否运行了正确的插件版本。如果用户报告问题但运行的是旧版本，这可能就是问题的根源。

- **`debugMode: false`**
  - **含义**: 调试模式当前处于关闭状态，不会输出详细的调试信息。
  - **异常指示**: 如果用户需要提供更详细的日志，支持人员可能会要求他们通过 `/ct debug on` 命令开启此模式。在正常情况下，此值为 `false` 是正常的。

通过分析这些状态项，用户和开发者可以快速定位问题的根源，例如，一个 `isInitialized: false` 和 `isEnabled: false` 的组合明确指向了初始化阶段的严重故障。

## 结论
`/ct status` 命令是 Accountant Classic 插件中一个简单而强大的诊断工具。它通过精心设计的信息收集机制，聚合了模块的核心运行状态，并将其格式化为易于理解的报告。该命令在用户支持和问题排查中扮演着关键角色，能够帮助开发者和用户快速评估模块的健康状况，验证环境配置，并为更深入的故障排除提供起点。其简洁的输出和明确的语义使其成为日常维护和问题诊断的必备命令。