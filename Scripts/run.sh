#!/bin/bash
# Build and launch, replacing any running copy.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/Scripts/build_app.sh" "${1:-debug}"
pkill -x MacarchySettings 2>/dev/null || true
open "$ROOT/dist/Macarchy Settings.app"
