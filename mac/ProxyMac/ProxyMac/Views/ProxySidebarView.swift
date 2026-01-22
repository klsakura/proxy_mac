import SwiftUI

@available(macOS 14.0, *)
struct ProxySidebarView: View {
    @ObservedObject var settings: ProxySettings
    @ObservedObject var controller: ProxyCoreController
    var rules: [Rule]

    var body: some View {
        VStack(spacing: 16) {
            statusCard
            listenersCard
            actionsCard
            Spacer(minLength: 0)
        }
        .frame(width: 250)
    }

    private var statusCard: some View {
        card(title: "Status", subtitle: "Control API") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(ProxyCoreActions.statusText(for: controller.state))
                        .font(bodyFont.weight(.semibold))
                }
                Text("Control: \(settings.controlAddress)")
                    .font(bodyFont.monospacedDigit())
                    .foregroundStyle(.secondary)
                if hasValidationError {
                    Text("Config needs attention")
                        .font(helperFont)
                        .foregroundStyle(Color(red: 0.78, green: 0.22, blue: 0.22))
                }
            }
        }
    }

    private var listenersCard: some View {
        card(title: "Listeners", subtitle: "HTTP + SOCKS5") {
            VStack(alignment: .leading, spacing: 10) {
                listenerRow(label: "HTTP", port: settings.httpPort, enabled: settings.httpEnabled)
                Divider()
                listenerRow(label: "SOCKS5", port: settings.socksPort, enabled: settings.socksEnabled)
            }
        }
    }

    private var actionsCard: some View {
        card(title: "Actions", subtitle: "Proxy controls") {
            VStack(alignment: .leading, spacing: 10) {
                Button(ProxyCoreActions.startStopTitle(for: controller.state)) {
                    ProxyCoreActions.toggle(controller: controller, settings: settings)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Apply") {
                    Task { await ProxyCoreActions.applyConfig(rules: rules, settings: settings, controller: controller) }
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Health Check") {
                    Task { await ProxyCoreActions.healthCheck(controller: controller, settings: settings) }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func listenerRow(label: String, port: Int, enabled: Bool) -> some View {
        HStack {
            Text(label)
                .font(bodyFont)
            Spacer()
            Text("\(port)")
                .font(bodyFont.monospacedDigit())
            Text(enabled ? "Enabled" : "Disabled")
                .font(helperFont)
                .foregroundStyle(enabled ? Color(red: 0.16, green: 0.27, blue: 0.45) : .secondary)
        }
    }

    private func card<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Source Sans 3", size: 14).weight(.semibold))
                Text(subtitle)
                    .font(helperFont)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var hasValidationError: Bool {
        ProxySettingsValidation.controlAddressError(settings.controlAddress) != nil
            || ProxySettingsValidation.portError(settings.httpPort) != nil
            || ProxySettingsValidation.portError(settings.socksPort) != nil
    }

    private var statusColor: Color {
        switch controller.state {
        case .running:
            return Color(red: 0.16, green: 0.27, blue: 0.45)
        case .starting:
            return Color(red: 0.35, green: 0.48, blue: 0.7)
        case .failed:
            return Color(red: 0.78, green: 0.22, blue: 0.22)
        case .stopped:
            return Color(red: 0.65, green: 0.68, blue: 0.72)
        }
    }

    private var bodyFont: Font {
        .custom("Source Sans 3", size: 12)
    }

    private var helperFont: Font {
        .custom("Source Sans 3", size: 11)
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
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(red: 0.16, green: 0.27, blue: 0.45).opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .font(.custom("Source Sans 3", size: 12).weight(.semibold))
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.8 : 0.95))
            .foregroundStyle(Color(red: 0.16, green: 0.27, blue: 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.78, green: 0.82, blue: 0.88), lineWidth: 1)
            )
            .font(.custom("Source Sans 3", size: 12).weight(.semibold))
    }
}
