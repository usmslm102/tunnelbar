#!/usr/bin/env python3
"""Check the static bundle's local assets, fragment links, and real downloads."""
import hashlib
import json
import sys
import zipfile
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.references = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            if attrs["id"] in self.ids:
                raise ValueError(f"Duplicate HTML id: {attrs['id']}")
            self.ids.add(attrs["id"])
        for attribute in ("src", "href"):
            if attribute in attrs:
                self.references.append(attrs[attribute])


def check(folder):
    root = folder.resolve()
    page = Page()
    page.feed((root / "index.html").read_text())
    for reference in page.references:
        url = urlsplit(reference)
        if url.scheme or url.netloc:
            continue
        if url.path:
            target = (root / unquote(url.path)).resolve()
            if not target.is_relative_to(root) or not target.is_file():
                raise ValueError(f"Missing or invalid local asset: {reference}")
        elif url.fragment and url.fragment not in page.ids:
            raise ValueError(f"Missing fragment target: {reference}")
    configuration = (root / "download-config.js").read_text()
    builds = json.loads(configuration.split("window.TUNNELBAR_DOWNLOADS = ", 1)[1].strip().rstrip(";"))
    for build in builds:
        archive = (root / build["href"]).resolve()
        if not archive.is_relative_to(root / "downloads"):
            raise ValueError("Download is outside the bundle's downloads directory")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if digest != build["sha256"]:
            raise ValueError(f"Checksum mismatch: {archive.name}")
        expected_checksum = f"{digest}  {archive.name}\n"
        if archive.with_suffix(".zip.sha256").read_text() != expected_checksum:
            raise ValueError(f"Invalid checksum file: {archive.name}")
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip() is not None:
                raise ValueError(f"Invalid ZIP: {archive.name}")
            if "TunnelBar.app/Contents/MacOS/TunnelBar" not in bundle.namelist():
                raise ValueError(f"App executable missing from {archive.name}")
            if "TunnelBar.app/Contents/MacOS/TunnelGuardian" not in bundle.namelist():
                raise ValueError(f"Process guardian missing from {archive.name}")
    print(f"Static site checked: local assets, fragment links, {len(builds)} download(s), ZIP integrity, and SHA-256 checksums.")


if __name__ == "__main__":
    check(Path(sys.argv[1] if len(sys.argv) > 1 else "dist/site"))
