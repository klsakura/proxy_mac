import Foundation
import SwiftData

@available(macOS 14.0, *)
@Model
final class Rule: Codable {
    var host: String
    var pathPrefix: String
    var upstream: String
    var enabled: Bool = true
    var note: String?
    var order: Int = 0

    init(
        host: String,
        pathPrefix: String,
        upstream: String,
        enabled: Bool = true,
        note: String? = nil,
        order: Int = 0
    ) {
        self.host = host
        self.pathPrefix = pathPrefix
        self.upstream = upstream
        self.enabled = enabled
        self.note = note
        self.order = order
    }

    enum CodingKeys: String, CodingKey {
        case host
        case pathPrefix
        case upstream
        case enabled
        case note
        case order
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let host = try container.decode(String.self, forKey: .host)
        let pathPrefix = try container.decode(String.self, forKey: .pathPrefix)
        let upstream = try container.decode(String.self, forKey: .upstream)
        let enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        let note = try container.decodeIfPresent(String.self, forKey: .note)
        let order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        self.init(host: host, pathPrefix: pathPrefix, upstream: upstream, enabled: enabled, note: note, order: order)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(host, forKey: .host)
        try container.encode(pathPrefix, forKey: .pathPrefix)
        try container.encode(upstream, forKey: .upstream)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(order, forKey: .order)
    }
}
