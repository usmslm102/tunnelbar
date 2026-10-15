# Contributing to TunnelBar

TunnelBar is an early-stage native macOS app. Keep contributions small, focused,
and consistent with system controls and the email-protected sharing workflow.

## Development

Use macOS 13 or later and Swift 6.0 or later, supplied by Xcode or Apple's Command
Line Tools. The app uses Swift 5 language mode. Tests use the pinned official Swift Testing source package and its SwiftSyntax
macro dependency. SwiftPM resolves them on first build; they are not linked into
the shipped app. Cloudflared is needed only for live use.

```sh
swift test
./scripts/test.sh # includes disposable-process lifecycle integration checks
bash scripts/build-app.sh
open dist/TunnelBar.app --args --show
```

The scripts keep compiler caches and build intermediates in the current user's
temporary directory. Set `TUNNELBAR_BUILD_PATH` to choose a build directory.

`Sources/TunnelCore` contains validation, CLI output parsing, and process control.
`Sources/TunnelBar` contains the SwiftUI panel, AppKit lifecycle, and app state.
`Sources/TunnelGuardian` contains the C process supervisor.
`Tests/TunnelCoreTests` contains offline Swift tests, and
`Tests/ProcessLifecycleTests` exercises crash cleanup with disposable processes.

## Pull requests

- Describe the problem and resulting behavior, and link an issue when relevant.
- Run the tests and app build. Add tests for meaningful behavior changes.
- Include screenshots for UI changes, using synthetic ports, URLs, and emails.
- Preserve email gating by default, sticky email preferences, explicit anonymous
  opt-in, direct process argument passing, and ownership of child processes. Never
  silently fall back to a public tunnel.
- Do not commit credentials, cloudflared certificates, logs, private hostnames,
  real email allowlists, generated apps, or signing material.
- Avoid dependencies and custom UI where native APIs suffice.

CI tests and builds the app without signing credentials or cloudflared. Live
network tests are deliberately opt-in. `python3 scripts/smoke-test.py` exposes
only its own synthetic fixture, verifies the anonymous email gate, and cleans
up. It requires network access and a cloudflared with `--allowed-mail` support;
it does not verify email delivery or complete an authenticated visitor session.

## Reporting bugs

Include macOS, Swift, and cloudflared versions, reproduction steps, and expected
versus actual behavior. Redact emails, tunnel URLs, account identifiers, login
links, and credentials from logs. Follow [SECURITY.md](SECURITY.md) for security
issues and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community expectations.

Contributions are provided under the repository's [MIT license](LICENSE).
