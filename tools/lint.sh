#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
FORMAT="$(xcrun --find swift-format)"
if [ "${1:-check}" = fix ]; then
  find src tests -path src/desktop/ui -prune -o -name '*.swift' -print0 | xargs -0 "$FORMAT" format --in-place --configuration .swift-format
else
  find src tests -path src/desktop/ui -prune -o -name '*.swift' -print0 | xargs -0 "$FORMAT" lint --strict --configuration .swift-format
fi
swiftlint lint --strict --quiet
