import SwiftData
import XCTest
@testable import ProxyMac

@available(macOS 14.0, *)
final class ImportExportTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let container = try ModelContainer(for: Rule.self)
        let context = ModelContext(container)

        let rule = Rule(host: "api.dev.test", pathPrefix: "/v1/", upstream: "https://api.example.com")
        context.insert(rule)

        let data = try RuleJSON.export([rule])
        let decoded = try RuleJSON.importRules(data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].host, "api.dev.test")
    }
}
