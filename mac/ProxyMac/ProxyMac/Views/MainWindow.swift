import SwiftUI

struct MainWindow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ProxyMac")
                .font(.largeTitle.weight(.semibold))
            Text("Local dev proxy is idle")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 320)
    }
}
