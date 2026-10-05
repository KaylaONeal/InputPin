import Foundation

public protocol InputEnvironment: AnyObject {
    var currentID: String { get }
    var isSecure: Bool { get }
    func isAvailable(_ id: String) -> Bool
    func select(_ id: String) -> Int32
}

public enum PinState: Equatable {
    case paused, waitingForSession, secureInput, unavailable, pinned, waitingToRestore
    case retrying(Int32)
}

/// Main-thread state machine. Monotonic time is supplied by the caller.
public final class PinEngine {
    public var targetID: String
    public var enabled: Bool
    public var sessionActive = true
    public var sleeping = false
    public private(set) var state: PinState = .paused
    public private(set) var restoreCount = 0
    public private(set) var failures = 0
    public private(set) var nextAttempt: TimeInterval = 0
    private let environment: InputEnvironment

    public init(targetID: String, enabled: Bool, environment: InputEnvironment) {
        self.targetID = targetID
        self.enabled = enabled
        self.environment = environment
    }

    public func reset() {
        failures = 0
        nextAttempt = 0
    }

    public func check(at now: TimeInterval) {
        guard enabled else { state = .paused; return }
        guard sessionActive, !sleeping else { state = .waitingForSession; return }
        guard !environment.isSecure else { state = .secureInput; return }
        guard environment.isAvailable(targetID) else { state = .unavailable; return }
        if environment.currentID == targetID {
            state = .pinned
            failures = 0
            return
        }
        guard now >= nextAttempt else { state = .waitingToRestore; return }
        let result = environment.select(targetID)
        if result == 0, environment.currentID == targetID {
            restoreCount += 1
            failures = 0
            nextAttempt = now + 0.5
            state = .pinned
        } else {
            failures += 1
            nextAttempt = now + min(30, pow(2, Double(min(failures, 5))))
            state = .retrying(result)
        }
    }
}
