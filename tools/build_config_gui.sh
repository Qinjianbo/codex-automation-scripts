#!/usr/bin/env bash
set -euo pipefail

# Build a self-contained GUI binary using PyInstaller.
# Requirements: python3, pyinstaller, pyyaml

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="${APP_NAME:-codex-config-gui}"

cd "$ROOT_DIR"

if ! command -v pyinstaller >/dev/null 2>&1; then
  echo "pyinstaller not found. Install with: pip install pyinstaller" >&2
  exit 1
fi

pyinstaller --clean --windowed --name "$APP_NAME" tools/config_gui.py

echo "Build complete. See dist/$APP_NAME (or dist/$APP_NAME.app on macOS)."
