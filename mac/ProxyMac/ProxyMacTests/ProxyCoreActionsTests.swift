import XCTest
@testable import ProxyMac

@MainActor
final class ProxyCoreActionsTests: XCTestCase {
    func testStartStopTitleForRunning() {
        XCTAssertEqual(ProxyCoreActions.startStopTitle(for: .running), "Stop")
        XCTAssertEqual(ProxyCoreActions.startStopTitle(for: .starting), "Stop")
    }

    func testStartStopTitleForStopped() {
        XCTAssertEqual(ProxyCoreActions.startStopTitle(for: .stopped), "Start")
        XCTAssertEqual(ProxyCoreActions.startStopTitle(for: .failed("boom")), "Start")
    }

    func testStatusTextMapping() {
        XCTAssertEqual(ProxyCoreActions.statusText(for: .running), "Proxy running")
        XCTAssertEqual(ProxyCoreActions.statusText(for: .starting), "Proxy starting")
        XCTAssertEqual(ProxyCoreActions.statusText(for: .failed("boom")), "Proxy failed")
        XCTAssertEqual(ProxyCoreActions.statusText(for: .stopped), "Proxy stopped")
    }

    func testToggleStopsWhenRunning() {
        let controller = FakeProxyCoreController(state: .running)
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)

        ProxyCoreActions.toggle(controller: controller, settings: settings)

        XCTAssertEqual(controller.stopCount, 1)
        XCTAssertEqual(controller.startAddresses.count, 0)
    }

    func testToggleStartsWhenStoppedUsesSettings() {
        let controller = FakeProxyCoreController(state: .stopped)
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        settings.controlAddress = "127.0.0.1:5959"

        ProxyCoreActions.toggle(controller: controller, settings: settings)

        XCTAssertEqual(controller.startAddresses, ["127.0.0.1:5959"])
        XCTAssertEqual(controller.updateAddresses, ["127.0.0.1:5959"])
    }

    func testApplyConfigSendsBuiltConfig() async throws {
        let controller = FakeProxyCoreController(state: .running)
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        settings.httpEnabled = true
        settings.socksEnabled = false
        settings.httpPort = 12560

        let rule = Rule(host: "api.dev.test", pathPrefix: "/", upstream: "http://localhost:3000", enabled: true, note: "n", order: 0, priority: 2)

        await ProxyCoreActions.applyConfig(rules: [rule], settings: settings, controller: controller)

        let data = try XCTUnwrap(controller.lastConfigData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let listeners = json?["listeners"] as? [[String: Any]]
        XCTAssertEqual(listeners?.count, 1)
        let rules = json?["rules"] as? [[String: Any]]
        XCTAssertEqual(rules?.first?["priority"] as? Int, 2)
    }

    func testHealthCheckCallsController() async {
        let controller = FakeProxyCoreController(state: .running)
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)

        await ProxyCoreActions.healthCheck(controller: controller, settings: settings)

        XCTAssertEqual(controller.healthCheckCount, 1)
    }
}

@MainActor
final class FakeProxyCoreController: ProxyCoreControlling {
    var state: ProxyCoreController.State
    private(set) var stopCount = 0
    private(set) var startAddresses: [String] = []
    private(set) var updateAddresses: [String] = []
    private(set) var lastConfigData: Data?
    private(set) var healthCheckCount = 0

    init(state: ProxyCoreController.State) {
        self.state = state
    }

    func start(controlAddress: String) {
        startAddresses.append(controlAddress)
    }

    func stop() {
        stopCount += 1
    }

    func updateControlAddress(_ address: String) {
        updateAddresses.append(address)
    }

    func applyConfig(_ data: Data) async {
        lastConfigData = data
    }

    func healthCheck() async {
        healthCheckCount += 1
    }
}
