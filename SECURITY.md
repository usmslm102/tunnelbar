# Security policy

TunnelBar is pre-release software. Security fixes target the latest commit on
`main`; there are no separately maintained release branches or response-time
guarantees.

## Reporting a vulnerability

Do not post exploit details, credentials, private tunnel URLs, or email allowlists
in a public issue. Use GitHub's **Report a vulnerability** option on this
repository's Security tab when available. If private reporting is unavailable,
open an issue asking the maintainer for a private reporting channel without
including vulnerability details.

A useful private report includes affected versions, reproduction steps with
synthetic data, impact, and a possible mitigation. Never include live secrets.

## Security boundaries

- Every share created by the app must use cloudflared's `--allowed-mail` gate.
  Unsupported versions are blocked; there is no public fallback.
- Cloudflare and cloudflared implement email authentication and TLS. This app
  does not independently implement or verify the provider's authentication.
- Allowed emails and recent share settings are saved in macOS UserDefaults,
  which is not encrypted credential storage. Clear recent shares when needed.
- The app uses an installed executable outside the App Sandbox. Choose a trusted
  cloudflared binary; selecting another executable runs that program as your user.
- Only processes launched by the app are stopped. Force-quit or crashes may leave
  a connector running; inspect Activity Monitor if termination was abnormal.
- A local service can remain reachable through its own listening interface or
  other tunnels. An email gate on this share does not secure those other routes.
- A Quick Tunnel's hostname is temporary. Do not treat secrecy of the URL as an
  access-control mechanism.

Live email delivery and an authenticated browser session have not yet been
verified for the initial implementation. Before publishing a release, complete
the manual checks in [docs/RELEASING.md](docs/RELEASING.md).
