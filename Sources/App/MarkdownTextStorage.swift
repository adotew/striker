import AppKit

/// NSTextStorage subclass that live-formats markdown using cmark-gfm.
///
/// Design:
/// - Wraps a concrete `NSTextStorage` (the backing store).
/// - On every edit, re-parses the full document (cmark is fast — sub-ms for typical notes).
/// - Applies attributes in `processEditing` after the edit is committed.
/// - Disables undo registration during attribute changes so only text edits are undoable.
final class MarkdownTextStorage: NSTextStorage {

    // MARK: - Backing store

    private let backing = NSMutableAttributedString()

    // MARK: - Re-entrancy guard

    private var isStyling = false

    // MARK: - Raw mode

    var isRawMode = false {
        didSet {
            guard isRawMode != oldValue else { return }
            reapplyAllStyles()
        }
    }

    // MARK: - NSTextStorage required overrides

    override var string: String {
        backing.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        let delta = (str as NSString).length - range.length
        edited(.editedCharacters, range: range, changeInLength: delta)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - Process editing (called after every edit transaction)

    override func processEditing() {
        // Let NSTextStorage do its thing first (fixes up attribute runs, etc.)
        super.processEditing()

        // Only re-style if characters actually changed (not just attributes)
        if editedMask.contains(.editedCharacters) {
            applyMarkdownStyles()
        }
    }

    // MARK: - Full re-style

    func reapplyAllStyles() {
        applyMarkdownStyles()
    }

    // MARK: - Attribute application

    private func applyMarkdownStyles() {
        guard !isStyling else { return }
        let fullRange = NSRange(location: 0, length: length)
        guard fullRange.length > 0 else { return }
        isStyling = true
        defer { isStyling = false }

        // Disable undo for attribute changes — only text edits should be undoable.
        let undoManager = self.undoManagerForTextStorage
        let wasUndoEnabled = undoManager?.isUndoRegistrationEnabled ?? false
        if wasUndoEnabled { undoManager?.disableUndoRegistration() }
        defer { if wasUndoEnabled { undoManager?.enableUndoRegistration() } }

        beginEditing()

        // Reset to base attributes
        setAttributes(MarkdownStyle.baseAttributes, range: fullRange)

        if !isRawMode {
            let source = string as NSString
            let ranges = CMarkParser.parse(string)
            for mdRange in ranges {
                // Clamp range to current string length
                let loc = min(mdRange.range.location, length)
                let len = min(mdRange.range.length, length - loc)
                guard len > 0 else { continue }
                let safeRange = NSRange(location: loc, length: len)

                let attrs = MarkdownStyle.attributes(for: mdRange.type)
                addAttributes(attrs, range: safeRange)

                // Hide syntax delimiters
                let syntaxRanges = MarkdownStyle.syntaxRanges(for: mdRange, in: source)
                let hiddenAttrs = MarkdownStyle.hiddenSyntaxAttributes
                for sr in syntaxRanges {
                    let sLoc = min(sr.location, length)
                    let sLen = min(sr.length, length - sLoc)
                    guard sLen > 0 else { continue }
                    addAttributes(hiddenAttrs, range: NSRange(location: sLoc, length: sLen))
                }
            }
        }

        endEditing()
    }

    // MARK: - Undo manager access

    /// Find the undo manager via the layout managers' text views.
    private var undoManagerForTextStorage: UndoManager? {
        layoutManagers.first?.textContainers.first?.textView?.undoManager
    }
}
