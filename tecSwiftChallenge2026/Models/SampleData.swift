import Foundation

// MARK: - UI models (mapa y detalle de solicitudes abiertas)

struct OpenRequest: Identifiable, Hashable {
    let id: String
    let activityType: ActivityType
    let neighborhood: String
    let timeWindow: TimeWindow
    let scheduledDateFormatted: String
    let duration: String
    let hours: Double
    let isUrgent: Bool
    let latitude: Double
    let longitude: Double
    let distance: String
    let matchScore: Int
    let elderlyName: String
    let title: String
    let description: String
}

#if DEBUG
enum PreviewData {
    static let openRequest = OpenRequest(
        id: "preview",
        activityType: .citas,
        neighborhood: "Del Valle",
        timeWindow: .morning,
        scheduledDateFormatted: "Hoy · 10:00",
        duration: "2 h",
        hours: 2,
        isUrgent: true,
        latitude: 19.3812,
        longitude: -99.1714,
        distance: "0.8 km",
        matchScore: 94,
        elderlyName: "Carmen",
        title: "Cita con el cardiólogo",
        description: "Acompañarla al hospital ABC, está un poco nerviosa."
    )
}
#endif
