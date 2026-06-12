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

    func registerAttendee(requestId: String) async throws {
        let _: [String: Bool] = try await post(path: "requests/\(requestId)/attendees", body: [:])
    }

    func fetchAttendees(requestId: String) async throws -> [EventAttendee] {
        try await get(path: "requests/\(requestId)/attendees")
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

    func submitRating(assignmentId: String, stars: Int, tags: [String], comment: String = "") async throws -> APIRating {
        try await post(
            path: "assignments/\(assignmentId)/ratings",
            body: ["stars": stars, "tags": tags, "comment": comment]
        )
    }

    func fetchStudentProfile(id: String) async throws -> StudentProfile {
        try await get(path: "students/\(id)")
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
