import SwiftData
import XCTest
@testable import ProxyMac

@available(macOS 14.0, *)
final class ImportExportTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Rule.self, configurations: config)
        let context = ModelContext(container)

        let rule = Rule(host: "api.dev.test", pathPrefix: "/v1/", upstream: "https://api.example.com")
        rule.enabled = false
        rule.note = "note"
        rule.order = 42
        context.insert(rule)

        let data = try RuleJSON.export([rule])
        let decoded = try RuleJSON.importRules(data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].host, "api.dev.test")
        XCTAssertEqual(decoded[0].enabled, false)
        XCTAssertEqual(decoded[0].note, "note")
        XCTAssertEqual(decoded[0].order, 42)
    }

    func testExportImportIncludesPriority() throws {
        let rule = Rule(
            host: "api.dev.test",
            pathPrefix: "/",
            upstream: "http://localhost",
            enabled: true,
            note: nil,
            order: 0,
            priority: 7
        )

        let data = try RuleJSON.export([rule])
        let decoded = try RuleJSON.importRules(data)
        XCTAssertEqual(decoded.first?.priority, 7)
    }
}
