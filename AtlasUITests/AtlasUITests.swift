import XCTest

final class AtlasUITests: XCTestCase {
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AtlasUITest", "YES"]
        app.launch()
    }
}
