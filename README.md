# Scripts README
Language: English | 中文请见 [README.zh.md](README.zh.md)

## Overview
This folder contains Codex‑driven automation helpers for task generation, execution, and publishing.
All scripts are plain Bash and should be run from your target repo root (or any subdirectory inside it).

## Configuration
- Create a project‑specific config at `config.yaml` (repo root), or at `<scripts_dir>/config.yaml`.
- Use `<scripts_dir>/config.example.yaml` as a template.
- Key fields: `project_name`, `codex_node`, `codex_cli`, `git_branch`, `git_remote`, `tasks_file`, `plan_file`.

## Usage
You can use these scripts in two common ways: clone into your target repo, or add as a Git submodule.
You can place the scripts in any folder; below, `<scripts_dir>` is just an example (e.g. `scripts`).

### Option A: Clone into your target repo
This keeps the scripts as normal files under your project.

1) From your target repo root, clone this repo into `<scripts_dir>`:

```bash
git clone <repo_url> <scripts_dir>
```

2) Create config in your target repo (recommended in repo root so it stays in your repo):

```bash
cp <scripts_dir>/config.example.yaml config.yaml
```

3) Edit `config.yaml` to point to your Codex Node/CLI paths and desired branch/remote.

4) Ensure your plan file exists (default: `PLAN.md`; create an empty one if needed).

5) Run scripts from the target repo root:

```bash
<scripts_dir>/auto-plan.sh --codex
<scripts_dir>/auto-iterate.sh --codex
<scripts_dir>/auto-exec.sh
<scripts_dir>/auto-commit.sh
# or run the full pipeline
<scripts_dir>/auto-run.sh
```

### Option B: Add as a Git submodule
This keeps the scripts versioned separately and pinned to a commit.

1) From your target repo root, add the submodule at `<scripts_dir>`:

```bash
git submodule add <repo_url> <scripts_dir>
git submodule update --init --recursive
```

2) Create config in your target repo root (recommended to avoid editing the submodule):

```bash
cp <scripts_dir>/config.example.yaml config.yaml
```

3) Edit `config.yaml` as needed (Codex paths, branch, remote).

4) Ensure your plan file exists in your target repo root (default: `PLAN.md`).

5) Run scripts from the target repo root:

```bash
<scripts_dir>/auto-plan.sh --codex
<scripts_dir>/auto-iterate.sh --codex
<scripts_dir>/auto-exec.sh
<scripts_dir>/auto-commit.sh
# or run the full pipeline
<scripts_dir>/auto-run.sh
```

## Core Scripts

- `auto-plan.sh --codex`  
  Updates the plan file (default: `PLAN.md`) using Codex based on current context (existing plan/tasks and git status).

- `codex-run.sh`  
  Wrapper to run Codex CLI in non‑TUI mode with the configured Node/Codex paths.  
  Example: `<scripts_dir>/codex-run.sh exec "Summarize repo status"`

- `auto-iterate.sh --codex`  
  Generates the tasks file (default: `TASKS.md`) using Codex based on the plan file, existing tasks, and git status.

- `auto-exec.sh`  
  Executes unchecked tasks from the tasks file (default: `TASKS.md`) and updates task status.  
  Flags: `--dry-run`, `--allow-dirty`, `--full-auto`.

- `auto-commit.sh`  
  Uses Codex to stage, commit, and push to `git_remote/git_branch`.  
  Optional: `-m "feat: your message"`

- `auto-run.sh`  
  Orchestrates `auto-iterate` → `auto-exec` → `auto-commit`.  
  Flags: `--dry-run`, `--allow-dirty`, `--full-auto`, `--skip-plan`, `--force-lock`, `--skip-commit`.

## Locking
`auto-run.sh` writes a lock file (default: `.auto-run.lock`) to prevent concurrent runs.
Use `--force-lock` to override if you’re sure it’s stale.

## Notes
- `--full-auto` uses Codex bypass mode (no approvals/sandbox). Use with caution.
- These scripts assume a Git repo with a configurable default branch (default: `main`).
