import ApplicationServices
import Foundation
import OSLog

final class AccessibilityPermissionService {
    private static let trustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"
    private let logger = Logger(subsystem: "com.alex.mydock", category: "Accessibility")
    private var hasPromptedForAccess = false

    func isTrusted(prompt: Bool = false) -> Bool {
        let options = [Self.trustedCheckOptionPromptKey: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestIfNeeded() {
        guard !hasPromptedForAccess else {
            return
        }

        hasPromptedForAccess = true
        logger.notice("Requesting Accessibility permission for exact window focus")
        _ = isTrusted(prompt: true)
    }
}
