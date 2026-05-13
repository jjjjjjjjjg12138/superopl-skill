# Unified Entrypoint `run.sh`

Use one stable command interface:

`bash scripts/run.sh --intent <intent> [params]`

## Intents

### Stable (recommended)
- setup
- read
- query — live keyword/type/responsible search, no local index needed ✅
- write
- edit
- delete
- track
- report
- analyze — live historical analysis, no knowledge-sync needed ✅

### Unstable (avoid on large OPLs)
- knowledge-sync ⚠️ — times out on OPLs with >500 tasks; API has no pagination
- knowledge-link ⚠️ — depends on knowledge-sync
- knowledge-search ⚠️ — depends on knowledge-sync
- knowledge-confirm ⚠️ — depends on local knowledge base

## Examples
Read tasks:
`bash scripts/run.sh --intent read --entity tasks --output table`

Read full payload (for `description` evidence):
`bash scripts/run.sh --intent read --entity tasks --output json --max-output-chars 50000`

Live keyword search:
`bash scripts/run.sh --intent query --query "断刀" --output table`
`bash scripts/run.sh --intent query --query "sensor" --type problem --status open`

Track overdue:
`bash scripts/run.sh --intent track --upcoming-days 7`

Live analysis (no sync needed):
`bash scripts/run.sh --intent analyze --query "sensor" --top 5 --output table`
`bash scripts/run.sh --intent analyze --query "sensor" --top 5 --output json`

## Recommendation Quality Rule
When users ask for measure suggestions, combine:
1) explicit measures (`type=7`) and links,
2) action evidence extracted from related task/problem `description`.
