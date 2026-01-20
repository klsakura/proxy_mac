import Foundation
import SwiftData

@available(macOS 14.0, *)
@Model
final class Rule: Codable {
    var host: String
    var pathPrefix: String
    var upstream: String

    init(host: String, pathPrefix: String, upstream: String) {
        self.host = host
        self.pathPrefix = pathPrefix
        self.upstream = upstream
    }

    enum CodingKeys: String, CodingKey {
        case host
        case pathPrefix
        case upstream
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let host = try container.decode(String.self, forKey: .host)
        let pathPrefix = try container.decode(String.self, forKey: .pathPrefix)
        let upstream = try container.decode(String.self, forKey: .upstream)
        self.init(host: host, pathPrefix: pathPrefix, upstream: upstream)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(host, forKey: .host)
        try container.encode(pathPrefix, forKey: .pathPrefix)
        try container.encode(upstream, forKey: .upstream)
    }
}
