#!/usr/bin/env bash
set -euo pipefail

# Generate/refresh plan file via Codex CLI only.
# Usage:
#   auto-plan.sh --codex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
load_config
DATE_STR="$(date +%Y-%m-%d)"

cd "$ROOT_DIR"

if [[ "${1:-}" != "--codex" ]]; then
  echo "Usage: auto-plan.sh --codex" >&2
  exit 1
fi

_trim() {
  local val="$1"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  echo "$val"
}

PLAN_CONTENT=""
if [[ -f "$PLAN_FILE" ]]; then
  PLAN_CONTENT=$(cat "$PLAN_FILE")
fi

TASKS_CONTENT=""
if [[ -f "$TASKS_FILE" ]]; then
  TASKS_CONTENT=$(cat "$TASKS_FILE")
fi

GIT_STATUS=$(git status --porcelain || true)

CONTEXT_RAW=""
if [[ -n "${PLAN_CONTEXT_FILES:-}" ]]; then
  IFS=',' read -r -a CONTEXT_FILE_LIST <<< "$PLAN_CONTEXT_FILES"
  for raw in "${CONTEXT_FILE_LIST[@]}"; do
    file="$(_trim "$raw")"
    [[ -z "$file" ]] && continue
    path="$file"
    if [[ "$path" != /* ]]; then
      path="$ROOT_DIR/$path"
    fi
    if [[ -f "$path" ]]; then
      CONTEXT_RAW+=$'\n\n'"### $(basename "$path")"$'\n'
      CONTEXT_RAW+="$(cat "$path")"
    fi
  done
fi

CONTEXT_SUMMARY=""
if [[ -n "$CONTEXT_RAW" ]]; then
  max_chars="${PLAN_CONTEXT_MAX_CHARS:-12000}"
  if [[ "$max_chars" =~ ^[0-9]+$ ]] && (( ${#CONTEXT_RAW} > max_chars )); then
    CONTEXT_RAW="${CONTEXT_RAW:0:max_chars}"
  fi

  SUMMARY_PROMPT=$(cat <<EOF
You are summarizing project context for planning.
Summarize the content below into 4-8 concise bullet points.
Focus on goals, scope, constraints, current progress, and open questions.
Output ONLY a Markdown bullet list (no heading).

Content:
$CONTEXT_RAW
EOF
)

  SUMMARY_TMP="$(mktemp)"
  "$SCRIPT_DIR/codex-run.sh" exec "$SUMMARY_PROMPT" > "$SUMMARY_TMP"
  CONTEXT_SUMMARY="$(cat "$SUMMARY_TMP")"
  rm -f "$SUMMARY_TMP"
fi

PROMPT=$(cat <<EOF
You are maintaining $PROJECT_NAME. Update $PLAN_FILE to reflect current priorities.
This is a higher-level plan, broader than $TASKS_FILE.
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

Auto-collected file summary (if any):
$CONTEXT_SUMMARY
EOF
)

TMP_OUT="$(mktemp)"
"$SCRIPT_DIR/codex-run.sh" exec "$PROMPT" > "$TMP_OUT"

if ! head -n 1 "$TMP_OUT" | grep -iq "^# plan"; then
  echo "Codex output did not start with the expected header. $(basename "$PLAN_FILE") not updated." >&2
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
- Generated $(basename "$PLAN_FILE") via Codex.
EOF

echo "Updated: $PLAN_FILE"
echo "Updated: $LOG_FILE"
