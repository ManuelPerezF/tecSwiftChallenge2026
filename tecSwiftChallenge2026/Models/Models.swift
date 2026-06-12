import SwiftData
import Foundation

// MARK: - FamilyMember
@Model
class FamilyMember {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String
    var phone: String

    @Relationship(deleteRule: .cascade)
    var elderlyPersons: [ElderlyPerson] = []

    @Relationship(deleteRule: .cascade)
    var requests: [ActivityRequest] = []

    init(name: String, email: String, phone: String) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.phone = phone
    }
}

// MARK: - ElderlyPerson
@Model
class ElderlyPerson {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var neighborhood: String
    var address: String
    var notes: String
    var createdAt: Date

    var familyMember: FamilyMember?

    @Relationship(deleteRule: .cascade)
    var requests: [ActivityRequest] = []

    @Relationship(deleteRule: .nullify)
    var ratings: [Rating] = []

    init(firstName: String, neighborhood: String, address: String, notes: String = "") {
        self.id = UUID()
        self.firstName = firstName
        self.neighborhood = neighborhood
        self.address = address
        self.notes = notes
        self.createdAt = Date()
    }
}

// MARK: - ActivityType
enum ActivityType: String, Codable, CaseIterable {
    case mandados    = "mandados"
    case citas       = "citas"
    case tecnologia  = "tecnologia"
    case hogar       = "hogar"
    case compania    = "compania"
    case medicamento = "medicamento"

    var emoji: String {
        switch self {
        case .mandados:    "🛒"
        case .citas:       "🚗"
        case .tecnologia:  "📱"
        case .hogar:       "🏠"
        case .compania:    "💬"
        case .medicamento: "💊"
        }
    }

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
}

// MARK: - RequestStatus
enum RequestStatus: String, Codable {
    case open, claimed, inProgress, completed, cancelled

    var label: String {
        switch self {
        case .open:      "Abierta"
        case .claimed:   "Becario asignado"
        case .inProgress:"En curso"
        case .completed: "Completada"
        case .cancelled: "Cancelada"
        }
    }
}

// MARK: - ActivityRequest
@Model
class ActivityRequest {
    @Attribute(.unique) var id: UUID
    var activityType: ActivityType
    var details: String
    var timeWindow: TimeWindow
    var frequency: String
    var isUrgent: Bool
    var status: RequestStatus
    var publishedAt: Date
    var latitude: Double
    var longitude: Double

    var elderlyPerson: ElderlyPerson?
    var familyMember: FamilyMember?

    @Relationship(deleteRule: .cascade)
    var claim: Claim?

    init(activityType: ActivityType, details: String,
         timeWindow: TimeWindow, frequency: String,
         isUrgent: Bool, latitude: Double, longitude: Double) {
        self.id = UUID()
        self.activityType = activityType
        self.details = details
        self.timeWindow = timeWindow
        self.frequency = frequency
        self.isUrgent = isUrgent
        self.status = .open
        self.publishedAt = Date()
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Student
@Model
class Student {
    @Attribute(.unique) var id: UUID
    var name: String
    var university: String
    var career: String
    var photoURL: String
    var averageRating: Double
    var totalHours: Int

    @Relationship(deleteRule: .cascade)
    var claims: [Claim] = []

    @Relationship(deleteRule: .nullify)
    var ratings: [Rating] = []

    @Relationship(deleteRule: .cascade)
    var serviceHours: [ServiceHours] = []

    init(name: String, university: String, career: String) {
        self.id = UUID()
        self.name = name
        self.university = university
        self.career = career
        self.photoURL = ""
        self.averageRating = 0.0
        self.totalHours = 0
    }
}

// MARK: - ClaimStatus
enum ClaimStatus: String, Codable {
    case pending, confirmed, onTheWay, arrived, completed, cancelled
}

// MARK: - Claim
@Model
class Claim {
    @Attribute(.unique) var id: UUID
    var proposedTime: Date
    var status: ClaimStatus
    var checkinTime: Date?
    var checkoutTime: Date?

    var request: ActivityRequest?
    var student: Student?

    @Relationship(deleteRule: .cascade)
    var serviceHours: ServiceHours?

    @Relationship(deleteRule: .cascade)
    var rating: Rating?

    init(proposedTime: Date) {
        self.id = UUID()
        self.proposedTime = proposedTime
        self.status = .pending
    }
}

// MARK: - Rating
@Model
class Rating {
    @Attribute(.unique) var id: UUID
    var stars: Int
    var tags: [String]
    var createdAt: Date

    var claim: Claim?
    var student: Student?
    var elderlyPerson: ElderlyPerson?

    init(stars: Int, tags: [String] = []) {
        self.id = UUID()
        self.stars = stars
        self.tags = tags
        self.createdAt = Date()
    }
}

// MARK: - ServiceHours
@Model
class ServiceHours {
    @Attribute(.unique) var id: UUID
    var hours: Double
    var activityType: ActivityType
    var date: Date
    var isVerified: Bool

    var claim: Claim?
    var student: Student?

    init(hours: Double, activityType: ActivityType) {
        self.id = UUID()
        self.hours = hours
        self.activityType = activityType
        self.date = Date()
        self.isVerified = false
    }
}

// MARK: - ModelContainer
extension ModelContainer {
    static var acompana: ModelContainer = {
        let schema = Schema([
            FamilyMember.self,
            ElderlyPerson.self,
            ActivityRequest.self,
            Student.self,
            Claim.self,
            Rating.self,
            ServiceHours.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
