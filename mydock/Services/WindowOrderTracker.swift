import CoreGraphics
import Foundation
import OSLog

final class WindowOrderTracker {
    private var cycleState = WindowCycleState()
    private var nextSequenceNumber = 0
    private let logger = Logger(subsystem: "com.alex.mydock", category: "WindowCycle")

    func sync(with windows: [WindowIdentity]) {
        let windowsByApp = Dictionary(grouping: windows, by: \.appIdentifier)
        var nextAppStates: [String: AppWindowCycleState] = [:]

        for (appIdentifier, appWindows) in windowsByApp {
            guard let appPID = appWindows.first?.appPID else {
                continue
            }

            let currentWindows = appWindows

            var appState = cycleState.appStates[appIdentifier]
            if appState?.appPID != appPID {
                appState = AppWindowCycleState(
                    appIdentifier: appIdentifier,
                    appPID: appPID,
                    orderedEntries: [],
                    nextIndex: 0,
                    lastResolvedWindowIdentifier: nil,
                    lastCycleAt: nil
                )
            }

            var orderedEntries = appState?.orderedEntries.filter { entry in
                currentWindows.contains(entry.identity)
            } ?? []
            let previousWindowIDs = orderedEntries.map(\.identity.runtimeIdentifier)
            let knownWindows = Set(orderedEntries.map(\.identity))
            var newlyAddedWindowIDs: [Int] = []

            for window in currentWindows where !knownWindows.contains(window) {
                nextSequenceNumber += 1
                newlyAddedWindowIDs.append(window.runtimeIdentifier)
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
            let removedWindowIDs = previousWindowIDs.filter { previousID in
                !orderedEntries.contains(where: { $0.identity.runtimeIdentifier == previousID })
            }

            if let lastResolvedWindowIdentifier = appState?.lastResolvedWindowIdentifier,
               !orderedEntries.contains(where: { $0.identity.runtimeIdentifier == lastResolvedWindowIdentifier }) {
                appState?.lastResolvedWindowIdentifier = nil
            }

            nextAppStates[appIdentifier] = AppWindowCycleState(
                appIdentifier: appIdentifier,
                appPID: appPID,
                orderedEntries: orderedEntries,
                nextIndex: nextIndex,
                lastResolvedWindowIdentifier: appState?.lastResolvedWindowIdentifier,
                lastCycleAt: appState?.lastCycleAt
            )

            let orderedWindowIDs = orderedEntries.map(\.identity.runtimeIdentifier)
            logger.notice(
                "Cycle sync app=\(appIdentifier, privacy: .public) pid=\(appPID, privacy: .public) windows=\(orderedWindowIDs.count, privacy: .public) nextIndex=\(nextIndex, privacy: .public) added=\(String(describing: newlyAddedWindowIDs), privacy: .public) removed=\(String(describing: removedWindowIDs), privacy: .public) ordered=\(String(describing: orderedWindowIDs), privacy: .public)"
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

        let previousIndex = appState.nextIndex
        appState.lastResolvedWindowIdentifier = resolvedWindow.runtimeIdentifier
        appState.lastCycleAt = Date()
        appState.nextIndex = normalized(appState.nextIndex + 1, count: appState.orderedEntries.count)
        cycleState.appStates[appIdentifier] = appState
        logger.notice(
            "Cycle cursor advanced app=\(appIdentifier, privacy: .public) pid=\(pid, privacy: .public) resolvedWindow=\(resolvedWindow.runtimeIdentifier, privacy: .public) fromIndex=\(previousIndex, privacy: .public) toIndex=\(appState.nextIndex, privacy: .public)"
        )
    }

    func state(for appIdentifier: String, pid: pid_t) -> AppWindowCycleState? {
        validState(for: appIdentifier, pid: pid)
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
