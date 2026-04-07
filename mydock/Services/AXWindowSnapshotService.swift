import ApplicationServices
import CoreGraphics
import Foundation
import OSLog

final class AXWindowSnapshotService {
    private let permissionService: AccessibilityPermissionService
    private let logger = Logger(subsystem: "com.alex.mydock", category: "AXWindows")

    init(permissionService: AccessibilityPermissionService) {
        self.permissionService = permissionService
    }

    func cycleWindowIdentities(for runningApps: [RunningAppRecord]) -> [WindowIdentity] {
        guard permissionService.isTrusted() else {
            logger.notice("Skipping AX window snapshot because Accessibility permission is missing")
            return []
        }

        return runningApps
            .filter { $0.activationPolicy == .regular && !$0.isHidden }
            .flatMap { windows(for: $0) }
    }

    private func windows(for app: RunningAppRecord) -> [WindowIdentity] {
        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = copyAttributeValue(
            for: applicationElement,
            attribute: kAXWindowsAttribute as CFString
        ) as? [AXUIElement] else {
            return []
        }

        return windows.compactMap { window in
            makeIdentity(for: window, app: app)
        }
    }

    private func makeIdentity(for window: AXUIElement, app: RunningAppRecord) -> WindowIdentity? {
        let title = copyAttributeValue(for: window, attribute: kAXTitleAttribute as CFString) as? String
        let document = copyAttributeValue(for: window, attribute: kAXDocumentAttribute as CFString) as? String
        let role = copyAttributeValue(for: window, attribute: kAXRoleAttribute as CFString) as? String
        let subrole = copyAttributeValue(for: window, attribute: kAXSubroleAttribute as CFString) as? String
        let minimized = boolValue(for: window, attribute: kAXMinimizedAttribute as CFString)
        let bounds = bounds(for: window)

        let identity = WindowIdentity(
            appIdentifier: app.stableIdentifier,
            appPID: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            appName: app.localizedName,
            element: AXUIElementBox(element: window),
            title: title,
            document: document,
            bounds: bounds,
            role: role,
            subrole: subrole,
            isMinimized: minimized
        )

        return isEligible(identity) ? identity : nil
    }

    private func isEligible(_ window: WindowIdentity) -> Bool {
        if window.isMinimized {
            return false
        }

        if let role = window.role, role != kAXWindowRole as String {
            return false
        }

        guard window.bounds.width >= 24, window.bounds.height >= 24 else {
            return false
        }

        return true
    }

    private func bounds(for window: AXUIElement) -> CGRect {
        let position = copyAXValue(for: window, attribute: kAXPositionAttribute as CFString)
            .flatMap(pointValue(from:))
            ?? .zero
        let size = copyAXValue(for: window, attribute: kAXSizeAttribute as CFString)
            .flatMap(sizeValue(from:))
            ?? .zero

        return CGRect(origin: position, size: size)
    }

    private func copyAttributeValue(for element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }

        return value
    }

    private func copyAXValue(for element: AXUIElement, attribute: CFString) -> AXValue? {
        guard let value = copyAttributeValue(for: element, attribute: attribute) else {
            return nil
        }

        return unsafeDowncast(value, to: AXValue.self)
    }

    private func boolValue(for element: AXUIElement, attribute: CFString) -> Bool {
        if let number = copyAttributeValue(for: element, attribute: attribute) as? NSNumber {
            return number.boolValue
        }

        return false
    }

    private func pointValue(from value: AXValue) -> CGPoint? {
        guard AXValueGetType(value) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func sizeValue(from value: AXValue) -> CGSize? {
        guard AXValueGetType(value) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }
}
