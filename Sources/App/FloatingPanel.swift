import AppKit

final class FloatingPanel: NSPanel {

    init() {
        let styleMask: NSWindow.StyleMask = [
            .nonactivatingPanel,
            .utilityWindow,
            .fullSizeContentView,
            .borderless
        ]
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        backgroundColor = .clear
        hasShadow = true

        setupVisualEffect()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Liquid glass background

    private func setupVisualEffect() {
        let vev = NSVisualEffectView()
        vev.material = .hudWindow
        vev.blendingMode = .behindWindow
        vev.state = .active
        vev.wantsLayer = true
        vev.layer?.cornerRadius = 16
        vev.layer?.masksToBounds = true
        contentView = vev
    }

    // MARK: - Show / hide

    func toggle() {
        if isVisible {
            orderOut(nil)
        } else {
            center()
            makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Always-on-top

    var isAlwaysOnTop: Bool {
        get { level == .floating }
        set { level = newValue ? .floating : .normal }
    }
}
