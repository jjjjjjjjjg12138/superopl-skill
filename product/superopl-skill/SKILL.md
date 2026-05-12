---
name: superopl
description: Read, write, edit, track, and analyze SuperOPL entries (tasks, problems, measures, risks) through REST API. Use when users ask to read OPL status, create or update OPL items, detect overdue/upcoming tasks, generate OPL tracking reports, or search historical OPL knowledge (frequency, past measures, similar incidents) for troubleshooting.
---

Execute SuperOPL workflows using the PowerShell scripts in `scripts/`.

Prefer unified entrypoint `scripts/run.ps1` for all models. It provides intent routing, consistent parameters, and a unified JSON response protocol across LLM vendors.

Default to `-Protocol json` for model orchestration. Use `-Protocol raw` only when human-readable passthrough output is explicitly needed.

Keep behavior model-agnostic so the skill can be reused by different LLM agents: rely on deterministic scripts, explicit parameters, and JSON/Markdown outputs.

## Core workflow
1. Use `scripts/run.ps1 -Intent setup` when config is missing or user asks to switch OPL/profile.
2. Use `scripts/run.ps1 -Intent read` for data retrieval and filtering.
3. Use `scripts/run.ps1 -Intent write` to create entries.
4. Use `scripts/run.ps1 -Intent edit` to update status, due date, owner/responsible, or subject.
5. Use `scripts/run.ps1 -Intent delete` to delete a task when explicitly requested.
6. Use `scripts/run.ps1 -Intent track` for overdue/upcoming tracking.
7. Use `scripts/run.ps1 -Intent report` to generate Markdown status report.
8. Use `scripts/run.ps1 -Intent knowledge-sync` for deduplicated knowledge snapshot and frequency rebuild.
9. Use `scripts/run.ps1 -Intent knowledge-link` to infer Problem-Measure links.
10. Use `scripts/run.ps1 -Intent knowledge-search` or `scripts/run.ps1 -Intent analyze` for historical analysis and recall (frequency + related measures + evidence trace).
11. Keep llm-wiki artifacts updated via `knowledge-sync` and `knowledge-link` (pages/chunks/entities/edges/evidence/revisions).

## Execution notes
- Default config file is `config/skill_config.json`.
- If config does not exist, copy from `config/skill_config.template.json` and run setup.
- Keep API key only in config/local secure storage; never hardcode in prompts.
- For cross-model portability, prefer returning:
  - concise human summary in plain text
  - optional raw JSON block when requested
  - Markdown report path when report is generated

## Suggested intent mapping
- "读取/看看OPL" -> `run.ps1 -Intent read`
- "帮我建一个task/problem/measure" -> `run.ps1 -Intent write`
- "改截止日期/关闭任务" -> `run.ps1 -Intent edit`
- "删除任务" -> `run.ps1 -Intent delete`
- "有哪些overdue" -> `run.ps1 -Intent track`
- "生成周报/状态报告" -> `run.ps1 -Intent report`
- "以前是否发生过/频次" -> `run.ps1 -Intent knowledge-sync` + `run.ps1 -Intent knowledge-search`
- "以前措施是什么/帮我分析这个问题" -> `run.ps1 -Intent knowledge-sync` + `run.ps1 -Intent knowledge-link` + `run.ps1 -Intent analyze`

Read details from:
- `references/superopl_api.md`
- `references/field_enums.md`
- `references/run_intents.md`
- `references/wiki_schema.md`
- `references/test_strategy.md`
