# superopl-skill-web

Bash/web-oriented variant of SuperOPL skill.

## Quick start
1. Copy `config/skill_config.template.json` to `config/skill_config.json`
2. Fill in `api_key`, `opl_id`, `user_login`
3. Run examples:

```bash
bash scripts/run.sh --intent read --entity tasks
bash scripts/run.sh --intent track
bash scripts/run.sh --intent analyze --query "漏油"
```

## Note
Measure recommendation must include evidence from task/problem `description`.
