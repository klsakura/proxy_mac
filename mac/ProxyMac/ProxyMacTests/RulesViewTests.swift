import XCTest
@testable import ProxyMac

final class RulesViewTests: XCTestCase {
    func testRulesSplitViewLoads() {
        _ = RulesSplitView()
    }

    func testFileDocumentLoads() {
        _ = JSONFileDocument(data: Data())
    }
}
