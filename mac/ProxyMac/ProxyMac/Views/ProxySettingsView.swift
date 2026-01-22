import SwiftUI

@available(macOS 14.0, *)
struct ProxySettingsView: View {
    @ObservedObject var settings: ProxySettings

    var body: some View {
        VStack(spacing: 16) {
            header
            controlCard
            listenersCard
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360)
        .background(backgroundGradient)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text("Proxy Settings")
                .font(titleFont)
            Spacer()
            Text(statusText)
                .font(.custom("Source Sans 3", size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var controlCard: some View {
        card(title: "Control Address", subtitle: "Local control API") {
            VStack(alignment: .leading, spacing: 6) {
                TextField("127.0.0.1:5959", text: $settings.controlAddress)
                    .textFieldStyle(.roundedBorder)
                    .font(bodyFont.monospacedDigit())
                helperText("Example: 127.0.0.1:5959")
                if let error = controlAddressError {
                    errorText(error)
                }
            }
        }
    }

    private var listenersCard: some View {
        card(title: "Listeners", subtitle: "HTTP and SOCKS5") {
            VStack(alignment: .leading, spacing: 12) {
                listenerRow(label: "HTTP", port: $settings.httpPort, enabled: $settings.httpEnabled)
                if let error = httpPortError {
                    errorText(error)
                }
                Divider()
                listenerRow(label: "SOCKS5", port: $settings.socksPort, enabled: $settings.socksEnabled)
                if let error = socksPortError {
                    errorText(error)
                }
                helperText("Port range: 1-65535")
            }
        }
    }

    private func listenerRow(label: String, port: Binding<Int>, enabled: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(bodyFont)
                .frame(width: 64, alignment: .leading)
            TextField("Port", value: port, formatter: numberFormatter)
                .textFieldStyle(.roundedBorder)
                .font(bodyFont.monospacedDigit())
                .frame(width: 120)
            Spacer()
            Toggle("Enabled", isOn: enabled)
                .toggleStyle(.switch)
        }
    }

    private func card<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Source Sans 3", size: 16).weight(.semibold))
                Text(subtitle)
                    .font(.custom("Source Sans 3", size: 12))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var controlAddressError: String? {
        ProxySettingsValidation.controlAddressError(settings.controlAddress)
    }

    private var httpPortError: String? {
        ProxySettingsValidation.portError(settings.httpPort)
    }

    private var socksPortError: String? {
        ProxySettingsValidation.portError(settings.socksPort)
    }

    private var statusText: String {
        if controlAddressError != nil || httpPortError != nil || socksPortError != nil {
            return "Config needs attention"
        }
        return "Auto-saved"
    }

    private var statusColor: Color {
        if controlAddressError != nil || httpPortError != nil || socksPortError != nil {
            return Color(red: 0.78, green: 0.22, blue: 0.22)
        }
        return Color(red: 0.16, green: 0.27, blue: 0.45)
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.custom("Source Sans 3", size: 11))
            .foregroundStyle(.secondary)
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .font(.custom("Source Sans 3", size: 11))
            .foregroundStyle(Color(red: 0.78, green: 0.22, blue: 0.22))
    }

    private var titleFont: Font {
        .custom("Source Sans 3", size: 20).weight(.semibold)
    }

    private var bodyFont: Font {
        .custom("Source Sans 3", size: 13)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.9))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color(red: 0.86, green: 0.88, blue: 0.91), lineWidth: 1)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.92, green: 0.95, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        return formatter
    }
}
