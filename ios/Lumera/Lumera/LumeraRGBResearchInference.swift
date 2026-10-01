import Foundation
import CoreImage
import UIKit
import simd

/// Research-only on-device classifier trained from aggregate RGB percentages.
/// It does NOT estimate hemoglobin and is NOT clinically validated.
struct LumeraRGBResearchInferenceEngine: LumeraInferenceEngine {

    private let modelVersion = "rgb-research-0.1.0"

    private let mean = SIMD3<Double>(
        45.654175,
        28.87550673076923,
        25.470325000000003
    )

    private let standardDeviation = SIMD3<Double>(
        2.802721327146927,
        1.5467845985403461,
        1.9751067524581474
    )

    private let coefficients = SIMD3<Double>(
        -0.4868029018455612,
        1.640084952592022,
        -0.593566882085709
    )

    private let intercept = -0.7039785808192356
    private let threshold = 0.5

    private let context = CIContext(options: [
        .workingColorSpace: NSNull(),
        .outputColorSpace: NSNull()
    ])

    func analyze(image: CIImage) async throws -> ScreeningResult {
        let features = try extractRGBPercentages(from: image)

        let normalized = SIMD3<Double>(
            (features.x - mean.x) / standardDeviation.x,
            (features.y - mean.y) / standardDeviation.y,
            (features.z - mean.z) / standardDeviation.z
        )

        let logit =
            simd_dot(coefficients, normalized) + intercept

        let probability = 1.0 / (1.0 + exp(-logit))

        let classification: ScreeningClassification =
            probability >= threshold
            ? .possibleAnemia
            : .normalRange

        return ScreeningResult(
            id: UUID(),
            haemoglobinEstimate: nil,
            uncertainty: nil,
            classification: classification,
            imageQuality: .acceptable,
            modelVersion: modelVersion,
            timestamp: .now,
            recommendation: .confirmatoryTesting
        )
    }

    private func extractRGBPercentages(
        from image: CIImage
    ) throws -> SIMD3<Double> {

        let extent = image.extent.integral

        guard extent.width > 20, extent.height > 20 else {
            throw InferenceError.modelUnavailable
        }

        // Provisional ROI:
        // central 60% of the supplied image.
        // This is intentionally conservative until a validated
        // conjunctiva detector is integrated.
        let roi = extent.insetBy(
            dx: extent.width * 0.20,
            dy: extent.height * 0.20
        )

        let averageFilter = CIFilter(name: "CIAreaAverage")

        averageFilter?.setValue(
            image,
            forKey: kCIInputImageKey
        )

        averageFilter?.setValue(
            CIVector(cgRect: roi),
            forKey: kCIInputExtentKey
        )

        guard
            let output = averageFilter?.outputImage
        else {
            throw InferenceError.modelUnavailable
        }

        var pixel = [UInt8](repeating: 0, count: 4)

        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(
                x: 0,
                y: 0,
                width: 1,
                height: 1
            ),
            format: .RGBA8,
            colorSpace: nil
        )

        let red = Double(pixel[0])
        let green = Double(pixel[1])
        let blue = Double(pixel[2])

        let total = red + green + blue

        guard total > 0 else {
            throw InferenceError.modelUnavailable
        }

        return SIMD3(
            red / total * 100.0,
            green / total * 100.0,
            blue / total * 100.0
        )
    }
}
