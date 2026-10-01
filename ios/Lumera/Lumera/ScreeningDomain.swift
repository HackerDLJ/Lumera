import SwiftUI
import UIKit
import CoreImage
import Combine

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum LumeraTheme {

    // MARK: - Surfaces

    static let background =
        Color(uiColor: .systemGroupedBackground)

    static let surface =
        Color(uiColor: .secondarySystemGroupedBackground)

    static let elevatedSurface =
        Color(uiColor: .systemBackground)

    // MARK: - Typography

    static let primaryText =
        Color.primary

    static let secondaryText =
        Color.secondary

    // MARK: - Brand

    static let accent =
        Color(
            red: 0.08,
            green: 0.31,
            blue: 0.26
        )

    // MARK: - Semantic

    static let success =
        Color(
            red: 0.12,
            green: 0.52,
            blue: 0.34
        )

    static let warning =
        Color(
            red: 0.65,
            green: 0.42,
            blue: 0.08
        )

    static let danger =
        Color(
            red: 0.72,
            green: 0.16,
            blue: 0.16
        )

    static let disabled =
        Color(uiColor: .systemGray3)

    // MARK: - Camera

    static let cameraOverlay =
        Color.black.opacity(0.58)
}



enum ImageQualityState: String, Codable, CaseIterable {
    case checking
    case acceptable
    case needsRecapture
    case unsupported

    var title: String {
        switch self {
        case .checking: "Checking image"
        case .acceptable: "Ready for review"
        case .needsRecapture: "Retake image"
        case .unsupported: "Image unsupported"
        }
    }
}

enum CalibrationState: String, Codable {
    case pendingCardSpecification
    case cardNotDetected
    case calibrated

    var title: String {
        switch self {
        case .pendingCardSpecification: "Reference-card detector pending"
        case .cardNotDetected: "Reference card not detected"
        case .calibrated: "Calibrated"
        }
    }
}

enum ScreeningClassification: String, Codable {
    case normalRange
    case possibleAnemia
    case highConcern
    case uncertain
    case modelUnavailable
    case imageRejected
}

enum ScreeningRecommendation: String, Codable {
    case confirmatoryTesting
    case recaptureImage
    case modelUnavailable
}

struct MeasurementInterval: Codable, Equatable {
    let lowerBound: Double
    let upperBound: Double
}

struct ScreeningResult: Codable, Identifiable, Equatable {
    let id: UUID
    let haemoglobinEstimate: Double?
    let uncertainty: MeasurementInterval?
    let classification: ScreeningClassification
    let imageQuality: ImageQualityState
    let modelVersion: String?
    let timestamp: Date
    let recommendation: ScreeningRecommendation
}

enum InferenceError: LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        "The research screening model could not process this image."
    }
}
protocol LumeraInferenceEngine {
    func analyze(image: CIImage) async throws -> ScreeningResult
}

struct ResearchUnavailableInferenceEngine: LumeraInferenceEngine {
    func analyze(image: CIImage) async throws -> ScreeningResult {
        throw InferenceError.modelUnavailable
    }
}

struct ImageQualityAssessment: Equatable {
    let state: ImageQualityState
    let detail: String
}

enum ImagePreparationError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "We couldn't read this image. Please choose another photo."
    }
}

struct ScreeningPipeline {
    let inferenceEngine: any LumeraInferenceEngine

    init(inferenceEngine: any LumeraInferenceEngine = LumeraRGBResearchInferenceEngine()) {
        self.inferenceEngine = inferenceEngine
    }

    func assess(image: UIImage) -> ImageQualityAssessment {
        let pixelWidth = image.cgImage?.width ?? Int(image.size.width * image.scale)
        let pixelHeight = image.cgImage?.height ?? Int(image.size.height * image.scale)

        guard pixelWidth >= 600, pixelHeight >= 600 else {
            return ImageQualityAssessment(
                state: .needsRecapture,
                detail: "The image is too small for screening. Take or choose a clearer image."
            )
        }

        return ImageQualityAssessment(
            state: .acceptable,
            detail: "Image dimensions are suitable. Blur, exposure, framing, intended-region visibility, and reference-card checks are not yet validated."
        )
    }

    func analyze(image: UIImage, quality: ImageQualityAssessment) async -> ScreeningResult {
        guard quality.state == .acceptable else {
            return ScreeningResult(
                id: UUID(),
                haemoglobinEstimate: nil,
                uncertainty: nil,
                classification: .imageRejected,
                imageQuality: quality.state,
                modelVersion: nil,
                timestamp: .now,
                recommendation: .recaptureImage
            )
        }

        guard let ciImage = CIImage(image: image) else {
            return ScreeningResult(
                id: UUID(),
                haemoglobinEstimate: nil,
                uncertainty: nil,
                classification: .imageRejected,
                imageQuality: .unsupported,
                modelVersion: nil,
                timestamp: .now,
                recommendation: .recaptureImage
            )
        }

        do {
            return try await inferenceEngine.analyze(image: ciImage)
        } catch {
            return ScreeningResult(
                id: UUID(),
                haemoglobinEstimate: nil,
                uncertainty: nil,
                classification: .modelUnavailable,
                imageQuality: quality.state,
                modelVersion: nil,
                timestamp: .now,
                recommendation: .modelUnavailable
            )
        }
    }
}

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let classification: ScreeningClassification
    let modelVersion: String?
}

@MainActor
final class ScreeningHistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []

    private let storageKey = "screeningHistory"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    func store(_ result: ScreeningResult) {
        guard result.classification != .modelUnavailable,
              result.classification != .imageRejected else {
            return
        }

        entries.insert(
            HistoryEntry(
                id: result.id,
                timestamp: result.timestamp,
                classification: result.classification,
                modelVersion: result.modelVersion
            ),
            at: 0
        )
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

nonisolated func downsampledImage(from image: UIImage, maximumDimension: CGFloat = 2_048) -> UIImage? {
    let longestSide = max(image.size.width, image.size.height)
    guard longestSide > 0 else { return nil }

    let scale = min(1, maximumDimension / longestSide)
    let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true

    return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
}
