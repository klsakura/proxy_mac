import Foundation

enum ProxySettingsValidation {
    static func portError(_ port: Int) -> String? {
        guard (1...65535).contains(port) else {
            return "Port must be between 1 and 65535"
        }
        return nil
    }

    static func controlAddressError(_ address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Control address is required" }
        guard let colonIndex = trimmed.lastIndex(of: ":") else {
            return "Use host:port"
        }
        let host = trimmed[..<colonIndex]
        let portStr = trimmed[trimmed.index(after: colonIndex)...]
        guard !host.isEmpty, let port = Int(portStr) else {
            return "Use host:port"
        }
        return portError(port)
    }
}
