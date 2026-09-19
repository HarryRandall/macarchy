#!/bin/bash
# Formatting and lint. swift-format ships with Xcode; SwiftLint is brew-installed.
#   ./Scripts/lint.sh        check only
#   ./Scripts/lint.sh fix    rewrite files in place
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODE="${1:-check}"
FORMAT="$(xcrun --find swift-format 2>/dev/null)"
status=0

if [ -n "$FORMAT" ]; then
  if [ "$MODE" = "fix" ]; then
    echo "==> swift-format (writing)"
    find Sources -name '*.swift' -print0 | xargs -0 "$FORMAT" format --in-place --configuration .swift-format
  else
    echo "==> swift-format (check)"
    find Sources -name '*.swift' -print0 \
      | xargs -0 "$FORMAT" lint --configuration .swift-format 2>&1 | head -40 || status=1
  fi
else
  echo "swift-format not found in the Xcode toolchain" >&2
fi

if command -v swiftlint >/dev/null 2>&1; then
  echo "==> swiftlint"
  if [ "$MODE" = "fix" ]; then swiftlint --fix --quiet >/dev/null 2>&1; fi
  swiftlint lint --quiet || status=1
else
  echo "swiftlint not installed (brew install swiftlint)" >&2
fi

exit $status
