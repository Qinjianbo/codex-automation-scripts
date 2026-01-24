#!/usr/bin/env bash
set -euo pipefail

# Orchestrate: generate tasks -> execute tasks -> commit & push
# Usage:
#   scripts/auto-run.sh
#   scripts/auto-run.sh --allow-dirty
#   scripts/auto-run.sh --dry-run
#   scripts/auto-run.sh --full-auto
#   scripts/auto-run.sh --skip-commit

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/config.sh"
load_config
cd "$ROOT_DIR"

ALLOW_DIRTY="false"
DRY_RUN="false"
FULL_AUTO="false"
SKIP_COMMIT="false"

for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY="true" ;;
    --dry-run) DRY_RUN="true" ;;
    --full-auto) FULL_AUTO="true" ;;
    --skip-commit) SKIP_COMMIT="true" ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

echo "[1/3] Generate TASKS.md via Codex..."
scripts/auto-iterate.sh --codex

echo "[2/3] Execute tasks via Codex..."
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
  scripts/auto-exec.sh
else
  # shellcheck disable=SC2086
  scripts/auto-exec.sh $EXEC_ARGS
fi

if [[ "$DRY_RUN" == "true" || "$SKIP_COMMIT" == "true" ]]; then
  echo "[3/3] Commit skipped."
  exit 0
fi

echo "[3/3] Commit and push via Codex..."
scripts/auto-commit.sh
