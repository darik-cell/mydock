import AppKit
import UniformTypeIdentifiers

struct RunningAppRecord {
    let runningApplication: NSRunningApplication
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String
    let bundleURL: URL?
    let activationPolicy: NSApplication.ActivationPolicy
    let isHidden: Bool
    let isActive: Bool
    let launchDate: Date?
    let icon: NSImage

    var stableIdentifier: String {
        bundleIdentifier ?? "pid:\(processIdentifier)"
    }
}

struct InstalledAppRecord {
    let bundleIdentifier: String
    let url: URL
    let displayName: String
    let icon: NSImage
}

final class RunningAppsService {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func snapshot() -> [RunningAppRecord] {
        workspace.runningApplications.compactMap { application in
            let localizedName = application.localizedName ?? application.bundleIdentifier ?? "Unknown App"
            let icon = application.icon ?? genericApplicationIcon()

            return RunningAppRecord(
                runningApplication: application,
                processIdentifier: application.processIdentifier,
                bundleIdentifier: application.bundleIdentifier,
                localizedName: localizedName,
                bundleURL: application.bundleURL,
                activationPolicy: application.activationPolicy,
                isHidden: application.isHidden,
                isActive: application.isActive,
                launchDate: application.launchDate,
                icon: icon
            )
        }
    }

    func resolveInstalledApplications(bundleIdentifiers: [String]) -> [String: InstalledAppRecord] {
        bundleIdentifiers.reduce(into: [:]) { partialResult, bundleIdentifier in
            if let resolved = resolveInstalledApplication(bundleIdentifier: bundleIdentifier) {
                partialResult[bundleIdentifier] = resolved
            }
        }
    }

    func genericApplicationIcon() -> NSImage {
        let icon = workspace.icon(for: .application)
        icon.size = NSSize(width: 40, height: 40)
        return icon
    }

    private func resolveInstalledApplication(bundleIdentifier: String) -> InstalledAppRecord? {
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let icon = workspace.icon(forFile: url.path)
        icon.size = NSSize(width: 40, height: 40)

        let displayName = FileManager.default.displayName(atPath: url.path)

        return InstalledAppRecord(
            bundleIdentifier: bundleIdentifier,
            url: url,
            displayName: displayName,
            icon: icon
        )
    }
}
