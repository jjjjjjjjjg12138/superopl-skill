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
2. Use `scripts/run.ps1 -Intent read` for structured data retrieval and filtering.
3. Use `scripts/run.ps1 -Intent query` for keyword/type/responsible-based live search (no local index needed).
4. Use `scripts/run.ps1 -Intent write` to create entries.
5. Use `scripts/run.ps1 -Intent edit` to update status, due date, owner/responsible, or subject.
6. Use `scripts/run.ps1 -Intent delete` to delete a task when explicitly requested.
7. Use `scripts/run.ps1 -Intent track` for overdue/upcoming tracking.
8. Use `scripts/run.ps1 -Intent report` to generate Markdown status report.
9. Use `scripts/run.ps1 -Intent analyze` for live historical analysis (frequency, related problems/measures). Does NOT require any prior sync step.

> ⚠️ `knowledge-sync`, `knowledge-link`, `knowledge-search`, `knowledge-confirm` are suspended — they depend on a local knowledge base that cannot be reliably built due to API timeout on large OPLs. Do not use or recommend these intents.

## Execution notes
- Default config file is `config/skill_config.json`.
- If config does not exist, copy from `config/skill_config.template.json` and run setup.
- Keep API key only in config/local secure storage; never hardcode in prompts.
- For cross-model portability, prefer returning:
  - concise human summary in plain text
  - optional raw JSON block when requested
  - Markdown report path when report is generated
- **knowledge-sync is unreliable on large OPLs (>500 tasks) due to API timeout. Prefer `query` and `analyze` for live lookup.**

## Suggested intent mapping
- "读取/看看OPL" -> `run.ps1 -Intent read`
- "搜索关键词/找某个问题" -> `run.ps1 -Intent query -Query "关键词"`
- "帮我建一个task/problem/measure" -> `run.ps1 -Intent write`
- "改截止日期/关闭任务" -> `run.ps1 -Intent edit`
- "删除任务" -> `run.ps1 -Intent delete`
- "有哪些overdue" -> `run.ps1 -Intent track`
- "生成周报/状态报告" -> `run.ps1 -Intent report`
- "以前是否发生过/频次/以前措施是什么/帮我分析这个问题" -> `run.ps1 -Intent analyze -Query "关键词"`

Read details from:
- `references/superopl_api.md`
- `references/field_enums.md`
- `references/run_intents.md`
- `references/wiki_schema.md`
- `references/test_strategy.md`
