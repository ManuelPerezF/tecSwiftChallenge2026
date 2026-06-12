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

// MARK: - Layout tokens

enum AcoSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum AcoRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

// MARK: - Surfaces

extension View {
    /// Fondo cálido de pantalla con soporte de grouped lists.
    func acoScreenBackground() -> some View {
        background(Color.acoBg.ignoresSafeArea())
    }

    /// Superficie agrupada estilo Settings.
    func acoGroupedSurface(cornerRadius: CGFloat = AcoRadius.md) -> some View {
        background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Interacción

struct AcoPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - iOS-native typography

enum AcoTypography {
    static func screenTitle(_ text: String) -> some View {
        Text(text)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(Color.acoInk)
            .tracking(-0.4)
    }

    static func heroTitle(_ text: String) -> some View {
        Text(text)
            .font(.title.weight(.bold))
            .foregroundStyle(Color.acoInk)
    }
    /// Encabezado de sección: oración normal, no uppercase.
    static func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(Color.acoInk2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }

    /// Etiqueta sobre campos de formulario.
    static func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color.acoInk2)
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
