import Foundation
import CoreML

// MARK: - HelperRecommender

/// Recomendador de afinidad becario ↔ adulto mayor, 100% on-device.
///
/// Si el bundle contiene un modelo Create ML compilado (`HelperAffinity.mlmodelc`)
/// lo usa para predecir el score; si no, usa un fallback determinista:
///   score = 0.6 · Jaccard(tags becario, tags adulto mayor)
///         + 0.25 · rating normalizado
///         + 0.15 · horas de servicio normalizadas
@MainActor
final class HelperRecommender {

    static let shared = HelperRecommender()

    private let model: MLModel?

    init() {
        // Create ML: el .mlmodel se compila a .mlmodelc dentro del bundle
        if let url = Bundle.main.url(forResource: "HelperAffinity", withExtension: "mlmodelc"),
           let loaded = try? MLModel(contentsOf: url) {
            model = loaded
        } else {
            model = nil
        }
    }

    /// Reordena las postulaciones por afinidad (mayor primero).
    func rank(applications: [APIApplication], elderlyTags: [String]) -> [APIApplication] {
        applications
            .map { (app: $0, score: score(for: $0, elderlyTags: elderlyTags)) }
            .sorted { $0.score > $1.score }
            .map(\.app)
    }

    /// Score de afinidad en [0, 1].
    func score(for application: APIApplication, elderlyTags: [String]) -> Double {
        if let model, let predicted = predictWithModel(model, application: application, elderlyTags: elderlyTags) {
            return predicted
        }
        return deterministicScore(for: application, elderlyTags: elderlyTags)
    }

    // MARK: - Create ML (si hay modelo en el bundle)

    private func predictWithModel(
        _ model: MLModel,
        application: APIApplication,
        elderlyTags: [String]
    ) -> Double? {
        let features: [String: Any] = [
            "tagOverlap": jaccard(application.tagList, elderlyTags),
            "averageRating": application.averageRating,
            "totalHours": application.totalHours,
        ]
        guard let provider = try? MLDictionaryFeatureProvider(dictionary: features),
              let output = try? model.prediction(from: provider),
              let name = output.featureNames.first,
              let value = output.featureValue(for: name) else { return nil }
        return value.doubleValue
    }

    // MARK: - Fallback determinista

    private func deterministicScore(for application: APIApplication, elderlyTags: [String]) -> Double {
        let affinity = jaccard(application.tagList, elderlyTags)
        let rating = min(max(application.averageRating / 5.0, 0), 1)
        let hours = min(application.totalHours / 50.0, 1) // 50 h ≈ becario experimentado
        return affinity * 0.6 + rating * 0.25 + hours * 0.15
    }

    /// Intersección / unión de tags (normalizados a minúsculas).
    private func jaccard(_ lhs: [String], _ rhs: [String]) -> Double {
        let a = Set(lhs.map { $0.lowercased() })
        let b = Set(rhs.map { $0.lowercased() })
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let union = a.union(b).count
        guard union > 0 else { return 0 }
        return Double(a.intersection(b).count) / Double(union)
    }
}
