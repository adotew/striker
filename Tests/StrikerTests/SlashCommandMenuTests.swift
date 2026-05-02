import XCTest
import AppKit
@testable import Striker

/// Tests for SlashCommandMenu filtering, navigation, and selection.
/// These are pure logic tests — no window needed for filter/nav,
/// only for show/hide visibility checks.
final class SlashCommandMenuTests: XCTestCase {

    private var menu: SlashCommandMenu!

    override func setUp() {
        super.setUp()
        menu = SlashCommandMenu()
    }

    override func tearDown() {
        menu.hide()
        menu = nil
        super.tearDown()
    }

    // MARK: - Filtering

    func testEmptyFilterShowsAllActions() {
        menu.filterString = ""
        XCTAssertEqual(menu.visibleItemCount, FormattingToolbar.actions.count)
        XCTAssertFalse(menu.hasNoResults)
    }

    func testFilterMatchesBoldByDisplayTitle() {
        menu.filterString = "bold"
        XCTAssertEqual(menu.visibleItemCount, 1)
        XCTAssertFalse(menu.hasNoResults)
    }

    func testFilterMatchesAllThreeHeadings() {
        menu.filterString = "heading"
        XCTAssertEqual(menu.visibleItemCount, 3)
    }

    func testFilterMatchesHeadingOne() {
        menu.filterString = "heading 1"
        XCTAssertEqual(menu.visibleItemCount, 1)
    }

    func testFilterMatchesItalic() {
        menu.filterString = "ital"
        XCTAssertEqual(menu.visibleItemCount, 1)
    }

    func testFilterMatchesStrikethrough() {
        menu.filterString = "stri"
        XCTAssertEqual(menu.visibleItemCount, 1)
    }

    func testFilterMatchesCode() {
        menu.filterString = "code"
        XCTAssertEqual(menu.visibleItemCount, 1)
    }

    func testFilterMatchesLink() {
        menu.filterString = "link"
        XCTAssertEqual(menu.visibleItemCount, 1)
    }

    func testFilterIsCaseInsensitive() {
        menu.filterString = "BOLD"
        XCTAssertEqual(menu.visibleItemCount, 1)

        menu.filterString = "Heading"
        XCTAssertEqual(menu.visibleItemCount, 3)
    }

    func testUnknownFilterSetsHasNoResults() {
        menu.filterString = "xyzzy"
        XCTAssertTrue(menu.hasNoResults)
        XCTAssertEqual(menu.visibleItemCount, 0)
    }

    func testFilterResetsToEmptyRestoresAll() {
        menu.filterString = "bold"
        XCTAssertEqual(menu.visibleItemCount, 1)
        menu.filterString = ""
        XCTAssertEqual(menu.visibleItemCount, FormattingToolbar.actions.count)
    }

    func testFilterResetsSelectionToFirstRow() {
        menu.filterString = ""
        menu.moveDown()
        menu.moveDown()
        XCTAssertGreaterThan(menu.selectedItemIndex, 0)

        menu.filterString = "bold"
        XCTAssertEqual(menu.selectedItemIndex, 0, "Changing filter should reset selection to row 0")
    }

    // MARK: - Navigation

    func testInitialSelectionIsZero() {
        XCTAssertEqual(menu.selectedItemIndex, 0)
    }

    func testMoveDownAdvancesSelection() {
        menu.filterString = ""
        menu.moveDown()
        XCTAssertEqual(menu.selectedItemIndex, 1)
    }

    func testMoveDownMultipleTimes() {
        menu.filterString = ""
        menu.moveDown()
        menu.moveDown()
        menu.moveDown()
        XCTAssertEqual(menu.selectedItemIndex, 3)
    }

    func testMoveUpDecrementsSelection() {
        menu.filterString = ""
        menu.moveDown()
        menu.moveDown()
        menu.moveUp()
        XCTAssertEqual(menu.selectedItemIndex, 1)
    }

    func testMoveUpClampsAtFirstRow() {
        menu.filterString = ""
        menu.moveUp()
        menu.moveUp()
        XCTAssertEqual(menu.selectedItemIndex, 0, "moveUp should not go below 0")
    }

    func testMoveDownClampsAtLastRow() {
        menu.filterString = ""
        let total = FormattingToolbar.actions.count
        for _ in 0..<total + 10 { menu.moveDown() }
        XCTAssertEqual(menu.selectedItemIndex, total - 1, "moveDown should not exceed last index")
    }

