import AppKit

struct DockItem {
    let slotIndex: Int
    let stableIdentifier: String
    let appIdentifier: String?
    let bundleIdentifier: String?
    let processIdentifier: pid_t?
    let displayName: String
    let icon: NSImage
    let runningApplication: NSRunningApplication?
    let launchURL: URL?
    let isPinned: Bool
    let isRunning: Bool
    let isActive: Bool
    let visibleWindowCount: Int

    var windowDotsCount: Int {
        min(visibleWindowCount, 4)
    }

    var indexLabel: String? {
        Self.label(for: slotIndex)
    }

    var canBePinned: Bool {
        bundleIdentifier != nil
    }

    private static func label(for zeroBasedIndex: Int) -> String? {
        guard zeroBasedIndex < 10 else {
            return nil
        }

        if zeroBasedIndex == 9 {
            return "0"
        }

        return String(zeroBasedIndex + 1)
    }
}
