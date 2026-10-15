import Foundation
import Testing
@testable import TunnelCore

@Suite struct TunnelCoreTests {
    @Test func protectedArgumentsIncludeEveryAllowedEmail() throws {
        let share = try Share(port: "3000", emails: "Alice@Example.com, bob@example.com;alice@example.com")
        #expect(share.emails == ["alice@example.com", "bob@example.com"])
        let args = share.arguments(config: "/tmp/isolated.yml")
        #expect(Array(args.suffix(4)) == ["--allowed-mail", "alice@example.com", "--allowed-mail", "bob@example.com"])
        #expect(args.contains("http://localhost:3000"))
        #expect(Array(args[1...2]) == ["--config", "/tmp/isolated.yml"])
    }

    @Test func emailGateIsDefaultAndRejectsEmptyOrInvalidAllowlist() {
        for email in ["", "  , ; \n", "*@example.com", "alice", "a@b", "x@example.com --hello-world"] {
            #expect(throws: (any Error).self) { try Share(port: "3000", emails: email) }
        }
    }

    @Test func anonymousSharingRequiresExplicitChoiceAndOmitsEmailFlags() throws {
        let share = try Share(port: "3000", emails: "alice@example.com", requiresEmail: false)
        #expect(!share.requiresEmail)
        #expect(share.emails.isEmpty)
        #expect(!share.arguments(config: "/tmp/config.yml").contains("--allowed-mail"))
        #expect(share.arguments(config: "/tmp/config.yml").contains("http://localhost:3000"))
        #expect(try Share(port: "3000", emails: "alice@example.com").requiresEmail)
        _ = try Share(port: "3000", emails: "", requiresEmail: false)
    }

    @Test func anonymousSharingStillValidatesPort() {
        #expect(throws: (any Error).self) { try Share(port: "0", emails: "", requiresEmail: false) }
    }

    @Test func emailDefaultsSurviveAnonymousShareAndPreferencesReload() throws {
        let suite = "TunnelBarTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = SharePreferences(defaults: defaults)
        preferences.emails = "alice@example.com"
        preferences.remember(try Share(port: "3000", emails: "", requiresEmail: false))
        #expect(SharePreferences(defaults: defaults).emails == "alice@example.com")
        preferences.remember(try Share(port: "3000", emails: "bob@example.com"))
        #expect(SharePreferences(defaults: defaults).emails == "bob@example.com")
    }

    @Test func legacyRecentShareDefaultsToEmailProtection() throws {
        let id = UUID()
        let data = Data("{\"id\":\"\(id)\",\"port\":3000,\"emails\":[\"alice@example.com\"],\"useHTTPS\":false}".utf8)
        let share = try JSONDecoder().decode(Share.self, from: data)
        #expect(share.id == id)
        #expect(share.requiresEmail)
        #expect(share.arguments(config: "/tmp/config.yml").contains("--allowed-mail"))
    }

    @Test func anonymousShareRoundTripPreservesExplicitMode() throws {
        let share = try Share(port: "8080", emails: "", requiresEmail: false)
        let decoded = try JSONDecoder().decode(Share.self, from: JSONEncoder().encode(share))
        #expect(decoded == share)
        #expect(!decoded.requiresEmail)
    }

    @Test func corruptProtectedHistoryCannotSilentlyBecomeAnonymous() {
        let data = Data("{\"id\":\"\(UUID())\",\"port\":3000,\"emails\":[],\"useHTTPS\":false}".utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Share.self, from: data) }
    }

    @Test func portBoundariesAndHTTPS() throws {
        for port in ["0", "65536", "-1", "3000; echo hello", "abc", ""] {
            #expect(throws: (any Error).self) { try Share(port: port, emails: "alice@example.com") }
        }
        #expect(try Share(port: "65535", emails: "alice@example.com", useHTTPS: true).origin == "https://localhost:65535")
        _ = try Share(port: "1", emails: "a+b@example.co.uk")
    }

    @Test func parsesOnlyQuickTunnelURLs() {
        #expect(TunnelOutput.quickURL(in: "INF | https://quiet-sky-123.trycloudflare.com |")?.host == "quiet-sky-123.trycloudflare.com")
        #expect(TunnelOutput.quickURL(in: "https://example.com") == nil)
        #expect(TunnelOutput.quickURL(in: "https://trycloudflare.com") == nil)
    }

    @Test func announcementDoesNotMeanConnected() {
        #expect(!TunnelOutput.isConnected("Your quick Tunnel has been created!"))
        #expect(TunnelOutput.isConnected("INF Registered tunnel connection connIndex=0 connection=123"))
    }

    @Test func accountTunnelListingAndPendingConnections() throws {
        let data = Data(#"[{"id":"b","name":"Beta","connections":[{"is_pending_reconnect":true}]},{"id":"a","name":"Alpha","connections":[{"is_pending_reconnect":false}],"remote_config":true}]"#.utf8)
        let tunnels = try TunnelOutput.accountTunnels(data)
        #expect(tunnels.map(\.name) == ["Alpha", "Beta"])
        #expect(tunnels[0].isConnected)
        #expect(!tunnels[1].isConnected)
        #expect(try TunnelOutput.accountTunnels(Data("null\n".utf8)).isEmpty)
    }

    @Test func streamHandlesSplitUTF8AndFinalLine() {
        var buffer = LineBuffer()
        let bytes = Array("héllo\nlast".utf8)
        #expect(buffer.append(Data(bytes[0..<2])).isEmpty)
        #expect(buffer.append(Data(bytes[2...])) == ["héllo"])
        #expect(buffer.finish() == ["last"])
        #expect(buffer.finish().isEmpty)
    }

    @Test func recentShareRoundTrip() throws {
        let share = try Share(port: "8080", emails: "alice@example.com")
        #expect(try JSONDecoder().decode(Share.self, from: JSONEncoder().encode(share)) == share)
    }
}
