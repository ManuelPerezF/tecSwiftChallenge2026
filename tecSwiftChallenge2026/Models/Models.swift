import Foundation

// MARK: - ActivityType

enum ActivityType: String, Codable, CaseIterable {
    case mandados    = "mandados"
    case citas       = "citas"
    case tecnologia  = "tecnologia"
    case hogar       = "hogar"
    case compania    = "compania"
    case medicamento = "medicamento"

    var label: String {
        switch self {
        case .mandados:    "Mandados"
        case .citas:       "Citas médicas"
        case .tecnologia:  "Ayuda digital"
        case .hogar:       "Tareas del hogar"
        case .compania:    "Compañía"
        case .medicamento: "Medicamentos"
        }
    }
}

// MARK: - TimeWindow

enum TimeWindow: String, Codable, CaseIterable {
    case morning   = "Mañana (8–12)"
    case afternoon = "Tarde (12–18)"
    case evening   = "Noche (18–21)"

    var shortLabel: String {
        switch self {
        case .morning:   "Mañana"
        case .afternoon: "Tarde"
        case .evening:   "Noche"
        }
    }

    static func from(date: Date) -> TimeWindow {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 12 { return .morning }
        if hour < 18 { return .afternoon }
        return .evening
    }
}

// MARK: - RequestStatus

enum RequestStatus: String, Codable {
    case open, claimed, inProgress, completed, cancelled, full

    var label: String {
        switch self {
        case .open:       "Abierta"
        case .claimed:    "Becario asignado"
        case .inProgress: "En curso"
        case .completed:  "Completada"
        case .cancelled:  "Cancelada"
        case .full:       "Lleno"
        }
    }
}

// MARK: - Auth

struct AuthUser: Codable, Sendable {
    let id: String
    let name: String
    let email: String
    let role: String

    var roleEnum: AppRole? {
        AppRole(rawValue: role)
    }
}

struct ProfilePayload: Codable, Sendable {
    var familyId: String?
    var familyCode: String?
    var familyName: String?
    var studentId: String?
    var universityId: String?
    var universityName: String?
    var career: String?
    var totalHours: Double?
    var averageRating: Double?
    var elderlyProfileId: String?
    var joinedFamily: Bool?
}

struct LoginResponse: Codable, Sendable {
    let token: String
    let user: AuthUser
    let profile: ProfilePayload
}

// MARK: - Catálogos

struct University: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let lat: Double
    let lng: Double
}

struct FamilyInfo: Codable, Sendable {
    let id: String
    let name: String
    let familyCode: String
    let elderly: [ElderlySummary]
}

struct ElderlySummary: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let firstName: String
    let address: String
    let neighborhood: String
    let lat: Double
    let lng: Double
    let tags: [String]?

    var tagList: [String] { tags ?? [] }
}

// MARK: - Postulaciones

struct APIApplication: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let requestId: String
    let studentId: String
    let studentName: String
    let universityName: String
    let career: String
    let totalHours: Double
    let averageRating: Double
    let message: String
    let status: String      // pending | approved | rejected | waiting_list | cancelled_by_helper
    let createdAt: String
    let tags: [String]?

    var isPending: Bool { status == "pending" }
    var isWaitingList: Bool { status == "waiting_list" }
    var tagList: [String] { tags ?? [] }
}

// MARK: - Eventos comunitarios

/// Tipo de evento del catálogo en BD (estándar o custom creado por organizador).
struct EventType: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let label: String
    let icon: String
    let isCustom: Bool
}

// MARK: - Notificaciones in-app

struct APINotification: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let type: String
    let title: String
    let body: String
    let data: [String: String]
    let read: Bool
    let createdAt: String

    /// Notificaciones que piden confirmación explícita (¿Estás disponible y cerca?)
    var requiresConfirmation: Bool { data["requiresConfirmation"] == "true" }
    var requestId: String? { data["requestId"] }
}

// MARK: - Organizador: becarios y bloqueos

struct OrganizerStudent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let universityName: String
    let career: String
    let totalHours: Double
    let averageRating: Double
    let tags: [String]
    let isBlocked: Bool
}

