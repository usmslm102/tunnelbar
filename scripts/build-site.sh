#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Build only a local bundle. This script never enables Pages, creates a release,
# changes repository visibility, or uploads the site.
bash scripts/build-app.sh
site_path="$PWD/dist/site"
mkdir -p "$site_path/assets" "$site_path/downloads"
cp site/index.html site/styles.css site/app.js "$site_path/"
cp site/assets/*.svg site/assets/*.png "$site_path/assets/"

architectures="$(lipo -archs dist/TunnelBar.app/Contents/MacOS/TunnelBar)"
if [[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]]; then
    arch=universal
else
    arch="$architectures"
fi

archive="TunnelBar-macOS-${arch}.zip"
# Downloads are generated artifacts. Never carry older binaries into a new site.
rm -f "$site_path"/downloads/TunnelBar-macOS-*.zip "$site_path"/downloads/TunnelBar-macOS-*.zip.sha256
ditto -c -k --sequesterRsrc --keepParent dist/TunnelBar.app "$site_path/downloads/$archive"
cp LICENSE "$site_path/downloads/LICENSE.txt"

python3 - "$site_path" <<'PY'
import hashlib
import json
import plistlib
import sys
import zipfile
from pathlib import Path

site = Path(sys.argv[1])
builds = []
for arch in ("arm64", "x86_64", "universal"):
    archive = site / "downloads" / f"TunnelBar-macOS-{arch}.zip"
    if not archive.exists():
        continue
    with zipfile.ZipFile(archive) as bundle:
        version = plistlib.loads(bundle.read("TunnelBar.app/Contents/Info.plist"))["CFBundleShortVersionString"]
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
    builds.append({"arch": arch, "href": f"downloads/{archive.name}",
                   "version": version, "size": f"{archive.stat().st_size / 1024 / 1024:.1f} MB",
                   "sha256": digest})
(site / "download-config.js").write_text("window.TUNNELBAR_DOWNLOADS = " + json.dumps(builds, indent=2) + ";\n")
PY

python3 scripts/check-site.py "$site_path"
echo "Static site built locally: $site_path/index.html"
echo "Contains a development download for $arch. Nothing was published."
