# superopl-skill-web (Web / Bash)

这是 SuperOPL 的 Web/跨平台版本（Bash-first）。

## 当前状态

- 已提供统一入口：`scripts/run.sh`
- 已具备基础 intents：`read` / `track` / `analyze`
- 其他 intents 处于扩展中（文档与结构已就位）

## 目录说明

- `SKILL.md`：Skill 行为说明（Web 版本）
- `config/`：配置模板
- `scripts/`：Bash 脚本（统一入口 `run.sh`）
- `references/`：API、字段、intent、测试策略文档

## 快速开始

1. 复制配置模板：
   - `config/skill_config.template.json` -> `config/skill_config.json`
2. 填写：`api_key`、`opl_id`、`user_login`
3. 运行示例：

```bash
bash scripts/run.sh --intent read --entity tasks
bash scripts/run.sh --intent track
bash scripts/run.sh --intent analyze --query "漏油"
```

## 关键规则

措施建议必须结合 task/problem `description`，不能只依赖显式 `type=7` measure 记录。
