import AppKit

@MainActor
final class AppCoordinator: NSObject {
    private let preferencesStore = PreferencesStore()
    private let visibilityController = DockVisibilityController()
    private let runningAppsService = RunningAppsService()
    private let windowSnapshotService = WindowSnapshotService()
    private let windowIdentityResolver = WindowIdentityResolver()
    private let windowOrderTracker = WindowOrderTracker()
    private let accessibilityPermissionService = AccessibilityPermissionService()
    private lazy var windowFocusService = WindowFocusService(permissionService: accessibilityPermissionService)
    private let modelBuilder = DockModelBuilder()
    private let hotkeyManager = HotkeyManager()
    private let panelController = DockPanelController()
    private let preferencesWindowController = PreferencesWindowController()
    private let stateStore: AppStateStore

    private var workspaceObservers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    private var isRefreshing = false

    override init() {
        let preferencesSnapshot = preferencesStore.snapshot
        self.stateStore = AppStateStore(
            configuration: preferencesSnapshot.configuration,
            panelState: DockPanelState(),
            layoutSettings: preferencesSnapshot.layoutSettings
        )
        super.init()
    }

    func start() {
        panelController.onItemSelected = { [weak self] item in
            self?.activate(item: item)
        }
        panelController.itemMenuProvider = { [weak self] item in
            self?.makeContextMenu(for: item)
        }
        panelController.panelMenuProvider = { [weak self] in
            self?.makePanelMenu()
        }

        stateStore.onChange = { [weak self] snapshot in
            self?.panelController.update(items: snapshot.items)
            self?.panelController.update(layoutSettings: snapshot.layoutSettings)
            self?.panelController.updateVisibility(isVisible: snapshot.panelState.isVisible)
            self?.preferencesWindowController.update(settings: snapshot.layoutSettings)
        }

        preferencesStore.onChange = { [weak self] snapshot in
            self?.stateStore.update(configuration: snapshot.configuration, layoutSettings: snapshot.layoutSettings)
            self?.refreshDockItems()
        }

        visibilityController.onChange = { [weak self] panelState in
            self?.stateStore.update(panelState: panelState)
        }

        hotkeyManager.onAction = { [weak self] action in
            self?.handle(hotkeyAction: action)
        }
        visibilityController.start()
        hotkeyManager.start()

        preferencesWindowController.onLayoutSettingsChanged = { [weak self] layoutSettings in
            self?.preferencesStore.update(layoutSettings: layoutSettings)
        }

        observeWorkspace()
        observeScreenChanges()

        panelController.showPanel()
        refreshDockItems()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDockItems()
            }
        }
    }

    func stop() {
        workspaceObservers.forEach(NotificationCenter.default.removeObserver(_:))
        workspaceObservers.removeAll()

        refreshTimer?.invalidate()
        refreshTimer = nil

        visibilityController.stop()
        hotkeyManager.stop()
    }

    private func observeWorkspace() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ]

        workspaceObservers = names.map { name in
            workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshDockItems()
                }
            }
        }
    }

    private func observeScreenChanges() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.panelController.reposition()
                self?.refreshDockItems()
            }
        }

        workspaceObservers.append(observer)
    }

    private func refreshDockItems() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let runningApps = runningAppsService.snapshot()
        let visibleWindowSnapshots = windowSnapshotService.visibleWindowSnapshots()
        let visibleWindowCounts = windowSnapshotService.visibleWindowCounts(from: visibleWindowSnapshots)
        let visibleWindowIdentities = windowIdentityResolver.resolve(
            snapshots: visibleWindowSnapshots,
            runningApps: runningApps
        )
        let pinnedInstallations = runningAppsService.resolveInstalledApplications(
            bundleIdentifiers: stateStore.configuration.pinnedBundleIdentifiers
        )

        windowOrderTracker.sync(with: visibleWindowIdentities)

        let result = modelBuilder.build(
            configuration: stateStore.configuration,
            runningApps: runningApps,
            visibleWindowCounts: visibleWindowCounts,
            pinnedInstallations: pinnedInstallations,
            previousDynamicOrder: stateStore.dynamicOrder
        )

        stateStore.update(items: result.items, dynamicOrder: result.dynamicOrder)
    }

    private func activateSlot(at slotIndex: Int) {
        guard slotIndex >= 0, slotIndex < min(10, stateStore.items.count) else {
            return
        }

        activateFromHotkey(item: stateStore.items[slotIndex])
    }

    private func activate(item: DockItem) {
        if let runningApplication = item.runningApplication {
            runningApplication.activate(options: [.activateAllWindows])
            return
        }

        guard item.isPinned, let launchURL = item.launchURL else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: launchURL, configuration: configuration) { _, _ in }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.refreshDockItems()
        }
    }

    private func activateFromHotkey(item: DockItem) {
        guard
            let runningApplication = item.runningApplication,
            let appIdentifier = item.appIdentifier,
            let processIdentifier = item.processIdentifier
        else {
            activate(item: item)
            return
        }

        let orderedWindows = windowOrderTracker.orderedWindows(for: appIdentifier, pid: processIdentifier)
        guard orderedWindows.count > 1, let targetWindow = windowOrderTracker.nextWindow(for: appIdentifier, pid: processIdentifier) else {
            activate(item: item)
            return
        }

        switch windowFocusService.focus(window: targetWindow, in: runningApplication) {
        case .focusedTargetWindow:
            windowOrderTracker.advanceCursor(
                for: appIdentifier,
                pid: processIdentifier,
                resolvedWindow: targetWindow
            )
        case .permissionRequired:
            accessibilityPermissionService.requestIfNeeded()
        case .activatedApplication:
            break
        }
    }

    private func handle(hotkeyAction: HotkeyAction) {
        switch hotkeyAction {
        case let .slot(slotIndex):
            activateSlot(at: slotIndex)
        case .toggleVisibility:
            visibilityController.toggleUserVisibility()
        }
    }

    private func makeContextMenu(for item: DockItem) -> NSMenu {
        let menu = NSMenu()

        if let bundleIdentifier = item.bundleIdentifier {
            if item.isPinned {
                let unpinItem = NSMenuItem(
                    title: "Unpin from mydock",
                    action: #selector(handleUnpinMenuItem(_:)),
                    keyEquivalent: ""
                )
                unpinItem.target = self
                unpinItem.representedObject = bundleIdentifier
                menu.addItem(unpinItem)
            } else {
                let pinItem = NSMenuItem(
                    title: "Pin to mydock",
                    action: #selector(handlePinMenuItem(_:)),
                    keyEquivalent: ""
                )
                pinItem.target = self
                pinItem.representedObject = bundleIdentifier
                menu.addItem(pinItem)
            }
        }

        if menu.items.isEmpty == false {
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(handleOpenSettingsMenuItem(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        return menu
    }

    private func makePanelMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(handleOpenSettingsMenuItem(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit mydock",
            action: #selector(handleQuitMenuItem(_:)),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func handlePinMenuItem(_ sender: NSMenuItem) {
        guard let bundleIdentifier = sender.representedObject as? String else {
            return
        }

        preferencesStore.pin(bundleIdentifier: bundleIdentifier)
    }

    @objc
    private func handleUnpinMenuItem(_ sender: NSMenuItem) {
        guard let bundleIdentifier = sender.representedObject as? String else {
            return
        }

        preferencesStore.unpin(bundleIdentifier: bundleIdentifier)
    }

    @objc
    private func handleOpenSettingsMenuItem(_ sender: Any?) {
        preferencesWindowController.show()
    }

    @objc
    private func handleQuitMenuItem(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
