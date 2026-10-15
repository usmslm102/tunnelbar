# Release checklist

The repository is private during development. This checklist does not publish
anything automatically; repository visibility and releases are maintainer actions.

Before the first public release:

- Review the source and full Git history for credentials and private data.
- Confirm the MIT license, copyright attribution, name, and bundle identifier.
- Verify CI is green on the release commit and review dependency update PRs.
- Test the packaged app on both Apple Silicon and Intel if claiming support for
  both. The build script produces a binary for the build host, not a universal app.
- Check the panel in light/dark mode, VoiceOver labels, keyboard navigation,
  startup without cloudflared, and account sign-in/list refresh.
- Verify a real browser receives an email code, an allowed email can enter, an
  unlisted email cannot enter, and Stop/Quit end access. Use a disposable local
  service and never publish a real allowlist in screenshots or logs.
- Test missing network access, DNS failures, local server failure, reconnects,
  and an unsupported cloudflared version. Confirm no ungated fallback occurs.
- Enable GitHub private vulnerability reporting when the repository supports it
  and verify a private maintainer contact route.
- Consider branch rules requiring the `test-and-build` check and review of changes
  to process control and authentication-related arguments.
- Set a release version in `Resources/Info.plist`; document user-visible changes.
- Build, verify the signature, and archive with `ditto` to preserve app metadata.
- For distribution to other Macs, use a Developer ID signature and notarization.
  The current build uses ad-hoc local signing and is not a notarized release.
- Publish architecture-labelled artifacts and checksums only after validation.

CI uploads a short-lived development artifact. It does not create a GitHub release,
change visibility, use signing secrets, or run a public tunnel.
