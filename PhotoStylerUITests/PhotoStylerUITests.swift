import XCTest

/// Drives the real app. Launch arguments reach states that cannot otherwise be
/// scripted: system permission alerts are not reliably driveable, and the
/// Simulator has no camera hardware.
/// XCUIApplication and every element query are main-actor bound, so the whole
/// case is isolated rather than each member individually.
@MainActor
final class PhotoStylerUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    func testHomeScreenShowsAllEntryPoints() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["PhotoStyler"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open Camera"].exists)
        XCTAssertTrue(app.buttons["Browse Styles"].exists)
        XCTAssertTrue(app.buttons["My Photos"].exists)
    }

    func testBrowsingStylesShowsCatalogue() {
        let app = launch("-openStyles")
        XCTAssertTrue(app.navigationBars["Styles"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cinematic"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Warm Film"].exists)
    }

    func testProfileDetailShowsIntensityControl() {
        let app = launch("-openStyles", "-openProfile", "warm-film")
        XCTAssertTrue(app.staticTexts["Intensity"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.sliders["Style intensity"].exists)
    }

    func testCameraDeniedOffersSettings() {
        let app = launch("-openCamera", "-forceCameraDenied")
        XCTAssertTrue(app.staticTexts["Camera Access Needed"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
    }

    func testCameraShowsProfileStripAndShutter() {
        // Relies on the Simulator's synthetic feed standing in for hardware.
        let app = launch("-openCamera")
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Switch camera"].exists)
        XCTAssertTrue(app.buttons["Cinematic"].waitForExistence(timeout: 10))
    }

    func testGalleryStartsEmpty() {
        let app = launch("-openGallery")
        XCTAssertTrue(app.staticTexts["No Photos Yet"].waitForExistence(timeout: 10))
    }
}
