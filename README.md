# TunnelBar

A native **Cloudflared Tunnel UI for macOS**, built with SwiftUI and AppKit. Share a local HTTP service through an email-protected link, view your account tunnels, and stop sharing from the menu bar.

Early-stage software: no notarized public release yet. This is an independent project, not affiliated with or endorsed by Cloudflare. Cloudflared is installed separately and remains under its own license.

## Requirements

- macOS 13 or later.
- Swift 6.0 or later from Xcode or Apple's Command Line Tools to build and test. The package uses Swift 5 language mode.
- An installed `cloudflared` with `--allowed-mail` support for live sharing (verified with 2026.10.0). The app checks capability at startup.

## Open the app

Build with Apple's Command Line Tools or Xcode; there are no third-party dependencies:

```sh
bash scripts/build-app.sh
open dist/TunnelBar.app --args --show
```

You can drag `dist/TunnelBar.app` to Applications. It runs in the menu bar without a Dock icon. The build is signed locally, not notarized for distribution.

## Share a port

1. Start your local HTTP service.
2. Click the network icon in the menu bar.
3. Enter the port and the full email addresses allowed to visit.
4. Click **Create protected link**. Once connected, copy or open the link.

Visitors authenticate using a one-time code sent to an allowed email. There is no public-share mode. HTTPS in the form describes the connection to your **local** server; public links always use HTTPS. Local HTTPS certificates must be trusted by cloudflared.

Links use temporary `trycloudflare.com` hostnames. Stop ends that connector; restarting creates a new URL. Keep the app open while sharing. Normal quit stops every connector started by TunnelBar. Other cloudflared processes and system services are left alone. Force-quitting the app or a crash may leave a child process running; use Activity Monitor to stop that process.

Recent shares save the port, local protocol, and email allowlist on this Mac. **Reuse** fills the form so you can review the addresses before starting again. Remove an entry with its × button, or clear all entries in Settings.

## Account tunnels

Quick shares need no account, domain, or API token. To see existing named tunnels, use **Sign in to Cloudflare**. This runs `cloudflared tunnel login` and uses its existing login certificate if one is available. Select the relevant account/domain in the browser. The account list refreshes every 30 seconds, showing all named tunnels returned by `cloudflared tunnel list --output json` for that login.

Account entries show Cloudflare connection status, including connectors running on other machines. You can copy their IDs and open the Cloudflare dashboard to manage their routing and Access policies. Named tunnels are listed, not started, stopped, or reconfigured by TunnelBar. Quick Tunnels created outside this app cannot be discovered through the named-tunnel API.

## Implementation

- Native `NSStatusItem` and `NSPopover` hosting SwiftUI, with system controls, fonts, colors, and light/dark appearance.
- Detects Homebrew's Apple Silicon and Intel cloudflared locations; Settings supports another executable.
- Checks the installed binary's help for email-gate support before enabling creation.
- Every Quick Tunnel passes an explicit `--allowed-mail` for every allowed address.
- Arguments go straight to `Process`, never through a shell.
- An isolated empty configuration prevents existing named-tunnel ingress from affecting Quick Tunnels. Inherited `TUNNEL_*` and `CLOUDFLARED_*` environment variables are removed; GUI launches use cloudflared's standard certificate locations.
- Cloudflared output is drained in the background, with separate stdout/stderr for structured commands. Logs are bounded in memory. Link creation and actual connector readiness are tracked separately.
- Stop sends SIGTERM, with SIGKILL after four seconds if the child fails to stop. The app only controls processes it launched.
- No telemetry, server, API keys, or additional dependencies.

## Verification

```sh
bash scripts/test.sh
```

Tests cover email-gate enforcement, input validation, safe argument passing, split output parsing, account status, persistence, stdout/stderr draining, and child-process timeout. Live email delivery requires a real allowed inbox; unit tests do not send mail or expose a local service.

An optional live smoke test creates an isolated synthetic HTTP server, starts a protected tunnel with a reserved example email, checks that anonymous access gets an email sign-in page, and stops both processes:

```sh
python3 scripts/smoke-test.py
```

CI runs offline tests, builds and verifies the app bundle, and uploads a development artifact. It does not run public tunnels. Full email delivery, authenticated browser access, and visual acceptance checks are still pending for the initial implementation; see the [release checklist](docs/RELEASING.md). Quick Tunnels require working DNS and outbound connectivity to Cloudflare.

Cloudflare references: [Quick Tunnels and email gates](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/), [named tunnels](https://developers.cloudflare.com/tunnel/get-started/).

## Static website

The unpublished landing page lives in [`site/`](site/README.md). Build a standalone
site bundle with an actual development download for the host Mac:

```sh
bash scripts/build-site.sh
open dist/site/index.html
```

No hosting, Pages deployment, or public release is enabled. The output includes
relative download links and SHA-256 checksums. See the site README for preview
and multi-architecture packaging instructions.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and pull request guidance, [SECURITY.md](SECURITY.md) for vulnerability reporting and security boundaries, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community expectations.

## License

[MIT](LICENSE), copyright 2026 Usama Ansari.
