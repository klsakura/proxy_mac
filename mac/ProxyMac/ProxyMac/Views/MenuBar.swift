import AppKit
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        Button("Open") {
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
