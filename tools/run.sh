#!/bin/bash
# Build and launch, replacing any running copy.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/tools/build.sh" "${1:-debug}"
pkill -x MacarchySettings 2>/dev/null || true
open "$ROOT/.build/artifacts/Macarchy.app"
