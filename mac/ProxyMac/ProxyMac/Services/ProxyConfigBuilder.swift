import Foundation

struct ProxyConfigBuilder {
    struct Listener: Codable {
        let type: String
        let addr: String
    }

    struct RulePayload: Codable {
        let host: String
        let pathPrefix: String
        let upstream: String
        let enabled: Bool
        let priority: Int
        let notes: String?
    }

    struct Config: Codable {
        let rules: [RulePayload]
        let listeners: [Listener]
    }

    @MainActor
    static func build(rules: [Rule], settings: ProxySettings) throws -> Data {
        let listeners = buildListeners(settings: settings)
        let payloadRules = rules.map {
            RulePayload(
                host: $0.host,
                pathPrefix: $0.pathPrefix,
                upstream: $0.upstream,
                enabled: $0.enabled,
                priority: $0.priority,
                notes: $0.note
            )
        }
        let cfg = Config(rules: payloadRules, listeners: listeners)
        return try JSONEncoder().encode(cfg)
    }

    @MainActor
    static func buildListeners(settings: ProxySettings) -> [Listener] {
        var result: [Listener] = []
        if settings.httpEnabled {
            result.append(Listener(type: "http", addr: "127.0.0.1:\(settings.httpPort)"))
        }
        if settings.socksEnabled {
            result.append(Listener(type: "socks5", addr: "127.0.0.1:\(settings.socksPort)"))
        }
        return result
    }
}
