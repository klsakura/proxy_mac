import Foundation
import SwiftData

@available(macOS 14.0, *)
@MainActor
final class RuleStore: ObservableObject {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(sortBy: [SortDescriptor(\Rule.host)])
        return try context.fetch(descriptor)
    }

    func add(_ rule: Rule) {
        context.insert(rule)
    }

    func remove(_ rule: Rule) {
        context.delete(rule)
    }

    func save() throws {
        try context.save()
    }
}
