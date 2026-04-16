import AppKit

// MARK: - Delegate

protocol StrikerTextViewDelegate: AnyObject {
    func strikerTextViewSave(_ textView: StrikerTextView)
    func strikerTextViewNewNote(_ textView: StrikerTextView)
    func strikerTextViewClose(_ textView: StrikerTextView)
    func strikerTextViewToggleRawMode(_ textView: StrikerTextView)
    func strikerTextViewToggleSidebar(_ textView: StrikerTextView)
}

// MARK: - StrikerTextView

/// NSTextView subclass that re-routes keyboard shortcuts explicitly.
/// Required because .accessory activation policy removes the app's menu bar,
/// so shortcuts that normally flow through NSMenu must be handled manually.
final class StrikerTextView: NSTextView {

    weak var strikerDelegate: StrikerTextViewDelegate?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        let shift = event.modifierFlags.contains(.shift)
        let key   = event.charactersIgnoringModifiers?.lowercased() ?? ""

        switch key {
        case "c":
            copy(nil)
            return true
        case "x":
            cut(nil)
            return true
        case "v":
            paste(nil)
            return true
        case "a":
            selectAll(nil)
            return true
        case "z":
            if shift {
                undoManager?.redo()
            } else {
                undoManager?.undo()
            }
            return true
        case "s":
            strikerDelegate?.strikerTextViewSave(self)
            return true
        case "w":
            strikerDelegate?.strikerTextViewClose(self)
            return true
        case "n":
            strikerDelegate?.strikerTextViewNewNote(self)
            return true
        case "r" where shift:
            strikerDelegate?.strikerTextViewToggleRawMode(self)
            return true
        case "b":
            strikerDelegate?.strikerTextViewToggleSidebar(self)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
