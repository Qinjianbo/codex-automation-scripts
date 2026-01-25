#!/usr/bin/env bash
set -euo pipefail

# Run Codex to implement tasks from TASKS_FILE.
# Usage:
#   auto-exec.sh                # requires clean git status
#   auto-exec.sh --allow-dirty  # allow dirty working tree
#   auto-exec.sh --dry-run      # ask Codex to only propose a plan (no edits)
#   auto-exec.sh --sandbox <mode>  # set codex sandbox (default: workspace-write)
#   auto-exec.sh --full-auto      # no prompts; bypass approvals/sandbox (dangerous)
#   auto-exec.sh --force-lock     # ignore existing lock file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
load_config

ALLOW_DIRTY="false"
DRY_RUN="false"
SANDBOX_MODE="$DEFAULT_SANDBOX"
FULL_AUTO="false"
FORCE_LOCK="false"

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
    --force-lock)
      FORCE_LOCK="true"
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

cd "$ROOT_DIR"

if [[ ! -f "$TASKS_FILE" ]]; then
  echo "Missing tasks file: $TASKS_FILE. Run \"$SCRIPT_DIR/auto-iterate.sh\" --codex first." >&2
  exit 1
fi

if [[ -f "$LOCK_FILE" && "$FORCE_LOCK" == "false" ]]; then
  echo "auto-exec is already running (lock file exists): $LOCK_FILE" >&2
  echo "Use --force-lock to override if you are sure it's stale." >&2
  exit 1
fi

if [[ "$FORCE_LOCK" == "true" ]]; then
  rm -f "$LOCK_FILE"
fi

echo "pid=$$" > "$LOCK_FILE"
echo "started=$(date -Iseconds)" >> "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

if [[ "$ALLOW_DIRTY" == "false" ]]; then
  if git status --porcelain | grep -q .; then
    echo "Working tree is not clean. Commit/stash or re-run with --allow-dirty." >&2
    exit 1
  fi
fi

TASKS_CONTENT="$(cat "$TASKS_FILE")"

PROMPT=$(cat <<EOF
You are a coding agent working inside this repo. Implement the unchecked tasks from $TASKS_FILE.

Rules:
- Make small, safe changes only; avoid refactors.
- Keep EN/ZH pages consistent when updating content or logic.
- Prefer editing existing files; avoid new dependencies.
- Update CHANGELOG.md if user-visible behavior changes.
- Report what you changed and any manual checks.
- After completing tasks, update $TASKS_FILE by checking off items you completed.

If --dry-run is enabled, produce a plan only and do not edit files.
EOF
)

if [[ "$DRY_RUN" == "true" ]]; then
  PROMPT="${PROMPT}"$'\n\nDRY RUN: Provide a concise plan only. Do not edit files.'
fi

PROMPT="${PROMPT}"$'\n\n'"$TASKS_FILE"$':\n'"$TASKS_CONTENT"

if [[ "$FULL_AUTO" == "true" ]]; then
  "$SCRIPT_DIR/codex-run.sh" --dangerously-bypass-approvals-and-sandbox exec "$PROMPT"
else
  "$SCRIPT_DIR/codex-run.sh" --sandbox "$SANDBOX_MODE" --ask-for-approval on-request exec "$PROMPT"
fi

if [[ ! -f "$LOG_FILE" ]]; then
  cat > "$LOG_FILE" <<EOF
# Iteration Log

EOF
fi

DATE_STR="$(date +%Y-%m-%d)"
cat >> "$LOG_FILE" <<EOF
## $DATE_STR
- Ran auto-exec via Codex (dry-run: $DRY_RUN, allow-dirty: $ALLOW_DIRTY).
EOF
