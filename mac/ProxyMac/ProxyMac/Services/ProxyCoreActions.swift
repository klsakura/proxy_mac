import Foundation

@MainActor
protocol ProxyCoreControlling: AnyObject {
    var state: ProxyCoreController.State { get }
    func start(controlAddress: String)
    func stop()
    func updateControlAddress(_ address: String)
    func applyConfig(_ data: Data) async
    func healthCheck() async
}

@MainActor
struct ProxyCoreActions {
    static func startStopTitle(for state: ProxyCoreController.State) -> String {
        switch state {
        case .running, .starting:
            return "Stop"
        case .stopped, .failed:
            return "Start"
        }
    }

    static func statusText(for state: ProxyCoreController.State) -> String {
        switch state {
        case .running:
            return "Proxy running"
        case .starting:
            return "Proxy starting"
        case .failed:
            return "Proxy failed"
        case .stopped:
            return "Proxy stopped"
        }
    }

    static func toggle(controller: ProxyCoreControlling, settings: ProxySettings) {
        switch controller.state {
        case .running, .starting:
            controller.stop()
        case .stopped, .failed:
            controller.updateControlAddress(settings.controlAddress)
            controller.start(controlAddress: settings.controlAddress)
        }
    }

    static func applyConfig(rules: [Rule], settings: ProxySettings, controller: ProxyCoreControlling) async {
        do {
            let data = try ProxyConfigBuilder.build(rules: rules, settings: settings)
            await controller.applyConfig(data)
        } catch {
            return
        }
    }

    static func healthCheck(controller: ProxyCoreControlling, settings: ProxySettings) async {
        await controller.healthCheck()
    }
}
