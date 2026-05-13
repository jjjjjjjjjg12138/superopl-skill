# SuperOPL Skill 修订计划

**版本:** v2.1-revised  
**日期:** 2026-05-13  
**背景:** 基于实际使用验证后的架构修正

---

## 1. 核心发现：knowledge-sync 不可行

### 问题描述

`opl_knowledge_sync.ps1` 在实际环境中无法完成执行：

- SuperOPL `/api/opls/{id}/tasks/` 接口**无分页**，必须一次性拉取全部数据
- 当前 OPL（322421）已有 **2206 条记录**，单次请求在公司网络环境下（代理/VPN）持续超时或挂起
- 在终端手动执行超过 10 分钟无响应，强制 Ctrl+C 才能退出
- 通过 AI agent 工具调用同样无法完成（工具超时限制）

### 根本原因

原计划 development-plan.md 第 7 条风险中已预见"SuperOPL API 无分页，大 OPL 数据量大"，应对措施为"本地缓存 + 增量同步"，但当前实现仍是全量同步，未解决初次拉取的超时问题。

### 结论

**knowledge-sync 依赖的本地知识库方案，在当前环境下不可行。** next-development-plan.md 中 WP1~WP5 的多项工作建立在 index.json 存在的前提上，需要重新评估。

---

## 2. 可行方案：实时 API 查询（方案二）

### 验证结果

今天通过直接调用 API + PowerShell 脚本过滤，成功在 30 秒内完成以下操作：

- 拉取全部 2206 条任务数据
- 定位目标 task（8733932）并提取完整字段
- 搜索关键词匹配的历史任务

关键发现：**API 响应本身不慢，问题出在 knowledge_sync 脚本对每条记录做大量本地处理和文件写入（wiki pages、chunks、entities、edges、evidence），导致整体超时。**

### 新架构方向

放弃"先全量同步到本地知识库、再检索"的模式，改为**实时 API 查询 + 轻量过滤**：

```
用户查询
   ↓
直接调用 /api/opls/{id}/tasks/
   ↓
在内存中按关键词/类型/负责人过滤
   ↓
返回结果给 agent 分析
```

优点：
- 无需本地索引，无超时风险
- 数据始终是最新的
- 对单次查询响应快（实测约 10-30 秒）

缺点：
- 每次都需要拉取全量数据（但 API 响应本身可接受）
- 不支持频次趋势等需要历史快照的分析
- 无法在无网络环境下使用

---

## 3. 修订后的功能范围

### 保留（已验证可行）

| 功能 | Intent | 状态 |
|------|--------|------|
| 配置初始化 | setup | ✅ 可用 |
| 读取/筛选任务 | read | ✅ 可用 |
| 创建条目 | write | ✅ 可用 |
| 编辑条目 | edit | ✅ 可用 |
| 删除条目 | delete | ✅ 可用 |
| Overdue/Upcoming 追踪 | track | ✅ 可用 |
| 状态报告生成 | report | ✅ 可用 |

### 重新设计（原方案不可行）

| 功能 | 原方案 | 新方案 |
|------|--------|--------|
| 历史问题检索 | knowledge-sync → 本地 index → analyze | 直接 API 拉取 → 内存过滤 → agent 分析 |
| 频次统计 | frequency.json | 实时统计（每次查询时计算） |
| 问题-措施关联 | knowledge-link 推断 | 实时查找同期 Problem+Measure 条目 |
| Wiki 知识库生成 | llm-wiki schema | 暂不实现，按需导出 Markdown |

### 暂缓/取消（next-development-plan.md 中）

- WP3 关系确认层（依赖 confirmed_links.json，前提是本地知识库存在）
- WP1 回归测试中涉及 knowledge-sync 的用例
- llm-wiki 文件化 schema（pages/chunks/entities/edges/evidence）

---

## 4. 新增开发工作包

### WP-A：实时查询脚本（优先级 P0，预计 1-2 天）

交付内容：
- 新增 `scripts/opl_query.ps1`
  - 参数：`-Keywords`、`-Type`、`-Responsible`、`-Status`、`-DaysBack`
  - 直接调用 API，在内存中过滤，返回匹配条目
  - 支持输出 JSON / table / markdown
- 更新 `run.ps1` 增加 `query` intent，映射到 opl_query.ps1
- 更新 `SKILL.md` 触发规则，覆盖"历史查询"场景

验收标准：
- 关键词查询在 60 秒内返回结果
- 无结果时返回明确提示，不报错

### WP-B：analyze intent 改造（优先级 P1，预计 1 天）

交付内容：
- 改造 `opl_analyze.ps1`，移除对 index.json 的依赖
- 改为调用 opl_query.ps1 实时拉取数据后分析
- 保留原有输出格式（table/json/markdown）

验收标准：
- `run.ps1 -Intent analyze -Query "断刀"` 无需 knowledge-sync 即可直接返回结果

---

## 5. 保留 knowledge-sync 的条件

如果未来满足以下任一条件，可重新评估知识库方案：

1. SuperOPL API 支持分页（`?page=&page_size=`）
2. OPL 数据量减少到可接受范围（< 500 条）
3. 找到在公司网络下稳定的大数据量拉取方案（如分批 + 断点续传）

在此之前，knowledge-sync / knowledge-link / knowledge-search 相关 intent 标记为**不稳定，不建议使用**。

---

## 下一步执行顺序

1. 实现 WP-A（opl_query.ps1 + run.ps1 query intent）✅ 已完成
2. 实现 WP-B（analyze 去依赖 index.json）✅ 已完成
3. 完成 next-development-plan.md 中仍然有效的 WP2（错误映射）和 WP5（发布）
4. 更新 SKILL.md 触发规则和使用说明 ✅ 已完成
