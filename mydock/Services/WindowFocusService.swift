import AppKit
import ApplicationServices
import Foundation
import OSLog

enum WindowFocusResult {
    case focusedTargetWindow
    case activatedApplication
    case permissionRequired
}

final class WindowFocusService {
    private let permissionService: AccessibilityPermissionService
    private let logger = Logger(subsystem: "com.alex.mydock", category: "WindowFocus")

    init(permissionService: AccessibilityPermissionService) {
        self.permissionService = permissionService
    }

    func focus(window target: WindowIdentity, in runningApplication: NSRunningApplication) -> WindowFocusResult {
        runningApplication.activate(options: [.activateAllWindows])

        guard permissionService.isTrusted() else {
            logger.notice("Accessibility permission missing for exact window focus on \(target.appName, privacy: .public)")
            return .permissionRequired
        }

        let applicationElement = AXUIElementCreateApplication(target.appPID)
        let windowElement = target.element.element

        guard focus(windowElement: windowElement, in: applicationElement) else {
            logger.notice("AX focus actions failed for \(target.appName, privacy: .public) window \(target.runtimeIdentifier, privacy: .public)")
            return .activatedApplication
        }

        let didVerifyFocusedWindow = verifyFocusedWindow(windowElement: windowElement, in: applicationElement)
        logger.notice(
            "AX focus verification app=\(target.appName, privacy: .public) targetWindow=\(target.runtimeIdentifier, privacy: .public) title=\(target.normalizedTitle, privacy: .public) verified=\(didVerifyFocusedWindow, privacy: .public)"
        )

        return didVerifyFocusedWindow ? .focusedTargetWindow : .activatedApplication
    }

    private func focus(windowElement: AXUIElement, in applicationElement: AXUIElement) -> Bool {
        let trueValue = kCFBooleanTrue!
        var didFocus = false

        if AXUIElementSetAttributeValue(applicationElement, kAXFocusedWindowAttribute as CFString, windowElement) == .success {
            didFocus = true
        }

        if AXUIElementSetAttributeValue(windowElement, kAXMainAttribute as CFString, trueValue) == .success {
            didFocus = true
        }

        if AXUIElementSetAttributeValue(windowElement, kAXFocusedAttribute as CFString, trueValue) == .success {
            didFocus = true
        }

        if AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString) == .success {
            didFocus = true
        }

        return didFocus
    }

    private func verifyFocusedWindow(windowElement: AXUIElement, in applicationElement: AXUIElement) -> Bool {
        guard let focusedWindow = copyAttributeValue(
            for: applicationElement,
            attribute: kAXFocusedWindowAttribute as CFString
        ) else {
            return false
        }

        return CFEqual(focusedWindow, windowElement)
    }

    private func copyAttributeValue(for element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }

        return value
    }
}
