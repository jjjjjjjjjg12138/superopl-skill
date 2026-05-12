# SuperOPL Skill 开发方案与计划

**版本:** v1.0  
**日期:** 2026-05-11  
**作者:** Jia GUO  

---

## 1. 项目目标

构建一个 AI Agent Skill，使 agent 能够与 SuperOPL 系统深度集成，实现三大核心能力：

1. **读写 OPL** — 通过自然语言指令读取和创建/编辑 OPL 条目（Task、Problem、Measure 等）
2. **自动追踪 OPL** — 主动检测 overdue / upcoming 任务，生成状态报告，提醒用户需要关注的条目
3. **知识沉淀与检索** — 将历史 OPL 数据结构化存储为本地知识库，支持问题回溯（历史发生频次、已采取措施、相关经验）

最终目标：agent 成为用户的 OPL 助手，不仅被动执行指令，还能主动提供洞察和历史经验参考。

---

## 2. 功能架构

```
┌─────────────────────────────────────────────────────┐
│                   SuperOPL Skill                     │
├──────────┬──────────────┬───────────────────────────┤
│  Layer 1 │  Layer 2     │  Layer 3                  │
│  读写层   │  追踪层       │  知识层                    │
├──────────┼──────────────┼───────────────────────────┤
│ 读取OPL  │ Overdue检测   │ 历史问题索引               │
│ 创建条目  │ 状态汇总报告  │ 问题频次统计               │
│ 编辑条目  │ 趋势分析      │ 措施关联查询               │
│ 删除条目  │ 变更追踪      │ Wiki/Markdown知识库生成    │
└──────────┴──────────────┴───────────────────────────┘
         ↕                          ↕
   SuperOPL REST API         本地知识库 (JSON/MD)
```

---

## 3. 详细功能设计

### 3.1 Layer 1 — 读写层（基础能力）

这一层是所有功能的基础，直接对接 SuperOPL API。

**读取功能：**
- 读取指定 OPL 的所有 tasks、risks
- 按条件筛选：按状态（open/closed）、按责任人、按类型（Task/Problem/Measure）、按时间范围
- 读取单条 task 的详细信息

**写入功能：**
- 通过自然语言描述创建新条目，agent 自动填充 API 所需字段
- 智能默认值：loginUser 自动填充、endDate 未指定时询问用户、type 根据描述自动判断
- 编辑现有条目：修改 due date、更换 responsible、关闭任务、添加 information to

**交互设计：**
- 用户说"帮我看看OPL上有什么overdue的" → agent 调用读取 + 筛选
- 用户说"帮我建一个task，主题是xxx，负责人是xxx" → agent 调用创建
- 用户说"把那个task的due date改到下周五" → agent 调用编辑

### 3.2 Layer 2 — 追踪层（主动能力）

这一层让 agent 具备主动提醒和分析能力。

**Overdue 检测与提醒：**
- 扫描所有 open tasks，识别 overdue（已过期）和 upcoming（7天内到期）
- 输出分级提醒（红色 overdue / 橙色 upcoming）
- 按 responsible 分组汇总，方便用户了解团队情况

**状态报告生成：**
- 生成标准 Markdown 报告，包含 summary 统计、overdue 列表、upcoming 列表、risk 列表
- 支持输出到指定路径（如 Obsidian vault）
- 报告模板见初始方案中的 opl_report.py 设计

**趋势分析：**
- 对比多次报告，识别趋势（overdue 数量是否在增加、哪些 task 长期未关闭）
- 识别"僵尸任务"：open 状态超过 N 天且无变更的 task

### 3.3 Layer 3 — 知识层（智能能力）

这一层是核心差异化功能，将 OPL 数据转化为可检索的知识库。

**知识库结构：**

```
knowledge_base/
├── index.json              # 所有问题的索引（ID、主题、类型、标签、日期）
├── problems/               # 按问题分类存储
│   ├── membrane_perforation.md
│   └── sensor_failure.md
├── measures/               # 措施库
│   ├── by_problem.json     # 问题→措施映射
│   └── effectiveness.json  # 措施有效性记录
├── statistics/             # 统计数据
│   └── frequency.json      # 问题发生频次
└── reports/                # 历史报告存档
    └── 2026-05-11.md
```

**知识沉淀流程：**

