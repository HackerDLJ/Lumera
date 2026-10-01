import XCTest

final class LumeraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeShowsScreeningEntryPoint() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["startScreening"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Lumera"].exists)
    }

    @MainActor
    func testScreeningOffersCameraAndPhotoLibrary() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["startScreening"].tap()

        XCTAssertTrue(app.buttons["takePhotoEntry"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["choosePhoto"].exists)
    }
}
