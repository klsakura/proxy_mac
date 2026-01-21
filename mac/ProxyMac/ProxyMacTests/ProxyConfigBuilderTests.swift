import XCTest
@testable import ProxyMac

@MainActor
final class ProxyConfigBuilderTests: XCTestCase {
    func testBuildConfigEncodesListenersAndRules() throws {
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        settings.httpPort = 12560
        settings.socksPort = 12561
        settings.httpEnabled = true
        settings.socksEnabled = true

        let rule = Rule(
            host: "api.dev.test",
            pathPrefix: "/",
            upstream: "http://localhost:3000",
            enabled: true,
            note: "n",
            order: 0,
            priority: 3
        )

        let data = try ProxyConfigBuilder.build(rules: [rule], settings: settings)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let listeners = json?["listeners"] as? [[String: Any]]
        XCTAssertEqual(listeners?.count, 2)
        let rules = json?["rules"] as? [[String: Any]]
        XCTAssertEqual(rules?.first?["priority"] as? Int, 3)
        XCTAssertEqual(rules?.first?["notes"] as? String, "n")
    }
}
