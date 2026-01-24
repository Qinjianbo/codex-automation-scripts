#!/usr/bin/env bash
set -euo pipefail

# Generate TASKS.md via Codex CLI only.
# Usage:
#   scripts/auto-iterate.sh --codex

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/config.sh"
load_config
DATE_STR="$(date +%Y-%m-%d)"

cd "$ROOT_DIR"

if [[ "${1:-}" != "--codex" ]]; then
  echo "Usage: scripts/auto-iterate.sh --codex" >&2
  exit 1
fi

PLAN_CONTENT=$(cat "$PLAN_FILE")
TASKS_CONTENT=""
if [[ -f "$TASKS_FILE" ]]; then
  TASKS_CONTENT=$(cat "$TASKS_FILE")
fi
GIT_STATUS=$(git status --porcelain || true)

PROMPT=$(cat <<EOF
You are maintaining RiskMeter. Generate a concise task list for today.
Requirements:
- Output ONLY Markdown that starts with "# Tasks (Auto-generated)"
- Include "## $DATE_STR"
- Provide 4-6 checkbox items
- Prioritize unfinished tasks from the existing TASKS.md and PLAN.md
- Keep tasks small, specific, and actionable

Current PLAN.md:
$PLAN_CONTENT

Existing TASKS.md:
$TASKS_CONTENT

Git status (if any):
$GIT_STATUS
EOF
)

TMP_OUT="$(mktemp)"
scripts/codex-run.sh exec "$PROMPT" > "$TMP_OUT"

if ! head -n 1 "$TMP_OUT" | grep -q "# Tasks (Auto-generated)"; then
  echo "Codex output did not start with the expected header. TASKS.md not updated." >&2
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
- Generated TASKS.md via Codex.
EOF

echo "Updated: $TASKS_FILE"
echo "Updated: $LOG_FILE"
