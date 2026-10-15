# Release checklist

The source repository is public, while the app remains a development preview.
This checklist covers binary release acceptance and does not publish anything
automatically; repository visibility, website hosting, and releases are separate
maintainer actions.

Before the first public release:

- Review the source and full Git history for credentials and private data.
- Confirm the MIT license, copyright attribution, name, and bundle identifier.
- Verify CI is green on the release commit and review dependency update PRs.
- Test the packaged app on both Apple Silicon and Intel if claiming support for
  both. `TUNNELBAR_ARCH=universal ./scripts/build-app.sh` produces both slices
  for the app and guardian; cross-compilation alone does not verify Intel execution.
- Check the panel in light/dark mode, VoiceOver labels, keyboard navigation,
  startup without cloudflared, and the optional account list using existing CLI
  credentials or a separately completed Terminal login.
- Verify a real browser receives an email code, an allowed email can enter, an
  unlisted email cannot enter, and Stop/Quit end access. Follow [EMAIL_VERIFICATION.md](EMAIL_VERIFICATION.md). Use a disposable local
  service and never publish a real allowlist in screenshots or logs.
- Verify email defaults survive relaunch and anonymous sharing; email protection
  returns after creation and recent-share reuse. Check that an explicitly
  anonymous link opens without sign-in and is clearly labelled in active shares.
- Verify app SIGKILL/crash stops its connector, a stubborn connector is killed
  after the grace period, and normal shutdown removes config only after exit.
- Test missing network access, DNS failures, local server failure, reconnects,
  and an unsupported cloudflared version. Confirm no ungated fallback occurs.
- Enable GitHub private vulnerability reporting when the repository supports it
  and verify a private maintainer contact route.
- Consider branch rules requiring the `test-and-build` check and review of changes
  to process control and authentication-related arguments.
- Set a release version in `Resources/Info.plist`; document user-visible changes.
- Build, verify the signature, and archive with `ditto` to preserve app metadata.
- Ad-hoc signing is the accepted distribution mode for now; no paid Apple
  Developer account is required. Verify the app and nested guardian signatures,
  and disclose possible Gatekeeper prompts. Developer ID signing and notarization
  are optional future improvements, not a merge or release prerequisite.
- Publish architecture-labelled artifacts and checksums only after validation.

CI uploads a short-lived development artifact. It does not create a GitHub release,
change visibility, use signing secrets, or run a public tunnel.
