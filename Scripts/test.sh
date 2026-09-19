#!/bin/bash
# Unit tests for MacarchyKit. Machine-level checks live in doctor.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
swift test "$@"