struct StudentBlock: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let reason: String
    let comment: String
    let familyName: String
    let stars: Int?
    let active: Bool
    let createdAt: String
}

struct OrganizerStudentDetail: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let universityName: String
    let career: String
    let totalHours: Double
    let averageRating: Double
    let tags: [String]
    let isBlocked: Bool
    let badges: [APIBadge]
    let ratings: [APIRating]
    let blocks: [StudentBlock]
}

struct EventAttendee: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let name: String
    let role: String
    let createdAt: String
}

// MARK: - Asignaciones (visitas)

enum AssignmentStatus: String, Codable, Sendable {
    case approved, enCamino = "en_camino", esperandoConfirmacion = "esperando_confirmacion"
    case iniciada, esperandoConfirmacionFin = "esperando_confirmacion_fin", completada, cancelada

    var label: String {
        switch self {
        case .approved:                 "Aprobada"
        case .enCamino:                 "En camino"
        case .esperandoConfirmacion:    "Esperando confirmación"
        case .iniciada:                 "En curso"
        case .esperandoConfirmacionFin: "Por confirmar fin"
        case .completada:               "Completada"
        case .cancelada:                "Cancelada"
        }
    }

    var isActive: Bool {
        self == .approved || self == .enCamino || self == .esperandoConfirmacion
            || self == .iniciada || self == .esperandoConfirmacionFin
    }
}

struct APIAssignment: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let requestId: String
    let studentId: String
    let studentName: String
    let status: String
    let approvedAt: String
    let enCaminoAt: String?
    let inicioSolicitadoAt: String?
    let checkinAt: String?
    let checkoutAt: String?
    let hoursLogged: Double
    let activityType: String
    let details: String
    let scheduledDate: String
    let isUrgent: Bool
    let latitude: Double
    let longitude: Double
    let elderlyName: String
    let neighborhood: String
    let address: String
    let familyId: String

    var statusEnum: AssignmentStatus {
        AssignmentStatus(rawValue: status) ?? .approved
    }

    var activityTypeEnum: ActivityType {
        ActivityType(rawValue: activityType) ?? .compania
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var scheduledDateParsed: Date {
        APIAssignment.isoFormatter.date(from: scheduledDate)
            ?? APIAssignment.isoFormatterNoFrac.date(from: scheduledDate)
            ?? Date()
    }

    var scheduledDateFormatted: String {
        let date = scheduledDateParsed
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            df.dateFormat = "'Hoy · 'HH:mm"
        } else if cal.isDateInTomorrow(date) {
            df.dateFormat = "'Mañana · 'HH:mm"
        } else {
            df.dateFormat = "EEE d MMM · HH:mm"
        }
        return df.string(from: date)
    }
}

// MARK: - Reputación

struct APIBadge: Codable, Identifiable, Hashable, Sendable {
    let slug: String
    let title: String
    let description: String
    let icon: String
    let earnedAt: String

    var id: String { slug }
}

struct APIRating: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let stars: Int
    let tags: [String]
    let comment: String
    let authorName: String
    let createdAt: String
}

struct StudentProfile: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let universityName: String
    let career: String
    let totalHours: Double
    let averageRating: Double
    let tags: [String]?
    let badges: [APIBadge]
    let ratings: [APIRating]

    var tagList: [String] { tags ?? [] }
}

// MARK: - Mensajería in-app

struct APIConversation: Codable, Identifiable, Hashable, Sendable {
    let studentId: String
    let studentName: String
    let lastBody: String
    let lastAt: String
    let unreadCount: Int

    var id: String { studentId }

    var lastAtFormatted: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        guard let date = iso.date(from: lastAt) ?? iso2.date(from: lastAt) else { return lastAt }
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        let cal = Calendar.current
        if cal.isDateInToday(date) { df.dateFormat = "HH:mm" }
        else if cal.isDateInYesterday(date) { df.dateFormat = "'Ayer'" }
        else { df.dateFormat = "d MMM" }
        return df.string(from: date)
    }
}

