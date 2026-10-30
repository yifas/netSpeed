import AppKit

/// AppKit 版菜单栏应用。
///
/// 用 `NSStatusItem`（`variableLength`）+ **按内容定尺寸图片**承载标签：
/// 下行部分定宽，速率位数变化时宽度恒定；上行部分关闭时整块去掉，标签随之收缩。
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let monitor = SpeedMonitor()
    private var statusItem: NSStatusItem!

    private let menu = NSMenu()
    private let downloadItem = NSMenuItem(title: "Download: 0 B/s", action: nil, keyEquivalent: "")
    private let uploadItem = NSMenuItem(title: "Upload: 0 B/s", action: nil, keyEquivalent: "")
    private let interfaceItem = NSMenuItem(title: "Interface Details", action: nil, keyEquivalent: "")
    private let scopeItem = NSMenuItem(title: "Scope", action: nil, keyEquivalent: "")
    private let intervalItem = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
    private let showUploadItem = NSMenuItem(title: "Show Upload Speed", action: #selector(toggleUpload(_:)), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit NetSpeed", action: #selector(quit), keyEquivalent: "q")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = StatusLabelRenderer.makeImage(download: "  0.0B", upload: "  0.0B", showUpload: true)
        statusItem.button?.toolTip = "NetSpeed · Live network speed in the menu bar"

        buildMenu()
        monitor.onChange = { [weak self] in self?.refresh() }
        monitor.start()
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    // MARK: - 菜单

    private func buildMenu() {
        menu.autoenablesItems = false

        downloadItem.isEnabled = false
        uploadItem.isEnabled = false
        showUploadItem.target = self
        loginItem.target = self
        quitItem.target = self

        menu.addItem(downloadItem)
        menu.addItem(uploadItem)
        menu.addItem(.separator())
        menu.addItem(interfaceItem)
        menu.addItem(scopeItem)
        menu.addItem(intervalItem)
        menu.addItem(showUploadItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refresh() {
        let snapshot = monitor.snapshot

        downloadItem.title = "Download: \(ByteFormatter.speed(snapshot.downloadBytesPerSecond))"
        uploadItem.title = "Upload: \(ByteFormatter.speed(snapshot.uploadBytesPerSecond))"
        showUploadItem.state = monitor.showUpload ? .on : .off
        loginItem.state = LoginItem.isEnabled ? .on : .off

        rebuildInterfaceMenu(snapshot.perInterface)
        rebuildScopeMenu()
        rebuildIntervalMenu()

        statusItem.button?.image = StatusLabelRenderer.makeImage(
            download: ByteFormatter.compactFixed(snapshot.downloadBytesPerSecond),
            upload: ByteFormatter.compactFixed(snapshot.uploadBytesPerSecond),
            showUpload: monitor.showUpload
        )
    }

    private func rebuildInterfaceMenu(_ speeds: [InterfaceSpeed]) {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        if speeds.isEmpty {
            let empty = NSMenuItem(title: "No active interfaces", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for speed in speeds {
                let title = String(format: "%@  ↓%@  ↑%@",
                                   speed.name,
                                   ByteFormatter.speed(speed.downloadBytesPerSecond),
                                   ByteFormatter.speed(speed.uploadBytesPerSecond))
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
        }
        interfaceItem.submenu = submenu
    }

    private func rebuildScopeMenu() {
        let submenu = NSMenu()
        for option in InterfaceFilter.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectScope(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = (option == monitor.filter) ? .on : .off
            submenu.addItem(item)
        }
        scopeItem.submenu = submenu
    }

    private func rebuildIntervalMenu() {
        let submenu = NSMenu()
        for option in RefreshInterval.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = (option == monitor.interval) ? .on : .off
            submenu.addItem(item)
        }
        intervalItem.submenu = submenu
    }

    // MARK: - 动作

    @objc private func selectScope(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let value = InterfaceFilter(rawValue: raw) else { return }
        monitor.filter = value
        refresh()
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Double,
              let value = RefreshInterval(rawValue: raw) else { return }
        monitor.interval = value
        refresh()
    }

    @objc private func toggleUpload(_ sender: NSMenuItem) {
        monitor.showUpload.toggle()
        refresh()
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        if let error = LoginItem.setEnabled(!LoginItem.isEnabled) {
            let alert = NSAlert()
            alert.messageText = "Could not update the login item"
            alert.informativeText = error
            alert.runModal()
        }
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
