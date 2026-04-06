import Foundation

struct AppConfiguration {
    static let defaultPinnedBundleIdentifiers: [String] = [
        "com.google.Chrome",
        "com.jetbrains.intellij"
    ]

    var pinnedBundleIdentifiers: [String] = Self.defaultPinnedBundleIdentifiers

    init(pinnedBundleIdentifiers: [String] = Self.defaultPinnedBundleIdentifiers) {
        self.pinnedBundleIdentifiers = pinnedBundleIdentifiers
    }
}
