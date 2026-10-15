# Manual email authentication acceptance check

Status: **not completed**. An HTTP login page does not establish email delivery,
allowed-user authentication, or denial of unlisted emails. Unit tests and CI do
not make those claims. Cloudflare controls these provider-side behaviors.

Use an inbox you own and a disposable local service. Do not test by exposing a
real project, home directory, or production service. Do not commit addresses,
one-time codes, login URLs, or session cookies as evidence.

1. Create a temporary folder containing only a synthetic `index.html`, then serve
   that folder on an unused local port with `python3 -m http.server <port>
   --bind 127.0.0.1 --directory <temporary-folder>`.
2. Start TunnelBar with a current cloudflared, keep **Require email** on, and add
   only the inbox you control. Create a protected link.
3. Open it in a fresh browser profile or private window. Verify the synthetic
   origin content is not visible before authentication.
4. Enter the allowed email, receive the one-time code, submit it, and verify the
   synthetic page becomes visible. Check a new unauthenticated browser session
   remains gated. Do not record the code.
5. Use a separate inbox you control that is not on the allowlist. Verify it
   cannot reach the origin, including after trying the email flow.
6. Stop the share; verify both the authenticated session and a fresh session
   cannot reach the origin. Restart and repeat with a new URL.
7. Create an explicitly anonymous link to the same disposable fixture. Verify
   fresh visitors reach it without email sign-in and Stop ends access.
8. Restart a share and force-quit only the app. Verify access ends after the
   guardian's grace period. Do not kill the guardian during this check.
9. Stop the local server and remove only the temporary fixture folder.

Record the date, app commit, macOS/cloudflared versions, test cases and pass/fail
results in a private release note. Keep any redacted screenshots free of live
links, email addresses, codes, cookies, and account identifiers. Until those
results exist, describe email authentication as implemented but not fully
verified end-to-end.
