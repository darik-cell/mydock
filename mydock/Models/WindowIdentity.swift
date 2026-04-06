import CoreGraphics
import Foundation

struct WindowIdentity: Hashable {
    let appIdentifier: String
    let appPID: pid_t
    let bundleIdentifier: String?
    let appName: String
    let cgWindowID: CGWindowID
    let title: String?
    let bounds: CGRect
    let layer: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(appPID)
        hasher.combine(cgWindowID)
    }

    static func == (lhs: WindowIdentity, rhs: WindowIdentity) -> Bool {
        lhs.appPID == rhs.appPID && lhs.cgWindowID == rhs.cgWindowID
    }

    var normalizedTitle: String {
        (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