    func testNavigationDoesNothingWhenNoResults() {
        menu.filterString = "xyzzy"
        // should not crash or change state
        menu.moveDown()
        menu.moveUp()
        XCTAssertTrue(menu.hasNoResults)
    }

    func testNavigationWithFilteredList() {
        // filter to only headings (rows 0,1,2 → original 0,1,2)
        menu.filterString = "heading"
        XCTAssertEqual(menu.visibleItemCount, 3)
        menu.moveDown()
        XCTAssertEqual(menu.selectedItemIndex, 1)
        menu.moveDown()
        XCTAssertEqual(menu.selectedItemIndex, 2)
        menu.moveDown()
        XCTAssertEqual(menu.selectedItemIndex, 2, "clamped at last visible row")
    }

    // MARK: - Selection / onSelect

    func testConfirmSelectionFiresOnSelectForFirstRow() {
        menu.filterString = ""
        var received: Int? = nil
        menu.onSelect = { received = $0 }

        menu.confirmSelection() // row 0 = H1 = original index 0
        XCTAssertEqual(received, 0)
    }

    func testConfirmSelectionAfterMoveDownFiresCorrectIndex() {
        menu.filterString = ""
        var received: Int? = nil
        menu.onSelect = { received = $0 }

        menu.moveDown() // row 1 = H2 = original index 1
        menu.confirmSelection()
        XCTAssertEqual(received, 1)
    }

    func testConfirmSelectionMapsFilteredBoldToOriginalIndex() {
        // Bold = original index 3
        menu.filterString = "bold"
        var received: Int? = nil
        menu.onSelect = { received = $0 }
        menu.confirmSelection()
        XCTAssertEqual(received, 3)
    }

    func testConfirmSelectionMapsFilteredItalicToOriginalIndex() {
        menu.filterString = "italic"
        var received: Int? = nil
        menu.onSelect = { received = $0 }
        menu.confirmSelection()
        XCTAssertEqual(received, 4)
    }

    func testConfirmSelectionMapsFilteredStrikethroughToOriginalIndex() {
        menu.filterString = "stri"
        var received: Int? = nil
        menu.onSelect = { received = $0 }
        menu.confirmSelection()
        XCTAssertEqual(received, 5)
    }

    func testConfirmSelectionMapsFilteredCodeToOriginalIndex() {
        menu.filterString = "code"
        var received: Int? = nil
        menu.onSelect = { received = $0 }
        menu.confirmSelection()
        XCTAssertEqual(received, 6)
    }

    func testConfirmSelectionMapsFilteredLinkToOriginalIndex() {
        menu.filterString = "link"
        var received: Int? = nil
        menu.onSelect = { received = $0 }
        menu.confirmSelection()
        XCTAssertEqual(received, 7)
    }

    func testConfirmSelectionHeadingTwoViaFilterAndNav() {
        menu.filterString = "heading"
        var received: Int? = nil
        menu.onSelect = { received = $0 }
        menu.moveDown() // row 1 = Heading 2 = original index 1
        menu.confirmSelection()
        XCTAssertEqual(received, 1)
    }

    func testConfirmSelectionHeadingThreeViaFilterAndNav() {
        menu.filterString = "heading"
        var received: Int? = nil
        menu.onSelect = { received = $0 }
        menu.moveDown()
        menu.moveDown() // row 2 = Heading 3 = original index 2
        menu.confirmSelection()
        XCTAssertEqual(received, 2)
    }

    func testConfirmSelectionDoesNothingWhenNoResults() {
        menu.filterString = "xyzzy"
        var received: Int? = nil
        menu.onSelect = { received = $0 }
        menu.confirmSelection()
        XCTAssertNil(received, "onSelect should not fire when there are no results")
    }

    // MARK: - Show / hide visibility

    func testConfirmSelectionHidesMenu() {
        let window = makeWindow()
        defer { window.close() }

        menu.show(caretRect: NSRect(x: 300, y: 300, width: 1, height: 16), in: window)
        XCTAssertTrue(menu.isVisible)

        menu.confirmSelection()
        XCTAssertFalse(menu.isVisible)
    }

    func testHideClosesMenu() {
        let window = makeWindow()
        defer { window.close() }

        menu.show(caretRect: NSRect(x: 300, y: 300, width: 1, height: 16), in: window)
        XCTAssertTrue(menu.isVisible)
        menu.hide()
        XCTAssertFalse(menu.isVisible)
    }

    // MARK: - Helpers

    private func makeWindow() -> NSWindow {
        let w = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.makeKeyAndOrderFront(nil)
        return w
    }
}
