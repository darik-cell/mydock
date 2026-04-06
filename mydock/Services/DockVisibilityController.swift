import AppKit
import Foundation

@MainActor
final class DockVisibilityController {
    private(set) var panelState = DockPanelState()

    var onChange: ((DockPanelState) -> Void)?

    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []

    func start() {
        stop()

        let distributedCenter = DistributedNotificationCenter.default()
        let willStartNotification = Notification.Name("com.apple.expose.animationWillStart")
        let didEndNotification = Notification.Name("com.apple.expose.animationDidEnd")

        distributedObservers = [
            distributedCenter.addObserver(forName: willStartNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.setMissionControlHidden(true)
                }
            },
            distributedCenter.addObserver(forName: didEndNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.setMissionControlHidden(false)
                }
            }
        ]

        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.panelState.isTemporarilyHiddenForMissionControl else {
                    return
                }

                // If the end notification is missed, active space changes are a reasonable fallback
                // for restoring the panel after Mission Control interaction.
                self.setMissionControlHidden(false)
            }
        }

        workspaceObservers = [observer]
        notify()
    }

    func stop() {
        let distributedCenter = DistributedNotificationCenter.default()
        distributedObservers.forEach(distributedCenter.removeObserver(_:))
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver(_:))
        distributedObservers.removeAll()
        workspaceObservers.removeAll()
    }

    func toggleUserVisibility() {
        panelState.isUserVisible.toggle()
        notify()
    }

    private func setMissionControlHidden(_ isHidden: Bool) {
        panelState.isTemporarilyHiddenForMissionControl = isHidden
        notify()
    }

    private func notify() {
        onChange?(panelState)
    }
}
