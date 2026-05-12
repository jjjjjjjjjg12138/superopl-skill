# Test Strategy (Smoke)

Script: `scripts/test_smoke.ps1`

## Purpose
Provide minimal regression coverage for unified gateway `run.ps1`.

## Coverage
For key intents, include:
- at least one success case
- at least one validation-error case
- at least one semantic-quality check for measure recommendations: verify that extracted action evidence from task/problem `description` is considered alongside explicit `type=7` measures

Current cases:
- read success
- track success
- knowledge-sync success
- knowledge-confirm list success
- analyze success
- analyze missing query (validation_error)
- knowledge-confirm add missing ids (validation_error)
- write missing subject (validation_error)
- delete missing taskid (validation_error)
- recommendation quality check: for a known historical problem sample, confirm the pipeline can surface action clues from `description` even when explicit `type=7` measure count is low

## Output
Writes JSON report to:
`test-results/smoke-YYYYMMDD-HHMMSS.json`

Fields:
- generated_at
- total/passed/failed
- per-case result with status/error_code

## Usage
`powershell -File scripts/test_smoke.ps1`
