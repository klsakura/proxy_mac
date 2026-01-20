import Foundation

@available(macOS 14.0, *)
enum RuleSorting {
    static func autoSort(_ rules: [Rule]) -> [Rule] {
        rules.sorted { lhs, rhs in
            let lhsSpec = hostSpecificity(lhs.host)
            let rhsSpec = hostSpecificity(rhs.host)
            if lhsSpec != rhsSpec { return lhsSpec > rhsSpec }
            if lhs.pathPrefix.count != rhs.pathPrefix.count { return lhs.pathPrefix.count > rhs.pathPrefix.count }
            return lhs.host < rhs.host
        }
    }

    static func manualSort(_ rules: [Rule]) -> [Rule] {
        rules.sorted { $0.order < $1.order }
    }

    static func reassignOrder(_ rules: [Rule]) -> [Rule] {
        for (index, rule) in rules.enumerated() {
            rule.order = index
        }
        return rules
    }

    private static func hostSpecificity(_ host: String) -> Int {
        host.hasPrefix("*.") ? 0 : 1
    }
}
