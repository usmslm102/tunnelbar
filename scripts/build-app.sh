#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/tunnelbar-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/tunnelbar-swift-cache"
build_path="${TUNNELBAR_BUILD_PATH:-${TMPDIR:-/tmp}/tunnelbar-build}"
mode="${TUNNELBAR_ARCH:-$(uname -m)}"
case "$mode" in
    arm64|x86_64) architectures=("$mode") ;;
    universal) architectures=(arm64 x86_64) ;;
    *) echo "TUNNELBAR_ARCH must be arm64, x86_64, or universal." >&2; exit 1 ;;
esac

app_binaries=()
guardian_binaries=()
for arch in "${architectures[@]}"; do
    swift build --disable-sandbox --scratch-path "$build_path" -c release --arch "$arch"
    bin_path="$(swift build --disable-sandbox --scratch-path "$build_path" -c release --arch "$arch" --show-bin-path)"
    app_binaries+=("$bin_path/TunnelBar")
    guardian_binaries+=("$bin_path/TunnelGuardian")
done
app_path="$PWD/dist/TunnelBar.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
if [[ "$mode" == universal ]]; then
    lipo -create "${app_binaries[@]}" -output "$app_path/Contents/MacOS/TunnelBar"
    lipo -create "${guardian_binaries[@]}" -output "$app_path/Contents/MacOS/TunnelGuardian"
else
    cp "${app_binaries[0]}" "$app_path/Contents/MacOS/TunnelBar"
    cp "${guardian_binaries[0]}" "$app_path/Contents/MacOS/TunnelGuardian"
fi
cp Resources/Info.plist "$app_path/Contents/Info.plist"
swift scripts/make-icon.swift "$app_path/Contents/Resources"
# Developer ID signing/notarization is intentionally optional for this project.
codesign --force --sign - "$app_path/Contents/MacOS/TunnelGuardian"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
echo "Built ($mode, ad-hoc signed): $app_path"
