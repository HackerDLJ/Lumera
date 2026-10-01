import Testing
import UIKit
@testable import Lumera

@MainActor
struct LumeraTests {
    @Test
    func smallImageNeedsRecapture() {
        let image = testImage(size: CGSize(width: 320, height: 320))
        let assessment = ScreeningPipeline().assess(image: image)

        #expect(assessment.state == .needsRecapture)
    }

    @Test
    func supportedImageIsReadyForPendingChecks() {
        let image = testImage(size: CGSize(width: 800, height: 800))
        let assessment = ScreeningPipeline().assess(image: image)

        #expect(assessment.state == .acceptable)
        #expect(assessment.detail.contains("not yet validated"))
    }

    @Test
    func unavailableEngineNeverFabricatesMedicalOutput() async {
        let image = testImage(size: CGSize(width: 800, height: 800))
        let pipeline = ScreeningPipeline()
        let assessment = pipeline.assess(image: image)

        let result = await pipeline.analyze(image: image, quality: assessment)

        #expect(result.classification == .modelUnavailable)
        #expect(result.haemoglobinEstimate == nil)
        #expect(result.modelVersion == nil)
    }

    @Test(arguments: AppAppearance.allCases)
    func appearanceOptionsAreStable(_ appearance: AppAppearance) {
        #expect(AppAppearance(rawValue: appearance.rawValue) == appearance)
    }

    private func testImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
