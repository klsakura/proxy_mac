import SwiftUI

@available(macOS 14.0, *)
struct ProxySettingsView: View {
    @ObservedObject var settings: ProxySettings

    var body: some View {
        Form {
            TextField("Control Address", text: $settings.controlAddress)
            HStack {
                TextField("HTTP Port", value: $settings.httpPort, formatter: numberFormatter)
                Toggle("HTTP Enabled", isOn: $settings.httpEnabled)
            }
            HStack {
                TextField("SOCKS5 Port", value: $settings.socksPort, formatter: numberFormatter)
                Toggle("SOCKS5 Enabled", isOn: $settings.socksEnabled)
            }
        }
        .padding()
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        return formatter
    }
}
