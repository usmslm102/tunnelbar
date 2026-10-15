#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/tunnelbar-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/tunnelbar-swift-cache"
swift test --disable-sandbox --scratch-path "${TUNNELBAR_BUILD_PATH:-${TMPDIR:-/tmp}/tunnelbar-build}" "$@"
bin_path="$(swift build --disable-sandbox --scratch-path "${TUNNELBAR_BUILD_PATH:-${TMPDIR:-/tmp}/tunnelbar-build}" --show-bin-path)"
python3 Tests/ProcessLifecycleTests/test_guardian.py "$bin_path/TunnelGuardian"
