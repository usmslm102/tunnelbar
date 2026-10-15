TunnelBar is a native macOS menu bar UI for cloudflared tunnels. Share a local
port, require email by default, remember allowed emails, or explicitly choose
anonymous access. Account tunnels use existing cloudflared CLI credentials.

Download `TunnelBar-macOS-universal.zip` for Apple Silicon or Intel, unzip it,
and move TunnelBar.app to Applications. macOS 13 or later and a separately
installed `cloudflared` are required. The SHA-256 checksum accompanies the ZIP.

TunnelBar 1.0.0 is the first stable release, following maintainer testing of the preview.
The app is ad-hoc signed and **not notarized**;
macOS may show Gatekeeper prompts. If blocked, review the source and build it
locally, or use macOS Privacy & Security → Open Anyway only if you trust the
download. No Apple Developer account is required to build from source.

Quick Tunnels provide temporary links for development and testing. Use named
Cloudflare tunnels and appropriate Access policies for production routing.
Automated checks cover unit tests, process lifetime, Universal 2 packaging,
signatures, and download checksums. Maintainer-reported testing does not establish
coverage of every supported macOS version or hardware configuration. See
docs/RELEASING.md for the repeatable acceptance checklist.

Independent project; not affiliated with, sponsored by, or endorsed by Cloudflare.
TunnelBar is MIT licensed. Cloudflared is installed separately under its own license.
