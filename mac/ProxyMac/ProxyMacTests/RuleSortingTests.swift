import XCTest
@testable import ProxyMac

@available(macOS 14.0, *)
final class RuleSortingTests: XCTestCase {
    func testAutoSortPrioritizesSpecificity() {
        let exact = Rule(host: "api.dev.test", pathPrefix: "/v1/", upstream: "https://a")
        let wildcard = Rule(host: "*.dev.test", pathPrefix: "/", upstream: "https://b")
        let longerPath = Rule(host: "api.dev.test", pathPrefix: "/v1/users/", upstream: "https://c")

        let sorted = RuleSorting.autoSort([wildcard, exact, longerPath])
        XCTAssertEqual(sorted.first?.pathPrefix, "/v1/users/")
        XCTAssertEqual(sorted[1].host, "api.dev.test")
        XCTAssertEqual(sorted.last?.host, "*.dev.test")
    }

    func testManualSortByOrder() {
        let a = Rule(host: "a.dev.test", pathPrefix: "/", upstream: "https://a", order: 2)
        let b = Rule(host: "b.dev.test", pathPrefix: "/", upstream: "https://b", order: 1)
        let sorted = RuleSorting.manualSort([a, b])
        XCTAssertEqual(sorted.first?.host, "b.dev.test")
    }

    func testReassignOrderPreservesListOrder() {
        let a = Rule(host: "a.dev.test", pathPrefix: "/", upstream: "https://a", order: 10)
        let b = Rule(host: "b.dev.test", pathPrefix: "/", upstream: "https://b", order: 20)
        let updated = RuleSorting.reassignOrder([b, a])
        XCTAssertEqual(updated[0].order, 0)
        XCTAssertEqual(updated[1].order, 1)
    }
}
