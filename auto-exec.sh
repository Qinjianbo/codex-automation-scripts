#!/usr/bin/env bash
set -euo pipefail

# Run Codex to implement tasks from TASKS_FILE.
# Usage:
#   auto-exec.sh                # requires clean git status
#   auto-exec.sh --allow-dirty  # allow dirty working tree
#   auto-exec.sh --dry-run      # ask Codex to only propose a plan (no edits)
#   auto-exec.sh --sandbox <mode>  # set codex sandbox (default: workspace-write)
#   auto-exec.sh --full-auto      # no prompts; bypass approvals/sandbox (dangerous)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
load_config

log() { echo "[$(date -Iseconds)] $*"; }
log_err() { echo "[$(date -Iseconds)] $*" >&2; }

ALLOW_DIRTY="false"
DRY_RUN="false"
SANDBOX_MODE="$DEFAULT_SANDBOX"
FULL_AUTO="false"
LANG_NOTE="Use $CODEX_LANGUAGE for all responses."
MODEL_ARGS=()
if [[ -n "${CODEX_MODEL_EXEC:-}" ]]; then
  MODEL_ARGS+=(--model "$CODEX_MODEL_EXEC")
elif [[ -n "${CODEX_MODEL_DEFAULT:-}" ]]; then
  MODEL_ARGS+=(--model "$CODEX_MODEL_DEFAULT")
fi

for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY="true" ;;
    --dry-run) DRY_RUN="true" ;;
    --sandbox)
      shift
      SANDBOX_MODE="${1:-workspace-write}"
      ;;
    --full-auto)
      FULL_AUTO="true"
      ;;
    *) log_err "Unknown option: $arg"; exit 1 ;;
  esac
done

cd "$ROOT_DIR"

if [[ ! -f "$TASKS_FILE" ]]; then
  log_err "Missing tasks file: $TASKS_FILE. Run \"$SCRIPT_DIR/auto-iterate.sh\" --codex first."
  exit 1
fi

if [[ "$ALLOW_DIRTY" == "false" ]]; then
  if git status --porcelain | grep -q .; then
    log_err "Working tree is not clean. Commit/stash or re-run with --allow-dirty."
    exit 1
  fi
fi

TASKS_CONTENT="$(cat "$TASKS_FILE")"

PROMPT=$(cat <<EOF
You are a coding agent working inside this repo. Implement the unchecked tasks from $TASKS_FILE.
$LANG_NOTE

Rules:
- Make small, safe changes only; avoid refactors.
- Keep EN/ZH pages consistent when updating content or logic.
- Prefer editing existing files; avoid new dependencies.
- Update CHANGELOG.md if user-visible behavior changes.
- Report what you changed and any manual checks.
- After completing tasks, update $PLAN_FILE PROGRESS ONLY (do not rewrite plan content):
  - Only edit progress marker lines inside the block delimited by:
    <!-- AUTO-PROGRESS:START --> and <!-- AUTO-PROGRESS:END --> (if present).
  - Allowed edits inside the block: change ONLY the status token at the start of a line:
    [TODO] -> [DOING] / [DONE] / [BLOCKED].
  - Outside the block, do not change anything in $PLAN_FILE except optionally updating a single existing
    "Last updated: YYYY-MM-DD" line near the top (do not add a new one if missing).
  - Do not add/reorder/remove plan sections, objectives, scope, or milestone text; do not append dated plan versions.
  - If the progress block is missing (or you are unsure how to map completed tasks to progress lines), leave $PLAN_FILE untouched
    and mention it in your report.
- After completing tasks, update $TASKS_FILE by checking off items you completed.

If --dry-run is enabled, produce a plan only and do not edit files.
EOF
)

if [[ "$DRY_RUN" == "true" ]]; then
  PROMPT="${PROMPT}"$'\n\nDRY RUN: Provide a concise plan only. Do not edit files.'
fi

PROMPT="${PROMPT}"$'\n\n'"$TASKS_FILE"$':\n'"$TASKS_CONTENT"

if [[ "$FULL_AUTO" == "true" ]]; then
  "$SCRIPT_DIR/codex-run.sh" "${MODEL_ARGS[@]}" --dangerously-bypass-approvals-and-sandbox exec "$PROMPT"
else
  "$SCRIPT_DIR/codex-run.sh" "${MODEL_ARGS[@]}" --sandbox "$SANDBOX_MODE" --ask-for-approval on-request exec "$PROMPT"
fi

if [[ ! -f "$LOG_FILE" ]]; then
  cat > "$LOG_FILE" <<EOF
# Iteration Log

EOF
fi

DATE_STR="$(date +%Y-%m-%d)"
TIMESTAMP="$(date -Iseconds)"
cat >> "$LOG_FILE" <<EOF
## $DATE_STR
- [$TIMESTAMP] Ran auto-exec via Codex (dry-run: $DRY_RUN, allow-dirty: $ALLOW_DIRTY).
EOF
