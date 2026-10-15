#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/tunnelbar-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/tunnelbar-swift-cache"
developer_path="$(xcode-select -p)"
frameworks="$developer_path/Library/Developer/Frameworks"
extra=()
# Command Line Tools ship Swift Testing here, outside the default framework search path.
if [[ -d "$frameworks/Testing.framework" ]]; then
    extra=(-Xswiftc -F -Xswiftc "$frameworks" -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xlinker -rpath -Xlinker "$frameworks")
fi
# The conditional expansion also supports macOS's Bash 3.2 with nounset enabled.
swift test --disable-sandbox --scratch-path "${TUNNELBAR_BUILD_PATH:-${TMPDIR:-/tmp}/tunnelbar-build}" ${extra[@]+"${extra[@]}"} "$@"
