import XCTest
@testable import ProxyMac

@MainActor
final class ProxyMacTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }

    func testProxySettingsViewLoads() {
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        _ = ProxySettingsView(settings: settings)
    }
}
