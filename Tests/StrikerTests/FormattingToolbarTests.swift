import XCTest
import AppKit
@testable import Striker

final class FormattingToolbarTests: XCTestCase {

    func testBoldButtonWrapsSelection() throws {
        let (window, textView) = makeWindowAndTextView(text: "hello")
        defer { window.close() }

        let toolbar = FormattingToolbar()
        defer { toolbar.close() }

        textView.setSelectedRange(NSRange(location: 0, length: 5))
        toolbar.show(for: textView)

        let boldButton = try XCTUnwrap(findButton(in: toolbar, toolTip: "B"))
        boldButton.performClick(nil)

        XCTAssertEqual(textView.string, "**hello**")
    }

    func testBoldButtonUnwrapsWhenSelectionInsideBoldText() throws {
        let (window, textView) = makeWindowAndTextView(text: "**hello**")
        defer { window.close() }

        let toolbar = FormattingToolbar()
        defer { toolbar.close() }

        textView.setSelectedRange(NSRange(location: 3, length: 2)) // inside "hello"
        toolbar.show(for: textView)

        let boldButton = try XCTUnwrap(findButton(in: toolbar, toolTip: "B"))
        boldButton.performClick(nil)

        XCTAssertEqual(textView.string, "hello")
    }

    func testHeadingButtonTogglesPrefixOnCurrentLine() throws {
        let (window, textView) = makeWindowAndTextView(text: "Title\nBody")
        defer { window.close() }

        let toolbar = FormattingToolbar()
        defer { toolbar.close() }

        let h2Button = try XCTUnwrap(findButton(in: toolbar, toolTip: "H2"))

        textView.setSelectedRange(NSRange(location: 0, length: 5))
        toolbar.show(for: textView)
        h2Button.performClick(nil)
        XCTAssertEqual(textView.string, "## Title\nBody")

        textView.setSelectedRange(NSRange(location: 0, length: 8))
        toolbar.show(for: textView)
        h2Button.performClick(nil)
        XCTAssertEqual(textView.string, "Title\nBody")
    }

    func testShowMarksBoldButtonActiveForBoldSelection() throws {
        let (window, textView) = makeWindowAndTextView(text: "**hello**")
        defer { window.close() }

        let toolbar = FormattingToolbar()
        defer { toolbar.close() }

        textView.setSelectedRange(NSRange(location: 3, length: 2))
        toolbar.show(for: textView)

        let boldButton = try XCTUnwrap(findButton(in: toolbar, toolTip: "B"))
        XCTAssertEqual(boldButton.contentTintColor, .controlAccentColor)
    }

    // MARK: - Helpers

    private func makeWindowAndTextView(text: String) -> (NSWindow, NSTextView) {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.string = text
        window.contentView?.addSubview(textView)
        window.makeKeyAndOrderFront(nil)

        return (window, textView)
    }

    private func findButton(in toolbar: FormattingToolbar, toolTip: String) -> NSButton? {
        guard let root = toolbar.contentView else { return nil }
        return allSubviews(of: root)
            .compactMap { $0 as? NSButton }
            .first(where: { $0.toolTip == toolTip })
    }

    private func allSubviews(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { allSubviews(of: $0) }
    }
}
