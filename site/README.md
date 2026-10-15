# TunnelBar static site

The site is plain HTML, CSS, SVG, and JavaScript. There is no package manager,
framework, backend, analytics, external font, or runtime API request.

## Preview and downloads

From the repository root:

```sh
bash scripts/build-site.sh
open dist/site/index.html
```

This builds the native app, archives it for the current Mac's architecture, and
creates `dist/site/` with an actual download and SHA-256 checksum. `download-config.js`
contains only public build metadata and relative paths; it contains no token.
The packaged archive includes the app; `downloads/LICENSE.txt` accompanies it.
The build also checks local assets, fragment links, archive integrity, and checksums
using `scripts/check-site.py`. Packaging requires Python 3.9 or later.

The source page at `site/index.html` works directly too. Without generated build
metadata it links to source-build instructions instead of claiming a nonexistent
binary is downloadable. The hero uses the supplied native macOS app screenshot at
`assets/tunnelbar-macos.png`, preserved at its original resolution. Its controls
are part of the image, not interactive website controls.

For an HTTP preview, from the root:

```sh
python3 -m http.server 8088 --bind 127.0.0.1 --directory dist/site
```

Open `http://127.0.0.1:8088`. Stop the server with Ctrl+C. The page is also usable
over `file://`; the copy button selects the command if clipboard access is denied.

## Other architectures

By default the build script packages the host architecture. An Intel Mac produces
the Intel ZIP; an Apple silicon Mac produces arm64. Set `TUNNELBAR_ARCH=arm64` or
`TUNNELBAR_ARCH=x86_64` to cross-compile a specific slice. Each site build replaces
previously generated ZIPs so stale app versions are not carried into a new bundle.
Versions are read from the archived plist; checksums come from the archive bytes.

For a single Universal 2 download, use:

```sh
TUNNELBAR_ARCH=universal ./scripts/build-site.sh
```

Both architecture buttons then use the universal ZIP. The native app and its
bundled guardian both contain arm64 and x86_64 slices.

Unpack and validate each build on its target architecture before distributing it.
These are ad-hoc signed development builds, not notarized public releases.

## Publication

Nothing in this project deploys the site, enables GitHub Pages, uploads a release,
or changes repository visibility. CI includes the static files in its private
development artifact only. The GitHub repository and release links still require
authorized access while the repository is private.

When publishing is explicitly requested later, host the contents of `dist/site/`
with the relative directory structure intact, review the pre-release copy, and
complete `docs/RELEASING.md`. A private Git repository alone does not make a hosted
website private; choose the hosting audience explicitly.
