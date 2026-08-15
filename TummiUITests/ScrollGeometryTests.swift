import XCTest

/// Guards against content that is wider than the screen.
///
/// Chip rows are built from data — a milestone can cite three bodies, a food can carry an
/// allergen plus a choking flag plus a paediatrician marker — so their total width is not
/// knowable at design time. When one overflows, the screen gains a sideways drag and the
/// layout drifts, which is what the Plan tab did before `FlowLayout`.
///
/// The check is the symptom, not the cause: drag horizontally and assert nothing moved.
/// Enumerating every label instead was correct but took a quarter of an hour once the food
/// library reached 168 rows — a test nobody runs guards nothing.
final class ScrollGeometryTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true

        app = XCUIApplication()
        app.launchArguments = ["-DemoSeed", "1", "-DemoReset", "1", "-OpenTab", "0"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func selectTab(_ index: Int) {
        app.tabBars.firstMatch.buttons.element(boundBy: index).tap()
    }

    private func drag(dxFrom: Double, dxTo: Double, dy: Double) {
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: dxFrom, dy: dy))
            .press(forDuration: 0.05,
                   thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: dxTo, dy: dy)))
    }

    /// Drags left and then right at mid-screen height, which avoids the two rows that are
    /// horizontal scrollers by design (the Foods filter chips and the allergen pills).
    private func assertDoesNotPanSideways(_ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        let probe = app.staticTexts.element(boundBy: 0)
        guard probe.waitForExistence(timeout: 5) else {
            return XCTFail("\(screen): no label to measure", file: file, line: line)
        }
        let before = probe.frame.minX

        drag(dxFrom: 0.92, dxTo: 0.08, dy: 0.45)
        XCTAssertEqual(probe.frame.minX, before, accuracy: 0.5,
                       "\(screen) panned left", file: file, line: line)

        drag(dxFrom: 0.08, dxTo: 0.92, dy: 0.45)
        XCTAssertEqual(probe.frame.minX, before, accuracy: 0.5,
                       "\(screen) panned right", file: file, line: line)
    }

    /// Cheap overflow check: the first labels on screen, not the whole tree.
    private func assertVisibleLabelsFitTheWindow(
        _ screen: String, limitCount: Int = 40,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let edge = app.windows.firstMatch.frame.maxX
        for element in app.staticTexts.allElementsBoundByIndex.prefix(limitCount) {
            guard element.exists else { continue }
            let frame = element.frame
            guard frame.width > 0, frame.minX >= 0, frame.minX < edge else { continue }
            XCTAssertLessThanOrEqual(
                frame.maxX, edge + 0.5,
                "\(screen): '\(element.label)' reaches \(frame.maxX)pt past the \(edge)pt window",
                file: file, line: line
            )
        }
    }

    private func scrollDown(_ steps: Int) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        for _ in 0..<steps {
            start.press(forDuration: 0.01, thenDragTo: end)
        }
    }

    // MARK: - Tests

    func testNoTabPansSideways() {
        for (index, name) in ["Today", "Log", "Foods", "Plan", "Growth"].enumerated() {
            selectTab(index)
            assertDoesNotPanSideways(name)
        }
    }

    /// The specific regression: the Plan timeline cites up to three bodies per milestone,
    /// which overflowed a single-line HStack.
    func testPlanTimelineChipsWrapInsteadOfOverflowing() {
        selectTab(3)
        scrollDown(8)
        assertVisibleLabelsFitTheWindow("Plan timeline")
        assertDoesNotPanSideways("Plan timeline")
    }

    /// A food detail carries the most chips of any screen: allergen, choking, nutrients
    /// and one citation per source.
    func testFoodDetailFitsTheWindow() {
        selectTab(2)
        let peanut = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'Peanut'")
        ).firstMatch
        if peanut.waitForExistence(timeout: 5) {
            peanut.tap()
            assertVisibleLabelsFitTheWindow("Peanut detail")
            assertDoesNotPanSideways("Peanut detail")
        }
    }
}
