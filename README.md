# TunnelBar

A native **Cloudflared Tunnel UI for macOS**, built with SwiftUI and AppKit. Share a local HTTP service through an email-protected link, view your account tunnels, and stop sharing from the menu bar.

Development preview: the source is open under the MIT license; no public binary release has been tagged. This is an independent project, not affiliated with or endorsed by Cloudflare. Cloudflared is installed separately and remains under its own license.

## Requirements

- macOS 13 or later.
- Swift 6.0 or later from Xcode or Apple's Command Line Tools to build and test. The package uses Swift 5 language mode.
- An installed `cloudflared` with `--allowed-mail` support for live sharing (verified with 2026.10.0). The app checks capability at startup.

## Open the app

Build with Apple's Command Line Tools or Xcode. The app has no external runtime dependencies beyond cloudflared. Tests use the pinned official Swift Testing source package (and its SwiftSyntax macro dependency); SwiftPM needs network access on first resolution:

```sh
bash scripts/build-app.sh
open dist/TunnelBar.app --args --show
```

You can drag `dist/TunnelBar.app` to Applications. It runs in the menu bar without a Dock icon. The build is signed locally, not notarized for distribution.

For a Universal 2 build containing both Apple silicon and Intel slices (including the guardian):

```sh
TUNNELBAR_ARCH=universal ./scripts/build-app.sh
```

The default builds for the host architecture. Ad-hoc signing is supported intentionally; no Apple Developer account is required. Downloaded builds may trigger Gatekeeper because they are not Developer ID signed or notarized.

## Share a port

1. Start your local HTTP service.
2. Click the network icon in the menu bar.
3. Enter the port and the full email addresses allowed to visit.
4. Click **Create protected link**. Once connected, copy or open the link.

The **Require email** switch is on by default. Allowed emails are remembered as you edit them and prefilled on the next launch. With the switch on, visitors authenticate using a one-time code sent to an allowed email. Turn it off to create an **anonymous link**, which anyone with the URL can access without signing in. The form restores email protection after you create a link; anonymous shares do not erase your saved emails. HTTPS in the form describes the connection to your **local** server; public links always use HTTPS. Local HTTPS certificates must be trusted by cloudflared.

Links use temporary `trycloudflare.com` hostnames. Stop ends that connector; restarting creates a new URL. Keep the app open while sharing. Normal quit stops every connector started by TunnelBar. Other cloudflared processes and system services are left alone. A bundled process guardian also stops the owned connector if the app crashes or receives SIGKILL. It gives the connector three seconds to exit, then kills its process group. Killing the guardian itself is outside this guarantee.

Recent shares save the port, local protocol, access mode, and email allowlist on this Mac. **Reuse** fills the form with email protection enabled, including when reusing an anonymous share. Review the addresses before starting again. Remove an entry with its × button, or clear all entries in Settings.

## Account tunnels

Quick shares need no account, domain, or API token. The collapsed **Account tunnels (optional)** section reads the native cloudflared CLI credentials; TunnelBar does not create or manage an account session.

To connect a CLI account, run `cloudflared tunnel login` in Terminal, select and authorize the relevant domain in the browser, and wait for the CLI to save its account certificate (normally `~/.cloudflared/cert.pem`). Signing in to the Cloudflare dashboard alone does not finish that authorization. Return to TunnelBar and refresh the list. The panel offers a copyable command rather than launching a browser login and waiting indefinitely. Existing CLI credentials work automatically; the list refreshes every 30 seconds.

Account entries show Cloudflare connection status, including connectors running on other machines. You can copy their IDs and open the Cloudflare dashboard to manage their routing and Access policies. Named tunnels are listed, not started, stopped, or reconfigured by TunnelBar. Quick Tunnels created outside this app cannot be discovered through the named-tunnel API.

## Implementation

- Native `NSStatusItem` and `NSPopover` hosting SwiftUI, with system controls, fonts, colors, and light/dark appearance.
- Detects Homebrew's Apple Silicon and Intel cloudflared locations; Settings supports another executable.
- Checks the installed binary's help for email-gate support before enabling protected sharing. Anonymous sharing is an explicit option, never an automatic fallback.
- Email-protected Quick Tunnels pass an explicit `--allowed-mail` for every allowed address. Explicitly anonymous shares omit that flag.
- Arguments go straight to `Process`, never through a shell.
- An isolated empty configuration prevents existing named-tunnel ingress from affecting Quick Tunnels. Inherited `TUNNEL_*` and `CLOUDFLARED_*` environment variables are removed; GUI launches use cloudflared's standard certificate locations.
- Cloudflared output is drained in the background, with separate stdout/stderr for structured commands. Logs are bounded in memory. Link creation and actual connector readiness are tracked separately.
- A separate bundled guardian owns each connector process group. Closing the app lifetime pipe, including on app SIGKILL, sends SIGTERM, followed by SIGKILL after three seconds if needed. Graceful app shutdown awaits process exit before deleting the temporary configuration.
- No app telemetry, server, API keys, or additional runtime libraries. The guardian is built from the C source in this repository.

## Verification

```sh
swift test
# Also run subprocess crash/lifetime integration checks:
./scripts/test.sh
```

Tests cover default email protection, explicit anonymous arguments, sticky email preferences, legacy saved-share migration, input validation, safe argument passing, split output parsing, account status, persistence, stdout/stderr draining, child-process timeout, shutdown completion, and missing-guardian handling. The integration checks exercise parent SIGKILL, lifetime-pipe closure, and stubborn-child termination using disposable processes. Live email delivery requires a real allowed inbox; unit tests do not send mail or expose a local service.

An optional live smoke test creates an isolated synthetic HTTP server, starts a protected tunnel with a reserved example email, checks that anonymous access gets an email sign-in page, and stops both processes:

```sh
python3 scripts/smoke-test.py
```

CI runs offline tests, builds and verifies the app bundle, and uploads a development artifact. It does not run public tunnels. Full email delivery, authenticated browser access, Intel execution, and visual acceptance checks are still pending for the initial implementation; see the [release checklist](docs/RELEASING.md). Quick Tunnels require working DNS and outbound connectivity to Cloudflare.

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
