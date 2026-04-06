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
    private let matcher: WindowAXMatcher
    private let logger = Logger(subsystem: "com.alex.mydock", category: "WindowFocus")

    init(
        permissionService: AccessibilityPermissionService,
        matcher: WindowAXMatcher = WindowAXMatcher()
    ) {
        self.permissionService = permissionService
        self.matcher = matcher
    }

    func focus(window target: WindowIdentity, in runningApplication: NSRunningApplication) -> WindowFocusResult {
        runningApplication.activate(options: [.activateAllWindows])

        guard permissionService.isTrusted() else {
            logger.notice("Accessibility permission missing for exact window focus on \(target.appName, privacy: .public)")
            return .permissionRequired
        }

        let applicationElement = AXUIElementCreateApplication(target.appPID)
        guard let windowElement = matcher.bestMatch(for: target, applicationElement: applicationElement) else {
            logger.notice("No AX window match for \(target.appName, privacy: .public) window \(target.cgWindowID)")
            return .activatedApplication
        }

        return focus(windowElement: windowElement, in: applicationElement)
            ? .focusedTargetWindow
            : .activatedApplication
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
}
