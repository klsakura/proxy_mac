import Foundation

@MainActor
final class ProxyCoreController: ObservableObject, ProxyCoreControlling {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    @Published private(set) var state: State = .stopped

    private var process: Process?
    private var terminationObserver: NSObjectProtocol?
    private var pendingConfig: Data?
    private var controlClient: ControlClientProtocol

    init(controlClient: ControlClientProtocol = ControlClient()) {
        self.controlClient = controlClient
    }

    func start(controlAddress: String) {
        guard process == nil else { return }
        state = .starting

        guard let binaryURL = Bundle.main.url(forResource: "proxycore", withExtension: nil) else {
            state = .failed("proxycore not found")
            return
        }

        let proc = Process()
        proc.executableURL = binaryURL
        proc.arguments = ["-control", controlAddress]
        terminationObserver = NotificationCenter.default.addObserver(
            forName: Process.didTerminateNotification,
            object: proc,
            queue: .main
        ) { [weak self] _ in
            self?.process = nil
            self?.state = .stopped
        }

        do {
            try proc.run()
            process = proc
            Task { await waitForHealthThenApply() }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
            self.terminationObserver = nil
        }
        state = .stopped
    }

    func updateControlAddress(_ address: String) {
        controlClient = ControlClient(baseURL: URL(string: "http://\(address)")!)
    }

    func applyConfig(_ data: Data) async {
        pendingConfig = data
        guard process != nil else { return }
        do {
            try await controlClient.applyConfig(data)
            state = .running
            pendingConfig = nil
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func waitForHealthThenApply() async {
        let maxAttempts = 20
        for _ in 0..<maxAttempts {
            do {
                try await controlClient.health()
                state = .running
                if let pendingConfig {
                    await applyConfig(pendingConfig)
                }
                return
            } catch {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        state = .failed("health check timeout")
    }
}

protocol ControlClientProtocol {
    func health() async throws
    func applyConfig(_ data: Data) async throws
}

extension ControlClient: ControlClientProtocol {}

struct FakeControlClient: ControlClientProtocol {
    func health() async throws {}
    func applyConfig(_ data: Data) async throws {}
}
