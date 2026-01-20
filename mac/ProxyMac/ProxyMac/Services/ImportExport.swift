import Foundation

@available(macOS 14.0, *)
enum RuleJSON {
    static func export(_ rules: [Rule]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(rules)
    }

    static func importRules(_ data: Data) throws -> [Rule] {
        let decoder = JSONDecoder()
        return try decoder.decode([Rule].self, from: data)
    }
}
