import Foundation

// MARK: - Lightweight UI models (prototype data, not SwiftData)

struct StudentMini: Hashable {
    let name: String
    let uni: String
    let career: String
    let hours: Int
    let rating: Double
}

struct FamilyRequestItem: Identifiable, Hashable {
    let id: String
    let activityType: ActivityType
    let status: RequestStatus
    let title: String
    let when: String
    let isUrgent: Bool
    let student: StudentMini?
    let eta: String?
    let aiSummary: String?
    let completedRating: Int?
}

struct OpenRequest: Identifiable, Hashable {
    let id: String
    let activityType: ActivityType
    let neighborhood: String
    let timeWindow: TimeWindow
    let duration: String
    let hours: Double
    let isUrgent: Bool
    let xPct: Double
    let yPct: Double
    let distance: String
    let matchScore: Int
    let elderlyName: String
    let title: String
    let description: String
}

struct CommitmentItem: Identifiable {
    let id: String
    let activityType: ActivityType
    let elderlyName: String
    let title: String
    let time: String
    let address: String
}

struct HistoryEntry: Identifiable {
    let id = UUID()
    let date: String
    let activity: String
    let studentName: String
    let rating: Int
}

// MARK: - Sample instances

let sampleFamilyRequests: [FamilyRequestItem] = [
    FamilyRequestItem(
        id: "r1", activityType: .mandados, status: .inProgress,
        title: "Mandado al super",
        when: "Hoy · mañana", isUrgent: false,
        student: StudentMini(name: "Carlos Méndez", uni: "UNAM", career: "Medicina", hours: 84, rating: 4.9),
        eta: "Llegó 10:05", aiSummary: nil, completedRating: nil
    ),
    FamilyRequestItem(
        id: "r2", activityType: .tecnologia, status: .claimed,
        title: "Configurar el celular",
        when: "Jueves · tarde", isUrgent: false,
        student: StudentMini(name: "Ana Rivas", uni: "ITESM", career: "Diseño", hours: 41, rating: 4.8),
        eta: nil, aiSummary: nil, completedRating: nil
    ),
    FamilyRequestItem(
        id: "r3", activityType: .citas, status: .open,
        title: "Cita con el cardiólogo",
        when: "Vie 13 · mañana", isUrgent: true,
        student: nil, eta: nil, aiSummary: nil, completedRating: nil
    ),
    FamilyRequestItem(
        id: "r4", activityType: .compania, status: .completed,
        title: "Tarde de compañía",
        when: "Lun 9 · tarde", isUrgent: false,
        student: StudentMini(name: "Diego Soto", uni: "IPN", career: "Ing. Civil", hours: 67, rating: 5.0),
        eta: nil,
        aiSummary: "Diego acompañó a Doña Carmen toda la tarde, jugaron dominó y se quedó 1h 50min. Ella lo calificó con 5 estrellas.",
        completedRating: 5
    ),
]

let sampleOpenRequests: [OpenRequest] = [
    OpenRequest(id: "o1", activityType: .citas,       neighborhood: "Del Valle",  timeWindow: .morning,   duration: "2 h",    hours: 2,    isUrgent: true,  xPct: 32, yPct: 30, distance: "0.8 km", matchScore: 94, elderlyName: "Carmen",  title: "Cita con el cardiólogo",       description: "Acompañarla al hospital ABC, está un poco nerviosa. Llevar su carpeta de estudios."),
    OpenRequest(id: "o2", activityType: .mandados,    neighborhood: "Narvarte",   timeWindow: .afternoon, duration: "1 h",    hours: 1,    isUrgent: false, xPct: 60, yPct: 48, distance: "1.2 km", matchScore: 88, elderlyName: "Jorge",   title: "Mandado al mercado",           description: "Ayuda cargando las bolsas, vive en 3er piso sin elevador."),
    OpenRequest(id: "o3", activityType: .tecnologia,  neighborhood: "Roma Sur",   timeWindow: .afternoon, duration: "45 min", hours: 0.75, isUrgent: false, xPct: 46, yPct: 66, distance: "1.5 km", matchScore: 81, elderlyName: "Lupita",  title: "Videollamada con la familia",  description: "Quiere aprender a usar WhatsApp para ver a sus nietos."),
    OpenRequest(id: "o4", activityType: .compania,    neighborhood: "Del Valle",  timeWindow: .evening,   duration: "1.5 h",  hours: 1.5,  isUrgent: false, xPct: 22, yPct: 54, distance: "0.9 km", matchScore: 77, elderlyName: "Roberto", title: "Tarde de plática y café",      description: "Le gusta platicar de fútbol y jugar dominó."),
    OpenRequest(id: "o5", activityType: .medicamento, neighborhood: "Narvarte",   timeWindow: .morning,   duration: "30 min", hours: 0.5,  isUrgent: true,  xPct: 72, yPct: 28, distance: "1.4 km", matchScore: 72, elderlyName: "Elena",   title: "Recoger medicamentos",         description: "Recoger receta en la farmacia y entregarla en casa."),
]

let sampleCommitments: [CommitmentItem] = [
    CommitmentItem(id: "c1", activityType: .mandados,   elderlyName: "Doña Carmen", title: "Mandado al super",      time: "Hoy · 10:30",   address: "Av. Coyoacán 1435, int. 3"),
    CommitmentItem(id: "c2", activityType: .tecnologia, elderlyName: "Don Jorge",   title: "Configurar el celular", time: "Jue 12 · 16:00", address: "Calle Diagonal 88"),
]

let sampleHistory: [HistoryEntry] = [
    HistoryEntry(date: "Lun 9 jun",  activity: "Compañía",   studentName: "Diego S.", rating: 5),
    HistoryEntry(date: "Jue 5 jun",  activity: "Tecnología", studentName: "Ana R.",   rating: 5),
    HistoryEntry(date: "Mar 3 jun",  activity: "Mandados",   studentName: "Carlos M.", rating: 4),
]
