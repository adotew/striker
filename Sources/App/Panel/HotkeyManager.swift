import AppKit

final class HotkeyManager {

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let panel: FloatingPanel

    // ⌥N — keyCode 45, modifier .option
    private let targetKeyCode: UInt16 = 45
    private let targetModifiers: NSEvent.ModifierFlags = [.option]

    init(panel: FloatingPanel) {
        self.panel = panel
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isHotkey(event) == true {
                self?.handle(event)
                return nil  // consume the event
            }
            return event
        }
    }

    private func stopMonitoring() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor  { NSEvent.removeMonitor(m) }
    }

    private func isHotkey(_ event: NSEvent) -> Bool {
        event.keyCode == targetKeyCode &&
        event.modifierFlags.intersection(.deviceIndependentFlagsMask) == targetModifiers
    }

    private func handle(_ event: NSEvent) {
        guard isHotkey(event) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.panel.toggle()
        }
    }
}
