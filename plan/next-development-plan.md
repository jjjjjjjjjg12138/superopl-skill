# SuperOPL Skill 下一步开发计划（基于当前实现进度）

**版本:** v2.0-next  
**日期:** 2026-05-12  

## 1. 计划回顾结论（对原 development-plan.md 的 review）

原计划 Phase 1~4 的主体目标已基本完成，并且实际交付已经超过原计划：

- 已完成：读写改删、追踪、报告、知识同步、检索、问题-措施关联
- 已超出：
  - 统一入口 `run.ps1`（intent router）
  - 统一 JSON 协议（状态、错误、输出）
  - 错误码 taxonomy（validation/api/runtime）
  - 输出裁剪（max lines/chars）
  - llm-wiki 文件化 schema（pages/chunks/entities/edges/evidence/revisions）

因此下一步重点不再是“功能从0到1”，而是进入 **稳定性、质量、可运维、可发布** 阶段。

---

## 2. 下一阶段目标（v2.1）

1. **稳定性工程化**：建立最小回归测试和错误映射，避免后续迭代破坏链路。  
2. **知识可靠性提升**：引入人工确认关系层，降低推断关联误判。  
3. **输出可消费性提升**：分析结果支持 Markdown/JSON 双输出，方便 Agent 二次处理和知识沉淀。  
4. **发布交付闭环**：完成打包、验收清单和版本发布说明。

---

## 3. v2.1 工作包与里程碑

### WP1：回归测试与质量门禁（优先级 P0，预计 1-2 天）

交付内容：
- 新增 `scripts/test_smoke.ps1`（最小回归）
- 覆盖每个 intent 至少 1 个成功用例 + 1 个失败用例（参数校验类）
- 产出 `product/superopl-skill/test-results/smoke-<date>.json`

验收标准：
- 所有 P0 用例通过
- 失败用例返回统一错误结构，且 code 正确

### WP2：错误映射增强（优先级 P0，预计 0.5-1 天）

交付内容：
- 在 `run.ps1` 增加 API 错误细分（示例：401/403/406/5xx）
- 统一 errors 字段扩展：`code`, `message`, `hint`, `source`

验收标准：
- 常见 API 失败场景可返回可读 hint（例如 key 无效、loginUser 无效）

### WP3：关系确认层（优先级 P1，预计 1-2 天）

交付内容：
- 新增 `knowledge_base/wiki/confirmed_links.json`
- 新增脚本：`scripts/opl_knowledge_confirm.ps1`
  - 支持确认/撤销 Problem-Measure 关系
- `opl_analyze.ps1` 优先读取 confirmed links，再回退推断 links

验收标准：
- 同一 query 下，确认关系优先展示
- 推断关系仍可作为候选保留

### WP4：分析输出模式升级（优先级 P1，预计 1 天）

交付内容：
- `opl_analyze.ps1` 增加 `-Output json|table|markdown`
- `run.ps1` 透传并在 JSON envelope 中稳定承载 `parsed_json`

验收标准：
- `-Output markdown` 可直接写入 wiki
- `-Output json` 可被多模型编排稳定消费

### WP5：发布与交付（优先级 P0，预计 0.5 天）

交付内容：
- 打包 skill（最终发布包）
- 生成验收清单（功能、接口、错误、回归）
- 版本说明：v2.1 release notes

验收标准：
- 可复制到新环境，按一份文档完成 setup 和 smoke test

---

## 4. 风险与应对（下一阶段）

- 关系确认流程增加人工操作成本  
  应对：仅对高价值问题做确认，其他保留推断。

- API 响应字段波动影响脚本稳定  
  应对：继续集中在 `common.ps1` 做字段归一，避免分散改动。

- 输出裁剪导致信息丢失  
  应对：在 envelope 中保留截断标记，并支持调大阈值。

---

## 5. 下一步执行顺序（建议）

先做 WP1（回归）+ WP2（错误映射），再做 WP3（确认层）+ WP4（输出模式），最后 WP5（发布）。

这样可以先稳住底盘，再提升分析可信度和交付体验。
