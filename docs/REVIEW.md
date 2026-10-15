# Release readiness review

The maintainer approved stable v1.0.0 publication after reporting successful
manual testing on 2026-10-16. The findings below document the original preview review. Source merge readiness and production
acceptance are different decisions; passing offline checks does not establish
provider email delivery or readiness for production traffic.

| Finding | Assessment and action |
| --- | --- |
| Bare `swift test` fails | Reproduced. Raising tools version alone did not fix this CLT installation. The package now requires Swift 6.0 and explicitly depends on the pinned official Swift Testing source for tests. Framework search flags were removed. |
| Scripts are not executable | Genuine usability issue. Shell and Python entry points now have executable permissions. The icon generator remains an interpreter-invoked Swift source file. |
| Ad-hoc signing prevents production merge | Distribution limitation, not an inherent source-merge blocker. Ad-hoc signing is intentional and accepted for this project. Gatekeeper behavior is disclosed. Paid Developer ID signing/notarization is optional. |
| OTP/email delivery not verified | Genuine remaining acceptance gap. No successful browser/email session is claimed. The manual acceptance procedure is in `EMAIL_VERIFICATION.md`. |
| Child survives app crash/SIGKILL | Genuine. A bundled C guardian watches the parent's lifetime pipe, owns a separate child process group, and terminates it on EOF, escalating after three seconds. Tests kill disposable parents and exercise stubborn children. Killing the guardian itself is outside this guarantee. |
| Config removed before child exit | Genuine ordering issue. Shutdown blocks new launches, stops and awaits all owned runners, and then deletes the shared temporary config. |
| macOS 13 app vs macOS 14 Testing.framework | The warning was test-only; the app never linked Testing.framework. Building the official test dependency from source removes that framework dependency and its deployment warning while keeping the app's macOS 13 target. Actual macOS 13 acceptance remains unverified. |
| Host-only build | Valid architecture-specific packaging, not inherently a blocker. An optional Universal 2 build now combines arm64/x86_64 for both app and guardian. Cross-compilation and slice checks do not substitute for Intel runtime testing. |
| Deprecated activation API | Genuine cleanup. macOS 14+ uses `NSApp.activate()`, with the older call retained only for macOS 13 compatibility. |

The test-only Swift Testing release is pinned to its upstream 6.0.3 commit; its
macro dependency is recorded in `Package.resolved`. Neither Testing nor SwiftSyntax
is linked into the app or guardian. Initial dependency resolution needs network
access. The static site and binary releases are now published through GitHub Actions.
Offline checks alone do not establish provider-side behavior or hardware coverage.

Local validation: bare `swift test` ran 19 passing tests; three disposable-process
integration tests passed for both the debug and packaged guardian. Universal 2
slice checks, nested code signature verification, ZIP/checksum checks, and the
static site's desktop/mobile interaction checks passed. App runtime libraries
were inspected and do not include Testing or SwiftSyntax. This evidence does not
complete the manual OTP, Intel execution, or macOS 13 acceptance checks.
