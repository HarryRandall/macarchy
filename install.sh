#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BREW=1

for arg in "$@"; do
  case "$arg" in
    --skip-brew)
      INSTALL_BREW=0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: bash ./install.sh [--skip-brew]" >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer is intended for macOS." >&2
  exit 1
fi

if [[ "$INSTALL_BREW" -eq 1 ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required. Install it first, then rerun this script." >&2
    exit 1
  fi

  brew bundle --file "$ROOT_DIR/Brewfile"
fi

mkdir -p "$HOME/Library/LaunchAgents"

rsync -a "$ROOT_DIR/home/" "$HOME/"
rsync -a "$ROOT_DIR/library/LaunchAgents/" "$HOME/Library/LaunchAgents/"

echo
echo "Macarchy files installed."
echo
echo "Next steps:"
echo "  1. Grant Accessibility permissions to yabai, skhd, Raycast, and Ghostty."
echo "  2. Load the launch agents from ~/Library/LaunchAgents."
echo "  3. Run ~/.local/bin/theme-switch \$(cat ~/.themes/.current) if you want to reapply the current theme."
