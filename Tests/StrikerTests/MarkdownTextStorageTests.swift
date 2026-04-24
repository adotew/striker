import XCTest
import AppKit
@testable import Striker

final class MarkdownTextStorageTests: XCTestCase {

    func testAppliesHiddenSyntaxInStyledMode() {
        let storage = MarkdownTextStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "**bold**")

        let hiddenColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(hiddenColor, NSColor.clear)

        let visibleColor = storage.attribute(.foregroundColor, at: 3, effectiveRange: nil) as? NSColor
        XCTAssertNotEqual(visibleColor, NSColor.clear)
    }

    func testRawModeShowsSyntaxCharacters() {
        let storage = MarkdownTextStorage()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "**bold**")

        storage.isRawMode = true

        let colorAtDelimiter = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNotEqual(colorAtDelimiter, NSColor.clear)

        let fontAtDelimiter = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(fontAtDelimiter)
        XCTAssertGreaterThan(fontAtDelimiter!.pointSize, 1.0)
    }
}
