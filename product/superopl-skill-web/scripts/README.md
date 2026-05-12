# superopl-web scripts

This folder is the bash-first implementation for web/runtime usage.

Planned scripts:
- `run.sh` (unified entrypoint)
- `opl_read.sh`
- `opl_write.sh`
- `opl_edit.sh`
- `opl_delete.sh`
- `opl_track.sh`
- `opl_report.sh`
- `opl_knowledge_sync.sh`
- `opl_knowledge_link.sh`
- `opl_knowledge_search.sh`
- `opl_analyze.sh`

Requirements (recommended):
- `bash`
- `curl`
- `jq`

Design principle:
When generating measure suggestions, parse not only explicit `type=7` measure records, but also action evidence written in task/problem `description` fields.
