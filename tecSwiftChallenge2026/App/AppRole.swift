import Foundation

enum AppRole: Hashable, CaseIterable {
    case family, student, elderly

    var title: String {
        switch self {
        case .family:  "Familia"
        case .student: "Becario"
        case .elderly: "Adulto mayor"
        }
    }

    var subtitle: String {
        switch self {
        case .family:  "Hijo / hija"
        case .student: "Estudiante"
        case .elderly: "Abuelito / a"
        }
    }

    var emoji: String {
        switch self {
        case .family:  "👨‍👩‍👧"
        case .student: "🎓"
        case .elderly: "🧓"
        }
    }
}
