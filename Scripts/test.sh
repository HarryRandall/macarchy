#!/bin/bash
# Unit tests for Desktop. Machine-level checks live in doctor.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
swift test "$@"
