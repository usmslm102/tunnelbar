import Foundation

public struct Share: Codable, Identifiable, Equatable {
    public var id: UUID
    public var port: Int
    public var emails: [String]
    public var useHTTPS: Bool

    public init(port: String, emails: String, useHTTPS: Bool = false) throws {
        guard let number = Int(port), (1...65535).contains(number) else {
            throw TunnelError.message("Enter a port between 1 and 65535.")
        }
        let addresses = emails.components(separatedBy: CharacterSet(charactersIn: ",;\n "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !addresses.isEmpty else {
            throw TunnelError.message("Add at least one allowed email. Every share requires email authentication.")
        }
        for address in addresses {
            // Deliberately accept exact email addresses only; no wildcard access.
            let pattern = #"^[A-Za-z0-9.!#$%&'+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$"#
            guard address.range(of: pattern, options: .regularExpression) != nil else {
                throw TunnelError.message("Invalid email: \(address). Use full email addresses separated by commas.")
            }
        }
        id = UUID()
        self.port = number
        self.emails = Array(Set(addresses)).sorted()
        self.useHTTPS = useHTTPS
    }

    public var origin: String { "\(useHTTPS ? "https" : "http")://localhost:\(port)" }

    public func arguments(config: String) -> [String] {
        ["tunnel", "--config", config, "--no-autoupdate", "--metrics", "127.0.0.1:0",
         "--grace-period", "2s", "--url", origin] + emails.flatMap { ["--allowed-mail", $0] }
    }
}

public enum TunnelError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}

public struct AccountTunnel: Decodable, Identifiable {
    public let id: String
    public let name: String
    public let connections: [Connection]?
    public let status: String?
    public let remote_config: Bool?

    public struct Connection: Decodable {
        public let is_pending_reconnect: Bool?
    }

    public var isConnected: Bool {
        if let status { return status == "healthy" || status == "degraded" }
        return connections?.contains { $0.is_pending_reconnect != true } ?? false
    }
}

public enum TunnelOutput {
    public static func quickURL(in output: String) -> URL? {
        let pattern = #"https://[a-z0-9]+(?:-[a-z0-9]+)*\.trycloudflare\.com\b"#
        guard let range = output.range(of: pattern, options: .regularExpression) else { return nil }
        return URL(string: String(output[range]))
    }

    public static func isConnected(_ line: String) -> Bool {
        line.contains("Registered tunnel connection")
    }

    public static func accountTunnels(_ data: Data) throws -> [AccountTunnel] {
        if String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "null" { return [] }
        return try JSONDecoder().decode([AccountTunnel].self, from: data)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// A bounded stream parser: process callbacks can split both lines and UTF-8 characters.
public struct LineBuffer {
    private var pending = Data()
    public init() {}
    public mutating func append(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: 10) {
            lines.append(String(decoding: pending[..<newline], as: UTF8.self))
            pending.removeSubrange(...newline)
        }
        if pending.count > 65_536 { pending.removeFirst(pending.count - 65_536) }
        return lines
    }
    public mutating func finish() -> [String] {
        defer { pending.removeAll() }
        return pending.isEmpty ? [] : [String(decoding: pending, as: UTF8.self)]
    }
}
