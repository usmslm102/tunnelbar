#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/tunnelbar-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/tunnelbar-swift-cache"
build_path="${TUNNELBAR_BUILD_PATH:-${TMPDIR:-/tmp}/tunnelbar-build}"
swift build --disable-sandbox --scratch-path "$build_path" -c release
bin_path="$(swift build --disable-sandbox --scratch-path "$build_path" -c release --show-bin-path)"
app_path="$PWD/dist/TunnelBar.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/TunnelBar" "$app_path/Contents/MacOS/TunnelBar"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
swift scripts/make-icon.swift "$app_path/Contents/Resources"
codesign --force --sign - "$app_path"
echo "Built: $app_path"
