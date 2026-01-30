#!/usr/bin/env bash
set -euo pipefail

# Generate/refresh plan file via Codex CLI only.
# Usage:
#   auto-plan.sh --codex

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
  log_err "Usage: auto-plan.sh --codex"
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

MODEL_ARGS_PLAN=()
if [[ -n "${CODEX_MODEL_PLAN:-}" ]]; then
  MODEL_ARGS_PLAN+=(--model "$CODEX_MODEL_PLAN")
elif [[ -n "${CODEX_MODEL_DEFAULT:-}" ]]; then
  MODEL_ARGS_PLAN+=(--model "$CODEX_MODEL_DEFAULT")
fi

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
$LANG_NOTE
Summarize the content below into 4-8 concise bullet points.
Focus on goals, scope, constraints, current progress, and open questions.
Output ONLY a Markdown bullet list (no heading).

Content:
$CONTEXT_RAW
EOF
)

  SUMMARY_TMP="$(mktemp)"
  "$SCRIPT_DIR/codex-run.sh" "${MODEL_ARGS_PLAN[@]}" exec "$SUMMARY_PROMPT" > "$SUMMARY_TMP"
  CONTEXT_SUMMARY="$(cat "$SUMMARY_TMP")"
  rm -f "$SUMMARY_TMP"
fi

PROMPT=$(cat <<EOF
You are maintaining $PROJECT_NAME. Update $PLAN_FILE to reflect current priorities.
$LANG_NOTE
This is a higher-level plan, broader than $TASKS_FILE.
Requirements:
- Output ONLY Markdown that starts with "# Plan"
- Include "## $DATE_STR" as the latest plan section
- Produce a concise but complete plan grounded in the current project state; do not limit the plan to a few bullets
- Under "## $DATE_STR", include these subsections (omit only if truly not applicable):
  - "### Objectives" with 3-7 outcome-oriented goals (broader than single tasks)
  - "### Current Status" with 2-5 bullets summarizing where things stand (reference git status/tasks for signal)
  - "### Milestones & Dates" with 3-6 dated or orderable milestones (month-level dates are fine if exact dates unknown)
  - "### Risks & Mitigations" with 2-5 bullets pairing each risk with a mitigation
  - "### Next 1-2 Weeks" with 3-7 priority focuses (group related tasks without copying $TASKS_FILE verbatim)
  - "### Out of Scope / Not Now" with any items being deferred (omit if none)
- Keep content actionable but higher-level than $TASKS_FILE; avoid duplicating line-by-line tasks
- If there is previous plan content, preserve still-relevant items/sections and prune stale ones

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
"$SCRIPT_DIR/codex-run.sh" "${MODEL_ARGS_PLAN[@]}" exec "$PROMPT" > "$TMP_OUT"

if ! head -n 1 "$TMP_OUT" | grep -iq "^# plan"; then
  log_err "Codex output did not start with the expected header. $(basename "$PLAN_FILE") not updated."
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
- [$TIMESTAMP] Generated $(basename "$PLAN_FILE") via Codex.
EOF

log "Updated: $PLAN_FILE"
log "Updated: $LOG_FILE"
