import AppKit
import UniformTypeIdentifiers

struct DockModelBuildResult {
    let items: [DockItem]
    let dynamicOrder: [String]
}

final class DockModelBuilder {
    func build(
        configuration: AppConfiguration,
        runningApps: [RunningAppRecord],
        visibleWindowCounts: [pid_t: Int],
        pinnedInstallations: [String: InstalledAppRecord],
        previousDynamicOrder: [String]
    ) -> DockModelBuildResult {
        let regularApps = runningApps.filter { $0.activationPolicy == .regular }
        let pinnedSet = Set(configuration.pinnedBundleIdentifiers)
        let pinnedAppsByBundleIdentifier = regularApps.reduce(into: [String: [RunningAppRecord]]()) { partialResult, record in
            guard let bundleIdentifier = record.bundleIdentifier else {
                return
            }

            partialResult[bundleIdentifier, default: []].append(record)
        }

        var items: [DockItem] = []

        for (slotIndex, bundleIdentifier) in configuration.pinnedBundleIdentifiers.enumerated() {
            let runningCandidates = pinnedAppsByBundleIdentifier[bundleIdentifier] ?? []
            let runningMatch = selectBestPinnedMatch(from: runningCandidates, visibleWindowCounts: visibleWindowCounts)
            let installedMatch = pinnedInstallations[bundleIdentifier]

            let icon = runningMatch?.icon ?? installedMatch?.icon ?? NSWorkspace.shared.icon(for: .application)
            icon.size = NSSize(width: 40, height: 40)

            let displayName = runningMatch?.localizedName
                ?? installedMatch?.displayName
                ?? bundleIdentifier

            let visibleWindowCount = runningMatch.map { visibleWindowCounts[$0.processIdentifier] ?? 0 } ?? 0

            items.append(
                DockItem(
                    slotIndex: slotIndex,
                    stableIdentifier: "pinned:\(bundleIdentifier)",
                    appIdentifier: runningMatch?.stableIdentifier ?? bundleIdentifier,
                    bundleIdentifier: bundleIdentifier,
                    processIdentifier: runningMatch?.processIdentifier,
                    displayName: displayName,
                    icon: icon,
                    runningApplication: runningMatch?.runningApplication,
                    launchURL: runningMatch?.bundleURL ?? installedMatch?.url,
                    isPinned: true,
                    isRunning: runningMatch != nil,
                    isActive: runningMatch?.isActive == true,
                    visibleWindowCount: visibleWindowCount
                )
            )
        }

        let dynamicCandidates = regularApps.filter { app in
            let visibleWindows = visibleWindowCounts[app.processIdentifier] ?? 0

            guard visibleWindows > 0 else {
                return false
            }

            guard !app.isHidden else {
                return false
            }

            if let bundleIdentifier = app.bundleIdentifier, pinnedSet.contains(bundleIdentifier) {
                return false
            }

            return true
        }

        let orderedDynamicApps = orderDynamicApps(dynamicCandidates, previousOrder: previousDynamicOrder)
        let dynamicOrder = orderedDynamicApps.map(\.stableIdentifier)

        for app in orderedDynamicApps {
            let slotIndex = items.count
            items.append(
                DockItem(
                    slotIndex: slotIndex,
                    stableIdentifier: app.stableIdentifier,
                    appIdentifier: app.stableIdentifier,
                    bundleIdentifier: app.bundleIdentifier,
                    processIdentifier: app.processIdentifier,
                    displayName: app.localizedName,
                    icon: app.icon,
                    runningApplication: app.runningApplication,
                    launchURL: app.bundleURL,
                    isPinned: false,
                    isRunning: true,
                    isActive: app.isActive,
                    visibleWindowCount: visibleWindowCounts[app.processIdentifier] ?? 0
                )
            )
        }

        return DockModelBuildResult(items: items, dynamicOrder: dynamicOrder)
    }

    private func selectBestPinnedMatch(
        from candidates: [RunningAppRecord],
        visibleWindowCounts: [pid_t: Int]
    ) -> RunningAppRecord? {
        candidates.max { lhs, rhs in
            let lhsScore = score(for: lhs, visibleWindowCounts: visibleWindowCounts)
            let rhsScore = score(for: rhs, visibleWindowCounts: visibleWindowCounts)
            return lhsScore < rhsScore
        }
    }

    private func score(for app: RunningAppRecord, visibleWindowCounts: [pid_t: Int]) -> Int {
        let visibleWindowCount = visibleWindowCounts[app.processIdentifier] ?? 0
        let activeBoost = app.isActive ? 1_000 : 0
        return visibleWindowCount * 10 + activeBoost
    }

    private func orderDynamicApps(
        _ apps: [RunningAppRecord],
        previousOrder: [String]
    ) -> [RunningAppRecord] {
        let appsByIdentifier = Dictionary(uniqueKeysWithValues: apps.map { ($0.stableIdentifier, $0) })
        var ordered: [RunningAppRecord] = []

        for identifier in previousOrder {
            if let app = appsByIdentifier[identifier] {
                ordered.append(app)
            }
        }

        let alreadyIncluded = Set(ordered.map(\.stableIdentifier))
        let newApps = apps
            .filter { !alreadyIncluded.contains($0.stableIdentifier) }
            .sorted { lhs, rhs in
                switch (lhs.launchDate, rhs.launchDate) {
                case let (left?, right?) where left != right:
                    return left < right
                default:
                    return lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName) == .orderedAscending
                }
            }

        ordered.append(contentsOf: newApps)
        return ordered
    }
}
