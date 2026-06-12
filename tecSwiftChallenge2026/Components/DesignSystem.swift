import SwiftUI

// MARK: - Color tokens
extension Color {
    static let acoFamily      = Color(acoHex: "185FA5")
    static let acoFamilySoft  = Color(acoHex: "E8F0F8")
    static let acoStudent     = Color(acoHex: "1D9E75")
    static let acoStudentSoft = Color(acoHex: "E4F4EE")
    static let acoElderly     = Color(acoHex: "C4763A")
    static let acoElderlySoft = Color(acoHex: "F7EBE0")
    static let acoBg          = Color(acoHex: "FDF8F3")
    static let acoInk         = Color(acoHex: "2A2622")
    static let acoInk2        = Color(acoHex: "736B62")
    static let acoInk3        = Color(acoHex: "A89E93")
    static let acoHair        = Color(acoHex: "3C3228").opacity(0.10)
    static let acoDone        = Color(acoHex: "7A8A55")
    static let acoUrgent      = Color(acoHex: "E07B3E")
    static let acoStar        = Color(acoHex: "F0A52B")
    static let acoMapPin      = Color(acoHex: "2E7FD6")

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
