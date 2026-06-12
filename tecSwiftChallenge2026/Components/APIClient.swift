import Foundation

// MARK: - APIClient

@MainActor
final class APIClient {

    static let shared = APIClient()

    private var baseURL: URL { APIConfig.apiBaseURL }

    /// Token de sesión; se setea al hacer login/registro y se limpia al salir.
    var authToken: String {
        get { UserDefaults.standard.string(forKey: "aco_authToken") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "aco_authToken") }
    }

    private let decoder = JSONDecoder()

    // MARK: - Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        let body: [String: Any] = [
            "email":    email.trimmingCharacters(in: .whitespaces).lowercased(),
            "password": password,
        ]
        let response: LoginResponse = try await post(path: "auth/login", body: body, authorized: false)
        authToken = response.token
        return response
    }

    func register(
        email: String,
        password: String,
        name: String,
        role: AppRole,
        universityId: String? = nil,
        career: String? = nil,
        familyName: String? = nil,
        familyCode: String? = nil,
        address: String? = nil,
        neighborhood: String? = nil
    ) async throws -> LoginResponse {
        var body: [String: Any] = [
            "email":    email.trimmingCharacters(in: .whitespaces).lowercased(),
            "password": password,
            "name":     name.trimmingCharacters(in: .whitespaces),
            "role":     role.rawValue,
        ]
        if let universityId { body["universityId"] = universityId }
        if let career, !career.isEmpty { body["career"] = career }
        if let familyName, !familyName.isEmpty { body["familyName"] = familyName }
        if let familyCode, !familyCode.isEmpty { body["familyCode"] = familyCode }
        if let address, !address.isEmpty { body["address"] = address }
        if let neighborhood, !neighborhood.isEmpty { body["neighborhood"] = neighborhood }

        let response: LoginResponse = try await post(path: "auth/register", body: body, authorized: false)
        authToken = response.token
        return response
    }

    func updateElderlyLocation(latitude: Double, longitude: Double) async {
        _ = try? await post(
            path: "auth/location",
            body: ["lat": latitude, "lng": longitude]
        ) as [String: Bool]
    }

    func logout(token: String) async {
        var req = request(path: "auth/logout", method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])
        _ = try? await URLSession.shared.data(for: req)
        authToken = ""
    }

    // MARK: - Universidades

    func fetchUniversities() async throws -> [University] {
        try await get(path: "universities", authorized: false)
    }

    // MARK: - Familias

    func fetchMyFamily() async throws -> FamilyInfo {
        try await get(path: "families/me")
    }

    func joinFamily(code: String) async throws -> FamilyInfo {
        try await post(path: "families/join", body: ["code": code.trimmingCharacters(in: .whitespaces).uppercased()])
    }

    /// 3.12/3.16 — edita el perfil del adulto mayor (familia dueña, o él mismo si tiene permiso).
    /// Solo envía los campos no-nil; los flags de control parental solo los puede mandar la familia.
    func updateElderly(
        id: String,
        address: String? = nil,
        neighborhood: String? = nil,
        age: Int? = nil,
        tags: [String]? = nil,
        allowSocialConnections: Bool? = nil,
        allowSelfProfileEdit: Bool? = nil
    ) async throws -> ElderlySummary {
        var body: [String: Any] = [:]
        if let address { body["address"] = address }
        if let neighborhood { body["neighborhood"] = neighborhood }
        if let age { body["age"] = age }
        if let tags { body["tags"] = tags }
        if let allowSocialConnections { body["allowSocialConnections"] = allowSocialConnections }
        if let allowSelfProfileEdit { body["allowSelfProfileEdit"] = allowSelfProfileEdit }
        return try await patch(path: "families/elderly/\(id)", body: body)
    }

    // MARK: - Solicitudes

    /// Solicitudes de mi familia (rol familiar)
    func fetchFamilyRequests() async throws -> [APIRequest] {
        try await get(path: "requests/mine")
    }

    /// Solicitudes abiertas (rol estudiante)
    func fetchOpenRequests() async throws -> [APIRequest] {
        try await get(path: "requests/open")
    }

    func createRequest(
        elderlyProfileId: String?,
        activityType: ActivityType,
        details: String,
        scheduledDate: Date,
        isUrgent: Bool,
        latitude: Double? = nil,
        longitude: Double? = nil,
        durationMinutes: Int? = nil,
        isCommunityEvent: Bool = false,
        maxHelpersRequired: Int? = nil
    ) async throws -> APIRequest {
        var body: [String: Any] = [
            "activityType":  activityType.rawValue,
            "details":       details,
            "scheduledDate": ISO8601DateFormatter().string(from: scheduledDate),
            "isUrgent":      isUrgent,
        ]
        if let elderlyProfileId { body["elderlyProfileId"] = elderlyProfileId }
        if let lat = latitude  { body["lat"] = lat }
        if let lng = longitude { body["lng"] = lng }
        if let dm = durationMinutes { body["durationMinutes"] = dm }
        if isCommunityEvent {
            body["isCommunityEvent"] = true
            if let max = maxHelpersRequired { body["maxHelpersRequired"] = max }
        }
        return try await post(path: "requests", body: body)
    }

    // MARK: - Eventos comunitarios

    func fetchCommunityEvents() async throws -> [APIRequest] {
        try await get(path: "requests/events")
    }

    func fetchEventTypes() async throws -> [EventType] {
        try await get(path: "event-types")
    }

    func createEventType(label: String, icon: String) async throws -> EventType {
        try await post(path: "event-types", body: ["label": label, "icon": icon])
    }

    /// Crea un evento comunitario con slug de tipo libre (catálogo event_types).
    func createCommunityEvent(
        activityTypeSlug: String,
        details: String,
        scheduledDate: Date,
        latitude: Double?,
        longitude: Double?,
        maxHelpersRequired: Int,
        maxElderlyAttendees: Int
    ) async throws -> APIRequest {
        var body: [String: Any] = [
            "activityType":  activityTypeSlug,
            "details":       details,
            "scheduledDate": ISO8601DateFormatter().string(from: scheduledDate),
            "isUrgent":      false,
            "isCommunityEvent": true,
            "maxHelpersRequired": maxHelpersRequired,
            "maxElderlyAttendees": maxElderlyAttendees,
        ]
        if let latitude { body["lat"] = latitude }
        if let longitude { body["lng"] = longitude }
        return try await post(path: "requests", body: body)
    }

    func registerAttendee(requestId: String) async throws {
        let _: [String: Bool] = try await post(path: "requests/\(requestId)/attendees", body: [:])
    }

    func fetchAttendees(requestId: String) async throws -> [EventAttendee] {
        try await get(path: "requests/\(requestId)/attendees")
    }

    func unregisterAttendee(requestId: String) async throws {
        let req = request(path: "requests/\(requestId)/attendees", method: "DELETE")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp, data: data)
    }

    func deleteRequest(id: String) async throws {
        let req = request(path: "requests/\(id)", method: "DELETE")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validate(resp, data: data)
    }

    // MARK: - Postulaciones

    func applyToRequest(requestId: String, message: String) async throws -> APIApplication {
        try await post(path: "requests/\(requestId)/applications", body: ["message": message])
    }

    func fetchApplicants(requestId: String) async throws -> [APIApplication] {
        try await get(path: "requests/\(requestId)/applications")
    }

    func fetchMyApplications() async throws -> [APIApplication] {
        try await get(path: "applications/mine")
    }

    func approveApplication(id: String) async throws -> [String: String] {
        try await post(path: "applications/\(id)/approve", body: [:])
    }

    func rejectApplication(id: String) async throws {
        let _: [String: Bool] = try await post(path: "applications/\(id)/reject", body: [:])
    }

    // MARK: - Asignaciones (ciclo de visita)

    func fetchMyAssignments() async throws -> [APIAssignment] {
        try await get(path: "assignments/mine")
    }

    func fetchFamilyAssignments() async throws -> [APIAssignment] {
        try await get(path: "assignments/for-family")
    }

    func fetchElderlyAssignments() async throws -> [APIAssignment] {
        try await get(path: "assignments/for-elderly")
    }

    func markEnCamino(assignmentId: String) async throws -> APIAssignment {
        try await post(path: "assignments/\(assignmentId)/en-camino", body: [:])
    }

    func markIniciada(assignmentId: String) async throws -> APIAssignment {
        try await post(path: "assignments/\(assignmentId)/iniciar", body: [:])
    }

    func confirmarInicio(assignmentId: String) async throws -> APIAssignment {
        try await post(path: "assignments/\(assignmentId)/confirmar-inicio", body: [:])
    }

    func markCompletada(assignmentId: String) async throws -> APIAssignment {
        try await post(path: "assignments/\(assignmentId)/completar", body: [:])
    }

    /// 3.15: la familia/adulto mayor confirma que el servicio terminó.
    func confirmCompletion(assignmentId: String) async throws -> APIAssignment {
        try await post(path: "assignments/\(assignmentId)/confirm-completion", body: [:])
    }

    // MARK: - Modificación de asignación por el becario (3.7)

    func cancelAssignmentAsStudent(assignmentId: String) async throws -> APIAssignment {
        try await post(path: "assignments/\(assignmentId)/cancelar-estudiante", body: [:])
    }

    func proposeScheduleChange(assignmentId: String, newDate: Date) async throws {
        let _: [String: String] = try await post(
            path: "assignments/\(assignmentId)/proponer-cambio",
            body: ["scheduledDate": ISO8601DateFormatter().string(from: newDate)]
        )
    }

    struct PendingProposal: Codable {
        let id: String
        let proposedDate: String
    }

    func fetchPendingProposal(assignmentId: String) async throws -> PendingProposal? {
        try await get(path: "assignments/\(assignmentId)/proposal")
    }

    func respondToProposal(proposalId: String, accept: Bool) async throws {
        let _: [String: Bool] = try await post(
            path: "assignments/proposals/\(proposalId)/respond",
            body: ["accept": accept]
        )
    }

    // MARK: - Ubicación (REST fallback)

    func sendLocation(assignmentId: String, latitude: Double, longitude: Double) async throws {
        let _: [String: Bool] = try await post(
            path: "assignments/\(assignmentId)/location",
            body: ["latitude": latitude, "longitude": longitude]
        )
    }

    func fetchLocations(assignmentId: String) async throws -> [APILocation] {
        try await get(path: "assignments/\(assignmentId)/locations")
    }

    // MARK: - Reputación

    func submitRating(assignmentId: String, stars: Int, tags: [String], comment: String = "", isReport: Bool = false) async throws -> APIRating {
        try await post(
            path: "assignments/\(assignmentId)/ratings",
            body: ["stars": stars, "tags": tags, "comment": comment, "isReport": isReport]
        )
    }

    func fetchStudentProfile(id: String) async throws -> StudentProfile {
        try await get(path: "students/\(id)")
    }

    // MARK: - Notificaciones

    func fetchNotifications() async throws -> [APINotification] {
        try await get(path: "notifications")
    }

    func fetchUnreadNotificationsCount() async throws -> Int {
        let result: [String: Int] = try await get(path: "notifications/unread-count")
        return result["count"] ?? 0
    }

    func markNotificationRead(id: String) async throws {
        let _: [String: Bool] = try await post(path: "notifications/\(id)/read", body: [:])
    }

    /// El becario declara su disponibilidad (morning/afternoon/evening).
    func updateMyAvailability(_ windows: [String]) async throws -> [String] {
        struct Response: Codable { let windows: [String] }
        var req = request(path: "students/me/availability", method: "PUT")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["windows": windows])
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)
        return try decoder.decode(Response.self, from: data).windows
    }

    func fetchRequest(id: String) async throws -> APIRequest {
        try await get(path: "requests/\(id)")
    }

    // MARK: - Organizador

    func fetchOrganizerStudents(blocked: Bool? = nil) async throws -> [OrganizerStudent] {
        var path = "organizer/students"
        if let blocked { path += "?blocked=\(blocked)" }
        return try await get(path: path)
    }

    func fetchOrganizerStudent(id: String) async throws -> OrganizerStudentDetail {
        try await get(path: "organizer/students/\(id)")
    }

    /// El estudiante actualiza los tags de afinidad de su propio perfil.
    func updateMyTags(_ tags: [String]) async throws -> [String] {
        struct TagsResponse: Codable { let tags: [String] }
        var req = request(path: "students/me/tags", method: "PUT")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["tags": tags])
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)
        return try decoder.decode(TagsResponse.self, from: data).tags
    }

    func fetchMyStudentProfile() async throws -> StudentProfile {
        try await get(path: "students/me")
    }

    // MARK: - Mensajería

    func sendMessage(toStudentId: String, body: String, assignmentId: String? = nil) async throws -> APIMessage {
        var payload: [String: Any] = ["toStudentId": toStudentId, "body": body]
        if let aid = assignmentId { payload["assignmentId"] = aid }
        return try await post(path: "messages", body: payload)
    }

    func fetchInbox() async throws -> [APIMessage] {
        try await get(path: "messages/mine")
    }

    func fetchConversations() async throws -> [APIConversation] {
        try await get(path: "messages/conversations")
    }

    func fetchThread(otherId: String) async throws -> [APIMessage] {
        try await get(path: "messages/thread/\(otherId)")
    }

    func replyMessage(toUserId: String, body: String) async throws -> APIMessage {
        try await post(path: "messages/reply", body: ["toUserId": toUserId, "body": body])
    }

    func fetchUnreadCount() async throws -> Int {
        let result: [String: Int] = try await get(path: "messages/unread-count")
        return result["count"] ?? 0
    }

    // MARK: - Private helpers

    private func request(path: String, method: String) -> URLRequest {
        var req = URLRequest(url: baseURL.appending(path: path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authToken.isEmpty {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func get<T: Decodable>(path: String, authorized: Bool = true) async throws -> T {
        var req = request(path: path, method: "GET")
        if !authorized { req.setValue(nil, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(path: String, body: [String: Any], authorized: Bool = true) async throws -> T {
        var req = request(path: path, method: "POST")
        if !authorized { req.setValue(nil, forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func patch<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        var req = request(path: path, method: "PATCH")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse, data: Data = Data()) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badStatus
        }
        if http.statusCode == 401 {
            let message = (try? decoder.decode([String: String].self, from: data))?["error"]
            throw APIError.unauthorized(message ?? "Credenciales inválidas")
        }
        guard (200...299).contains(http.statusCode) else {
            if let message = (try? decoder.decode([String: String].self, from: data))?["error"] {
                throw APIError.server(message)
            }
            throw APIError.badStatus
        }
    }
}

// MARK: - APIError

enum APIError: LocalizedError {
    case badStatus
    case serverUnreachable
    case unauthorized(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badStatus:                 "El servidor devolvió un error."
        case .serverUnreachable:         "No se puede conectar al servidor. Verifica que esté corriendo."
        case .unauthorized(let message): message
        case .server(let message):       message
        }
    }
}
