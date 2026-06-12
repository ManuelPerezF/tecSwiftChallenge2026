import Foundation
import NaturalLanguage

// MARK: - ActivityIntent

/// Resultado del parseo on-device de una descripción en lenguaje natural.
struct ActivityIntent {
    let activityType: ActivityType?
    let isUrgent: Bool
    let suggestedDate: Date?
    let rawText: String
}

// MARK: - IntentParser

/// Parser de intenciones 100% on-device usando el framework NaturalLanguage.
/// Sin APIs externas: tokeniza con NLTagger, normaliza acentos y mapea
/// keywords en español a los casos existentes de `ActivityType`.
enum IntentParser {

    // Keywords → tipo de actividad (lemas sin acentos, en minúsculas)
    private static let activityKeywords: [(keywords: Set<String>, type: ActivityType)] = [
        (["mandado", "mandados", "super", "supermercado", "tienda", "comprar",
          "compras", "compra", "mercado", "despensa", "tortillas", "pan"], .mandados),
        (["doctor", "doctora", "medico", "medica", "cita", "citas", "consulta",
          "hospital", "clinica", "dentista", "acompanar", "acompane", "acompañe",
          "laboratorio", "vacuna"], .citas),
        (["celular", "telefono", "computadora", "compu", "tablet", "internet",
          "whatsapp", "videollamada", "tecnologia", "aplicacion", "app",
          "television", "tele", "control"], .tecnologia),
        (["limpiar", "limpieza", "casa", "hogar", "jardin", "plantas", "regar",
          "arreglar", "reparar", "foco", "mueble", "cocinar", "cocina",
          "lavar", "ropa", "barrer", "trapear"], .hogar),
        (["compania", "acompañar", "platicar", "platica", "conversar", "visita",
          "visitar", "caminar", "caminata", "paseo", "pasear", "parque",
          "domino", "loteria", "cartas", "leer", "solo", "sola"], .compania),
        (["medicina", "medicinas", "medicamento", "medicamentos", "pastilla",
          "pastillas", "farmacia", "receta", "inyeccion", "tratamiento"], .medicamento),
    ]

    private static let urgencyKeywords: Set<String> = [
        "urgente", "urge", "urgentemente", "ahora", "ahorita", "ya",
        "inmediato", "inmediatamente", "rapido", "pronto", "emergencia",
    ]

    private static let weekdays: [String: Int] = [
        "domingo": 1, "lunes": 2, "martes": 3, "miercoles": 4,
        "jueves": 5, "viernes": 6, "sabado": 7,
    ]

    /// Parsea texto libre en español y devuelve la intención detectada.
    /// Ej. "necesito que alguien me acompañe al doctor el viernes, es urgente"
    /// → (.citas, isUrgent: true, suggestedDate: próximo viernes)
    static func parseIntent(from text: String) -> ActivityIntent {
        let tokens = tokenize(text)

        return ActivityIntent(
            activityType: detectActivity(in: tokens),
            isUrgent: detectUrgency(in: tokens),
            suggestedDate: detectDate(in: tokens, fullText: text),
            rawText: text
        )
    }

    // MARK: - Tokenización (NLTagger)

    /// Tokeniza con NLTagger y normaliza: minúsculas y sin acentos.
    private static func tokenize(_ text: String) -> [String] {
        // Confirmar idioma (es) — informativo; el parseo funciona igual
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        _ = recognizer.dominantLanguage

        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text

        var tokens: [String] = []
        tagger.enumerateTags(
            in: text.startIndex ..< text.endIndex,
            unit: .word,
            scheme: .tokenType,
            options: [.omitWhitespace, .omitPunctuation]
        ) { _, range in
            tokens.append(normalize(String(text[range])))
            return true
        }
        return tokens
    }

    private static func normalize(_ word: String) -> String {
        word.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
    }

    // MARK: - Detección

    private static func detectActivity(in tokens: [String]) -> ActivityType? {
        var scores: [ActivityType: Int] = [:]
        for token in tokens {
            for entry in activityKeywords where entry.keywords.contains(token) {
                scores[entry.type, default: 0] += 1
            }
        }
        return scores.max { $0.value < $1.value }?.key
    }

    private static func detectUrgency(in tokens: [String]) -> Bool {
        tokens.contains { urgencyKeywords.contains($0) }
    }

    /// Referencias temporales simples: hoy, mañana, pasado mañana, día de la semana.
    private static func detectDate(in tokens: [String], fullText: String) -> Date? {
        let cal = Calendar.current
        let now = Date()
        // Hora por defecto para fechas sugeridas: 10:00 am
        func at10(_ date: Date) -> Date {
            cal.date(bySettingHour: 10, minute: 0, second: 0, of: date) ?? date
        }

        let normalized = normalize(fullText)

        if normalized.contains("pasado manana") {
            return at10(cal.date(byAdding: .day, value: 2, to: now) ?? now)
        }
        // "mañana" como referencia temporal (no "por la mañana")
        if tokens.contains("manana"), !normalized.contains("por la manana"),
           !normalized.contains("en la manana"), !normalized.contains("de la manana") {
            return at10(cal.date(byAdding: .day, value: 1, to: now) ?? now)
        }
        if tokens.contains("hoy") {
            // Hoy: dentro de 2 horas para que sea agendable
            return cal.date(byAdding: .hour, value: 2, to: now)
        }
        for token in tokens {
            if let weekday = weekdays[token] {
                var components = DateComponents()
                components.weekday = weekday
                if let next = cal.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                    return at10(next)
                }
            }
        }
        return nil
    }
}
