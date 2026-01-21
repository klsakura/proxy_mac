import AppKit
import SwiftData
import SwiftUI

@main
struct ProxyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = ProxySettings()
    @StateObject private var controller = ProxyCoreController()
    private let modelContainer: ModelContainer = {
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isTesting)
        return try! ModelContainer(for: Rule.self, configurations: configuration)
    }()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(settings)
                .environmentObject(controller)
        }
        .modelContainer(modelContainer)

        if #available(macOS 13.0, *) {
            MenuBarExtra("ProxyMac") {
                MenuBarView()
                    .environmentObject(settings)
                    .environmentObject(controller)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard #available(macOS 13.0, *) else {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.title = "ProxyMac"

            let menu = NSMenu()
            let openItem = NSMenuItem(title: "Open", action: #selector(openApp), keyEquivalent: "o")
            let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
            openItem.target = self
            quitItem.target = self
            menu.addItem(openItem)
            menu.addItem(.separator())
            menu.addItem(quitItem)

            item.menu = menu
            statusItem = item
            return
        }
    }

    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
