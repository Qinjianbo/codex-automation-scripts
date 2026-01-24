# Scripts README

## Overview
This folder contains Codex‑driven automation helpers for task generation, execution, and publishing.
All scripts are plain Bash and work from the repo root.

## Configuration
- Create a project‑specific config at `config.yaml` (repo root), or at `scripts/config.yaml`.
- Use `scripts/config.example.yaml` as a template.
- Key fields: `codex_node`, `codex_cli`, `git_branch`, `git_remote`, `tasks_file`, `plan_file`.

## Core Scripts

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
  Flags: `--dry-run`, `--allow-dirty`, `--full-auto`, `--skip-commit`.

## Locking
`auto-exec.sh` writes a lock file (default: `.auto-exec.lock`) to prevent concurrent runs.
Use `--force-lock` to override if you’re sure it’s stale.

## Notes
- `--full-auto` uses Codex bypass mode (no approvals/sandbox). Use with caution.
- These scripts assume a Git repo with a configurable default branch (default: `main`).
