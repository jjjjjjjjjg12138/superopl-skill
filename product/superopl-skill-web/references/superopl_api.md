# SuperOPL API Reference (Web/Bash)

## Base URLs
- Production: `https://rb-superopl.emea.bosch.com/api/`
- EDU/Test: `https://rb-superopl-edu.emea.bosch.com/api/`

## Authentication
Append API key as URL query parameter:
`?key=<API_KEY>`

## Verified Endpoints
- `GET /api/opls/{opl_id}/` : OPL metadata, access/team, risks
- `GET /api/opls/{opl_id}/tasks/` : all tasks (includes rich fields like `description` in payload)
- `POST /api/opls/{opl_id}/tasks/` : create task-like entry
- `PUT /api/opls/{opl_id}/tasks/{task_id}` : update task
- `DELETE /api/opls/{opl_id}/tasks/{task_id}` : delete task (body must include `loginUser`)

## Important Constraints
- `endDate` is mandatory in create payload.
- `responsible` currently supports only one user.
- `loginUser` must be a valid SuperOPL NT login.
- Data modeling caveat: many teams store actions/measures in `description` instead of dedicated `type=7` records.
