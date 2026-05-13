# SuperOPL Skill Product

这个目录用于团队发布，包含两个并行版本：

- `superopl-skill/`：Windows 版本（PowerShell，生产可用）
- `superopl-skill-web/`：Web/跨平台版本（Bash，当前为基础骨架）
- `release/`：发布产物与发布说明

## 版本定位

### 1) Windows 版本（主版本）
路径：`superopl-skill/`

适用场景：
- Windows 桌面/Agent 运行环境
- 需要完整 intent 能力（read/write/edit/delete/track/report/knowledge）

入口：
- `scripts/run.ps1`

配置模板：
- `config/skill_config.template.json`

### 2) Web 版本（Bash 版）
路径：`superopl-skill-web/`

适用场景：
- Web runtime / Linux / 容器
- 先提供统一接口骨架，逐步补齐 intents

入口：
- `scripts/run.sh`

配置模板：
- `config/skill_config.template.json`

## 团队发布建议（GitLab）

推荐把 `product/` 原样发布到团队 GitLab，并在发布说明中注明：

- Windows 版本是当前主交付版本。
- Web 版本为并行实现，当前已具备基础 read/track/analyze 路由能力与文档框架。
- 两个版本都遵循同一条分析原则：
  - 做“措施建议/历史措施”时，不能只看 `type=7`，必须联合读取 task/problem `description`。

## 发布前自检

- Windows 版本：
  - `superopl-skill/SKILL.md`
  - `superopl-skill/references/*`
  - `superopl-skill/scripts/run.ps1`
- Web 版本：
  - `superopl-skill-web/SKILL.md`
  - `superopl-skill-web/references/*`
  - `superopl-skill-web/scripts/run.sh`
- release：
  - `release/release-notes-*.md`
  - `release/acceptance-checklist-*.md`
