#!/usr/bin/env bash
set -euo pipefail

# Generate/refresh PLAN.md via Codex CLI only.
# Usage:
#   scripts/auto-plan.sh --codex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
load_config
DATE_STR="$(date +%Y-%m-%d)"

cd "$ROOT_DIR"

if [[ "${1:-}" != "--codex" ]]; then
  echo "Usage: scripts/auto-plan.sh --codex" >&2
  exit 1
fi

PLAN_CONTENT=""
if [[ -f "$PLAN_FILE" ]]; then
  PLAN_CONTENT=$(cat "$PLAN_FILE")
fi

TASKS_CONTENT=""
if [[ -f "$TASKS_FILE" ]]; then
  TASKS_CONTENT=$(cat "$TASKS_FILE")
fi

GIT_STATUS=$(git status --porcelain || true)

PROMPT=$(cat <<EOF
You are maintaining $PROJECT_NAME. Update PLAN.md to reflect current priorities.
This is a higher-level plan, broader than TASKS.md.
Requirements:
- Output ONLY Markdown that starts with "# Plan"
- Include "## $DATE_STR" as the latest plan section
- Provide 3-6 goal-oriented bullets (themes/milestones), not step-by-step tasks
- Each bullet should be a short, meaningful outcome (bigger than a single coding task)
- Align with current tasks and repo status without duplicating items from $TASKS_FILE
- If there is previous plan content, preserve any still-relevant items and prune stale ones

Existing $PLAN_FILE:
$PLAN_CONTENT

Existing $TASKS_FILE:
$TASKS_CONTENT

Git status (if any):
$GIT_STATUS
EOF
)

TMP_OUT="$(mktemp)"
scripts/codex-run.sh exec "$PROMPT" > "$TMP_OUT"

if ! head -n 1 "$TMP_OUT" | grep -iq "^# plan"; then
  echo "Codex output did not start with the expected header. PLAN.md not updated." >&2
  cat "$TMP_OUT" >&2
  rm -f "$TMP_OUT"
  exit 1
fi

cat "$TMP_OUT" > "$PLAN_FILE"
rm -f "$TMP_OUT"

if [[ ! -f "$LOG_FILE" ]]; then
  cat > "$LOG_FILE" <<EOF
# Iteration Log

EOF
fi

cat >> "$LOG_FILE" <<EOF
## $DATE_STR
- Generated PLAN.md via Codex.
EOF

echo "Updated: $PLAN_FILE"
echo "Updated: $LOG_FILE"
