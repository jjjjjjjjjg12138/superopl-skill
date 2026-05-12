# Unified Entrypoint `run.sh`

Use one stable command interface:

`bash scripts/run.sh --intent <intent> [params]`

## Intents
- setup
- read
- write
- edit
- delete
- track
- report
- knowledge-sync
- knowledge-link
- knowledge-search
- knowledge-confirm
- analyze

## Examples
Read tasks:
`bash scripts/run.sh --intent read --entity tasks --output table`

Read full payload (for `description` evidence):
`bash scripts/run.sh --intent read --entity tasks --output json --max-output-chars 50000`

Track overdue:
`bash scripts/run.sh --intent track --upcoming-days 7`

Analyze:
`bash scripts/run.sh --intent analyze --query "sensor" --top 5 --output table`

## Recommendation Quality Rule
When users ask for measure suggestions, combine:
1) explicit measures (`type=7`) and links,
2) action evidence extracted from related task/problem `description`.
