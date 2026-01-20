import NetworkExtension

final class TransparentProxyProvider: NETransparentProxyProvider {
    override func startProxy(options: [String : Any]? = nil) async throws {
        // TODO: connect to Go core
    }

    override func stopProxy(with reason: NEProviderStopReason) async {
        // TODO: cleanup
    }
}
