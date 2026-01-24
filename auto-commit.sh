#!/usr/bin/env bash
set -euo pipefail

# Auto-commit and push changes to origin/main via Codex CLI.
# Usage:
#   scripts/auto-commit.sh
#   scripts/auto-commit.sh -m "your message"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
load_config
cd "$ROOT_DIR"

COMMIT_MSG=""
while getopts ":m:" opt; do
  case "$opt" in
    m) COMMIT_MSG="$OPTARG" ;;
    *) echo "Usage: scripts/auto-commit.sh [-m \"message\"]" >&2; exit 1 ;;
  esac
done

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "$GIT_BRANCH" ]]; then
  echo "Not on $GIT_BRANCH (current: $BRANCH). Aborting." >&2
  exit 1
fi

STATUS="$(git status --porcelain)"
if [[ -z "$STATUS" ]]; then
  echo "No changes to commit." >&2
  exit 0
fi

MSG_LINE=""
if [[ -n "$COMMIT_MSG" ]]; then
  MSG_LINE="Use this commit message exactly: $COMMIT_MSG"
else
  MSG_LINE="Generate a concise commit message (one line, <=72 chars) using prefixes like feat:, fix:, chore:, docs:."
fi

PROMPT=$(cat <<EOF
You are in the $PROJECT_NAME repo on branch $GIT_BRANCH.
Stage all changes, create a commit, and push to ${GIT_REMOTE}/${GIT_BRANCH}.

Rules:
- Do not modify files beyond what is necessary to stage/commit.
- If there are no changes, exit gracefully without error.
- $MSG_LINE

Git status:
$STATUS
EOF
)

scripts/codex-run.sh --dangerously-bypass-approvals-and-sandbox exec "$PROMPT"
