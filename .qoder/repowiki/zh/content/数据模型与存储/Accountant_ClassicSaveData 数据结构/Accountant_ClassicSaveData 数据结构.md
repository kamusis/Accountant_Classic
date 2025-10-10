# Accountant_ClassicSaveData 数据结构

<cite>
**本文档中引用的文件**  
- [Core.lua](file://Core/Core.lua)
- [Constants.lua](file://Core/Constants.lua)
</cite>

## 目录
1. [简介](#简介)
2. [数据结构层级](#数据结构层级)
3. [核心表结构](#核心表结构)
4. [数据初始化流程](#数据初始化流程)
5. [示例数据](#示例数据)
6. [跨角色数据聚合](#跨角色数据聚合)

## 简介
Accountant_ClassicSaveData 是 Accountant Classic 插件用于存储玩家金币收支记录的核心数据结构。该结构采用三层嵌套设计，以服务器→角色→数据的方式组织信息，支持按不同时间窗口和交易类型进行分类统计。本文档详细说明其结构设计、初始化机制和实际应用。

**Section sources**
- [Core.lua](file://Core/Core.lua#L265-L310)
- [Constants.lua](file://Core/Constants.lua#L1-L260)

## 数据结构层级
Accountant_ClassicSaveData 采用三层层级架构：

1. **第一层 - 服务器**：以服务器名称作为顶级键，区分不同服务器的数据
2. **第二层 - 角色**：在每个服务器下，以角色名称作为二级键，存储该角色的独立数据
3. **第三层 - 数据**：包含 options 和 data 两个核心表，分别存储配置信息和收支记录

这种设计允许插件在同一个账号下管理多个服务器、多个角色的财务数据，同时保持数据隔离和查询效率。

**Section sources**
- [Core.lua](file://Core/Core.lua#L270-L277)
- [Core.lua](file://Core/Core.lua#L436-L489)

## 核心表结构
### data 表
data 表存储具体的收支记录，按 Constants.logtypes 和 Constants.logmodes 进行双重分类：

- **Constants.logtypes**：交易类型，包括 MERCH（商人）、REPAIRS（修理）、QUEST（任务）等
- **Constants.logmodes**：时间窗口，包括 Session（会话）、Day（天）、Week（周）、Month（月）、Year（年）、Total（总计）等

每个 logtype 在每个 logmode 下都有独立的收支记录，结构为 {In = 0, Out = 0}。

### options 表
options 表存储配置信息和元数据：

- **版本信息**：version 字段记录数据结构版本
- **日期信息**：date、weekdate、month、curryear 等字段记录当前日期状态
- **角色元数据**：faction（阵营）、class（职业）字段记录角色基本信息
- **财务统计**：totalcash 字段记录角色总金币数
- **初始化状态**：primed 字段标记是否已完成基线初始化

**Section sources**
- [Core.lua](file://Core/Core.lua#L277-L282)
- [Constants.lua](file://Core/Constants.lua#L30-L32)
- [Constants.lua](file://Core/Constants.lua#L50-L52)
- [Core.lua](file://Core/Core.lua#L102-L118)

## 数据初始化流程
数据初始化通过 Core.lua 中的 InitializeData 函数（实际为 initOptions 函数）实现，流程如下：

1. **检查数据结构**：确保 Accountant_ClassicSaveData 存在，若不存在则创建空表
2. **初始化服务器层**：确保当前服务器的数据容器存在
3. **初始化角色层**：为当前角色创建数据容器，包含 options 和 data 两个子表
4. **填充默认值**：使用 AccountantClassicDefaultOptions 填充 options 表的默认值
5. **更新选项**：调用 AccountantClassic_UpdateOptions 确保所有必要字段都存在
6. **初始化日志**：调用 AccountantClassic_InitZoneDB 初始化 data 表结构

该流程采用"一次性基线初始化"策略，通过 primed 标志避免首次会话的余额被误计为收入，确保数据准确性。

**Section sources**
- [Core.lua](file://Core/Core.lua#L265-L310)
- [Core.lua](file://Core/Core.lua#L1013-L1049)
- [Core.lua](file://Core/Core.lua#L200-L218)

## 示例数据
以下是 Accountant_ClassicSaveData 的 JSON 格式示例：

```json
{
  "MyServer": {
    "MyCharacter": {
      "options": {
        "version": "2.20",
        "date": "01/01/23",
        "lastsessiondate": "01/01/23",
        "weekdate": "",
        "month": "01",
        "weekstart": 1,
        "curryear": "2023",
        "totalcash": 50000,
        "faction": "Alliance",
        "class": "Mage",
        "primed": true
      },
      "data": {
        "TRAIN": {
          "Session": {"In": 0, "Out": 100},
          "Day": {"In": 0, "Out": 500},
          "Total": {"In": 0, "Out": 5000}
        },
        "MERCH": {
          "Session": {"In": 200, "Out": 50},
          "Day": {"In": 1000, "Out": 300},
          "Total": {"In": 10000, "Out": 4000}
        }
      }
    }
  }
}
```

**Section sources**
- [Core.lua](file://Core/Core.lua#L277-L282)
- [Core.lua](file://Core/Core.lua#L102-L118)

## 跨角色数据聚合
该数据结构支持跨角色数据聚合，主要通过以下方式实现：

1. **服务器遍历**：遍历 Accountant_ClassicSaveData 中的所有服务器键
2. **角色遍历**：在每个服务器下遍历所有角色键
3. **数据累加**：将符合条件的角色的收支数据进行累加

聚合时可按服务器（cross_server 选项）和阵营（faction 过滤）进行筛选。例如，在"All Chars"标签页中，插件会遍历所有服务器和角色，计算总金币数（totalcash）和总收入/支出，实现全局财务概览。

**Section sources**
- [Core.lua](file://Core/Core.lua#L1768-L1787)
- [Core.lua](file://Core/Core.lua#L1652-L1675)
- [Core.lua](file://Core/Core.lua#L607-L642)