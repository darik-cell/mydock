import Foundation

final class AppStateStore {
    struct Snapshot {
        let items: [DockItem]
        let panelState: DockPanelState
        let layoutSettings: DockLayoutSettings
    }

    private(set) var configuration: AppConfiguration
    private(set) var panelState: DockPanelState
    private(set) var layoutSettings: DockLayoutSettings
    private(set) var items: [DockItem] = []
    private(set) var dynamicOrder: [String] = []

    var onChange: ((Snapshot) -> Void)?

    init(
        configuration: AppConfiguration = AppConfiguration(),
        panelState: DockPanelState = DockPanelState(),
        layoutSettings: DockLayoutSettings = .default
    ) {
        self.configuration = configuration
        self.panelState = panelState
        self.layoutSettings = layoutSettings
    }

    func update(items: [DockItem], dynamicOrder: [String]) {
        self.items = items
        self.dynamicOrder = dynamicOrder
        notify()
    }

    func update(panelState: DockPanelState) {
        self.panelState = panelState
        notify()
    }

    func update(configuration: AppConfiguration) {
        self.configuration = configuration
        notify()
    }

    func update(layoutSettings: DockLayoutSettings) {
        self.layoutSettings = layoutSettings
        notify()
    }

    func update(configuration: AppConfiguration, layoutSettings: DockLayoutSettings) {
        self.configuration = configuration
        self.layoutSettings = layoutSettings
        notify()
    }

    private func notify() {
        onChange?(Snapshot(items: items, panelState: panelState, layoutSettings: layoutSettings))
    }
}
