import AppKit

final class EditorViewController: NSViewController {

    // MARK: - Subviews

    private(set) var textView: StrikerTextView!
    let scrollView = NSScrollView()

    // MARK: - State

    let markdownStorage = MarkdownTextStorage()
    private let autoSave  = AutoSaveController()
    private let formattingToolbar = FormattingToolbar()
    private let slashMenu = SlashCommandMenu()
    private var slashAnchorPosition: Int? = nil
    private var currentURL: URL?

    private let rawModeBadge: NSTextField = {
        let label = NSTextField(labelWithString: "RAW")
        label.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        label.textColor = NSColor.secondaryLabelColor
        label.backgroundColor = NSColor(white: 0.5, alpha: 0.12)
        label.isBezeled = false
        label.isEditable = false
        label.wantsLayer = true
        label.layer?.cornerRadius = 4
        label.alphaValue = 0
        return label
    }()

    // MARK: - View lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupTextSystem()
        setupAutoSave()
        setupFormattingToolbar()
        setupRawModeBadge()
        slashMenu.onSelect = { [weak self] index in
            self?.applySlashCommand(index)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: view.window
        )
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        formattingToolbar.hide()
        slashMenu.hide()
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller   = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers    = true
        scrollView.drawsBackground       = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupTextSystem() {
        // Build custom text system chain:
        // MarkdownTextStorage → NSLayoutManager → NSTextContainer → StrikerTextView
        let layoutManager = NSLayoutManager()
        markdownStorage.addLayoutManager(layoutManager)

        let containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        let textContainer = NSTextContainer(size: containerSize)
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let contentSize = scrollView.contentSize
        textView = StrikerTextView(
            frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
            textContainer: textContainer
        )

        // Layout
        textView.autoresizingMask        = [.width]
        textView.isVerticallyResizable   = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 20, height: 20)

        // Editing
        textView.isRichText   = true
        textView.allowsUndo   = true
        textView.isEditable   = true
        textView.isSelectable = true
        textView.drawsBackground = false

        // Font — set on text storage via base attributes, but also set on textView
        // for the insertion point attributes
        textView.font = MarkdownStyle.baseFont
        textView.textColor = .labelColor

        // Kill autocorrect / substitutions
        textView.isAutomaticSpellingCorrectionEnabled  = false
        textView.isAutomaticTextReplacementEnabled     = false
        textView.isAutomaticQuoteSubstitutionEnabled   = false
        textView.isAutomaticDashSubstitutionEnabled    = false
        textView.isAutomaticDataDetectionEnabled       = false
        textView.isAutomaticLinkDetectionEnabled       = false
        textView.isContinuousSpellCheckingEnabled      = false
        textView.isGrammarCheckingEnabled              = false

        textView.delegate        = self
        textView.strikerDelegate = self

        scrollView.documentView = textView
    }

    private func setupAutoSave() {
        autoSave.onSave = { [weak self] in
            self?.saveCurrentFile()
        }
    }

    private func setupFormattingToolbar() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollBoundsChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    private func setupRawModeBadge() {
        view.addSubview(rawModeBadge)
        rawModeBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rawModeBadge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            rawModeBadge.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private func saveCurrentFile() {
        guard let url = currentURL else { return }
        do {
            try FileManager.default.writeNote(at: url, content: textView.string)
            NotificationCenter.default.post(name: .strikerDidSaveFile, object: url)
        } catch {
            NSSound.beep()
        }
    }

    // MARK: - Public API

    /// Loads a file, saving any dirty current file first.
    func load(url: URL) {
        autoSave.saveNow()
        currentURL = url

        let content = (try? FileManager.default.readNote(at: url)) ?? ""
        applyLoadedContent(content, resetScrollPosition: true)
    }

    /// Force-saves immediately (e.g. Cmd+S).
    func save() {
        autoSave.saveNow()
    }

    var isDirty: Bool { autoSave.isDirty }
    var currentFileURL: URL? { currentURL }
    var isRawMode: Bool { markdownStorage.isRawMode }

    func reloadCurrentFileFromDisk() {
        guard let url = currentURL else { return }
        let selected = textView.selectedRange()
        let content = (try? FileManager.default.readNote(at: url)) ?? ""
        applyLoadedContent(content, resetScrollPosition: false)
        let maxLoc = max(0, min(selected.location, markdownStorage.length))
        textView.setSelectedRange(NSRange(location: maxLoc, length: 0))
    }

    // MARK: - Raw mode toggle

    func toggleRawMode() {
        markdownStorage.isRawMode.toggle()
        updateFormattingToolbar()
        updateRawModeBadge()
        slashMenu.hide()
        slashAnchorPosition = nil
    }

    private func updateRawModeBadge() {
        let show = markdownStorage.isRawMode
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            rawModeBadge.animator().alphaValue = show ? 1 : 0
        }
    }

    // MARK: - Window key notifications

    @objc private func windowDidResignKey(_ notification: Notification) {
        autoSave.saveNow()
        formattingToolbar.hide()
        slashMenu.hide()
        slashAnchorPosition = nil
    }

    @objc private func handleScrollBoundsChange(_ notification: Notification) {
        updateFormattingToolbar()
    }

    private func applyLoadedContent(_ content: String, resetScrollPosition: Bool) {
        let fullRange = NSRange(location: 0, length: markdownStorage.length)
        markdownStorage.replaceCharacters(in: fullRange, with: content)
        markdownStorage.reapplyAllStyles()

        textView.undoManager?.removeAllActions()
        autoSave.reset()
        if resetScrollPosition {
            textView.scrollToBeginningOfDocument(nil)
        }
        updateFormattingToolbar()
        view.window?.makeFirstResponder(textView)
    }

    private func updateFormattingToolbar() {
        guard view.window?.isVisible == true, !markdownStorage.isRawMode else {
            formattingToolbar.hide()
            return
        }
        let selection = textView.selectedRange()
        guard selection.length > 0 else {
            formattingToolbar.hide()
            return
        }
        formattingToolbar.show(for: textView)
    }
}

