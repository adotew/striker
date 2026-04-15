import Foundation

final class AutoSaveController {

    var onSave: (() -> Void)?
    private(set) var isDirty = false
    private var pendingTask: DispatchWorkItem?
    private let delay: TimeInterval = 2.5

    /// Called on every text change. Resets the 2.5s debounce timer.
    func markDirty() {
        isDirty = true
        scheduleSave()
    }

    /// Cancels the pending timer and saves immediately.
    func saveNow() {
        pendingTask?.cancel()
        pendingTask = nil
        guard isDirty else { return }
        onSave?()
        isDirty = false
    }

    /// Marks the editor as clean without writing (e.g. after loading a new file).
    func reset() {
        pendingTask?.cancel()
        pendingTask = nil
        isDirty = false
    }

    private func scheduleSave() {
        pendingTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        pendingTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }
}
