import Foundation
import FoundationModels

// On-device AI via Apple Foundation Models (iOS 26+).
// All inference is private — no data leaves the device.
@MainActor
final class FoundationModelClient {

    static let shared = FoundationModelClient()

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Student: visit preparation tip

    /// Short empathetic tip to help the student prepare for a specific visit.
    func visitTip(
        activityType: ActivityType,
        description: String,
        elderlyName: String,
        neighborhood: String
    ) async throws -> String {
        let session = LanguageModelSession(instructions: """
            Eres el asistente de Kuidar, app que conecta becarios universitarios con adultos mayores en México.
            Das consejos breves, empáticos y prácticos para que los becarios brinden atención de calidad.
            Responde en máximo 2 oraciones cortas. Sin saludos ni introducciones. Solo el consejo en español.
            Tono: cálido, concreto, orientado al bienestar del adulto mayor.
            """)

        let prompt = """
            Actividad: \(activityType.label)
            Descripción: \(description)
            Adulto mayor: \(elderlyName), colonia \(neighborhood)
            """

        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Family: suggest request description

    /// Generate a clear, empathetic description for a help request based on activity + optional notes.
    func suggestDescription(activityType: ActivityType, notes: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
            Eres asistente de Kuidar. Ayudas a familias mexicanas a describir solicitudes de ayuda para sus adultos mayores.
            Escribe en primera persona del familiar. Máximo 120 caracteres. Sin emojis. Sin introducción.
            Solo la descripción, clara y concreta para que el becario sepa exactamente qué necesita el adulto mayor.
            """)

        let context = notes.isEmpty
            ? "Solicitud de \(activityType.label.lowercased())."
            : "Solicitud de \(activityType.label.lowercased()). Notas del familiar: \(notes)."

        let response = try await session.respond(to: context)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Elderly: visit welcome message

    /// Short warm message shown to the elderly person about the upcoming visit.
    func elderlyWelcome(studentName: String, activityType: ActivityType) async throws -> String {
        let session = LanguageModelSession(instructions: """
            Eres el asistente de Kuidar. Escribes mensajes cálidos y sencillos para adultos mayores.
            Usa lenguaje muy simple, letras grandes (no emojis). Máximo 1 oración de bienvenida.
            """)

        let prompt = "\(studentName) viene a ayudar con \(activityType.label.lowercased())."
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
