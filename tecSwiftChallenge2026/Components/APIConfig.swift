import Foundation

/// Host del backend Kuidar según dónde corre la app.
enum APIConfig {
    static let port = 3000

    /// IP de tu Mac en la Wi‑Fi local. Actualízala con: `ipconfig getifaddr en0`
    private static let devLANHost = "192.168.1.222"

    static var host: String {
        #if targetEnvironment(simulator)
        "localhost"
        #else
        let override = UserDefaults.standard.string(forKey: "aco_apiHost") ?? ""
        return override.isEmpty ? devLANHost : override
        #endif
    }

    static var apiBaseURL: URL {
        URL(string: "http://\(host):\(port)/api")!
    }

    static var webSocketBaseURL: URL {
        URL(string: "ws://\(host):\(port)/ws")!
    }
}
