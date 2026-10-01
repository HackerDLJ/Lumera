import Foundation
import UIKit

struct ScreeningResult: Sendable {
    enum Classification: String, Sendable {
        case normalRange
        case possibleAnemia
        case highConcern
        case uncertain
        case modelUnavailable
    }

    let haemoglobinEstimate: Double?
    let classification: Classification
    let modelVersion: String?
    let recommendation: String
}

protocol LumeraInferenceEngine {
    func analyze(image: UIImage) async throws -> ScreeningResult
}

enum LumeraInferenceError: LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "No validated Lumera screening model is installed."
        }
    }
}

struct ResearchUnavailableInferenceEngine: LumeraInferenceEngine {
    func analyze(image: UIImage) async throws -> ScreeningResult {
        throw LumeraInferenceError.modelUnavailable
    }
}