1. 定期（或手动触发）从 SuperOPL 拉取所有条目
2. 对 Problem 和 Measure 类型条目进行关联分析（同一问题的 Problem → Measure 链）
3. 提取关键信息写入结构化 JSON（问题名称、发生次数、每次的措施、措施效果）
4. 生成可读的 Markdown wiki 页面

**智能检索场景：**

- 用户说"以前有没有出现过膜片穿孔的问题" → agent 搜索知识库 index，返回历史记录
- 用户说"这个问题以前怎么解决的" → agent 查找 measures/by_problem.json，列出历史措施
- 用户说"最近最频繁的问题是什么" → agent 查询 frequency.json，返回 Top N
- 用户说"帮我分析一下这个问题" → agent 综合历史频次、措施、效果给出分析建议

---

## 4. 技术实现方案

### 4.1 Skill 文件结构

```
superopl/
├── SKILL.md                        # Skill 描述与触发规则
├── scripts/
│   ├── opl_setup.ps1               # 前置信息收集（API Key、OPL ID、用户身份）
│   ├── opl_read.ps1                # 读取 OPL 数据
│   ├── opl_write.ps1               # 创建条目
│   ├── opl_edit.ps1                # 编辑条目
│   ├── opl_track.ps1               # Overdue 检测 + 状态追踪
│   ├── opl_report.ps1              # 生成 Markdown 报告
│   ├── opl_knowledge_sync.ps1      # 同步数据到知识库
│   └── opl_knowledge_search.ps1    # 检索知识库
├── references/
│   ├── superopl_api.md             # API 文档（endpoints、字段、示例）
│   └── field_enums.md              # 枚举值参考（type、status、prio 等）
├── config/
│   └── skill_config.json           # 存储 API Key、OPL ID、user login（首次设置后持久化）
└── knowledge_base/                 # 本地知识库（自动生成和维护）
    ├── index.json
    ├── problems/
    ├── measures/
    ├── statistics/
    └── reports/
```

### 4.2 脚本语言选择

使用 **PowerShell** 作为脚本语言（Windows 环境原生支持，无需额外依赖），通过 `Invoke-RestMethod` 调用 SuperOPL API。对于知识库的 JSON 处理，PowerShell 原生支持即可满足。

### 4.3 配置持久化

首次使用时收集的三个前置信息（API Key、OPL ID、User Login）存储在 `config/skill_config.json` 中，后续使用时自动加载，无需重复输入。支持多个 OPL 的配置切换。

```json
{
  "profiles": {
    "default": {
      "api_key": "MjI3MzUx...",
      "opl_id": "427539",
      "user_login": "uio1sgh",
      "user_name": "Jia GUO",
      "base_url": "https://rb-superopl.emea.bosch.com"
    }
  },
  "active_profile": "default",
  "knowledge_base_path": "./knowledge_base"
}
```

### 4.4 知识库同步机制

每次执行读取或报告生成时，自动将新数据增量同步到知识库。同步逻辑：

1. 拉取当前所有 tasks
2. 与 index.json 对比，识别新增/变更/关闭的条目
3. 对新增的 Problem 类型条目，创建对应 wiki 页面
4. 更新 frequency.json 中的统计数据
5. 对新关闭的 Problem-Measure 对，更新 measures/by_problem.json

---

## 5. SKILL.md 触发规则设计

```
name: superopl
description: >
  读取、创建、编辑和追踪 SuperOPL 系统中的 OPL 条目（Tasks、Problems、Measures、Risks）。
  自动检测 overdue 和 upcoming 任务并生成状态报告。
  维护本地知识库，支持历史问题检索、频次分析和措施回溯。
  触发关键词：OPL、SuperOPL、task tracking、问题追踪、overdue、
  帮我建一个task、OPL状态、以前有没有出现过、问题频次、措施是什么。
```

---

## 6. 开发计划与里程碑

### Phase 1 — 基础读写（Week 1-2）

| 任务 | 交付物 | 预计工时 |
|------|--------|----------|
| 搭建 skill 目录结构 | superopl/ 完整目录 | 0.5h |
| 编写 references/superopl_api.md | API 参考文档 | 1h |
| 实现 opl_setup.ps1 | 配置收集与验证脚本 | 2h |
| 实现 opl_read.ps1 | 读取脚本（支持筛选） | 3h |
| 实现 opl_write.ps1 | 创建条目脚本 | 2h |
| 实现 opl_edit.ps1 | 编辑条目脚本 | 2h |
| 编写 SKILL.md | Skill 描述文件 | 1h |
| 集成测试（OPL 427539） | 测试报告 | 2h |

