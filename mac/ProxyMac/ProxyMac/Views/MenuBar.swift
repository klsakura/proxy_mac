import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var settings: ProxySettings
    @EnvironmentObject private var controller: ProxyCoreController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ProxyCoreActions.statusText(for: controller.state))
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button(ProxyCoreActions.startStopTitle(for: controller.state)) {
                ProxyCoreActions.toggle(controller: controller, settings: settings)
            }
            Button("Open") {
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }
}
