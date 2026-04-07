import AppKit
import Carbon
import Foundation

enum HotkeyAction: Hashable {
    case slot(Int)
    case toggleVisibility
}

final class HotkeyManager {
    var onAction: ((HotkeyAction) -> Void)?
    var onOptionReleased: (() -> Void)?

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    private var lastInvocationByAction: [HotkeyAction: TimeInterval] = [:]
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var isOptionPressed = false

    func start() {
        stop()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        let keyCodes: [UInt32] = [
            UInt32(kVK_ANSI_1),
            UInt32(kVK_ANSI_2),
            UInt32(kVK_ANSI_3),
            UInt32(kVK_ANSI_4),
            UInt32(kVK_ANSI_5),
            UInt32(kVK_ANSI_6),
            UInt32(kVK_ANSI_7),
            UInt32(kVK_ANSI_8),
            UInt32(kVK_ANSI_9),
            UInt32(kVK_ANSI_0)
        ]

        for (slotIndex, keyCode) in keyCodes.enumerated() {
            registerHotkey(keyCode: keyCode, identifier: UInt32(slotIndex))
        }

        registerHotkey(keyCode: UInt32(kVK_ANSI_D), identifier: 100)

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        hotKeyRefs.forEach { hotKeyRef in
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
        }
        hotKeyRefs.removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
            self.globalFlagsMonitor = nil
        }

        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
            self.localFlagsMonitor = nil
        }

        isOptionPressed = false
    }

    private func registerHotkey(keyCode: UInt32, identifier: UInt32) {
        let hotKeyID = EventHotKeyID(signature: fourCharCode("MDRK"), id: identifier)
        var hotKeyRef: EventHotKeyRef?

        RegisterEventHotKey(
            keyCode,
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        hotKeyRefs.append(hotKeyRef)
    }

    private func handle(event: EventRef?) -> OSStatus {
        guard let event else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        guard let action = action(for: hotKeyID.id) else {
            return noErr
        }

        let timestamp = CFAbsoluteTimeGetCurrent()
        if let previousTimestamp = lastInvocationByAction[action], timestamp - previousTimestamp < 0.08 {
            return noErr
        }

        lastInvocationByAction[action] = timestamp
        onAction?(action)
        return noErr
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let optionPressed = event.modifierFlags.contains(.option)
        if isOptionPressed && !optionPressed {
            onOptionReleased?()
        }

        isOptionPressed = optionPressed
    }

    private func action(for identifier: UInt32) -> HotkeyAction? {
        switch identifier {
        case 0...9:
            return .slot(Int(identifier))
        case 100:
            return .toggleVisibility
        default:
            return nil
        }
    }

    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard let userData else {
            return noErr
        }

        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        return manager.handle(event: event)
    }

    private func fourCharCode(_ value: String) -> OSType {
        value.utf8.reduce(0) { result, byte in
            (result << 8) + OSType(byte)
        }
    }
}
