import Foundation

// MARK: - Mensajes del servidor

struct WSChatMessage: Codable, Sendable {
    let message: APIMessage
}

struct WSLocationBroadcast: Codable, Sendable {
    struct Point: Codable, Sendable {
        let lat: Double
        let lng: Double
        let at: String
    }
    let assignmentId: String
    let student: Point?
    let elderly: Point?
}

struct WSAssignmentStatus: Codable, Sendable {
    struct Timestamps: Codable, Sendable {
        let approvedAt: String?
        let enCaminoAt: String?
        let checkinAt: String?
        let checkoutAt: String?
    }
    let assignmentId: String
    let status: String
    let timestamps: Timestamps
    let hoursLogged: Double?
}

// MARK: - WebSocketClient

/// Cliente WS para ubicación en tiempo real durante una visita.
/// Reconexión automática con backoff simple.
@MainActor
@Observable
final class WebSocketClient {

    static let shared = WebSocketClient()

    private(set) var isConnected = false
    var onLocation: ((WSLocationBroadcast) -> Void)?
    var onStatus: ((WSAssignmentStatus) -> Void)?
    /// Se dispara cuando un request se reabre (cancelación del becario). Param: requestId.
    var onRequestReopened: ((String) -> Void)?
    var onChatMessage: ((APIMessage) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var subscribed: Set<String> = []
    private var shouldReconnect = false
    private var reconnectDelay: TimeInterval = 1

    private let decoder = JSONDecoder()

    func connect(token: String) {
        guard task == nil, !token.isEmpty else { return }
        shouldReconnect = true

        var components = URLComponents(url: APIConfig.webSocketBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { return }

        let wsTask = URLSession.shared.webSocketTask(with: url)
        task = wsTask
        wsTask.resume()
        isConnected = true
        reconnectDelay = 1

        // Re-suscribir tras reconexión
        for id in subscribed {
            sendJSON(["type": "assignment:subscribe", "assignmentId": id])
        }

        receiveLoop(token: token)
    }

    func disconnect() {
        shouldReconnect = false
        subscribed.removeAll()
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }

    func subscribe(assignmentId: String) {
        subscribed.insert(assignmentId)
        sendJSON(["type": "assignment:subscribe", "assignmentId": assignmentId])
    }

    func unsubscribe(assignmentId: String) {
        subscribed.remove(assignmentId)
        sendJSON(["type": "assignment:unsubscribe", "assignmentId": assignmentId])
    }

    func sendLocation(assignmentId: String, latitude: Double, longitude: Double) {
        sendJSON([
            "type": "location:update",
            "assignmentId": assignmentId,
            "lat": latitude,
            "lng": longitude,
        ])
    }

    // MARK: - Private

    private func sendJSON(_ payload: [String: Any]) {
        guard let task,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { _ in }
    }

    private func receiveLoop(token: String) {
        task?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self.handle(text: text)
                    }
                    self.receiveLoop(token: token)
                case .failure:
                    self.isConnected = false
                    self.task = nil
                    if self.shouldReconnect {
                        let delay = self.reconnectDelay
                        self.reconnectDelay = min(delay * 2, 15)
                        try? await Task.sleep(for: .seconds(delay))
                        if self.shouldReconnect {
                            self.connect(token: token)
                        }
                    }
                }
            }
        }
    }

    private func handle(text: String) {
        guard let data = text.data(using: .utf8),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = envelope["type"] as? String else { return }

        switch type {
        case "location:broadcast":
            if let payload = try? decoder.decode(WSLocationBroadcast.self, from: data) {
                onLocation?(payload)
            }
        case "assignment:status":
            if let payload = try? decoder.decode(WSAssignmentStatus.self, from: data) {
                onStatus?(payload)
            }
        case "request:reopened":
            if let requestId = envelope["requestId"] as? String {
                onRequestReopened?(requestId)
            }
        case "chat:message":
            if let payload = try? decoder.decode(WSChatMessage.self, from: data) {
                onChatMessage?(payload.message)
            }
        default:
            break
        }
    }
}
