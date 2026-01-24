# Scripts README
Language: English | 中文请见 [README.zh.md](README.zh.md)

## Overview
This folder contains Codex‑driven automation helpers for task generation, execution, and publishing.
All scripts are plain Bash and work from the repo root.

## Configuration
- Create a project‑specific config at `config.yaml` (repo root), or at `scripts/config.yaml`.
- Use `scripts/config.example.yaml` as a template.
- Key fields: `project_name`, `codex_node`, `codex_cli`, `git_branch`, `git_remote`, `tasks_file`, `plan_file`.

## Usage
You can use these scripts in two common ways: clone into your target repo, or add as a Git submodule.

### Option A: Clone into your target repo
This keeps the scripts as normal files under your project.

1) From your target repo root, clone this repo into `scripts/`:

```bash
git clone <repo_url> scripts
```

2) Create config in your target repo (recommended in repo root so it stays in your repo):

```bash
cp scripts/config.example.yaml config.yaml
```

3) Edit `config.yaml` to point to your Codex Node/CLI paths and desired branch/remote.

4) Ensure your target repo has `PLAN.md` (create an empty one if needed).

5) Run scripts from the target repo root:

```bash
scripts/auto-plan.sh --codex
scripts/auto-iterate.sh --codex
scripts/auto-exec.sh
scripts/auto-commit.sh
# or run the full pipeline
scripts/auto-run.sh
```

### Option B: Add as a Git submodule
This keeps the scripts versioned separately and pinned to a commit.

1) From your target repo root, add the submodule at `scripts/`:

```bash
git submodule add <repo_url> scripts
git submodule update --init --recursive
```

2) Create config in your target repo root (recommended to avoid editing the submodule):

```bash
cp scripts/config.example.yaml config.yaml
```

3) Edit `config.yaml` as needed (Codex paths, branch, remote).

4) Ensure `PLAN.md` exists in your target repo root.

5) Run scripts from the target repo root:

```bash
scripts/auto-plan.sh --codex
scripts/auto-iterate.sh --codex
scripts/auto-exec.sh
scripts/auto-commit.sh
# or run the full pipeline
scripts/auto-run.sh
```

## Core Scripts

- `auto-plan.sh --codex`  
  Updates `PLAN.md` using Codex based on current context (existing plan/tasks and git status).

- `codex-run.sh`  
  Wrapper to run Codex CLI in non‑TUI mode with the configured Node/Codex paths.  
  Example: `scripts/codex-run.sh exec "Summarize repo status"`

- `auto-iterate.sh --codex`  
  Generates `TASKS.md` using Codex based on `PLAN.md`, existing tasks, and git status.

- `auto-exec.sh`  
  Executes unchecked tasks from `TASKS.md` and updates task status.  
  Flags: `--dry-run`, `--allow-dirty`, `--full-auto`, `--force-lock`.

- `auto-commit.sh`  
  Uses Codex to stage, commit, and push to `git_remote/git_branch`.  
  Optional: `-m "feat: your message"`

- `auto-run.sh`  
  Orchestrates `auto-iterate` → `auto-exec` → `auto-commit`.  
  Flags: `--dry-run`, `--allow-dirty`, `--full-auto`, `--skip-plan`, `--skip-commit`.

## Locking
`auto-exec.sh` writes a lock file (default: `.auto-exec.lock`) to prevent concurrent runs.
Use `--force-lock` to override if you’re sure it’s stale.

## Notes
- `--full-auto` uses Codex bypass mode (no approvals/sandbox). Use with caution.
- These scripts assume a Git repo with a configurable default branch (default: `main`).
