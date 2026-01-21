import Foundation

final class ControlClient {
    private let baseURL: URL

    init(baseURL: URL = URL(string: "http://127.0.0.1:5959")!) {
        self.baseURL = baseURL
    }

    func health() async throws {
        let url = baseURL.appendingPathComponent("health")
        let (_, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "ControlClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    func applyConfig(_ data: Data) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("config"))
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "ControlClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    func health(completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("health")
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                completion(.success(()))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            completion(.failure(NSError(domain: "ControlClient", code: status)))
        }
        task.resume()
    }
}
