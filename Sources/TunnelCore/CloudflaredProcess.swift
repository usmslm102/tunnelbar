import Foundation
import Darwin

@MainActor
public final class CloudflaredProcess {
    private let process = Process()
    private var timeoutWork: DispatchWorkItem?
    private var stopping = false
    private var lifetimePipe: Pipe?
    private let guardianURL: URL?
    private var exitWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasStarted = false
    private var hasFinished = false
    public var isRunning: Bool { process.isRunning }
    public init(guardianURL: URL? = CloudflaredProcess.findGuardian()) { self.guardianURL = guardianURL }

    public nonisolated static func findGuardian(relativeTo executable: URL? = nil) -> URL? {
        var folder = (executable ?? Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
            .standardizedFileURL.deletingLastPathComponent()
        // SwiftPM test runners may live inside an .xctest bundle beside the helper.
        for _ in 0..<5 {
            let candidate = folder.appendingPathComponent("TunnelGuardian")
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
            folder.deleteLastPathComponent()
        }
        return nil
    }

    public func start(binary: String, arguments: [String], timeout: TimeInterval? = nil,
               onError: ((String) -> Void)? = nil,
               onLine: @escaping (String) -> Void,
               onExit: @escaping (Int32, Bool) -> Void) throws {
        let pipe = Pipe()
        guard let guardianURL else {
            throw TunnelError.message("TunnelGuardian is missing. Rebuild the complete TunnelBar app before sharing.")
        }
        let lifetime = Pipe()
        guard fcntl(lifetime.fileHandleForWriting.fileDescriptor, F_SETFD, FD_CLOEXEC) != -1 else {
            throw TunnelError.message("Cannot protect the connector lifetime pipe.")
        }
        process.executableURL = guardianURL
        process.arguments = [binary] + arguments
        // Do not inherit shell tunnel flags or tokens that could override the requested share.
        process.environment = ProcessInfo.processInfo.environment.filter {
            !$0.key.hasPrefix("TUNNEL_") && !$0.key.hasPrefix("CLOUDFLARED_")
        }
        process.standardOutput = pipe
        let errorPipe = onError == nil ? pipe : Pipe()
        process.standardError = errorPipe
        process.standardInput = lifetime
        try process.run()
        hasStarted = true
        lifetimePipe = lifetime
        lifetime.fileHandleForReading.closeFile()
        if let timeout {
            let work = DispatchWorkItem { [weak self] in self?.stop() }
            timeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
        }
        let child = process
        let group = DispatchGroup()
        var streams: [(Pipe, (String) -> Void)] = [(pipe, onLine)]
        if let onError { streams.append((errorPipe, onError)) }
        for (stream, callback) in streams {
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                defer { group.leave() }
                var buffer = LineBuffer()
                while true {
                    let data = stream.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    for line in buffer.append(data) {
                        DispatchQueue.main.async { callback(line) }
                    }
                }
                for line in buffer.finish() { DispatchQueue.main.async { callback(line) } }
            }
        }
        group.notify(queue: .global(qos: .utility)) {
            child.waitUntilExit()
            let code = child.terminationStatus
            DispatchQueue.main.async { [self] in
                timeoutWork?.cancel()
                lifetimePipe?.fileHandleForWriting.closeFile()
                lifetimePipe = nil
                onExit(code, stopping)
                hasFinished = true
                for waiter in exitWaiters { waiter.resume() }
                exitWaiters.removeAll()
            }
        }
    }

    public func stop() {
        stopping = true
        guard process.isRunning else { return }
        // The helper also sees EOF if this app crashes or is killed with SIGKILL.
        lifetimePipe?.fileHandleForWriting.closeFile()
        lifetimePipe = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [self] in
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    public func stopAndWait() async {
        stop()
        // Always wait for pipe draining/onExit, even if the OS child already exited.
        if hasStarted && !hasFinished {
            await withCheckedContinuation { exitWaiters.append($0) }
        }
    }
}
