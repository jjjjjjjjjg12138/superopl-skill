# SuperOPL API Reference (Practical)

## Base URLs
- Production: `https://rb-superopl.emea.bosch.com/api/`
- EDU/Test: `https://rb-superopl-edu.emea.bosch.com/api/`

## Authentication
Append API key as URL query parameter:
`?key=<API_KEY>`

## Verified Endpoints
- `GET /api/opls/{opl_id}/` : OPL metadata, access/team, risks
- `GET /api/opls/{opl_id}/tasks/` : all tasks (includes rich fields like `description` in raw payload)
- `POST /api/opls/{opl_id}/tasks/` : create task-like entry
- `PUT /api/opls/{opl_id}/tasks/{task_id}` : update task
- `DELETE /api/opls/{opl_id}/tasks/{task_id}` : delete task (request body must include `loginUser`)

## Important Constraints
- `endDate` is mandatory in create payload.
- `responsible` currently supports only one user.
- `loginUser` must be a valid SuperOPL NT login.
- Team member management is not available via API.
- `DELETE /tasks/{task_id}` must include `loginUser` in request body.
- Data modeling caveat: in many real OPLs, concrete actions/measures are documented in task/problem `description` instead of dedicated `type=7` records. Analysis and recommendation logic should read `description` to avoid under-reporting measures.

## Type Enum
- 1 = Task
- 2 = Decision
- 3 = Information
- 4 = Review
- 6 = Problem
- 7 = Measure

## Status Enum (tasks)
- 0 = Open
- 1 = Closed

## Reminder State (observed)
- 1 = OK
- 2 = Upcoming
- 3 = Overdue
