import Foundation

@MainActor
final class ProxySettings: ObservableObject {
    @Published var controlAddress: String {
        didSet { defaults.set(controlAddress, forKey: Keys.controlAddress) }
    }
    @Published var httpPort: Int {
        didSet { defaults.set(httpPort, forKey: Keys.httpPort) }
    }
    @Published var socksPort: Int {
        didSet { defaults.set(socksPort, forKey: Keys.socksPort) }
    }
    @Published var httpEnabled: Bool {
        didSet { defaults.set(httpEnabled, forKey: Keys.httpEnabled) }
    }
    @Published var socksEnabled: Bool {
        didSet { defaults.set(socksEnabled, forKey: Keys.socksEnabled) }
    }

    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.controlAddress = userDefaults.string(forKey: Keys.controlAddress) ?? "127.0.0.1:5959"
        self.httpPort = userDefaults.integer(forKey: Keys.httpPort)
        self.socksPort = userDefaults.integer(forKey: Keys.socksPort)
        self.httpEnabled = userDefaults.object(forKey: Keys.httpEnabled) as? Bool ?? true
        self.socksEnabled = userDefaults.object(forKey: Keys.socksEnabled) as? Bool ?? true

        if self.httpPort == 0 { self.httpPort = 12560 }
        if self.socksPort == 0 { self.socksPort = 12561 }
    }

    struct Snapshot: Equatable {
        let controlAddress: String
        let httpPort: Int
        let socksPort: Int
        let httpEnabled: Bool
        let socksEnabled: Bool
    }

    var snapshot: Snapshot {
        Snapshot(
            controlAddress: controlAddress,
            httpPort: httpPort,
            socksPort: socksPort,
            httpEnabled: httpEnabled,
            socksEnabled: socksEnabled
        )
    }

    private enum Keys {
        static let controlAddress = "proxy.controlAddress"
        static let httpPort = "proxy.httpPort"
        static let socksPort = "proxy.socksPort"
        static let httpEnabled = "proxy.httpEnabled"
        static let socksEnabled = "proxy.socksEnabled"
    }
}
