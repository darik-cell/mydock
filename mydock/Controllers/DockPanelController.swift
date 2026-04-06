import AppKit

final class DockPanelController: NSWindowController {
    private let panelView = DockPanelView()
    private var layoutSettings = DockLayoutSettings.default

    var onItemSelected: ((DockItem) -> Void)? {
        didSet {
            panelView.onItemSelected = onItemSelected
        }
    }

    var itemMenuProvider: ((DockItem) -> NSMenu?)? {
        didSet {
            panelView.itemMenuProvider = itemMenuProvider
        }
    }

    var panelMenuProvider: (() -> NSMenu?)? {
        didSet {
            panelView.panelMenuProvider = panelMenuProvider
        }
    }

    init() {
        let panel = DockPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 88, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)
        configure(panel: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(items: [DockItem]) {
        panelView.update(items: items)
        updateFrame()
    }

    func update(layoutSettings: DockLayoutSettings) {
        self.layoutSettings = layoutSettings
        panelView.update(layoutSettings: layoutSettings)
        updateFrame()
    }

    func updateVisibility(isVisible: Bool) {
        guard let panel = window else {
            return
        }

        if isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func showPanel() {
        updateFrame()
        window?.orderFrontRegardless()
    }

    func reposition() {
        updateFrame()
    }

    private func configure(panel: DockPanelWindow) {
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = panelView
        panel.orderFrontRegardless()
    }

    private func updateFrame() {
        guard let panel = window else {
            return
        }

        let size = panelView.preferredPanelSize
        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: size.width, height: size.height)

        let x = visibleFrame.minX + layoutSettings.dockScreenLeftOffset
        let y = visibleFrame.midY - (size.height / 2)
        let origin = NSPoint(x: x, y: max(visibleFrame.minY + 16, y))

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

private final class DockPanelWindow: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
