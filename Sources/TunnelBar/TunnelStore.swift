import AppKit
import Combine
import TunnelCore

enum ShareState: String {
    case starting = "Starting", connected = "Connected", reconnecting = "Reconnecting"
    case stopping = "Stopping", stopped = "Stopped", failed = "Failed"
}

struct LiveShare: Identifiable {
    let share: Share
    var state: ShareState = .starting
    var url: URL?
    var logs: [String] = []
    var id: UUID { share.id }
}

@MainActor
final class TunnelStore: ObservableObject {
    @Published var sessions: [LiveShare] = []
    @Published var recent: [Share] = []
    @Published var tunnels: [AccountTunnel] = []
    @Published var binary: String
    @Published var version = "Checking cloudflared…"
    @Published var supportsEmailGate = false
    @Published var error: String?
    @Published var accountMessage: String?
    @Published var refreshing = false
    @Published var defaultEmails: String {
        didSet { sharePreferences.emails = defaultEmails }
    }
    @Published var selectedLog: UUID?
    @Published var inspected = false
    private var processes: [UUID: CloudflaredProcess] = [:]
    private var commands: [UUID: CloudflaredProcess] = [:]
    private let defaults = UserDefaults.standard
    private let sharePreferences = SharePreferences()
    private var refreshTimer: Timer?
    private let configURL: URL
    private var shuttingDown = false

    var activeCount: Int { sessions.filter { [.starting, .connected, .reconnecting, .stopping].contains($0.state) }.count }