// MARK: - NSTextViewDelegate

extension EditorViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        autoSave.markDirty()
        updateFormattingToolbar()
        updateSlashMenu()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateFormattingToolbar()
    }
}

// MARK: - StrikerTextViewDelegate

extension EditorViewController: StrikerTextViewDelegate {

    func strikerTextViewSave(_ textView: StrikerTextView) {
        save()
    }

    func strikerTextViewClose(_ textView: StrikerTextView) {
        NotificationCenter.default.post(name: .strikerHidePanel, object: nil)
    }

    func strikerTextViewNewNote(_ textView: StrikerTextView) {
        NotificationCenter.default.post(name: .strikerNewNote, object: nil)
    }

    func strikerTextViewToggleRawMode(_ textView: StrikerTextView) {
        toggleRawMode()
    }

    func strikerTextViewToggleSidebar(_ textView: StrikerTextView) {
        NotificationCenter.default.post(name: .strikerToggleSidebar, object: nil)
    }

    func strikerTextViewDidTypeSlash(_ textView: StrikerTextView) {
        guard !markdownStorage.isRawMode else { return }
        let cursorPos = textView.selectedRange().location
        guard cursorPos >= 1 else { return }
        let anchor = cursorPos - 1
        slashAnchorPosition = anchor

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let window = view.window else { return }

        // Use layoutManager rect (same as FormattingToolbar) — reliable after text insertion
        let slashCharRange = NSRange(location: anchor, length: 1)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: slashCharRange, actualCharacterRange: nil)
        var charRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        charRect.origin.x += textView.textContainerOrigin.x
        charRect.origin.y += textView.textContainerOrigin.y
        let rectInWindow = textView.convert(charRect, to: nil)
        let caretRect = window.convertToScreen(rectInWindow)

        slashMenu.show(caretRect: caretRect, in: window)
    }

    func strikerTextViewInterceptKey(_ event: NSEvent) -> Bool {
        guard slashMenu.isVisible else { return false }
        switch event.keyCode {
        case 125: slashMenu.moveDown(); return true          // ↓
        case 126: slashMenu.moveUp();   return true          // ↑
        case 36, 76: slashMenu.confirmSelection(); return true  // Return / numpad Enter
        case 53:                                             // Escape
            slashMenu.hide()
            slashAnchorPosition = nil
            return true
        default: return false
        }
    }

    // MARK: - Slash menu helpers

    private func updateSlashMenu() {
        guard let anchor = slashAnchorPosition else { return }
        let nsText = textView.string as NSString
        let textLen = nsText.length
        let cursorPos = textView.selectedRange().location
        let slashChar: unichar = "/".utf16.first!

        if anchor >= textLen || nsText.character(at: anchor) != slashChar || cursorPos <= anchor {
            slashMenu.hide()
            slashAnchorPosition = nil
            return
        }

        let filterLen = cursorPos - anchor - 1
        slashMenu.filterString = filterLen > 0
            ? nsText.substring(with: NSRange(location: anchor + 1, length: filterLen))
            : ""

        if slashMenu.hasNoResults {
            slashMenu.hide()
            slashAnchorPosition = nil
        }
    }

    private func applySlashCommand(_ actionIndex: Int) {
        guard let anchor = slashAnchorPosition else { return }
        let tv = textView!
        let cursorPos = tv.selectedRange().location

        // Delete "/" plus any filter text the user typed
        let deleteLen = cursorPos - anchor
        if deleteLen > 0 {
            let deleteRange = NSRange(location: anchor, length: deleteLen)
            if tv.shouldChangeText(in: deleteRange, replacementString: "") {
                tv.textStorage?.replaceCharacters(in: deleteRange, with: "")
                tv.didChangeText()
            }
        }

        tv.setSelectedRange(NSRange(location: anchor, length: 0))
        slashAnchorPosition = nil

        formattingToolbar.apply(actionAt: actionIndex, to: tv)

        let action = FormattingToolbar.actions[actionIndex]
        if !action.suffix.isEmpty {
            // Inline: park cursor between the delimiters
            let cursorAfter = anchor + action.prefix.count
            tv.setSelectedRange(NSRange(location: cursorAfter, length: 0))
        } else if !markdownStorage.isRawMode {
            // Heading: cursor sits right after the hidden "# " prefix.
            // The preceding char has near-zero font (hiddenSyntaxAttributes),
            // so NSTextView draws an invisible cursor. Fix by setting typingAttributes
            // to the heading font so the caret uses the correct line height.
            let level = action.prefix.count - 1  // "# "→1, "## "→2, "### "→3
            tv.typingAttributes = MarkdownStyle.attributes(for: .heading(level: level))
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let strikerHidePanel    = Notification.Name("strikerHidePanel")
    static let strikerNewNote      = Notification.Name("strikerNewNote")
    static let strikerDidSaveFile  = Notification.Name("strikerDidSaveFile")
    static let strikerToggleSidebar = Notification.Name("strikerToggleSidebar")
}
