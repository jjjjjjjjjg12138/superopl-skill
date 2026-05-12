# Field Enums and Conventions

## Task Type
Use semantic strings in scripts; script converts to numeric code.
- task -> 1
- decision -> 2
- information -> 3
- review -> 4
- problem -> 6
- measure -> 7

## Task Status
- 0: open
- 1: closed

## Priority
- A, B, C, D, E

## Date Format
All date values use `YYYY-MM-DD`.

## No Deadline Convention
Because API requires `endDate`, use `2099-12-31` as placeholder for no practical deadline.
