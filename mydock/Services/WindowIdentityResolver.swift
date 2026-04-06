import Foundation

final class WindowIdentityResolver {
    func resolve(
        snapshots: [WindowSnapshot],
        runningApps: [RunningAppRecord]
    ) -> [WindowIdentity] {
        let runningAppsByPID = Dictionary(uniqueKeysWithValues: runningApps.map { ($0.processIdentifier, $0) })

        return snapshots.compactMap { snapshot in
            guard let app = runningAppsByPID[snapshot.ownerPID] else {
                return nil
            }

            guard app.activationPolicy == .regular, !app.isHidden else {
                return nil
            }

            return WindowIdentity(
                appIdentifier: app.stableIdentifier,
                appPID: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                appName: app.localizedName,
                cgWindowID: snapshot.windowID,
                title: snapshot.title,
                bounds: snapshot.bounds,
                layer: snapshot.layer
            )
        }
    }
}
