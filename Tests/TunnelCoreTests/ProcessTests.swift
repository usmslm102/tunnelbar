import Testing
import Foundation
@testable import TunnelCore

private final class ProcessTestBundle: NSObject {}

@Suite struct ProcessTests {
    @MainActor private func makeRunner() throws -> CloudflaredProcess {
        let url = try #require(CloudflaredProcess.findGuardian(relativeTo: Bundle(for: ProcessTestBundle.self).bundleURL))
        return CloudflaredProcess(guardianURL: url)
    }
    @Test @MainActor func drainsStdoutAndStderrBeforeExit() async throws {
        let runner = try makeRunner()
        var stdout: [String] = []
        var stderr: [String] = []
        let result: (Int32, Bool) = try await withCheckedThrowingContinuation { continuation in
            do {
                try runner.start(binary: "/bin/sh", arguments: ["-c", "printf 'first\\nlast'; printf 'warning\\n' >&2"], timeout: 3, onError: {
                    stderr.append($0)
                }, onLine: { stdout.append($0) }, onExit: { code, stopped in
                    continuation.resume(returning: (code, stopped))
                })
            } catch { continuation.resume(throwing: error) }
        }
        #expect(result.0 == 0)
        #expect(!result.1)
        #expect(stdout == ["first", "last"])
        #expect(stderr == ["warning"])
    }

    @Test @MainActor func timeoutStopsChild() async throws {
        let runner = try makeRunner()
        let stopped: Bool = try await withCheckedThrowingContinuation { continuation in
            do {
                try runner.start(binary: "/bin/sleep", arguments: ["30"], timeout: 0.1,
                                 onLine: { _ in }, onExit: { _, stopped in
                    continuation.resume(returning: stopped)
                })
            } catch { continuation.resume(throwing: error) }
        }
        #expect(stopped)
        #expect(!runner.isRunning)
    }

    @Test @MainActor func argumentsNeverGoThroughShell() async throws {
        let runner = try makeRunner()
        let literal = "$(whoami); `id`"
        var lines: [String] = []
        let code: Int32 = try await withCheckedThrowingContinuation { continuation in
            do {
                try runner.start(binary: "/usr/bin/printf", arguments: ["%s\\n", literal], timeout: 3, onLine: { lines.append($0) }, onExit: { code, _ in
                    continuation.resume(returning: code)
                })
            } catch { continuation.resume(throwing: error) }
        }
        #expect(code == 0)
        #expect(lines == [literal])
    }

    @Test @MainActor func stopAndWaitCompletesExitBeforeReturning() async throws {
        let runner = try makeRunner()
        var exited = false
        try runner.start(binary: "/bin/sleep", arguments: ["30"], onLine: { _ in }, onExit: { _, _ in exited = true })
        await runner.stopAndWait()
        #expect(exited)
        #expect(!runner.isRunning)
    }

    @Test @MainActor func missingGuardianFailsClosed() {
        let runner = CloudflaredProcess(guardianURL: nil)
        #expect(throws: (any Error).self) {
            try runner.start(binary: "/bin/sleep", arguments: ["30"], onLine: { _ in }, onExit: { _, _ in })
        }
        #expect(!runner.isRunning)
    }
}
