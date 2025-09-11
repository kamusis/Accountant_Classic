# Currency Tracker Implementation Check

以下为设计与实现对照检查（不含第 7 节测试）。

| 检查项 | 状态 | 对应代码行 |
|---|---|---|
| 4.1 模块加载变更（禁用 UI 初始化/启用） | 已完成 | `CurrencyTracker/CurrencyCore.lua` (第47-55行、85-92行) |
| 4.2 XML 文件更新（在 XML 中禁用 UI 脚本） | 已完成 | `CurrencyTracker/CurrencyTracker.xml` (第9-12行) |
| 4.3 事件处理优化（注册 CURRENCY_DISPLAY_UPDATE 与 BAG_UPDATE） | 已完成 | `CurrencyTracker/CurrencyEventHandler.lua` (第77-106行) |
| 4.4 事件处理实现（完整载荷消费、计算变更与来源编码、登录/变更前滚动） | 已完成 | 事件分发与载荷标准化：`CurrencyTracker/CurrencyEventHandler.lua` (第122-141行、184-189行)；现代事件入口：同文件 (第183-199行)；变更处理/来源编码/前置滚动：同文件 (第203-214行、215-270行)；旧版回退：同文件 (第190-200行、285-301行) |
| 4.5 斜杠命令实现（/ct 主入口与分支） | 已完成 | `CurrencyTracker/CurrencyCore.lua` (第216-245行、430-455行) |
| 5.1 In-Game Commands（展示指定/全部货币数据） | 已完成 | 命令解析：`CurrencyTracker/CurrencyCore.lua` (第262-306行)；展示数据（单一货币）：同文件 (第308-336行)；打印单一货币：同文件 (第338-397行)；打印全部货币：同文件 (第399-428行) |
| 5.6 In-Game Debug Mode（/ct debug on|off + 事件结构化输出） | 已完成 | DEBUG 开关与命令：`CurrencyTracker/CurrencyCore.lua` (第169行、226-239行、430-455行)；调试日志辅助：同文件 (第160-165行)；结构化调试输出：`CurrencyTracker/CurrencyEventHandler.lua` (第243-259行) |
| 周起始日一致性（与金币记录逻辑同等的滚动） | 已完成 | 周起始滚动实现：`CurrencyTracker/CurrencyStorage.lua` (第26-133行)；初始化阶段一次性滚动：同文件 (第96-104行；101-103行调用)；登录时滚动：`CurrencyTracker/CurrencyEventHandler.lua` (第151-160行)；记录前滚动：同文件 (第210-213行) |
| /etrace 表格载荷兼容（首参为 table 的情况） | 已完成 | `CurrencyTracker/CurrencyEventHandler.lua` (第184-189行) |
| 数据模型保持不变（period->sourceKey->{In,Out}） | 已完成 | 记录交易：`CurrencyTracker/CurrencyStorage.lua` (第176-216行)；读取汇总：同文件 (第218-270行)；货币列举：同文件 (第272-291行) |
| 来源代码到可读标签的映射（显示时解析） | 已完成 | `CurrencyTracker/CurrencyConstants.lua` (约第339-346行，`SourceCodeTokens`) |
| 向后兼容与旧版回退（BAG_UPDATE） | 已完成 | `CurrencyTracker/CurrencyEventHandler.lua` (第190-200行、285-301行) |


![20250911222755](https://s2.loli.net/2025/09/11/OYhmQlptZaMHLJx.png)
