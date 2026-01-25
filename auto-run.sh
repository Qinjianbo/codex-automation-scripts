#!/usr/bin/env bash
set -euo pipefail

# Orchestrate: generate tasks -> execute tasks -> commit & push
# Usage:
#   auto-run.sh
#   auto-run.sh --allow-dirty
#   auto-run.sh --dry-run
#   auto-run.sh --full-auto
#   auto-run.sh --skip-plan
#   auto-run.sh --force-lock
#   auto-run.sh --skip-commit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
load_config
cd "$ROOT_DIR"

ALLOW_DIRTY="false"
DRY_RUN="false"
FULL_AUTO="false"
SKIP_PLAN="false"
SKIP_COMMIT="false"
FORCE_LOCK="false"

for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY="true" ;;
    --dry-run) DRY_RUN="true" ;;
    --full-auto) FULL_AUTO="true" ;;
    --skip-plan) SKIP_PLAN="true" ;;
    --force-lock) FORCE_LOCK="true" ;;
    --skip-commit) SKIP_COMMIT="true" ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

if [[ "$FORCE_LOCK" == "true" ]]; then
  rm -f "$LOCK_FILE"
fi

if ( set -o noclobber; echo "pid=$$" > "$LOCK_FILE" ) 2>/dev/null; then
  echo "started=$(date -Iseconds)" >> "$LOCK_FILE"
else
  echo "auto-run is already running (lock file exists): $LOCK_FILE" >&2
  echo "Use --force-lock to override if you are sure it's stale." >&2
  exit 1
fi
trap 'rm -f "$LOCK_FILE"' EXIT

if [[ "$SKIP_PLAN" == "false" ]]; then
  echo "[1/4] Update $(basename "$PLAN_FILE") via Codex..."
  "$SCRIPT_DIR/auto-plan.sh" --codex
else
  echo "[1/4] Plan update skipped."
fi

echo "[2/4] Generate $(basename "$TASKS_FILE") via Codex..."
"$SCRIPT_DIR/auto-iterate.sh" --codex

echo "[3/4] Execute tasks via Codex..."
EXEC_ARGS=""
if [[ "$ALLOW_DIRTY" == "true" ]]; then
  EXEC_ARGS+=" --allow-dirty"
fi
if [[ "$DRY_RUN" == "true" ]]; then
  EXEC_ARGS+=" --dry-run"
fi
if [[ "$FULL_AUTO" == "true" ]]; then
  EXEC_ARGS+=" --full-auto"
fi
if [[ -z "$EXEC_ARGS" ]]; then
  "$SCRIPT_DIR/auto-exec.sh"
else
  # shellcheck disable=SC2086
  "$SCRIPT_DIR/auto-exec.sh" $EXEC_ARGS
fi

if [[ "$DRY_RUN" == "true" || "$SKIP_COMMIT" == "true" ]]; then
  echo "[4/4] Commit skipped."
  exit 0
fi

echo "[4/4] Commit and push via Codex..."
"$SCRIPT_DIR/auto-commit.sh"
