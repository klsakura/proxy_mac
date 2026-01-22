import XCTest
@testable import ProxyMac

final class RulesViewTests: XCTestCase {
    func testRulesSplitViewLoads() {
        _ = RulesSplitView()
    }

    func testFileDocumentLoads() {
        _ = JSONFileDocument(data: Data())
    }

    @MainActor
    func testProxySidebarViewLoads() {
        let settings = ProxySettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let controller = ProxyCoreController()
        _ = ProxySidebarView(settings: settings, controller: controller, rules: [])
    }
}
