# SuperOPL Skill Release Notes v2.2

发布日期：2026-05-13

## 版本定位
v2.2 聚焦架构修正：用实时 API 查询替代本地知识库方案，解决 knowledge-sync 在大 OPL 下不可用的问题。

---

## 背景问题（v2.1 遗留）

`knowledge-sync` 在实际使用中发现不可用：
- SuperOPL API 无分页，OPL 322421 有 2206 条记录，一次性拉取加本地文件写入持续超时
- 依赖 knowledge-sync 的 analyze / knowledge-search / knowledge-confirm 均无法使用
- 在公司网络环境（代理/VPN）下问题更为突出

---

## 本版本变更

### 新增：`query` intent / `opl_query.ps1`
- 直接调用 API，在内存中过滤，无需本地索引
- 支持参数：`-Keywords`、`-Type`、`-Responsible`、`-Owner`、`-Status`、`-DaysBack`、`-TaskId`、`-Top`
- 输出格式：table / json / markdown
- 用法：`run.ps1 -Intent query -Query "关键词"`

### 改造：`analyze` intent / `opl_analyze.ps1`
- 完全移除对 index.json / frequency.json 的依赖
- 实时拉取全量 API 数据，在内存中按关键词评分排序
- 支持频次统计（实时计算）、problems / measures / tasks 分类输出
- 保留 table / json / markdown 输出格式
- 用法：`run.ps1 -Intent analyze -Query "关键词"`（无需任何前置步骤）

### 更新：`run.ps1`
- ValidateSet 新增 `query` intent
- 新增 `query` intent 路由

### 更新：`SKILL.md` / `references/run_intents.md`
- Core workflow 移除 knowledge-sync / knowledge-confirm 推荐用法
- Intent 列表区分 Stable / Unstable
- Suggested intent mapping 更新历史查询场景为 `analyze`

---

## 暂停功能

以下功能因依赖本地知识库而暂停，待 API 支持分页或环境改善后重新评估：
- `knowledge-sync`
- `knowledge-link`
- `knowledge-search`
- `knowledge-confirm`

---

## 重要文件
- `scripts/opl_query.ps1`（新增）
- `scripts/opl_analyze.ps1`（改造）
- `scripts/run.ps1`（更新）
- `SKILL.md`（更新）
- `references/run_intents.md`（更新）

---

## 从 v2.1 升级说明
- `analyze` 行为变化：不再读取本地 index.json，每次直接调用 API，约需 10-30 秒
- `knowledge-sync` 不再需要在 analyze 前执行
- `query` 为新增 intent，可直接使用
