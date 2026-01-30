#!/usr/bin/env bash
set -euo pipefail

# Generate tasks file via Codex CLI only.
# Usage:
#   auto-iterate.sh --codex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
load_config
DATE_STR="$(date +%Y-%m-%d)"
TIMESTAMP="$(date -Iseconds)"
LANG_NOTE="Use $CODEX_LANGUAGE for all prose. Keep required headings exactly as specified."

cd "$ROOT_DIR"

log() { echo "[$(date -Iseconds)] $*"; }
log_err() { echo "[$(date -Iseconds)] $*" >&2; }

if [[ "${1:-}" != "--codex" ]]; then
  log_err "Usage: auto-iterate.sh --codex"
  exit 1
fi

PLAN_CONTENT=$(cat "$PLAN_FILE")
TASKS_CONTENT=""
if [[ -f "$TASKS_FILE" ]]; then
  TASKS_CONTENT=$(cat "$TASKS_FILE")
fi
GIT_STATUS=$(git status --porcelain || true)

PROMPT=$(cat <<EOF
You are maintaining $PROJECT_NAME. Generate a concise task list for today.
$LANG_NOTE
Requirements:
- Output ONLY Markdown that starts with "# Tasks (Auto-generated)"
- Include "## $DATE_STR"
- Provide 4-6 checkbox items
- Prioritize unfinished tasks from the existing $TASKS_FILE and $PLAN_FILE
- Keep tasks small, specific, and actionable
- If $PLAN_FILE has no remaining actionable items (or all tasks are already completed), output exactly "已无计划可以进行" and nothing else

Current $PLAN_FILE:
$PLAN_CONTENT

Existing $TASKS_FILE:
$TASKS_CONTENT

Git status (if any):
$GIT_STATUS
EOF
)

TMP_OUT="$(mktemp)"
"$SCRIPT_DIR/codex-run.sh" exec "$PROMPT" > "$TMP_OUT"

FIRST_LINE="$(head -n 1 "$TMP_OUT" || true)"
if [[ "$FIRST_LINE" != "已无计划可以进行" ]] && ! grep -q "^# Tasks (Auto-generated)" <<<"$FIRST_LINE"; then
  log_err "Codex output did not start with the expected header or the 'no plan' message. $(basename "$TASKS_FILE") not updated."
  cat "$TMP_OUT" >&2
  rm -f "$TMP_OUT"
  exit 1
fi

cat "$TMP_OUT" > "$TASKS_FILE"
rm -f "$TMP_OUT"

  if [[ ! -f "$LOG_FILE" ]]; then
    cat > "$LOG_FILE" <<EOF
# Iteration Log

EOF
  fi

cat >> "$LOG_FILE" <<EOF
## $DATE_STR
- [$TIMESTAMP] Generated $(basename "$TASKS_FILE") via Codex.
EOF

log "Updated: $TASKS_FILE"
log "Updated: $LOG_FILE"
