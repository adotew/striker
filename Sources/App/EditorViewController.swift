import AppKit

final class EditorViewController: NSViewController {

    // MARK: - Subviews

    let textView   = StrikerTextView()
    let scrollView = NSScrollView()

    // MARK: - State

    private let autoSave  = AutoSaveController()
    private var currentURL: URL?

    // MARK: - View lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupTextView()
        setupAutoSave()
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
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller   = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers    = true
        scrollView.drawsBackground       = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupTextView() {
        // Layout
        textView.autoresizingMask        = [.width]
        textView.isVerticallyResizable   = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView  = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 20, height: 20)

        // Editing
        textView.isRichText   = true
        textView.allowsUndo   = true
        textView.isEditable   = true
        textView.isSelectable = true
        textView.drawsBackground = false

        // Font — JetBrains Mono with system monospace fallback
        textView.font = NSFont(name: "JetBrainsMono-Regular", size: 13)
                     ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
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
            guard let self, let url = currentURL else { return }
            try? FileManager.default.writeNote(at: url, content: textView.string)
        }
    }

    // MARK: - Public API

    /// Loads a file, saving any dirty current file first.
    func load(url: URL) {
        autoSave.saveNow()
        currentURL = url

        let content = (try? FileManager.default.readNote(at: url)) ?? ""
        textView.string = content
        textView.undoManager?.removeAllActions()
        autoSave.reset()
        textView.scrollToBeginningOfDocument(nil)
        view.window?.makeFirstResponder(textView)
    }

    /// Force-saves immediately (e.g. Cmd+S).
    func save() {
        autoSave.saveNow()
    }

    var isDirty: Bool { autoSave.isDirty }

    // MARK: - Window key notifications

    @objc private func windowDidResignKey(_ notification: Notification) {
        autoSave.saveNow()
    }
}

// MARK: - NSTextViewDelegate

extension EditorViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        autoSave.markDirty()
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
}

// MARK: - Notification names

extension Notification.Name {
    static let strikerHidePanel = Notification.Name("strikerHidePanel")
    static let strikerNewNote   = Notification.Name("strikerNewNote")
}
