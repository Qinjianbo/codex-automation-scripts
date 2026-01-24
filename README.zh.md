# 脚本说明（README）
语言：中文 | English: [README.md](README.md)

## 概述
本目录包含一组基于 Codex 的自动化脚本，用于生成任务、执行任务、提交与发布。
所有脚本均为 Bash，并假定从目标仓库根目录运行。

## 配置
- 在目标仓库根目录创建 `config.yaml`，或在 `scripts/config.yaml` 创建。
- 可基于 `scripts/config.example.yaml` 复制修改。
- 关键字段：`project_name`、`codex_node`、`codex_cli`、`git_branch`、`git_remote`、`tasks_file`、`plan_file`。

## 使用方式
你可以用两种常见方式集成这些脚本：直接克隆到项目，或作为 Git submodule 引入。

### 方式一：克隆到目标仓库
此方式会把脚本作为普通文件放在你的项目中。

1) 在目标仓库根目录下，将本仓库克隆到 `scripts/`：

```bash
git clone <repo_url> scripts
```

2) 在目标仓库根目录创建配置文件：

```bash
cp scripts/config.example.yaml config.yaml
```

3) 编辑 `config.yaml`，配置 Codex Node/CLI 路径及分支/远程等。

4) 确保目标仓库根目录存在 `PLAN.md`（没有可先创建空文件）。

5) 从目标仓库根目录运行脚本：

```bash
scripts/auto-plan.sh --codex
scripts/auto-iterate.sh --codex
scripts/auto-exec.sh
scripts/auto-commit.sh
# 或执行全流程
scripts/auto-run.sh
```

### 方式二：作为 Git submodule 引入
此方式让脚本独立版本管理，可固定到某个提交。

1) 在目标仓库根目录添加 submodule：

```bash
git submodule add <repo_url> scripts
git submodule update --init --recursive
```

2) 在目标仓库根目录创建配置文件（避免直接改 submodule 内部）：

```bash
cp scripts/config.example.yaml config.yaml
```

3) 编辑 `config.yaml`，配置 Codex Node/CLI 路径及分支/远程等。

4) 确保目标仓库根目录存在 `PLAN.md`。

5) 从目标仓库根目录运行脚本：

```bash
scripts/auto-plan.sh --codex
scripts/auto-iterate.sh --codex
scripts/auto-exec.sh
scripts/auto-commit.sh
# 或执行全流程
scripts/auto-run.sh
```

## 核心脚本

- `auto-plan.sh --codex`
  基于当前上下文（已有计划/任务与 git 状态）更新 `PLAN.md`。

- `codex-run.sh`
  封装运行 Codex CLI（非 TUI 模式），使用配置中的 Node/Codex 路径。  
  示例：`scripts/codex-run.sh exec "Summarize repo status"`

- `auto-iterate.sh --codex`
  基于 `PLAN.md`、已有 `TASKS.md` 和 git 状态生成 `TASKS.md`。

- `auto-exec.sh`
  执行 `TASKS.md` 中未完成的任务并更新状态。  
  参数：`--dry-run`、`--allow-dirty`、`--full-auto`、`--force-lock`。

- `auto-commit.sh`
  使用 Codex 进行 stage/commit/push 到 `git_remote/git_branch`。  
  可选：`-m "feat: your message"`

- `auto-run.sh`
  串联 `auto-iterate` → `auto-exec` → `auto-commit`。  
  参数：`--dry-run`、`--allow-dirty`、`--full-auto`、`--skip-plan`、`--skip-commit`。

## 锁机制
`auto-exec.sh` 会写入锁文件（默认：`.auto-exec.lock`）以防并发运行。
若确定锁文件过期，可使用 `--force-lock` 强制覆盖。

## 备注
- `--full-auto` 会启用 Codex 的 bypass 模式（无审批/无沙箱），请谨慎使用。
- 脚本假定目标仓库有可配置的默认分支（默认：`main`）。
