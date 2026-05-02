import XCTest
import AppKit
@testable import Striker

/// Tests for FormattingToolbar.apply(actionAt:to:) exercised via the slash command flow.
///
/// Each test simulates what EditorViewController.applySlashCommand does:
///   1. Delete the "/" (and any filter text) at the anchor position
///   2. Call apply(actionAt:to:) with the cursor at the anchor
///
/// Raw vs markdown distinction:
///   - In markdown mode (isRawMode = false): MarkdownTextStorage hides syntax delimiters
///     (foreground = .clear, near-zero font size).
///   - In raw mode (isRawMode = true): delimiters are visible with normal color/font.
///
/// Note: apply() produces the SAME raw text in both modes.
/// The tests verify raw text content + visual attributes per mode.
final class SlashCommandApplyTests: XCTestCase {

    private var window: NSWindow!
    private var storage: MarkdownTextStorage!
    private var textView: NSTextView!
    private var toolbar: FormattingToolbar!

    override func setUp() {
        super.setUp()

        storage = MarkdownTextStorage()

        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        textView = NSTextView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 400),
            textContainer: container
        )
        textView.isEditable = true
        textView.isRichText = true

        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(textView)
        window.makeKeyAndOrderFront(nil)

        toolbar = FormattingToolbar()
    }

    override func tearDown() {
        toolbar.close()
        window.close()
        window = nil
        storage = nil
        textView = nil
        toolbar = nil
        super.tearDown()
    }

    // MARK: - Heading at cursor (empty selection)

    func testApplyH1AtCursorAddsPrefix() {
        setContent("Hello")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 0, to: textView)
        XCTAssertEqual(textView.string, "# Hello")
    }

    func testApplyH2AtCursorAddsPrefix() {
        setContent("World")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 1, to: textView)
        XCTAssertEqual(textView.string, "## World")
    }

    func testApplyH3AtCursorAddsPrefix() {
        setContent("Sub")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 2, to: textView)
        XCTAssertEqual(textView.string, "### Sub")
    }

    func testApplyH2UpgradesExistingH1() {
        setContent("# Title")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 1, to: textView) // H2
        XCTAssertEqual(textView.string, "## Title", "H1 should be replaced by H2 prefix")
    }

    func testApplyH1TogglesOffExistingH1() {
        setContent("# Title")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 0, to: textView) // H1 again = toggle off
        XCTAssertEqual(textView.string, "Title")
    }

    func testApplyH1TogglesOffExistingH3() {
        setContent("### Title")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 0, to: textView) // H1 replaces H3
        XCTAssertEqual(textView.string, "# Title")
    }

    // MARK: - Inline formats at cursor (empty selection)

    func testApplyBoldWithEmptySelectionInsertsDelimiters() {
        setContent("")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 3, to: textView)
        XCTAssertEqual(textView.string, "****")
    }

    func testApplyItalicWithEmptySelectionInsertsDelimiters() {
        setContent("")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 4, to: textView)
        XCTAssertEqual(textView.string, "**")
    }

    func testApplyStrikethroughWithEmptySelectionInsertsDelimiters() {
        setContent("")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 5, to: textView)
        XCTAssertEqual(textView.string, "~~~~")
    }

    func testApplyCodeWithEmptySelectionInsertsDelimiters() {
        setContent("")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 6, to: textView)
        XCTAssertEqual(textView.string, "``")
    }

    func testApplyLinkWithEmptySelectionInsertsDelimiters() {
        setContent("")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 7, to: textView)
        XCTAssertEqual(textView.string, "[](url)")
    }

    // MARK: - Raw mode: same raw text, delimiters visible

    func testBoldDelimitersHiddenInMarkdownMode() {
        storage.isRawMode = false
        setContent("hello")
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        toolbar.apply(actionAt: 3, to: textView) // Bold → "**hello**"

        // Position 0 is first '*' — should be hidden in markdown mode
        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .clear, "Bold '*' delimiters should be invisible in markdown mode")
    }

    func testBoldDelimitersVisibleInRawMode() {
        storage.isRawMode = true
        setContent("hello")
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        toolbar.apply(actionAt: 3, to: textView) // Bold → "**hello**"

        // Position 0 is first '*' — should be visible in raw mode
        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNotEqual(color, .clear, "Bold '*' delimiters should be visible in raw mode")
    }

    func testBoldRawTextSameInBothModes() {
        // Raw text content must be identical regardless of mode
        storage.isRawMode = false
        setContent("word")
        textView.setSelectedRange(NSRange(location: 0, length: 4))
        toolbar.apply(actionAt: 3, to: textView)
        let markdownModeText = textView.string

        storage.isRawMode = true
        setContent("word")
        textView.setSelectedRange(NSRange(location: 0, length: 4))
        toolbar.apply(actionAt: 3, to: textView)
        let rawModeText = textView.string

        XCTAssertEqual(markdownModeText, rawModeText, "apply() should produce identical raw text in both modes")
    }

    func testH1PrefixHiddenInMarkdownMode() {
        storage.isRawMode = false
        setContent("Title")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 0, to: textView) // H1 → "# Title"

        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .clear, "H1 '#' should be hidden in markdown mode")
    }

    func testH1PrefixVisibleInRawMode() {
        storage.isRawMode = true
        setContent("Title")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        toolbar.apply(actionAt: 0, to: textView) // H1 → "# Title"

        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNotEqual(color, .clear, "H1 '#' should be visible in raw mode")
    }

    func testItalicDelimitersHiddenInMarkdownMode() {
        storage.isRawMode = false
        setContent("hello")
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        toolbar.apply(actionAt: 4, to: textView) // Italic → "*hello*"

        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .clear, "Italic '*' delimiters should be hidden in markdown mode")
    }

    func testItalicDelimitersVisibleInRawMode() {
        storage.isRawMode = true
        setContent("hello")
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        toolbar.apply(actionAt: 4, to: textView) // Italic → "*hello*"

        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNotEqual(color, .clear, "Italic '*' delimiters should be visible in raw mode")
    }

    // MARK: - Empty heading: prefix hidden even with no content

    func testH1PrefixHiddenWhenHeadingContentIsEmpty() {
        // This is the slash-command-on-blank-line scenario:
        // "/ " → delete "/" → apply H1 → "# " (no content after prefix)
        // The "#" MUST be hidden even though the heading has no content yet.
        storage.isRawMode = false
        setContent("# ")
        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .clear, "H1 '#' must be hidden in markdown mode even on an empty heading line")
    }

    func testH2PrefixHiddenWhenHeadingContentIsEmpty() {
        storage.isRawMode = false
        setContent("## ")
        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .clear, "H2 '#' must be hidden in markdown mode even on an empty heading line")
    }

    func testH3PrefixHiddenWhenHeadingContentIsEmpty() {
        storage.isRawMode = false
        setContent("### ")
        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .clear, "H3 '#' must be hidden in markdown mode even on an empty heading line")
    }

    // MARK: - Slash command delete-then-apply flow

    func testSlashDeletedBeforeHeadingApplied() {
        // Simulate: line was "Hello", user types "/" → "Hello\n/" on its own line,
        // then selects H1 from slash menu. After delete: "/" gone, H1 applied to line.
        setContent("Hello\n/")
        let anchor = 6 // position of "/"

        // Delete the "/"
        deleteRange(NSRange(location: anchor, length: 1))
        textView.setSelectedRange(NSRange(location: anchor, length: 0))

        toolbar.apply(actionAt: 0, to: textView) // H1 on the now-empty second line
        XCTAssertEqual(textView.string, "Hello\n# ")
    }

    func testSlashAndFilterDeletedBeforeBoldApplied() {
        // Simulate: text = "note /bo text", user types "/bo" → selects Bold
        setContent("note /bo text")
        let anchor = 5  // position of "/"
        let cursor = 8  // position after "bo"

        // Delete "/bo"
        deleteRange(NSRange(location: anchor, length: cursor - anchor))
        textView.setSelectedRange(NSRange(location: anchor, length: 0))

        toolbar.apply(actionAt: 3, to: textView) // Bold at cursor
        XCTAssertEqual(textView.string, "note **** text")
    }

    func testSlashDeletedBeforeCodeApplied() {
        setContent("Use / here")
        let anchor = 4

        deleteRange(NSRange(location: anchor, length: 1))
        textView.setSelectedRange(NSRange(location: anchor, length: 0))

        toolbar.apply(actionAt: 6, to: textView) // Code
        XCTAssertEqual(textView.string, "Use `` here")
    }

    // MARK: - Helpers

    private func setContent(_ text: String) {
        let range = NSRange(location: 0, length: storage.length)
        storage.replaceCharacters(in: range, with: text)
    }

    private func deleteRange(_ range: NSRange) {
        if textView.shouldChangeText(in: range, replacementString: "") {
            textView.textStorage?.replaceCharacters(in: range, with: "")
            textView.didChangeText()
        }
    }
}
