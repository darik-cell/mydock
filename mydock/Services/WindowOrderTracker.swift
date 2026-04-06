import Foundation

final class WindowOrderTracker {
    private var cycleState = WindowCycleState()
    private var nextSequenceNumber = 0

    func sync(with windows: [WindowIdentity]) {
        let windowsByApp = Dictionary(grouping: windows, by: \.appIdentifier)
        var nextAppStates: [String: AppWindowCycleState] = [:]

        for (appIdentifier, appWindows) in windowsByApp {
            guard let appPID = appWindows.first?.appPID else {
                continue
            }

            let sortedCurrentWindows = appWindows.sorted { lhs, rhs in
                if lhs.cgWindowID != rhs.cgWindowID {
                    return lhs.cgWindowID < rhs.cgWindowID
                }

                if lhs.bounds.minX != rhs.bounds.minX {
                    return lhs.bounds.minX < rhs.bounds.minX
                }

                return lhs.bounds.minY < rhs.bounds.minY
            }

            var appState = cycleState.appStates[appIdentifier]
            if appState?.appPID != appPID {
                appState = AppWindowCycleState(
                    appIdentifier: appIdentifier,
                    appPID: appPID,
                    orderedEntries: [],
                    nextIndex: 0,
                    lastResolvedWindowID: nil,
                    lastCycleAt: nil
                )
            }

            var orderedEntries = appState?.orderedEntries.filter { entry in
                sortedCurrentWindows.contains(entry.identity)
            } ?? []
            let knownWindows = Set(orderedEntries.map(\.identity))

            for window in sortedCurrentWindows where !knownWindows.contains(window) {
                nextSequenceNumber += 1
                orderedEntries.append(
                    WindowCycleEntry(
                        identity: window,
                        sequenceNumber: nextSequenceNumber
                    )
                )
            }

            orderedEntries.sort { $0.sequenceNumber < $1.sequenceNumber }
            guard !orderedEntries.isEmpty else {
                continue
            }

            var nextIndex = appState?.nextIndex ?? 0
            nextIndex = normalized(nextIndex, count: orderedEntries.count)

            if let lastResolvedWindowID = appState?.lastResolvedWindowID,
               !orderedEntries.contains(where: { $0.identity.cgWindowID == lastResolvedWindowID }) {
                appState?.lastResolvedWindowID = nil
            }

            nextAppStates[appIdentifier] = AppWindowCycleState(
                appIdentifier: appIdentifier,
                appPID: appPID,
                orderedEntries: orderedEntries,
                nextIndex: nextIndex,
                lastResolvedWindowID: appState?.lastResolvedWindowID,
                lastCycleAt: appState?.lastCycleAt
            )
        }

        cycleState.appStates = nextAppStates
    }

    func orderedWindows(for appIdentifier: String, pid: pid_t) -> [WindowIdentity] {
        guard let appState = validState(for: appIdentifier, pid: pid) else {
            return []
        }

        return appState.orderedEntries.map(\.identity)
    }

    func nextWindow(for appIdentifier: String, pid: pid_t) -> WindowIdentity? {
        guard let appState = validState(for: appIdentifier, pid: pid), !appState.orderedEntries.isEmpty else {
            return nil
        }

        return appState.orderedEntries[appState.nextIndex].identity
    }

    func advanceCursor(for appIdentifier: String, pid: pid_t, resolvedWindow: WindowIdentity) {
        guard var appState = validState(for: appIdentifier, pid: pid), !appState.orderedEntries.isEmpty else {
            return
        }

        appState.lastResolvedWindowID = resolvedWindow.cgWindowID
        appState.lastCycleAt = Date()
        appState.nextIndex = normalized(appState.nextIndex + 1, count: appState.orderedEntries.count)
        cycleState.appStates[appIdentifier] = appState
    }

    private func validState(for appIdentifier: String, pid: pid_t) -> AppWindowCycleState? {
        guard let appState = cycleState.appStates[appIdentifier], appState.appPID == pid else {
            return nil
        }

        return appState
    }

    private func normalized(_ index: Int, count: Int) -> Int {
        guard count > 0 else {
            return 0
        }

        let remainder = index % count
        return remainder >= 0 ? remainder : remainder + count
    }
}
