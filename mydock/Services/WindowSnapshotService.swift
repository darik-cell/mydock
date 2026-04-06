import CoreGraphics
import Foundation

struct WindowSnapshot {
    let ownerPID: pid_t
    let windowID: CGWindowID
    let ownerName: String
    let title: String?
    let layer: Int
    let alpha: Double
    let bounds: CGRect
}

final class WindowSnapshotService {
    func visibleWindowSnapshots() -> [WindowSnapshot] {
        guard
            let windowInfoList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return []
        }

        return windowInfoList.compactMap { windowInfo in
            guard let snapshot = makeSnapshot(from: windowInfo) else {
                return nil
            }

            return isCountable(snapshot: snapshot) ? snapshot : nil
        }
    }

    func visibleWindowCounts() -> [pid_t: Int] {
        visibleWindowCounts(from: visibleWindowSnapshots())
    }

    func visibleWindowCounts(from snapshots: [WindowSnapshot]) -> [pid_t: Int] {
        var counts: [pid_t: Int] = [:]

        for snapshot in snapshots {
            counts[snapshot.ownerPID, default: 0] += 1
        }

        return counts
    }

    private func makeSnapshot(from windowInfo: [String: Any]) -> WindowSnapshot? {
        guard
            let ownerPIDNumber = windowInfo[kCGWindowOwnerPID as String] as? NSNumber,
            let windowIDNumber = windowInfo[kCGWindowNumber as String] as? NSNumber,
            let layerNumber = windowInfo[kCGWindowLayer as String] as? NSNumber,
            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
            let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
        else {
            return nil
        }

        let alpha = (windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
        let title = windowInfo[kCGWindowName as String] as? String

        return WindowSnapshot(
            ownerPID: pid_t(ownerPIDNumber.intValue),
            windowID: CGWindowID(windowIDNumber.uint32Value),
            ownerName: ownerName,
            title: title,
            layer: layerNumber.intValue,
            alpha: alpha,
            bounds: bounds
        )
    }

    private func isCountable(snapshot: WindowSnapshot) -> Bool {
        guard snapshot.layer == 0 else {
            return false
        }

        guard snapshot.alpha > 0.01 else {
            return false
        }

        guard snapshot.bounds.width >= 24, snapshot.bounds.height >= 24 else {
            return false
        }

        return true
    }
}
