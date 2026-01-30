#!/usr/bin/env bash
set -euo pipefail

# Orchestrate: generate tasks -> execute tasks -> commit & push
# Usage:
#   auto-run.sh
#   auto-run.sh --allow-dirty
#   auto-run.sh --dry-run
#   auto-run.sh --full-auto
#   auto-run.sh --force-lock
#   auto-run.sh --skip-commit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
load_config
cd "$ROOT_DIR"

log() { echo "[$(date -Iseconds)] $*"; }
log_err() { echo "[$(date -Iseconds)] $*" >&2; }

DATE_STR="$(date +%Y-%m-%d)"
TIMESTAMP="$(date -Iseconds)"

ALLOW_DIRTY="false"
DRY_RUN="false"
FULL_AUTO="false"
SKIP_COMMIT="false"
FORCE_LOCK="false"

for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY="true" ;;
    --dry-run) DRY_RUN="true" ;;
    --full-auto) FULL_AUTO="true" ;;
    --force-lock) FORCE_LOCK="true" ;;
    --skip-commit) SKIP_COMMIT="true" ;;
    *) log_err "Unknown option: $arg"; exit 1 ;;
  esac
done

if [[ "$FORCE_LOCK" == "true" ]]; then
  rm -f "$LOCK_FILE"
fi

if ( set -o noclobber; echo "pid=$$" > "$LOCK_FILE" ) 2>/dev/null; then
  echo "started=$(date -Iseconds)" >> "$LOCK_FILE"
else
  log_err "auto-run is already running (lock file exists): $LOCK_FILE"
  log_err "Use --force-lock to override if you are sure it's stale."
  exit 1
fi
trap 'rm -f "$LOCK_FILE"' EXIT

log "[1/3] Generate $(basename "$TASKS_FILE") via Codex..."
"$SCRIPT_DIR/auto-iterate.sh" --codex

log "[2/3] Execute tasks via Codex..."
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
  log "[3/3] Commit skipped."

  if [[ ! -f "$LOG_FILE" ]]; then
    cat > "$LOG_FILE" <<EOF
# Iteration Log

EOF
  fi

  cat >> "$LOG_FILE" <<EOF
## $DATE_STR
- [$TIMESTAMP] Ran auto-run (allow-dirty: $ALLOW_DIRTY, dry-run: $DRY_RUN, full-auto: $FULL_AUTO, skip-commit: $SKIP_COMMIT, force-lock: $FORCE_LOCK).
EOF
  exit 0
fi

log "[3/3] Commit and push via Codex..."
"$SCRIPT_DIR/auto-commit.sh"

if [[ ! -f "$LOG_FILE" ]]; then
  cat > "$LOG_FILE" <<EOF
# Iteration Log

EOF
fi

cat >> "$LOG_FILE" <<EOF
## $DATE_STR
- [$TIMESTAMP] Ran auto-run (allow-dirty: $ALLOW_DIRTY, dry-run: $DRY_RUN, full-auto: $FULL_AUTO, skip-commit: $SKIP_COMMIT, force-lock: $FORCE_LOCK).
EOF
