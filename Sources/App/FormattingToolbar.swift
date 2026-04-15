import AppKit

/// Floating toolbar that appears above the text selection with formatting buttons.
/// Uses `.nonactivatingPanel` so clicks don't steal focus from the editor.
final class FormattingToolbar: NSPanel {

    private weak var targetTextView: NSTextView?

    private struct Action {
        let title: String
        let symbol: String
        let prefix: String
        let suffix: String
    }

    private static let actions: [Action] = [
        Action(title: "H1", symbol: "textformat.size.larger", prefix: "# ", suffix: ""),
        Action(title: "H2", symbol: "textformat.size", prefix: "## ", suffix: ""),
        Action(title: "H3", symbol: "textformat.size.smaller", prefix: "### ", suffix: ""),
        Action(title: "B",  symbol: "bold", prefix: "**", suffix: "**"),
        Action(title: "I",  symbol: "italic", prefix: "*", suffix: "*"),
        Action(title: "S",  symbol: "strikethrough", prefix: "~~", suffix: "~~"),
        Action(title: "<>", symbol: "chevron.left.forwardslash.chevron.right", prefix: "`", suffix: "`"),
        Action(title: "🔗", symbol: "link", prefix: "[", suffix: "](url)"),
    ]

    init() {
        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .borderless]
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 36),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        level = .popUpMenu
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        hasShadow = true
        backgroundColor = .clear

        setupContent()
    }

    override var canBecomeKey: Bool { false }

    // MARK: - Setup

    private func setupContent() {
        let vev = NSVisualEffectView()
        vev.material = .popover
        vev.blendingMode = .behindWindow
        vev.state = .active
        vev.wantsLayer = true
        vev.layer?.cornerRadius = 8
        vev.layer?.masksToBounds = true
        contentView = vev

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        vev.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: vev.topAnchor),
            stack.leadingAnchor.constraint(equalTo: vev.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: vev.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: vev.bottomAnchor),
        ])

        for (index, action) in Self.actions.enumerated() {
            let btn = NSButton()
            btn.bezelStyle = .accessoryBarAction
            btn.isBordered = false
            btn.tag = index
            btn.target = self
            btn.action = #selector(buttonTapped(_:))
            btn.toolTip = action.title

            if let img = NSImage(systemSymbolName: action.symbol, accessibilityDescription: action.title) {
                btn.image = img
                btn.imagePosition = .imageOnly
            } else {
                btn.title = action.title
            }

            btn.widthAnchor.constraint(equalToConstant: 32).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
            stack.addArrangedSubview(btn)
        }
    }

    // MARK: - Show / hide

    func show(for textView: NSTextView) {
        targetTextView = textView
        guard let window = textView.window else { return }

        let selRange = textView.selectedRange()
        guard selRange.length > 0 else { hide(); return }

        // Get the rect of the selection in window coordinates
        let layoutManager = textView.layoutManager!
        let glyphRange = layoutManager.glyphRange(forCharacterRange: selRange, actualCharacterRange: nil)
        var selRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer!)
        selRect.origin.x += textView.textContainerOrigin.x
        selRect.origin.y += textView.textContainerOrigin.y

        let rectInWindow = textView.convert(selRect, to: nil)
        let rectOnScreen = window.convertToScreen(rectInWindow)

        // Position toolbar above selection, centered
        let toolbarWidth = frame.width
        let toolbarHeight = frame.height
        var x = rectOnScreen.midX - toolbarWidth / 2
        let y = rectOnScreen.maxY + 6

        // Screen-edge clamping
        if let screen = window.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            x = max(screenFrame.minX + 4, min(x, screenFrame.maxX - toolbarWidth - 4))
        }

        setFrameOrigin(NSPoint(x: x, y: y))
        orderFront(nil)
    }

    func hide() {
        orderOut(nil)
        targetTextView = nil
    }

    // MARK: - Actions

    @objc private func buttonTapped(_ sender: NSButton) {
        guard let textView = targetTextView,
              sender.tag < Self.actions.count else { return }

        let action = Self.actions[sender.tag]
        let selRange = textView.selectedRange()

        // Get the selected text
        let nsString = textView.string as NSString
        let selectedText = nsString.substring(with: selRange)

        // Check if this is a heading action (prefix-only, no suffix)
        if action.suffix.isEmpty {
            // Heading: wrap entire line — find line boundaries
            let lineRange = nsString.lineRange(for: selRange)
            let lineText = nsString.substring(with: lineRange).trimmingCharacters(in: .newlines)

            // Strip existing heading prefix if toggling
            let newText: String
            if lineText.hasPrefix(action.prefix) {
                newText = String(lineText.dropFirst(action.prefix.count))
            } else {
                // Strip any existing heading prefix first
                let stripped = lineText.replacingOccurrences(
                    of: "^#{1,6}\\s*",
                    with: "",
                    options: .regularExpression
                )
                newText = action.prefix + stripped
            }

            let trimmedLineRange = NSRange(
                location: lineRange.location,
                length: (lineText as NSString).length
            )

            if textView.shouldChangeText(in: trimmedLineRange, replacementString: newText) {
                textView.replaceCharacters(in: trimmedLineRange, with: newText)
                textView.didChangeText()
            }
        } else {
            // Inline wrapper: toggle prefix/suffix around selection
            let newText: String
            if selectedText.hasPrefix(action.prefix) && selectedText.hasSuffix(action.suffix)
                && selectedText.count >= action.prefix.count + action.suffix.count {
                // Unwrap
                let start = selectedText.index(selectedText.startIndex, offsetBy: action.prefix.count)
                let end = selectedText.index(selectedText.endIndex, offsetBy: -action.suffix.count)
                newText = String(selectedText[start..<end])
            } else {
                // Wrap
                newText = action.prefix + selectedText + action.suffix
            }

            if textView.shouldChangeText(in: selRange, replacementString: newText) {
                textView.replaceCharacters(in: selRange, with: newText)
                textView.didChangeText()
            }
        }
    }
}
