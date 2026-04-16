import AppKit

/// Floating toolbar that appears above the text selection with formatting buttons.
/// Uses `.nonactivatingPanel` so clicks don't steal focus from the editor.
final class FormattingToolbar: NSPanel {

    private weak var targetTextView: NSTextView?
    private var buttons: [NSButton] = []

    private struct Action {
        let title: String
        let symbol: String
        let prefix: String
        let suffix: String
        let matchesNodeType: ((MarkdownNodeType) -> Bool)?
    }

    private static let actions: [Action] = [
        Action(title: "H1", symbol: "textformat.size.larger",                   prefix: "# ",   suffix: "",       matchesNodeType: nil),
        Action(title: "H2", symbol: "textformat.size",                           prefix: "## ",  suffix: "",       matchesNodeType: nil),
        Action(title: "H3", symbol: "textformat.size.smaller",                   prefix: "### ", suffix: "",       matchesNodeType: nil),
        Action(title: "B",  symbol: "bold",                                      prefix: "**",   suffix: "**",     matchesNodeType: { $0 == .strong }),
        Action(title: "I",  symbol: "italic",                                    prefix: "*",    suffix: "*",      matchesNodeType: { $0 == .emphasis }),
        Action(title: "S",  symbol: "strikethrough",                             prefix: "~~",   suffix: "~~",     matchesNodeType: { $0 == .strikethrough }),
        Action(title: "<>", symbol: "chevron.left.forwardslash.chevron.right",   prefix: "`",    suffix: "`",      matchesNodeType: { $0 == .code }),
        Action(title: "🔗", symbol: "link",                                      prefix: "[",    suffix: "](url)", matchesNodeType: { if case .link = $0 { return true }; return false }),
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

        buttons = []
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
            buttons.append(btn)
        }
    }

    // MARK: - Show / hide

    func show(for textView: NSTextView) {
        targetTextView = textView
        guard let window = textView.window else { return }

        let selRange = textView.selectedRange()
        guard selRange.length > 0 else { hide(); return }

        // Get the rect of the selection in window coordinates
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: selRange, actualCharacterRange: nil)
        var selRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        selRect.origin.x += textView.textContainerOrigin.x
        selRect.origin.y += textView.textContainerOrigin.y

        let rectInWindow = textView.convert(selRect, to: nil)
        let rectOnScreen = window.convertToScreen(rectInWindow)

        // Position toolbar above selection, centered
        let toolbarWidth = frame.width
        var x = rectOnScreen.midX - toolbarWidth / 2
        let y = rectOnScreen.maxY + 6

        // Screen-edge clamping
        if let screen = window.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            x = max(screenFrame.minX + 4, min(x, screenFrame.maxX - toolbarWidth - 4))
        }

        setFrameOrigin(NSPoint(x: x, y: y))
        updateButtonStates(for: textView)
        orderFront(nil)
    }

    func hide() {
        orderOut(nil)
        targetTextView = nil
    }

    // MARK: - Button state detection

    private func updateButtonStates(for textView: NSTextView) {
        let selRange = textView.selectedRange()
        guard selRange.length > 0 else { return }

        let nsString = textView.string as NSString
        let parsed = CMarkParser.parse(textView.string)

        for (index, action) in Self.actions.enumerated() {
            let isActive: Bool
            if action.suffix.isEmpty {
                // Heading: check raw line text for prefix
                let lineRange = nsString.lineRange(for: selRange)
                let lineText = nsString.substring(with: lineRange)
                isActive = lineText.hasPrefix(action.prefix)
            } else if let matcher = action.matchesNodeType {
                // Inline: check parsed ranges for overlap with selection
                isActive = parsed.contains { mdRange in
                    matcher(mdRange.type) && NSIntersectionRange(mdRange.range, selRange).length > 0
                }
            } else {
                isActive = false
            }

            buttons[index].contentTintColor = isActive ? .controlAccentColor : nil
        }
    }

    // MARK: - Actions

    @objc private func buttonTapped(_ sender: NSButton) {
        guard let textView = targetTextView,
              sender.tag < Self.actions.count else { return }

        let action = Self.actions[sender.tag]
        let selRange = textView.selectedRange()

        let nsString = textView.string as NSString
        let selectedText = nsString.substring(with: selRange)

        if action.suffix.isEmpty {
            // Heading: wrap entire line — find line boundaries
            let lineRange = nsString.lineRange(for: selRange)
            let lineText = nsString.substring(with: lineRange).trimmingCharacters(in: .newlines)

            let newText: String
            if lineText.hasPrefix(action.prefix) {
                newText = String(lineText.dropFirst(action.prefix.count))
            } else {
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
            // Inline wrapper: use CMarkParser to detect active range (works in both raw and styled mode)
            let parsed = CMarkParser.parse(textView.string)
            let activeNodeRange: NSRange? = {
                guard let matcher = action.matchesNodeType else { return nil }
                return parsed.first(where: { mdRange in
                    matcher(mdRange.type) && NSIntersectionRange(mdRange.range, selRange).length > 0
                })?.range
            }()

            if let fullRange = activeNodeRange {
                // Unwrap: remove delimiters from the full node range in raw text
                let fullText = nsString.substring(with: fullRange)
                let prefixCount = action.prefix.count
                let suffixCount = action.suffix.count
                guard fullText.count >= prefixCount + suffixCount else { return }
                let start = fullText.index(fullText.startIndex, offsetBy: prefixCount)
                let end   = fullText.index(fullText.endIndex,   offsetBy: -suffixCount)
                let content = String(fullText[start..<end])
                if textView.shouldChangeText(in: fullRange, replacementString: content) {
                    textView.replaceCharacters(in: fullRange, with: content)
                    textView.didChangeText()
                }
            } else {
                // Wrap selection
                let newText = action.prefix + selectedText + action.suffix
                if textView.shouldChangeText(in: selRange, replacementString: newText) {
                    textView.replaceCharacters(in: selRange, with: newText)
                    textView.didChangeText()
                }
            }
            updateButtonStates(for: textView)
        }
    }
}