struct APIMessage: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let fromUserId: String
    let fromName: String
    let toStudentId: String
    let toUserId: String?
    let body: String
    let assignmentId: String?
    let readAt: String?
    let createdAt: String

    var isUnread: Bool { readAt == nil }

    var createdAtFormatted: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        guard let date = iso.date(from: createdAt) ?? iso2.date(from: createdAt) else { return createdAt }
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        let cal = Calendar.current
        if cal.isDateInToday(date) { df.dateFormat = "HH:mm" }
        else if cal.isDateInYesterday(date) { df.dateFormat = "'Ayer · 'HH:mm" }
        else { df.dateFormat = "d MMM · HH:mm" }
        return df.string(from: date)
    }
}

// MARK: - Ubicación

struct APILocation: Codable, Hashable, Sendable {
    let role: String        // student | elderly
    let latitude: Double
    let longitude: Double
    let recordedAt: String
}

// MARK: - APIRequest  (respuesta del servidor)

struct APIRequest: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let elderlyProfileId: String?
    let activityType: String
    let details: String
    let scheduledDate: String   // ISO8601 string
    let isUrgent: Bool
    let status: String
    let publishedAt: String
    let latitude: Double
    let longitude: Double
    let elderlyName: String
    let neighborhood: String
    let matchScore: Int
    let duration: String
    let hours: Double
    // Eventos comunitarios (opcionales para compatibilidad)
    let isCommunityEvent: Bool?
    let maxHelpersRequired: Int?
    let activeHelpers: Int?
    let maxElderlyAttendees: Int?
    let activeElderlyAttendees: Int?

    var isEvent: Bool { isCommunityEvent ?? false }
    var helpersLabel: String { "\(activeHelpers ?? 0)/\(maxHelpersRequired ?? 1) becarios" }
    var elderlyQuotaLabel: String? {
        guard let max = maxElderlyAttendees, max > 0 else { return nil }
        return "\(activeElderlyAttendees ?? 0)/\(max) adultos mayores"
    }
    var isFull: Bool { status == "full" }

    // MARK: Computed helpers

    var activityTypeEnum: ActivityType {
        ActivityType(rawValue: activityType) ?? .compania
    }

    var statusEnum: RequestStatus {
        RequestStatus(rawValue: status) ?? .open
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var scheduledDateParsed: Date {
        APIRequest.isoFormatter.date(from: scheduledDate)
            ?? APIRequest.isoFormatterNoFrac.date(from: scheduledDate)
            ?? Date()
    }

    var scheduledDateFormatted: String {
        let date = scheduledDateParsed
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            df.dateFormat = "'Hoy · 'HH:mm"
        } else if cal.isDateInTomorrow(date) {
            df.dateFormat = "'Mañana · 'HH:mm"
        } else {
            df.dateFormat = "EEE d MMM · HH:mm"
        }
        return df.string(from: date)
    }

    var timeWindow: TimeWindow {
        TimeWindow.from(date: scheduledDateParsed)
    }

    // MARK: Conversion helpers

    func toOpenRequest(fromLat: Double? = nil, fromLng: Double? = nil) -> OpenRequest {
        let dist: String
        if let sLat = fromLat, let sLng = fromLng, latitude != 0 && longitude != 0 {
            let dLat = (sLat - latitude) * 111_320
            let dLng = (sLng - longitude) * 111_320 * cos(latitude * .pi / 180)
            let meters = (dLat * dLat + dLng * dLng).squareRoot()
            dist = meters < 1_000
                ? String(format: "%.0f m", meters)
                : String(format: "%.1f km", meters / 1_000)
        } else {
            dist = ""
        }
        return OpenRequest(
            id: id,
            activityType: activityTypeEnum,
            neighborhood: neighborhood,
            timeWindow: timeWindow,
            scheduledDateFormatted: scheduledDateFormatted,
            duration: duration,
            hours: hours,
            isUrgent: isUrgent,
            latitude: latitude,
            longitude: longitude,
            distance: dist,
            matchScore: matchScore,
            elderlyName: elderlyName,
            title: activityTypeEnum.label,
            description: details
        )
    }
}
