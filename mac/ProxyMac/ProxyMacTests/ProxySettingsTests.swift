import XCTest
@testable import ProxyMac

@MainActor
final class ProxySettingsTests: XCTestCase {
    func testDefaults() {
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        XCTAssertEqual(settings.controlAddress, "127.0.0.1:5959")
        XCTAssertEqual(settings.httpPort, 12560)
        XCTAssertEqual(settings.socksPort, 12561)
        XCTAssertTrue(settings.httpEnabled)
        XCTAssertTrue(settings.socksEnabled)
    }
}
