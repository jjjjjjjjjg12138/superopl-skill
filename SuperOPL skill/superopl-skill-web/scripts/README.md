# superopl-skill-web scripts

Bash 实现目录（Web/跨平台）。

## 当前已实现

- `run.sh`（统一入口，已支持基础路由）
- `common.sh`（通用函数）

## 规划中的拆分脚本

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

## 运行依赖（建议）

- `bash`
- `curl`
- `python3`（当前 run.sh 用于 JSON 处理）
- `jq`（后续脚本推荐）

## 设计原则

做措施建议时，既要解析显式 `type=7` measure，也要从 task/problem `description` 中抽取动作证据。
