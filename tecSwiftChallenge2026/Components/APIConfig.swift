import Foundation

/// Host del backend Kuidar según dónde corre la app.
enum APIConfig {
    /// IP LAN del Mac en desarrollo. Actualízala con `ipconfig getifaddr en0`
    /// o la línea «Red local» al correr `npm run dev`.
    /// OJO: también actualiza KUIDAR_API_HOST en Info.plist (ese tiene prioridad).
    private static let devLANHost = "10.22.205.93"

    private static func plistString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else { return nil }
        return value
    }

    static var port: Int {
        if let raw = plistString("KUIDAR_API_PORT"), let parsed = Int(raw) {
            return parsed
        }
        return 3000
    }

    static var host: String {
        #if targetEnvironment(simulator)
        plistString("KUIDAR_API_HOST") ?? "localhost"
        #else
        if let plist = plistString("KUIDAR_API_HOST") { return plist }
        return devLANHost
        #endif
    }

    static var apiBaseURL: URL {
        URL(string: "http://\(host):\(port)/api")!
    }

    static var webSocketBaseURL: URL {
        URL(string: "ws://\(host):\(port)/ws")!
    }
}
