import SwiftUI
import UIKit

// MARK: - Color tokens
extension Color {
    // Kuidar brand teal (primary brand color)
    static let acoFamily      = Color(acoHex: "167B70")
    static let acoFamilySoft  = Color(acoHex: "DFF4F1")
    // Student green — complementary to teal
    static let acoStudent     = Color(acoHex: "1D9E75")
    static let acoStudentSoft = Color(acoHex: "E4F4EE")
    // Elderly warm orange — matches logo accent
    static let acoElderly     = Color(acoHex: "C4763A")
    static let acoElderlySoft = Color(acoHex: "F7EBE0")
    // Backgrounds and ink
    static let acoBg          = Color(acoHex: "FDF9F5")
    static let acoInk         = Color(acoHex: "1E1C1A")
    static let acoInk2        = Color(acoHex: "6B6259")
    static let acoInk3        = Color(acoHex: "A49B90")
    static let acoHair        = Color(acoHex: "3C3228").opacity(0.09)
    static let acoDone        = Color(acoHex: "6E8A4A")
    static let acoUrgent      = Color(acoHex: "D96B2A")
    static let acoStar        = Color(acoHex: "F0A52B")
    static let acoMapPin      = Color(acoHex: "167B70")

    init(acoHex hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red:     Double((int >> 16) & 0xFF) / 255,
            green:   Double((int >>  8) & 0xFF) / 255,
            blue:    Double( int        & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Haptics
enum KuidarHaptic {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Role SF Symbols
extension AppRole {
    var symbolName: String {
        switch self {
        case .family:  "person.2.fill"
        case .student: "graduationcap.fill"
        case .elderly: "figure.stand"
        }
    }
}

// MARK: - Activity SF Symbols
extension ActivityType {
    var symbolName: String {
        switch self {
        case .mandados:    "cart.fill"
        case .citas:       "car.fill"
        case .tecnologia:  "iphone"
        case .hogar:       "house.fill"
        case .compania:    "bubble.left.and.bubble.right.fill"
        case .medicamento: "pills.fill"
        }
    }
}

// MARK: - Role color helper
extension AppRole {
    var tint: Color {
        switch self {
        case .family:  .acoFamily
        case .student: .acoStudent
        case .elderly: .acoElderly
        }
    }
    var soft: Color {
        switch self {
        case .family:  .acoFamilySoft
        case .student: .acoStudentSoft
        case .elderly: .acoElderlySoft
        }
    }
}
