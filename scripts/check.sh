#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

section() {
  printf '\n==> %s\n' "$1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Error: %s is required to run the repository checks.\n' "$1" >&2
    exit 1
  }
}

repository_files() {
  git -C "$REPO_ROOT" ls-files -co --exclude-standard -z
}

check_shell_syntax() {
  local path relative first_line

  section 'Checking Bash and Zsh syntax'
  while IFS= read -r -d '' relative; do
    path="$REPO_ROOT/$relative"
    [ -f "$path" ] || continue

    case "$relative" in
      *.zsh|*.zsh-theme|*/.zprofile|*/.zshenv|*/.zshrc)
        zsh -n "$path"
        continue
        ;;
      *.sh)
        bash -n "$path"
        continue
        ;;
    esac

    first_line="$(LC_ALL=C head -n 1 "$path" 2>/dev/null || true)"
    case "$first_line" in
      *bash*) bash -n "$path" ;;
      *zsh*) zsh -n "$path" ;;
    esac
  done < <(repository_files)
}

check_json_and_plists() {
  local path relative

  section 'Validating JSON and property lists'
  while IFS= read -r -d '' relative; do
    path="$REPO_ROOT/$relative"
    [ -f "$path" ] || continue

    case "$relative" in
      *.json|*.jsonc)
        jq empty "$path"
        ;;
      *.plist)
        python3 -c \
          'import plistlib, sys; plistlib.load(open(sys.argv[1], "rb"))' \
          "$path"
        ;;
    esac
  done < <(repository_files)
}

check_raycast() {
  section 'Checking the Raycast extension'
  node -e '
    const [major, minor, patch] = process.versions.node.split(".").map(Number);
    if (major < 22 || (major === 22 && (minor < 22 || (minor === 22 && patch < 2)))) {
      console.error("Error: Raycast checks require Node.js 22.22.2 or newer.");
      process.exit(1);
    }
  '
  (
    cd "$REPO_ROOT/raycast-theme"
    npm ci
    npm run lint
    npm run build
  )
}

main() {
  require_command git
  require_command jq
  require_command node
  require_command npm
  require_command python3
  require_command strings
  require_command zsh

  check_shell_syntax
  check_json_and_plists

  section 'Validating themes'
  bash "$REPO_ROOT/tests/theme_validation_test.sh"

  section 'Checking for personal hard-coded values'
  bash "$REPO_ROOT/tests/no_personal_data_test.sh"

  section 'Testing the installer'
  bash "$REPO_ROOT/tests/installer_test.sh"

  section 'Testing SketchyBar metrics'
  bash "$REPO_ROOT/tests/sketchybar_metrics_test.sh"

  section 'Testing yabai helpers'
  bash "$REPO_ROOT/tests/yabai_helpers_test.sh"

  check_raycast

  printf '\nAll repository checks passed.\n'
}

main "$@"
