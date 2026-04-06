import Foundation

struct DockPanelState {
    var isUserVisible: Bool = true
    var isTemporarilyHiddenForMissionControl: Bool = false

    var isVisible: Bool {
        isUserVisible && !isTemporarilyHiddenForMissionControl
    }
}