**Phase 1 完成标准：** agent 能通过自然语言指令完成 OPL 条目的增删改查。

### Phase 2 — 自动追踪（Week 3）

| 任务 | 交付物 | 预计工时 |
|------|--------|----------|
| 实现 opl_track.ps1 | Overdue/upcoming 检测脚本 | 3h |
| 实现 opl_report.ps1 | Markdown 报告生成脚本 | 3h |
| 报告模板优化 | 标准报告模板 | 1h |
| 集成测试 | 测试报告 | 1h |

**Phase 2 完成标准：** agent 能主动报告 overdue 任务，生成标准状态报告。

### Phase 3 — 知识沉淀（Week 4-5）

| 任务 | 交付物 | 预计工时 |
|------|--------|----------|
| 设计知识库 schema | index.json / frequency.json 结构定义 | 2h |
| 实现 opl_knowledge_sync.ps1 | 数据同步脚本 | 4h |
| 实现 opl_knowledge_search.ps1 | 知识检索脚本 | 3h |
| Problem-Measure 关联分析逻辑 | 关联映射算法 | 3h |
| Wiki 页面自动生成 | Markdown wiki 模板 + 生成逻辑 | 2h |
| 端到端测试 | 完整场景测试 | 2h |

**Phase 3 完成标准：** agent 能根据历史数据回答"以前有没有出现过类似问题"、"措施是什么"、"发生了几次"。

### Phase 4 — 优化与扩展（Week 6）

| 任务 | 交付物 | 预计工时 |
|------|--------|----------|
| 多 OPL 支持 | 配置切换功能 | 2h |
| 报告输出到 Obsidian vault | 路径配置 + 自动归档 | 1h |
| 错误处理与 edge case 完善 | 健壮性提升 | 2h |
| 使用文档编写 | 用户手册 | 1h |
| 打包发布 | 最终 skill 包 | 1h |

---

## 7. 风险与限制

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| API Key 过期或权限变更 | 所有功能不可用 | setup 脚本增加 key 有效性检查，失败时提示用户更新 |
| SuperOPL API 无分页，大 OPL 数据量大 | 响应慢 | 本地缓存 + 增量同步，避免每次全量拉取 |
| Team 成员管理不支持 API | 无法自动添加成员 | 提示用户在网页端操作，skill 只做读取 |
| Problem-Measure 无显式关联字段 | 知识库关联可能不准确 | 通过主题关键词 + 时间窗口进行模糊关联，支持用户手动修正 |
| 知识库依赖本地文件 | 换机器后数据丢失 | 存储路径可配置，建议放在 OneDrive 同步目录下 |

---

## 8. 使用场景示例

**场景 1 — 日常检查：**
> 用户：帮我看看OPL上有什么需要注意的
> Agent：[调用 opl_track.ps1] 当前有3个overdue任务和2个本周到期的任务...

**场景 2 — 创建条目：**
> 用户：帮我建一个Problem，主题是"L1092传感器误报警"，负责人是Cai PEI，下周五之前解决
> Agent：[调用 opl_write.ps1] 已创建 Problem T-8761xxx，负责人 Cai PEI，Due date 2026-05-16

**场景 3 — 问题回溯：**
> 用户：以前有没有出现过传感器相关的问题？
> Agent：[检索知识库] 历史上出现过3次传感器相关问题：(1) 2025-11 传感器误报警，措施是更换供应商批次；(2) 2026-01 传感器信号漂移，措施是增加校准频率...

**场景 4 — 生成报告：**
> 用户：帮我生成一份OPL状态报告
> Agent：[调用 opl_report.ps1] 报告已生成并保存到 xxx/reports/2026-05-11.md

---

## 9. 总结

本 skill 分三层递进实现：基础读写 → 自动追踪 → 知识沉淀。Phase 1-2 约3周可交付可用版本，Phase 3 的知识库是核心差异化能力，预计5周内完成全部开发。整体工时约 40 小时。
