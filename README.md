# Scripts README
Language: English | 中文请见 [README.zh.md](README.zh.md)

## Overview
This folder contains Codex‑driven automation helpers for task generation, execution, and publishing.
All scripts are plain Bash and should be run from your target repo root (or any subdirectory inside it).

## Configuration
- Create a project‑specific config at `config.yaml` (repo root), or at `<scripts_dir>/config.yaml`.
- Use `<scripts_dir>/config.example.yaml` as a template.
- Key fields: `project_name`, `codex_node`, `codex_cli`, `git_branch`, `git_remote`, `tasks_file`, `plan_file`, `plan_context_files`, `codex_language`.
- Model selection (optional):
- `codex_model_default`: fallback model for all steps when step‑specific values are empty.
- `codex_model_iterate`, `codex_model_plan`, `codex_model_exec`, `codex_model_commit`: override the model per step (task generation, plan refresh, task execution, commit). Leave blank to inherit the default or CLI’s own default.

### GUI Config Editor
- Run without packaging: `python3 tools/config_gui.py` (requires `pip install -r requirements-gui.txt`).
- One-click app (PyInstaller): `tools/build_config_gui.sh` → output in `dist/`.
- Features: load/save `config.yaml`, backup on save, path pickers, sandbox/model dropdowns, and a quick `codex-run.sh --help` test.

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

5) Run from the target repo root:

```bash
# Refresh or adjust the plan when scope changes
<scripts_dir>/auto-plan.sh --codex

# Then run the task pipeline (iterate → execute → commit)
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

5) Run from the target repo root:

```bash
# Refresh or adjust the plan when scope changes
<scripts_dir>/auto-plan.sh --codex

# Then run the task pipeline (iterate → execute → commit)
<scripts_dir>/auto-run.sh
```

## Recommended Workflow

- Plan first: run `auto-plan.sh --codex` to draft, review, and finalize `PLAN.md` before execution. A clear plan sets the high-level frame and keeps downstream tasks aligned.
- Ship via auto-run: run `auto-run.sh` to generate tasks, execute them, and commit/push. It assumes the plan is already up to date.
- Language: set `codex_language` in `config.yaml` (e.g., `English`, `简体中文`). Headings stay as specified (`# Plan`, `# Tasks (Auto-generated)`) while body text follows your language.

## Core Scripts

- `auto-plan.sh --codex`  
  Updates the plan file (default: `PLAN.md`) using Codex based on current context (existing plan/tasks, git status, and summaries of `plan_context_files`).

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
  Orchestrates `auto-iterate` → `auto-exec` → `auto-commit` (plan is managed separately).  
  Flags: `--dry-run`, `--allow-dirty`, `--full-auto`, `--force-lock`, `--skip-commit`.

## Locking
`auto-run.sh` writes a lock file (default: `.auto-run.lock`) to prevent concurrent runs.
Use `--force-lock` to override if you’re sure it’s stale.

## Notes
- `--full-auto` uses Codex bypass mode (no approvals/sandbox). Use with caution.
- These scripts assume a Git repo with a configurable default branch (default: `main`).
