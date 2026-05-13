# SuperOPL Skill Release Notes v2.1

发布日期：2026-05-12

## 版本定位
v2.1 聚焦“可发布可编排”：在已有功能基础上，补齐统一网关协议、错误治理、知识图谱化和质量门禁。

## 新增与增强
1. 统一网关
- 新增/增强 `scripts/run.ps1`
- 支持统一 intent 路由与 JSON 协议

2. 错误治理
- 错误码：`validation_error / api_error / runtime_error`
- 错误对象增加：`hint/source/http_status`

3. 输出控制
- 新增输出裁剪参数：`MaxOutputLines / MaxOutputChars`
- 新增截断标记：`truncated / line_truncated / char_truncated`

4. 知识图谱（llm-wiki）
- 新增 artifacts：pages/chunks/entities/edges/evidence/revisions
- 知识同步脚本已集成 schema 生成

5. 关系可靠性
- 新增 `knowledge-confirm` 人工确认层
- `analyze` 采用 confirmed 优先，inferred 回退

6. 分析输出模式
- `opl_analyze.ps1` 支持 `table/json/markdown`

7. 质量保障
- 新增 `scripts/test_smoke.ps1`
- 当前 smoke：9/9 通过

## 重要文件
- `scripts/run.ps1`
- `scripts/opl_knowledge_sync.ps1`
- `scripts/opl_knowledge_link.ps1`
- `scripts/opl_knowledge_confirm.ps1`
- `scripts/opl_analyze.ps1`
- `scripts/test_smoke.ps1`
- `references/wiki_schema.md`
- `references/test_strategy.md`

## 发布包
- `product/release/superopl-skill-v2.1.skill`
