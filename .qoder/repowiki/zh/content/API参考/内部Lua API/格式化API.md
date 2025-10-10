# 格式化API

<cite>
**本文档中引用的文件**  
- [Core.lua](file://Core/Core.lua)
- [Constants.lua](file://Core/Constants.lua)
- [MoneyFrame.lua](file://Core/MoneyFrame.lua)
- [localization.en.lua](file://Locale/localization.en.lua)
</cite>

## 目录
1. [简介](#简介)
2. [核心格式化函数](#核心格式化函数)
3. [GetFormattedValue() 函数详解](#getformattedvalue-函数详解)
4. [ShowSessionToolTip() 函数详解](#showsessiontooltip-函数详解)
5. [实际使用示例](#实际使用示例)
6. [本地化处理](#本地化处理)
7. [性能考虑与优化](#性能考虑与优化)
8. [结论](#结论)

## 简介
Accountant_Classic 是一个用于跟踪《魔兽世界》中货币收支的基础工具。本文档详细说明了 Core.lua 文件中提供的两个核心格式化函数：GetFormattedValue() 用于将金币数值格式化为可读的金/银/铜表示，以及 ShowSessionToolTip() 用于生成会话统计工具提示。这些函数在插件的用户界面中广泛使用，确保货币数据显示的准确性和可读性。

## 核心格式化函数
Accountant_Classic 插件提供了两个关键的格式化函数，用于处理和显示货币信息。这些函数位于 Core.lua 文件中，是插件数据展示层的核心组成部分。

**Section sources**
- [Core.lua](file://Core/Core.lua#L1327-L1345)
- [Core.lua](file://Core/Core.lua#L2036-L2082)

## GetFormattedValue() 函数详解
GetFormattedValue() 函数负责将一个以铜币为单位的整数金额转换为带有金、银、铜图标和适当格式的可读字符串。

### 输入参数
- **amount** (number): 以铜币为单位的总金额。这是一个非负整数，代表游戏中的货币总量。

### 格式化规则
该函数首先将总金额分解为金、银、铜三个部分：
- 1 金币 = 100 银币
- 1 银币 = 100 铜币
函数使用 `floor(amount / (100 * 100))` 计算金币数量，`floor((amount % 10000) / 100)` 计算银币数量，`amount % 100` 计算铜币数量。

### 输出格式
函数的输出是一个包含颜色代码和图标的格式化字符串：
- 如果金额包含金币，则输出格式为 "X金 Y银 Z铜"，其中 X、Y、Z 分别是金、银、铜的数量，并附带相应的游戏内图标。
- 如果金额只有银币和铜币，则输出格式为 "Y银 Z铜"。
- 如果金额只有铜币，则输出格式为 "Z铜"。
- 如果金额为零，则返回空字符串。
此外，函数会根据用户的配置 `profile.breakupnumbers` 决定是否对大数字进行分组（例如，1,000 而不是 1000）。

**Section sources**
- [Core.lua](file://Core/Core.lua#L1327-L1345)

## ShowSessionToolTip() 函数详解
ShowSessionToolTip() 函数用于生成当前会话的收支统计信息，通常显示在工具提示（Tooltip）中。

### 功能描述
该函数遍历 `AC_DATA` 表中的所有数据源（如任务、商人、拍卖行等），累加当前会话（Session）的总收入和总支出。

### 输出格式
函数返回一个格式化的多行字符串，包含以下信息：
1.  **总收入**: 使用 `GetFormattedValue()` 格式化的总收入金额。
2.  **总支出**: 使用 `GetFormattedValue()` 格式化的总支出金额。
3.  **净收益/损失**: 根据总收入和总支出的差值，显示“净收益”或“净损失”，并用绿色或红色突出显示，金额同样经过 `GetFormattedValue()` 格式化。

### 本地化处理
该函数使用 AceLocale-3.0 库进行本地化。所有显示的标签（如 "Total Incomings"、"Net Profit"）都通过 `L["key"]` 的方式从语言文件中获取，确保在不同语言环境下显示正确的文本。

**Section sources**
- [Core.lua](file://Core/Core.lua#L2036-L2082)
- [localization.en.lua](file://Locale/localization.en.lua#L0-L258)

## 实际使用示例
以下是在插件其他部分调用这些格式化功能的示例：

### 在主界面显示总金额
```lua
-- 在主框架中显示总收入
AccountantClassicFrame.TotalInValue:SetText("|cFFFFFFFF"..addon:GetFormattedValue(TotalIn))
```
此代码将总收入 `TotalIn` 格式化后显示在主界面的相应文本框中。

### 在迷你地图按钮上显示会话信息
```lua
LDB.OnTooltipShow = (function(tooltip)
    tooltip:AddLine(title);
    if (profile.showsessiononbutton == true) then
        tooltip:AddLine(addon:ShowSessionToolTip());
    end
end);
```
当用户将鼠标悬停在迷你地图按钮上时，如果启用了会话信息显示，`ShowSessionToolTip()` 的返回值会被添加到工具提示中。

### 在浮动金钱框架中显示
```lua
local function frame_OnEnter(self)
    local amoney_str = addon:ShowSessionToolTip()
    GameTooltip_SetTitle(tooltip, "|cFFFFFFFF"..L["Accountant Classic"].." - "..L["This Session"])
    GameTooltip_AddNormalLine(tooltip, amoney_str, true)
end
```
在浮动金钱框架上显示时，会话统计信息同样通过 `ShowSessionToolTip()` 生成。

**Section sources**
- [Core.lua](file://Core/Core.lua#L2045-L2055)
- [MoneyFrame.lua](file://Core/MoneyFrame.lua#L82-L83)

## 本地化处理
Accountant_Classic 插件通过 AceLocale-3.0 库实现了全面的本地化支持。

### 本地化机制
- 所有用户界面文本都存储在 `Locale` 目录下的语言文件中（如 `localization.en.lua`、`localization.cn.lua`）。
- 代码中通过 `L["key"]` 的方式引用这些文本，其中 `key` 是一个唯一的标识符。
- AceLocale-3.0 会根据客户端的语言设置自动加载对应的语言文件。

### 确保正确显示
为了确保在不同语言环境下正确显示，插件遵循了以下原则：
1.  **避免硬编码文本**: 所有显示给用户的文本都从语言文件中获取。
2.  **使用标准键名**: 语言文件中的键名（如 `["Total Incomings"]`）是标准化的，便于翻译。
3.  **格式化函数独立于语言**: `GetFormattedValue()` 函数只负责数值和图标的格式化，不包含任何语言相关的文本，因此其输出在所有语言环境下都是一致的。

**Section sources**
- [localization.en.lua](file://Locale/localization.en.lua#L0-L258)
- [Constants.lua](file://Core/Constants.lua#L0-L260)

## 性能考虑与优化
频繁调用格式化函数可能会对性能产生影响，尤其是在高频率更新的界面元素上。

### 优化建议
1.  **缓存结果**: 对于不经常变化的数值，可以缓存其格式化后的字符串，避免重复计算。例如，在 `MoneyFrame.lua` 中，`AC_MNYSTR` 变量用于缓存当前金钱的格式化字符串，只有当金钱发生变化时才重新生成。
    ```lua
    local AC_MNYSTR = nil
    local function frame_OnUpdate(self)
        local frametxt = "|cFFFFFFFF"..addon:GetFormattedValue(GetMoney())
        if (frametxt ~= AC_MNYSTR) then
            self.Text:SetText(frametxt)
            AC_MNYSTR = frametxt -- 缓存结果
        end
    end
    ```
2.  **减少调用频率**: 避免在每一帧都调用格式化函数。应使用事件驱动的方式，仅在数据发生变化时才进行格式化和更新。
3.  **避免在循环中进行复杂格式化**: 如果需要在循环中处理大量数据，应尽量简化格式化逻辑，或将格式化操作移到循环外部。

**Section sources**
- [MoneyFrame.lua](file://Core/MoneyFrame.lua#L39-L40)

## 结论
GetFormattedValue() 和 ShowSessionToolTip() 是 Accountant_Classic 插件中至关重要的格式化函数。它们不仅将原始的数值数据转换为用户友好的视觉表示，还通过集成 AceLocale-3.0 库确保了全球用户的可访问性。通过理解这些函数的工作原理和最佳实践，开发者可以有效地在自己的插件中复用这些功能，同时通过适当的缓存和事件驱动设计来优化性能。