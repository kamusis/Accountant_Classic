# /ct debug 命令

<cite>
**本文档中引用的文件**  
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua)
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua)
- [CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md)
</cite>

## 目录
1. [简介](#简介)
2. [/ct debug 命令实现](#ct-debug-命令实现)
3. [调试日志输出机制](#调试日志输出机制)
4. [副作用管理](#副作用管理)
5. [使用场景示例](#使用场景示例)
6. [调试状态验证](#调试状态验证)
7. [生产环境注意事项](#生产环境注意事项)

## 简介
`/ct debug` 命令是CurrencyTracker插件提供的一个调试工具，用于动态控制模块的详细日志输出。该命令通过切换全局调试标志来启用或禁用CurrencyEventHandler中的事件日志记录，帮助用户追踪货币变更事件。此功能在开发和故障排除期间非常有用，但在生产环境中应谨慎使用。

## /ct debug 命令实现
`/ct debug` 命令的实现位于 `CurrencyCore.lua` 文件中，作为主模块 `CurrencyTracker` 的一部分。该命令通过修改全局的 `DEBUG_MODE` 标志来控制调试模式的开启和关闭。

当用户输入 `/ct debug on` 时，系统会将 `CurrencyTracker.DEBUG_MODE` 设置为 `true`，并输出确认信息"CurrencyTracker debug: ON"。相反，当输入 `/ct debug off` 时，系统会将该标志设置为 `false`，并输出"CurrencyTracker debug: OFF"。

该命令的解析逻辑集成在主命令处理器中，通过正则表达式匹配 `debug` 关键字，并检查后续参数来确定用户意图。如果参数无效，系统会显示正确的使用方法和当前的调试状态。

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L937-L959)

## 调试日志输出机制
当调试模式启用时，系统会在聊天框中打印关键事件的详细信息，特别是 `CURRENCY_DISPLAY_UPDATE` 事件的触发信息、参数值和处理流程。

在 `CurrencyEventHandler.lua` 中，`OnCurrencyDisplayUpdate` 方法会在调试模式下输出事件接收的确认信息，包括原始参数和规范化后的参数。这有助于验证事件流的正确性。

`ProcessCurrencyChange` 方法在调试模式下会输出结构化的调试信息，包括：
- 原始参数：货币ID、新数量、变化量、获取来源和丢失来源
- 计算结果：旧数量、变化量和来源键
- 存储路径：数据将被写入的具体位置

这些日志信息帮助开发者理解系统如何处理货币变更事件，包括变化量的计算、来源键的确定以及数据的存储位置。

**Section sources**
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L567-L597)
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L817-L848)

## 副作用管理
`/ct debug` 命令的设计确保了调试日志不会影响正常的数据记录。调试模式仅控制日志输出，而不改变系统的实际行为或数据存储。

所有日志输出都通过 `CurrencyTracker:LogDebug` 方法进行，该方法在内部检查 `DEBUG_MODE` 标志。只有当标志为 `true` 时，日志才会被打印到聊天框中。

调试日志的输出是只读的，不会修改任何数据结构或影响事件处理流程。即使在调试模式下，系统仍然按照相同的逻辑处理货币变更事件，确保数据记录的完整性和一致性。

这种设计使得用户可以在不干扰正常功能的情况下进行调试，避免了调试工具本身引入新的问题。

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L100-L105)
- [CurrencyEventHandler.lua](file://CurrencyTracker/CurrencyEventHandler.lua#L567-L597)

## 使用场景示例
`/ct debug` 命令的一个典型使用场景是追踪特定货币的变更事件。例如，当用户怀疑某个货币的计数不准确时，可以启用调试模式来观察事件的详细处理过程。

使用步骤如下：
1. 输入 `/ct debug on` 启用调试模式
2. 执行可能触发货币变更的操作（如完成任务、交易物品等）
3. 观察聊天框中的详细日志输出
4. 分析日志以确定问题所在
5. 输入 `/ct debug off` 关闭调试模式

通过这种方式，用户可以精确地追踪特定货币（如ID为3008的货币）的变更事件，查看每次变更的触发条件、参数值和处理结果。

**Section sources**
- [CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md#L67-L75)

## 调试状态验证
用户可以结合 `/ct status` 命令来验证调试状态。`/ct status` 命令会显示系统的当前状态，包括调试模式是否启用。

`GetStatus` 方法返回一个包含 `debugMode` 字段的状态对象，该字段的值直接来自 `CurrencyTracker.DEBUG_MODE` 标志。`ShowStatus` 方法将这个状态信息格式化后输出到聊天框。

通过这种方式，用户可以确认调试模式的实际状态，确保命令执行的效果符合预期。这对于验证调试模式是否正确启用或禁用非常重要。

**Section sources**
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L107-L115)
- [CurrencyCore.lua](file://CurrencyTracker/CurrencyCore.lua#L937-L945)

## 生产环境注意事项
在生产环境中，强烈建议关闭调试模式。持续的详细日志输出会产生大量聊天信息，可能干扰用户的正常游戏体验。

此外，频繁的日志输出可能会对性能产生轻微影响，尤其是在处理大量货币变更事件时。虽然这种影响通常很小，但在资源受限的系统上可能会更加明显。

调试模式应仅在需要诊断问题时临时启用，并在问题解决后立即关闭。这有助于保持游戏界面的整洁，并确保最佳的性能表现。

**Section sources**
- [CurrencyTracker-Usage.md](file://Docs/CurrencyTracker-Usage.md#L67-L75)