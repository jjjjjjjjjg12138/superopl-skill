# superopl-skill (Windows / PowerShell)

这是 SuperOPL 的 Windows 主版本。

## 目录说明

- `SKILL.md`：Skill 行为说明与 intent 工作流
- `config/`：配置模板与本地配置
- `scripts/`：PowerShell 实现（统一入口 `run.ps1`）
- `references/`：API、字段、测试策略、知识库结构说明
- `knowledge_base/`：知识构建产物目录
- `test-results/`：测试输出目录

## 快速开始

1. 复制配置模板：
   - `config/skill_config.template.json` -> `config/skill_config.json`
2. 填写：`api_key`、`opl_id`、`user_login`
3. 运行示例：

```powershell
powershell -File scripts/run.ps1 -Intent read -Protocol json -Entity tasks -Output table
powershell -File scripts/run.ps1 -Intent track -Protocol json -UpcomingDays 7
powershell -File scripts/run.ps1 -Intent analyze -Protocol json -Query "漏油" -Top 5 -Output table
```

## 关键规则

在“措施建议/历史措施”场景中，必须同时考虑：
- 显式 measure（`type=7`）
- 问题/任务 `description` 中记录的围堵、整改、验证信息
