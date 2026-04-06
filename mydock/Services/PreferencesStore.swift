import Foundation

final class PreferencesStore {
    struct Snapshot {
        let configuration: AppConfiguration
        let layoutSettings: DockLayoutSettings
    }

    private enum Key {
        static let pinnedBundleIdentifiers = "mydock.preferences.pinnedBundleIdentifiers"
        static let contentInsetLeft = "mydock.preferences.layout.contentInsetLeft"
        static let contentInsetRight = "mydock.preferences.layout.contentInsetRight"
        static let itemSpacing = "mydock.preferences.layout.itemSpacing"
        static let iconSize = "mydock.preferences.layout.iconSize"
        static let dockScreenLeftOffset = "mydock.preferences.layout.dockScreenLeftOffset"
    }

    private let userDefaults: UserDefaults

    private(set) var snapshot: Snapshot {
        didSet {
            onChange?(snapshot)
        }
    }

    var onChange: ((Snapshot) -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        Self.registerDefaults(on: userDefaults)
        snapshot = Self.loadSnapshot(from: userDefaults)
    }

    func pin(bundleIdentifier: String) {
        var pinnedBundleIdentifiers = snapshot.configuration.pinnedBundleIdentifiers
        guard !pinnedBundleIdentifiers.contains(bundleIdentifier) else {
            return
        }

        pinnedBundleIdentifiers.append(bundleIdentifier)
        update(configuration: AppConfiguration(pinnedBundleIdentifiers: pinnedBundleIdentifiers))
    }

    func unpin(bundleIdentifier: String) {
        let pinnedBundleIdentifiers = snapshot.configuration.pinnedBundleIdentifiers.filter { $0 != bundleIdentifier }
        update(configuration: AppConfiguration(pinnedBundleIdentifiers: pinnedBundleIdentifiers))
    }

    func update(layoutSettings: DockLayoutSettings) {
        persist(layoutSettings: layoutSettings)
        snapshot = Snapshot(configuration: snapshot.configuration, layoutSettings: layoutSettings)
    }

    func updateLayout(_ mutate: (inout DockLayoutSettings) -> Void) {
        var layoutSettings = snapshot.layoutSettings
        mutate(&layoutSettings)
        update(layoutSettings: layoutSettings)
    }

    private func update(configuration: AppConfiguration) {
        userDefaults.set(configuration.pinnedBundleIdentifiers, forKey: Key.pinnedBundleIdentifiers)
        snapshot = Snapshot(configuration: configuration, layoutSettings: snapshot.layoutSettings)
    }

    private func persist(layoutSettings: DockLayoutSettings) {
        userDefaults.set(Double(layoutSettings.contentInsetLeft), forKey: Key.contentInsetLeft)
        userDefaults.set(Double(layoutSettings.contentInsetRight), forKey: Key.contentInsetRight)
        userDefaults.set(Double(layoutSettings.itemSpacing), forKey: Key.itemSpacing)
        userDefaults.set(Double(layoutSettings.iconSize), forKey: Key.iconSize)
        userDefaults.set(Double(layoutSettings.dockScreenLeftOffset), forKey: Key.dockScreenLeftOffset)
    }

    private static func registerDefaults(on userDefaults: UserDefaults) {
        userDefaults.register(defaults: [
            Key.pinnedBundleIdentifiers: AppConfiguration.defaultPinnedBundleIdentifiers,
            Key.contentInsetLeft: Double(DockLayoutSettings.default.contentInsetLeft),
            Key.contentInsetRight: Double(DockLayoutSettings.default.contentInsetRight),
            Key.itemSpacing: Double(DockLayoutSettings.default.itemSpacing),
            Key.iconSize: Double(DockLayoutSettings.default.iconSize),
            Key.dockScreenLeftOffset: Double(DockLayoutSettings.default.dockScreenLeftOffset)
        ])
    }

    private static func loadSnapshot(from userDefaults: UserDefaults) -> Snapshot {
        let pinnedBundleIdentifiers = userDefaults.stringArray(forKey: Key.pinnedBundleIdentifiers)
            ?? AppConfiguration.defaultPinnedBundleIdentifiers

        let layoutSettings = DockLayoutSettings(
            contentInsetLeft: CGFloat(userDefaults.double(forKey: Key.contentInsetLeft)),
            contentInsetRight: CGFloat(userDefaults.double(forKey: Key.contentInsetRight)),
            itemSpacing: CGFloat(userDefaults.double(forKey: Key.itemSpacing)),
            iconSize: CGFloat(userDefaults.double(forKey: Key.iconSize)),
            dockScreenLeftOffset: CGFloat(userDefaults.double(forKey: Key.dockScreenLeftOffset))
        )

        return Snapshot(
            configuration: AppConfiguration(pinnedBundleIdentifiers: pinnedBundleIdentifiers),
            layoutSettings: layoutSettings
        )
    }
}
