import ApplicationServices
import CoreGraphics
import Foundation

struct AXUIElementBox: Hashable {
    let element: AXUIElement

    var runtimeIdentifier: Int {
        Int(CFHash(element))
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(runtimeIdentifier)
    }

    static func == (lhs: AXUIElementBox, rhs: AXUIElementBox) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }
}

struct WindowIdentity: Hashable {
    let appIdentifier: String
    let appPID: pid_t
    let bundleIdentifier: String?
    let appName: String
    let element: AXUIElementBox
    let title: String?
    let document: String?
    let bounds: CGRect
    let role: String?
    let subrole: String?
    let isMinimized: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(appPID)
        hasher.combine(element)
    }

    static func == (lhs: WindowIdentity, rhs: WindowIdentity) -> Bool {
        lhs.appPID == rhs.appPID && lhs.element == rhs.element
    }

    var runtimeIdentifier: Int {
        element.runtimeIdentifier
    }

    var normalizedTitle: String {
        let primary = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty {
            return primary
        }

        return (document ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
