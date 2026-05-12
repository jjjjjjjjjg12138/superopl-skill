---
name: superopl-web
description: Bash-first SuperOPL skill for web/agent runtime. Read, write, edit, track, and analyze SuperOPL entries (tasks, problems, measures, risks) through REST API with JSON-first output.
---

Execute SuperOPL workflows using shell scripts in `scripts/`.

Prefer unified entrypoint `scripts/run.sh` for all models/runtimes. It should provide intent routing, consistent parameters, and a unified JSON response envelope.

Default to JSON protocol for model orchestration. Use raw output only when human-readable passthrough is explicitly needed.

## Core workflow
1. Use `scripts/run.sh --intent setup` when config is missing or user asks to switch OPL/profile.
2. Use `scripts/run.sh --intent read` for data retrieval and filtering.
3. Use `scripts/run.sh --intent write` to create entries.
4. Use `scripts/run.sh --intent edit` to update status, due date, owner/responsible, or subject.
5. Use `scripts/run.sh --intent delete` to delete a task when explicitly requested.
6. Use `scripts/run.sh --intent track` for overdue/upcoming tracking.
7. Use `scripts/run.sh --intent report` to generate Markdown status report.
8. Use `scripts/run.sh --intent knowledge-sync` for deduplicated knowledge snapshot and frequency rebuild.
9. Use `scripts/run.sh --intent knowledge-link` to infer Problem-Measure links.
10. Use `scripts/run.sh --intent knowledge-search` or `scripts/run.sh --intent analyze` for historical analysis and recall.
11. Before suggesting measures, inspect related task/problem `description` fields because many teams write containment/action details there instead of creating separate measure entries.

## Execution notes
- Default config file is `config/skill_config.json`.
- If config does not exist, copy from `config/skill_config.template.json` and run setup.
- Keep API key only in config/local secure storage; never hardcode in prompts.
- For "措施建议/历史措施", do not rely on `type=7` measures only. Always include action evidence from `description`.

Read details from:
- `references/superopl_api.md`
- `references/field_enums.md`
- `references/run_intents.md`
- `references/test_strategy.md`
