TunnelBar is a native macOS menu bar UI for cloudflared tunnels. Share a local
port, require email by default, remember allowed emails, or explicitly choose
anonymous access. Account tunnels use existing cloudflared CLI credentials.

Download `TunnelBar-macOS-universal.zip` for Apple Silicon or Intel, unzip it,
and move TunnelBar.app to Applications. macOS 13 or later and a separately
installed `cloudflared` are required. The SHA-256 checksum accompanies the ZIP.

This is a development preview. The app is ad-hoc signed and **not notarized**;
macOS may show Gatekeeper prompts. If blocked, review the source and build it
locally, or use macOS Privacy & Security → Open Anyway only if you trust the
download. No Apple Developer account is required to build from source.

Real email-code delivery and browser authentication, physical Intel execution,
and macOS 13 runtime acceptance remain manual checks. Do not rely on this preview
for sensitive or production services. See docs/EMAIL_VERIFICATION.md and
docs/RELEASING.md in the repository for the acceptance checklist.

Independent project; not affiliated with, sponsored by, or endorsed by Cloudflare.
TunnelBar is MIT licensed. Cloudflared is installed separately under its own license.
