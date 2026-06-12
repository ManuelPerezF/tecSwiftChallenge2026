import SwiftUI

// MARK: - EventTypeCatalog

/// Caché del catálogo de tipos de evento (tabla `event_types` en BD).
/// Permite que cualquier vista resuelva label/icono para slugs que no
/// existen en el enum cerrado `ActivityType` (tipos custom de organizador).
@MainActor
@Observable
final class EventTypeCatalog {

    static let shared = EventTypeCatalog()

    private(set) var types: [EventType] = []
    private var bySlug: [String: EventType] = [:]

    func loadIfNeeded() async {
        guard types.isEmpty else { return }
        await reload()
    }

    func reload() async {
        if let fetched = try? await APIClient.shared.fetchEventTypes() {
            types = fetched
            bySlug = Dictionary(uniqueKeysWithValues: fetched.map { ($0.slug, $0) })
        }
    }

    func register(_ type: EventType) {
        if bySlug[type.slug] == nil { types.append(type) }
        bySlug[type.slug] = type
    }

    /// Label legible: catálogo → enum ActivityType → slug capitalizado.
    func label(for slug: String) -> String {
        bySlug[slug]?.label
            ?? ActivityType(rawValue: slug)?.label
            ?? slug.replacingOccurrences(of: "-", with: " ").capitalized
    }

    /// SF Symbol: catálogo → enum ActivityType → genérico.
    func icon(for slug: String) -> String {
        bySlug[slug]?.icon
            ?? ActivityType(rawValue: slug)?.symbolName
            ?? "star.fill"
    }
}