    init() {
        let saved = UserDefaults.standard.string(forKey: "binary")
        binary = saved ?? ["/opt/homebrew/bin/cloudflared", "/usr/local/bin/cloudflared", "/usr/bin/cloudflared"]
            .first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/cloudflared"
        defaultEmails = SharePreferences().emails
        if let data = UserDefaults.standard.data(forKey: "recentShares"),
           let shares = try? JSONDecoder().decode([Share].self, from: data) { recent = shares }
        configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelBar-\(UUID().uuidString).yml")
        do {
            // Isolate Quick Tunnels from a user's named-tunnel ingress configuration.
            try Data("{}\n".utf8).write(to: configURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        } catch { self.error = "Cannot prepare tunnel configuration: \(error.localizedDescription)" }
    }

    func boot() {
        Task { await inspect(); await refresh() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    private func command(_ arguments: [String], timeout: TimeInterval = 25) async throws -> String {
        guard !shuttingDown else { throw TunnelError.message("TunnelBar is closing.") }
        let id = UUID()
        let runner = CloudflaredProcess()
        commands[id] = runner
        defer { commands.removeValue(forKey: id) }
        return try await withCheckedThrowingContinuation { continuation in
            var output = ""
            var diagnostics = ""
            do {
                try runner.start(binary: binary, arguments: arguments, timeout: timeout, onError: { line in
                    diagnostics = String((diagnostics + line + "\n").suffix(4000))
                }) { line in
                    if output.utf8.count < 4_000_000 { output += line + "\n" }
                } onExit: { code, stopped in
                    if stopped {
                        continuation.resume(throwing: TunnelError.message("cloudflared timed out. Check your connection and try again."))
                    } else if code == 0 { continuation.resume(returning: output) }
                    else { continuation.resume(throwing: TunnelError.message(String((diagnostics + output).suffix(2000)))) }
                }
            } catch { continuation.resume(throwing: error) }
        }
    }

    func inspect() async {
        supportsEmailGate = false
        inspected = false
        do {
            guard FileManager.default.isExecutableFile(atPath: binary) else {
                throw TunnelError.message("cloudflared was not found. Choose its executable in Settings.")
            }
            version = try await command(["--version"]).trimmingCharacters(in: .whitespacesAndNewlines)
            let help = try await command(["tunnel", "--help"])
            supportsEmailGate = help.contains("--allowed-mail")
            if !supportsEmailGate { error = "Update cloudflared to a version with --allowed-mail to create email-protected shares." }
        } catch { version = "cloudflared unavailable"; self.error = error.localizedDescription }
        inspected = true
    }

    func refresh() async {
        guard !refreshing, inspected, version != "cloudflared unavailable" else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let output = try await command(["tunnel", "list", "--output", "json"])
            tunnels = try TunnelOutput.accountTunnels(Data(output.utf8))
            accountMessage = nil
        } catch {
            tunnels = []
            let message = error.localizedDescription
            accountMessage = message.contains("cert.pem") || message.contains("origin cert")
                ? "No cloudflared CLI account certificate found. Quick shares work without an account."
                : "Couldn’t refresh account tunnels. \(message)"
        }
    }

    func start(_ share: Share) {
        guard !shuttingDown else { return }
        guard inspected, version != "cloudflared unavailable" else {
            error = "Choose an available cloudflared executable before sharing."; return
        }
        guard !share.requiresEmail || supportsEmailGate else {
            error = "This cloudflared version does not support email gates. Update it or explicitly choose anonymous sharing."; return
        }
        guard !sessions.contains(where: { $0.share.port == share.port && ![.failed, .stopped].contains($0.state) }) else {
            error = "Port \(share.port) already has an active share. Stop it before changing access."; return
        }
        let runner = CloudflaredProcess()
        sessions.insert(LiveShare(share: share), at: 0)
        processes[share.id] = runner
        do {
            try runner.start(binary: binary, arguments: share.arguments(config: configURL.path)) { [weak self] line in
                self?.receive(line, for: share.id)
            } onExit: { [weak self] code, stopped in
                guard let self else { return }
                self.processes.removeValue(forKey: share.id)
                guard let index = self.sessions.firstIndex(where: { $0.id == share.id }) else { return }
                self.sessions[index].state = stopped || code == 0 ? .stopped : .failed
                self.sessions[index].url = nil
                if !stopped && code != 0 {
                    self.error = "Share on port \(share.port) stopped unexpectedly. Open its logs for details."
                }
            }
            sharePreferences.remember(share)
            if share.requiresEmail { defaultEmails = sharePreferences.emails }
            recent.removeAll { $0.port == share.port && $0.emails == share.emails && $0.useHTTPS == share.useHTTPS && $0.requiresEmail == share.requiresEmail }
            recent.insert(share, at: 0)
            recent = Array(recent.prefix(8))
            defaults.set(try? JSONEncoder().encode(recent), forKey: "recentShares")
        } catch {
            sessions.removeAll { $0.id == share.id }; processes.removeValue(forKey: share.id)
            self.error = error.localizedDescription
        }
    }

    private func receive(_ line: String, for id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].logs = Array((sessions[index].logs + [line]).suffix(150))
        if let url = TunnelOutput.quickURL(in: line) { sessions[index].url = url }
        if sessions[index].state != .stopping {
            if TunnelOutput.isConnected(line) { sessions[index].state = .connected }
            else if line.contains("Retrying connection") || line.contains("Connection terminated") {
                sessions[index].state = .reconnecting
            }
        }
    }

    func stop(_ id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }), processes[id] != nil {
            sessions[index].state = .stopping
            processes[id]?.stop()
        }
    }

    func dismiss(_ id: UUID) { sessions.removeAll { $0.id == id } }
    func forget(_ id: UUID) {
        recent.removeAll { $0.id == id }
        defaults.set(try? JSONEncoder().encode(recent), forKey: "recentShares")
    }
    func saveBinary(_ path: String) {
        binary = path
        defaults.set(path, forKey: "binary")
        Task { await inspect(); await refresh() }
    }
    func shutdown() async {
        shuttingDown = true
        refreshTimer?.invalidate()
        let runners = Array(processes.values) + Array(commands.values)
        await withTaskGroup(of: Void.self) { group in
            for runner in runners { group.addTask { await runner.stopAndWait() } }
        }
        try? FileManager.default.removeItem(at: configURL)
    }
}
