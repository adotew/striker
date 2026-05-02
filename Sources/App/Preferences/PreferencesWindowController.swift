import AppKit
import ServiceManagement

final class PreferencesWindowController: NSWindowController {

    private let directoryProvider: () -> URL?
    private let onDirectoryChanged: (URL) -> Void
    private let isAlwaysOnTop: () -> Bool
    private let setAlwaysOnTop: (Bool) -> Void

    private let directoryValueLabel = NSTextField(labelWithString: "")
    private let alwaysOnTopCheckbox = NSButton(checkboxWithTitle: "Always on Top", target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)

    init(
        directoryProvider: @escaping () -> URL?,
        onDirectoryChanged: @escaping (URL) -> Void,
        isAlwaysOnTop: @escaping () -> Bool,
        setAlwaysOnTop: @escaping (Bool) -> Void
    ) {
        self.directoryProvider = directoryProvider
        self.onDirectoryChanged = onDirectoryChanged
        self.isAlwaysOnTop = isAlwaysOnTop
        self.setAlwaysOnTop = setAlwaysOnTop

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupUI()
        refreshUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        refreshUI()
        super.showWindow(sender)
        window?.center()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 14
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        let directoryTitle = NSTextField(labelWithString: "Notes Directory")
        directoryTitle.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        container.addArrangedSubview(directoryTitle)

        directoryValueLabel.lineBreakMode = .byTruncatingMiddle
        directoryValueLabel.textColor = .secondaryLabelColor
        container.addArrangedSubview(directoryValueLabel)

        let changeButton = NSButton(title: "Change Directory…", target: self, action: #selector(changeDirectory))
        container.addArrangedSubview(changeButton)

        alwaysOnTopCheckbox.target = self
        alwaysOnTopCheckbox.action = #selector(toggleAlwaysOnTop)
        container.addArrangedSubview(alwaysOnTopCheckbox)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin)
        container.addArrangedSubview(launchAtLoginCheckbox)
    }

    private func refreshUI() {
        if let url = directoryProvider() {
            directoryValueLabel.stringValue = url.path
        } else {
            directoryValueLabel.stringValue = "Not selected"
        }
        alwaysOnTopCheckbox.state = isAlwaysOnTop() ? .on : .off
        launchAtLoginCheckbox.state = LaunchAtLoginManager.isEnabled ? .on : .off
    }

    @objc private func changeDirectory() {
        DirectoryPicker.pick { [weak self] url in
            guard let self, let url else { return }
            self.onDirectoryChanged(url)
            self.refreshUI()
        }
    }

    @objc private func toggleAlwaysOnTop() {
        setAlwaysOnTop(alwaysOnTopCheckbox.state == .on)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.setEnabled(launchAtLoginCheckbox.state == .on)
        } catch {
            showLaunchAtLoginError(error)
            refreshUI()
        }
    }

    private func showLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Launch at Login Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
