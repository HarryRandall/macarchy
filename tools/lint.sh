#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Stopping processes by name can reach the person's real desktop, so tools
# and integration tests must use a recorded pid. The pattern is split so this
# file does not match itself.
banned='p''kill|kill''all'
for dir in tools tests/integration; do
  if [ -d "$dir" ] && grep -rnIE "$banned" "$dir"; then
    echo "error: $dir stops processes by name; signal a recorded pid instead." >&2
    exit 1
  fi
done

FORMAT="$(xcrun --find swift-format)"
if [ "${1:-check}" = fix ]; then
  find src tests -path src/desktop/ui -prune -o -name '*.swift' -print0 | xargs -0 "$FORMAT" format --in-place --configuration .swift-format
else
  find src tests -path src/desktop/ui -prune -o -name '*.swift' -print0 | xargs -0 "$FORMAT" lint --strict --configuration .swift-format
fi
swiftlint lint --strict --quiet
