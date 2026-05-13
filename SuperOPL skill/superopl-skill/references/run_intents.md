# Unified Entrypoint `run.ps1`

Use one stable command interface for all models:

`powershell -File scripts/run.ps1 -Intent <intent> [params]`

Protocol options:
- `-Protocol json` (default): returns unified envelope `{status,intent,timestamp,exit_code,data,errors}`
- `-Protocol raw`: passthrough legacy script output

Output control options (json mode):
- `-MaxOutputLines <int>`: cap line count in `data.output_lines` (default 120)
- `-MaxOutputChars <int>`: cap characters in `data.output_text` (default 8000)
- truncation flags: `data.truncated`, `data.line_truncated`, `data.char_truncated`

## Intents

### Stable (recommended)
- `setup` — initialize config
- `read` — structured task retrieval with filters
- `query` — live keyword/type/responsible search (no local index needed) ✅ NEW
- `write` — create task/problem/measure/etc.
- `edit` — update due date, status, responsible, subject
- `delete` — delete a task
- `track` — overdue/upcoming detection
- `report` — generate Markdown status report
- `analyze` — live historical analysis, frequency count, related problems/measures ✅ UPDATED (no knowledge-sync needed)
- `knowledge-confirm` — manually confirm/remove Problem-Measure links

### Unstable (avoid on large OPLs)
- `knowledge-sync` ⚠️ — times out on OPLs with >500 tasks; API has no pagination
- `knowledge-link` ⚠️ — depends on knowledge-sync
- `knowledge-search` ⚠️ — depends on knowledge-sync

## Examples

Read tasks:
`run.ps1 -Intent read -Entity tasks -Output table`

Live keyword search (no sync needed):
`run.ps1 -Intent query -Query "断刀" -Output table`
`run.ps1 -Intent query -Query "sensor" -Type problem -Responsible "uio1sgh"`
`run.ps1 -Intent query -Query "sensor" -Status open -Top 20 -Output json`

Create problem:
`run.ps1 -Intent write -Type problem -Subject "sensor issue" -Responsible "uio1sgh" -DueDate "2026-05-20"`

Edit due date:
`run.ps1 -Intent edit -TaskId 8761275 -DueDate 2026-05-22 -DueDateChangeReason "reschedule"`

Track upcoming/overdue:
`run.ps1 -Intent track -UpcomingDays 7`

Generate report:
`run.ps1 -Intent report -UpcomingDays 7 -RecentClosedDays 30`

Live analysis (no knowledge-sync needed):
`run.ps1 -Intent analyze -Query "sensor failure" -Top 5 -Output table`
`run.ps1 -Intent analyze -Query "sensor failure" -Top 5 -Output json`
`run.ps1 -Intent analyze -Query "sensor failure" -Top 5 -Output markdown`

Machine-friendly JSON envelope examples:
- `run.ps1 -Intent track -Protocol json`
- `run.ps1 -Intent query -Query "断刀" -Protocol json`
- `run.ps1 -Intent analyze -Query "sensor" -Protocol json`
- `run.ps1 -Intent track -Protocol json -MaxOutputChars 2000`

Error taxonomy (errors[].code):
- `validation_error`
- `api_error`
- `runtime_error`

Error object fields:
- `code`
- `message`
- `hint`
- `source`
- `http_status` (if detectable)

## Note on knowledge pipeline
`knowledge-sync` writes llm-wiki artifacts locally (pages/chunks/entities/edges/evidence/revisions).
This pipeline is **unreliable** on large OPLs due to API timeout. Use `analyze` and `query` instead for live lookup.
