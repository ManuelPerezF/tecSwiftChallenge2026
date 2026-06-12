import Foundation

enum AppRole: String, Hashable, CaseIterable {
    case family    = "family"
    case student   = "student"
    case elderly   = "elderly"
    case organizer = "organizer"

    var title: String {
        switch self {
        case .family:    "Familia"
        case .student:   "Becario"
        case .elderly:   "Adulto mayor"
        case .organizer: "Organizador"
        }
    }

    var subtitle: String {
        switch self {
        case .family:    "Publica solicitudes para tu familiar"
        case .student:   "Explora visitas y acumula horas"
        case .elderly:   "Ve quién viene a visitarte"
        case .organizer: "Crea eventos comunitarios multi-becario"
        }
    }

}
