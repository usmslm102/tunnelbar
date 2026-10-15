import Foundation
import Darwin

@MainActor
public final class CloudflaredProcess {
    private let process = Process()
    private var timeoutWork: DispatchWorkItem?
    private var stopping = false
    public var isRunning: Bool { process.isRunning }
    public init() {}

    public func start(binary: String, arguments: [String], timeout: TimeInterval? = nil,
               onError: ((String) -> Void)? = nil,
               onLine: @escaping (String) -> Void,
               onExit: @escaping (Int32, Bool) -> Void) throws {
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        // Do not inherit shell tunnel flags or tokens that could override the requested share.
        process.environment = ProcessInfo.processInfo.environment.filter {
            !$0.key.hasPrefix("TUNNEL_") && !$0.key.hasPrefix("CLOUDFLARED_")
        }
        process.standardOutput = pipe
        let errorPipe = onError == nil ? pipe : Pipe()
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice
        try process.run()
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
                onExit(code, stopping)
            }
        }
    }

    public func stop() {
        stopping = true
        guard process.isRunning else { return }
        process.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [self] in
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
}
