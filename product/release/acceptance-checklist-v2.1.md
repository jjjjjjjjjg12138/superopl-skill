# SuperOPL Skill v2.1 验收清单

## A. 基础能力
- [x] setup：可验证 OPL 访问并生成配置
- [x] read：可读取 tasks/opl，支持筛选
- [x] write：可创建 task/problem/measure
- [x] edit：可修改任务字段（due/status/responsible）
- [x] delete：可删除任务（带 loginUser）

## B. 追踪与报告
- [x] track：可识别 overdue/upcoming
- [x] report：可输出 Markdown 报告

## C. 知识层
- [x] knowledge-sync：可同步 legacy + llm-wiki artifacts
- [x] knowledge-link：可推断 problem-measure 关系
- [x] knowledge-search：可按关键词检索
- [x] knowledge-confirm：可 add/remove/list 人工确认关系
- [x] analyze：confirmed 优先，inferred 回退

## D. 网关与协议
- [x] run.ps1 统一 intent 路由
- [x] 默认 JSON envelope 输出（status/data/errors）
- [x] 错误码 taxonomy（validation/api/runtime）
- [x] 错误字段包含 hint/source/http_status
- [x] 输出裁剪控制（max lines/chars）

## E. 输出模式
- [x] analyze -Output table
- [x] analyze -Output json
- [x] analyze -Output markdown

## F. 回归测试
- [x] smoke 测试通过（9/9）
- [x] 最新报告：`product/superopl-skill/test-results/smoke-20260512-133844.json`

## G. 发布物
- [x] 发布包 `.skill` 已生成
- [x] 路径：`product/release/superopl-skill-v2.1.skill`
- [x] 未包含敏感配置文件 `skill_config.json`
