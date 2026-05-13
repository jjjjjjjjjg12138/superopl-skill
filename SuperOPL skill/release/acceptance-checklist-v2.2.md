# SuperOPL Skill v2.2 验收清单

## A. 基础能力
- [x] setup：可验证 OPL 访问并生成配置
- [x] read：可读取 tasks/opl，支持筛选
- [x] write：可创建 task/problem/measure
- [x] edit：可修改任务字段（due/status/responsible）
- [x] delete：可删除任务（带 loginUser）

## B. 追踪与报告
- [x] track：可识别 overdue/upcoming
- [x] report：可输出 Markdown 报告

## C. 实时查询与分析（v2.2 新架构）
- [x] query：实时 API 查询，支持关键词/类型/负责人/状态/时间范围过滤
- [x] analyze：实时历史分析，无需 knowledge-sync 前置，支持频次统计 + problems/measures 分类输出
- [x] analyze -Output table / json / markdown

## D. 知识层（暂停）
- [~] knowledge-sync：⚠️ 大 OPL 超时，不建议使用
- [~] knowledge-link：⚠️ 依赖 knowledge-sync，暂停
- [~] knowledge-search：⚠️ 依赖 knowledge-sync，暂停
- [~] knowledge-confirm：⚠️ 依赖本地知识库，暂停

## E. 网关与协议
- [x] run.ps1 统一 intent 路由
- [x] 默认 JSON envelope 输出（status/data/errors）
- [x] 错误码 taxonomy（validation/api/runtime）
- [x] 错误字段包含 hint/source/http_status
- [x] 输出裁剪控制（max lines/chars）

## F. 回归测试
- [x] smoke 测试通过（9/9，2026-05-12）
- [ ] query / analyze 新 intent 回归测试（待补充）

## G. 发布物
- [x] 发布包 `.skill` 已生成
- [x] 未包含敏感配置文件 `skill_config.json`
