# Test Strategy (Web/Bash)

## Purpose
Minimal regression coverage for `scripts/run.sh`.

## Coverage
- at least one success case for read/track/analyze
- at least one validation-error case
- at least one semantic-quality case proving `description` evidence is used for measure recommendation

## Suggested Cases
- read success
- track success
- analyze success
- analyze missing query (validation_error)
- write missing subject (validation_error)
- recommendation quality check with known historical problem sample
