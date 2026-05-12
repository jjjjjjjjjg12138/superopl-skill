# Test Strategy (Smoke)

Script: `scripts/test_smoke.ps1`

## Purpose
Provide minimal regression coverage for unified gateway `run.ps1`.

## Coverage
For key intents, include:
- at least one success case
- at least one validation-error case

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

## Output
Writes JSON report to:
`test-results/smoke-YYYYMMDD-HHMMSS.json`

Fields:
- generated_at
- total/passed/failed
- per-case result with status/error_code

## Usage
`powershell -File scripts/test_smoke.ps1`
