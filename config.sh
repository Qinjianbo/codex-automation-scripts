#!/usr/bin/env bash
set -euo pipefail

# Lightweight config loader for scripts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$ROOT_DIR" && -f "$SCRIPT_DIR/config.yaml" ]]; then
  ROOT_DIR="$SCRIPT_DIR"
fi
if [[ -z "$ROOT_DIR" && -f "$SCRIPT_DIR/../config.yaml" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(git -C "$PWD" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
fi
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$PWD"
fi

CONFIG_FILE="$ROOT_DIR/config.yaml"
ALT_CONFIG_FILE="$SCRIPT_DIR/config.yaml"

_expand_tilde() {
  local val="$1"
  if [[ "$val" == "~"* ]]; then
    echo "${val/#\~/$HOME}"
  else
    echo "$val"
  fi
}

_resolve_path() {
  local val="$1"
  if [[ -z "$val" ]]; then
    echo "$val"
    return
  fi
  if [[ "$val" = /* ]]; then
    echo "$val"
  else
    echo "$ROOT_DIR/$val"
  fi
}

load_config() {
  # Defaults
  PROJECT_NAME="${PROJECT_NAME:-$(basename "$ROOT_DIR")}"
  CODEX_NODE="${CODEX_NODE:-$HOME/.nvm/versions/node/v22.18.0/bin/node}"
  CODEX_CLI="${CODEX_CLI:-$HOME/.nvm/versions/node/v22.18.0/lib/node_modules/@openai/codex/bin/codex.js}"
  GIT_BRANCH="${GIT_BRANCH:-main}"
  GIT_REMOTE="${GIT_REMOTE:-origin}"
  TASKS_FILE="${TASKS_FILE:-$ROOT_DIR/TASKS.md}"
  PLAN_FILE="${PLAN_FILE:-$ROOT_DIR/PLAN.md}"
  LOG_FILE="${LOG_FILE:-$ROOT_DIR/ITERATION_LOG.md}"
  LOCK_FILE="${LOCK_FILE:-$ROOT_DIR/.auto-run.lock}"
  DEFAULT_SANDBOX="${DEFAULT_SANDBOX:-workspace-write}"

  local config_to_use=""
  if [[ -f "$CONFIG_FILE" ]]; then
    config_to_use="$CONFIG_FILE"
  elif [[ -f "$ALT_CONFIG_FILE" ]]; then
    config_to_use="$ALT_CONFIG_FILE"
  fi

  if [[ -n "$config_to_use" ]]; then
    while IFS=: read -r raw_key raw_val; do
      raw_key="${raw_key%%#*}"
      raw_val="${raw_val%%#*}"
      local key
      local val
      key="$(echo "$raw_key" | tr -d '[:space:]')"
      val="$(echo "$raw_val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      val="${val%\"}"
      val="${val#\"}"
      val="${val%\'}"
      val="${val#\'}"
      [[ -z "$key" || -z "$val" ]] && continue
      case "$key" in
        codex_node) CODEX_NODE="$val" ;;
        codex_cli) CODEX_CLI="$val" ;;
        project_name) PROJECT_NAME="$val" ;;
        git_branch) GIT_BRANCH="$val" ;;
        git_remote) GIT_REMOTE="$val" ;;
        tasks_file) TASKS_FILE="$val" ;;
        plan_file) PLAN_FILE="$val" ;;
        log_file) LOG_FILE="$val" ;;
        lock_file) LOCK_FILE="$val" ;;
        default_sandbox) DEFAULT_SANDBOX="$val" ;;
      esac
    done < <(grep -v '^[[:space:]]*$' "$config_to_use" | grep -v '^[[:space:]]*#')
  fi

  CODEX_NODE="$(_expand_tilde "$CODEX_NODE")"
  CODEX_CLI="$(_expand_tilde "$CODEX_CLI")"

  TASKS_FILE="$(_resolve_path "$TASKS_FILE")"
  PLAN_FILE="$(_resolve_path "$PLAN_FILE")"
  LOG_FILE="$(_resolve_path "$LOG_FILE")"
  LOCK_FILE="$(_resolve_path "$LOCK_FILE")"
}
