import SwiftUI

struct MainWindow: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            RulesSplitView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("ProxyMac")
                    .font(.largeTitle.weight(.semibold))
                Text("Local dev proxy is idle")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}
