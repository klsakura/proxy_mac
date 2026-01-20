import SwiftUI

struct MainWindow: View {
    var body: some View {
        if isRunningTests {
            placeholderView
        } else if #available(macOS 14.0, *) {
            RulesSplitView()
        } else {
            placeholderView
        }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var placeholderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ProxyMac")
                .font(.largeTitle.weight(.semibold))
            Text("Local dev proxy is idle")
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
