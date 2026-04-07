import CoreGraphics
import Foundation

struct WindowCycleEntry: Hashable {
    let identity: WindowIdentity
    let sequenceNumber: Int
}

struct AppWindowCycleState {
    let appIdentifier: String
    let appPID: pid_t
    var orderedEntries: [WindowCycleEntry]
    var nextIndex: Int
    var lastResolvedWindowIdentifier: Int?
    var lastCycleAt: Date?
}

struct WindowCycleState {
    var appStates: [String: AppWindowCycleState] = [:]
}
