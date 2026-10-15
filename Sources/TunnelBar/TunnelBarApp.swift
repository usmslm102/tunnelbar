import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TunnelStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var subscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let menu = NSMenu()
        let appMenu = NSMenuItem()
        let submenu = NSMenu()
        submenu.addItem(withTitle: "Quit TunnelBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.submenu = submenu
        menu.addItem(appMenu)
        NSApp.mainMenu = menu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "TunnelBar")
            button.toolTip = "TunnelBar — share a local port"
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 620)
        popover.contentViewController = NSHostingController(rootView: PanelView(store: store))
        subscription = store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.statusItem.button?.title = self.store.activeCount > 0 ? " \(self.store.activeCount)" : ""
            }
        }
        store.boot()
        if CommandLine.arguments.contains("--show") { showPopover() }
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Open TunnelBar", action: #selector(openPanel), keyEquivalent: "")
                .target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit TunnelBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown { popover.performClose(nil) }
        else { showPopover() }
    }

    @objc private func openPanel() { showPopover() }
    private func showPopover() {
        guard let button = statusItem.button else { return }
        if #available(macOS 14.0, *) { NSApp.activate() }
        else { NSApp.activate(ignoringOtherApps: true) }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await store.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
enum TunnelBarApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
