# Security policy

Security fixes target the latest release and the latest commit on
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

- Email protection is on by default and uses cloudflared's `--allowed-mail` gate.
  Unsupported versions cannot start a protected share; there is no automatic
  public fallback. Turning off **Require email** explicitly creates an anonymous
  link accessible to anyone with the URL. The form restores email protection
  after creation and when reusing recent shares. Saved emails survive anonymous
  sharing. Older saved shares without an access-mode field stay protected.
- Cloudflare and cloudflared implement email authentication and TLS. This app
  does not independently implement or verify the provider's authentication.
- Allowed emails and recent share settings are saved in macOS UserDefaults,
  which is not encrypted credential storage. Clear recent shares when needed.
- The app uses an installed executable outside the App Sandbox. Choose a trusted
  cloudflared binary; selecting another executable runs that program as your user.
- A bundled guardian stops its owned connector process group when the app lifetime
  pipe closes, including app SIGKILL/crash. It sends SIGTERM and escalates to
  SIGKILL after three seconds. It cannot protect against someone also killing
  the guardian itself. It never targets external cloudflared instances.
- The guardian must be bundled with the app; connector launch fails closed if it
  is missing. Graceful shutdown waits for exit before removing shared config.
- A local service can remain reachable through its own listening interface or
  other tunnels. An email gate on this share does not secure those other routes.
- A Quick Tunnel's hostname is temporary. Do not treat secrecy of the URL as an
  access-control mechanism.

The maintainer reported successful manual testing before publishing v1.0.0.
Cloudflare controls provider-side email delivery and authentication. No Apple Developer account is required: builds are intentionally ad-hoc signed,
with Developer ID signing and notarization left optional. Gatekeeper may require
additional user action for a downloaded app. Before publishing a release, complete
the manual checks in [docs/RELEASING.md](docs/RELEASING.md).
