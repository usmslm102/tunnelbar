# Release checklist

The source repository and stable releases are public.
Tag pushes publish binaries automatically through GitHub Actions. Development
previews may be published while the manual acceptance checks below remain open;
keep their limitations explicit in the release notes. Complete these checks before
claiming a stable production release.

Before a stable release:

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

## Publish a release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in
   `Resources/Info.plist`, and update `docs/RELEASE_NOTES.md` for the release.
2. Merge the changes into `main` and check CI.
3. Tag that commit and push the tag, for example:

   ```sh
   git tag -a v1.0.0-preview.1 -m "TunnelBar 1.0.0 development preview 1"
   git push origin v1.0.0-preview.1
   ```

The Release workflow checks that the tag matches the plist version, runs unit and
process lifecycle tests, builds Universal 2 binaries, verifies signatures and both
architecture slices, and publishes the ZIP, SHA-256 checksum, and MIT license.
A suffix in the tag makes a GitHub prerelease; an unsuffixed tag creates a normal
release. The workflow does not run public tunnels or require signing secrets.
Never move a published tag; fix a failed build before publishing a new version.
If publication fails before creating the release, rerun the failed job. If a
release already exists, inspect its assets before changing or replacing anything.

After a successful Release run, the Static site workflow deploys GitHub Pages with
the published ZIP. Site changes on `main` also redeploy using the existing release.
Use the Static site workflow's manual dispatch to retry deployment. CI continues
to upload short-lived development artifacts independently of release publishing.
