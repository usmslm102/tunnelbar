import SwiftUI
import AppKit
import TunnelCore

struct PanelView: View {
    @ObservedObject var store: TunnelStore
    @State private var port = "3000"
    @State private var emails = ""
    @State private var useHTTPS = false
    @State private var requiresEmail = true
    @State private var settings = false
    @State private var copied: UUID?
    @State private var loginCommandCopied = false
    @State private var accountExpanded = false
    @FocusState private var portFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "network").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TunnelBar").font(.headline)
                    Text("Localhost, a little further.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { settings.toggle() } label: { Image(systemName: settings ? "arrow.left" : "gearshape") }
                    .help(settings ? "Back to tunnels" : "Settings")
                    .accessibilityLabel(settings ? "Back to tunnels" : "Settings")
            }.padding(18)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let id = store.selectedLog { logs(id) }
                    else if settings { settingsView }
                    else {
                        createView
                        if !store.sessions.isEmpty { sessionsView }
                        DisclosureGroup("Account tunnels (optional)", isExpanded: $accountExpanded) {
                            accountView.padding(.top, 12)
                        }
                        if !store.recent.isEmpty { recentView }
                    }
                }.padding(18)
            }
            if let error = store.error {
                Divider()
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).font(.caption).textSelection(.enabled).lineLimit(5)
                    Spacer(minLength: 0)
                    Button { store.error = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss error")
                }.padding(12).background(.orange.opacity(0.06))
            }
            Divider()
            HStack {
                Circle().fill(store.activeCount > 0 ? Color.green : Color.secondary.opacity(0.4)).frame(width: 6, height: 6)
                Text(store.activeCount == 0 ? "Ready to share" : "\(store.activeCount) active on this Mac")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                    .help("Stop TunnelBar shares and quit")
            }.padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 420, height: 620)
        .onAppear { emails = store.defaultEmails; requiresEmail = true }
        .onChange(of: emails) { store.defaultEmails = $0 }
    }

    private var createView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share a local port").font(.headline)
            HStack {
                Text("localhost:").foregroundStyle(.secondary)
                TextField("3000", text: $port).textFieldStyle(.roundedBorder)
                    .focused($portFocused).accessibilityLabel("Local port")
                    .onSubmit(create)
                Toggle("HTTPS", isOn: $useHTTPS).toggleStyle(.checkbox).help("Use HTTPS for the local server")
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $requiresEmail) {
                    Label("Require email", systemImage: "lock.shield").font(.subheadline.weight(.medium))
                }.toggleStyle(.switch)
                if requiresEmail {
                    TextField("alice@example.com, bob@example.com", text: $emails, axis: .vertical)
                        .lineLimit(2...3).textFieldStyle(.roundedBorder).accessibilityLabel("Allowed email addresses")
                    Text("Only these people can enter, using a code sent to their email.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Emails are remembered. Email protection is on by default.")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Label("Anonymous: anyone with the link can access this port. No sign-in required.", systemImage: "lock.open")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Button(action: create) {
                Label(requiresEmail ? "Create protected link" : "Create anonymous link", systemImage: requiresEmail ? "lock.fill" : "lock.open")
                    .frame(maxWidth: .infinity)
            }.controlSize(.large).buttonStyle(.borderedProminent)
                .disabled(!store.inspected || store.version == "cloudflared unavailable" || (requiresEmail && !store.supportsEmailGate))
            Text("Temporary URL · ends when stopped · no account needed")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func create() {
        do {
            store.error = nil
            let share = try Share(port: port, emails: emails, useHTTPS: useHTTPS, requiresEmail: requiresEmail)
            store.start(share)
            requiresEmail = true
        } catch { store.error = error.localizedDescription }
    }

    private var sessionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("ON THIS MAC")
            ForEach(store.sessions) { session in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(stateColor(session.state)).frame(width: 7, height: 7)
                        Text(":\(session.share.port)").font(.system(.body, design: .monospaced).weight(.medium))
                        Text(session.state.rawValue).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if [.stopped, .failed].contains(session.state) {
                            Button { store.dismiss(session.id) } label: { Image(systemName: "xmark") }.help("Dismiss share")
                        } else {
                            Button("Stop") { store.stop(session.id) }.disabled(session.state == .stopping)
                        }
                    }
                    if let url = session.url, session.state == .connected {
                        HStack(spacing: 8) {
                            Link(url.host ?? url.absoluteString, destination: url)
                                .font(.caption).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 0)
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(url.absoluteString, forType: .string)
                                copied = session.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = nil }
                            } label: { Image(systemName: copied == session.id ? "checkmark" : "doc.on.doc") }
                                .help("Copy link").accessibilityLabel("Copy link")
                        }
                    }
                    HStack {
                        Label(session.share.requiresEmail ? session.share.emails.joined(separator: ", ") : "Anonymous · anyone with the link",
                              systemImage: session.share.requiresEmail ? "lock.fill" : "lock.open")
                            .font(.caption2).foregroundStyle(session.share.requiresEmail ? Color.secondary : Color.orange).lineLimit(1)
                        Spacer()
                        Button("Logs") { store.selectedLog = session.id }.font(.caption).buttonStyle(.link)
                    }
                }
                if session.id != store.sessions.last?.id { Divider() }
            }
        }
    }

    private var accountView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("ACCOUNT TUNNELS")
                Spacer()
                if store.refreshing { ProgressView().controlSize(.small) }
                Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).disabled(store.refreshing).help("Refresh tunnels")
                    .accessibilityLabel("Refresh account tunnels")
            }
            if let message = store.accountMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
                Text("To list named tunnels, run this in Terminal and complete Cloudflare’s domain authorization. Then refresh here.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("cloudflared tunnel login").font(.caption.monospaced()).textSelection(.enabled)
                    Spacer()
                    Button(loginCommandCopied ? "Copied" : "Copy command") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("cloudflared tunnel login", forType: .string)
                        loginCommandCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loginCommandCopied = false }
                    }.font(.caption)
                }
            } else if store.tunnels.isEmpty {
                Text(store.refreshing ? "Loading tunnels…" : "No named tunnels in this account.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.tunnels) { tunnel in
                    HStack(spacing: 9) {
                        Circle().fill(tunnel.isConnected ? Color.green : Color.secondary.opacity(0.35)).frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tunnel.name).font(.subheadline).lineLimit(1)
                            Text(tunnel.status?.capitalized ?? (tunnel.isConnected ? "Connected" : "Inactive"))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(tunnel.id, forType: .string)
                        } label: { Image(systemName: "doc.on.doc") }
                            .help("Copy tunnel ID").accessibilityLabel("Copy ID for \(tunnel.name)")
                    }
                }
            }
            Link("Manage named tunnels ↗", destination: URL(string: "https://one.dash.cloudflare.com/")!)
                .font(.caption)
            Text("Uses the native cloudflared CLI certificate. TunnelBar does not create an account session.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var recentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("RECENT SHARES")
            ForEach(store.recent) { share in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(share.origin).font(.caption.monospaced())
                        Text(share.requiresEmail ? share.emails.joined(separator: ", ") : "Anonymous · anyone with the link")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button("Reuse") {
                        port = String(share.port)
                        emails = share.requiresEmail ? share.emails.joined(separator: ", ") : store.defaultEmails
                        useHTTPS = share.useHTTPS
                        requiresEmail = true
                        portFocused = true
                    }.help("Fill the form with these settings")
                    Button { store.forget(share.id) } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Forget recent share")
                        .accessibilityLabel("Forget recent share on port \(share.port)")
                }
            }
        }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.headline)
            Label(store.version, systemImage: "terminal").font(.caption).textSelection(.enabled)
            Text(store.binary).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            Button("Choose cloudflared…") {
                let picker = NSOpenPanel()
                picker.canChooseDirectories = false
                picker.allowsMultipleSelection = false
                picker.message = "Choose the installed cloudflared executable."
                if picker.runModal() == .OK, let url = picker.url { store.saveBinary(url.path) }
            }
            Divider()
            Text("Email-protected Quick Tunnels").font(.subheadline.weight(.medium))
            Text("Email protection is on by default, and allowed emails are remembered. Turn off Require email for a share to allow anyone with the link. Each share gets a temporary trycloudflare.com address.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Keep TunnelBar open while sharing. Quitting stops the shares started by this app. Account tunnel status refreshes every 30 seconds.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Recent ports and allowed emails are saved on this Mac. No API tokens are stored. Cloudflare sign-in is managed by cloudflared.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Clear recent shares") { for share in store.recent { store.forget(share.id) } }
            Link("Cloudflare Quick Tunnel documentation", destination: URL(string: "https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/")!)
                .font(.caption)
        }
    }

    @ViewBuilder private func logs(_ id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { store.selectedLog = nil } label: { Label("Back to tunnels", systemImage: "chevron.left") }
            if let session = store.sessions.first(where: { $0.id == id }) {
                Text("Port \(session.share.port) · \(session.state.rawValue)").font(.headline)
                Text(session.logs.isEmpty ? "Waiting for cloudflared…" : session.logs.joined(separator: "\n"))
                    .font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
    }
    private func stateColor(_ state: ShareState) -> Color {
        switch state {
        case .connected: return .green
        case .starting, .stopping, .reconnecting: return .orange
        case .failed: return .red
        case .stopped: return .secondary
        }
    }
}
