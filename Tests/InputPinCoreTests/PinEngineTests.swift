import XCTest
@testable import InputPinCore

final class FakeEnvironment: InputEnvironment {
    var currentID = "abc"
    var isSecure = false
    var available = true
    var result: Int32 = 0
    var acceptsSelection = true
    var selections: [String] = []
    func isAvailable(_ id: String) -> Bool { available }
    func select(_ id: String) -> Int32 {
        selections.append(id)
        if result == 0 && acceptsSelection { currentID = id }
        return result
    }
}

final class PinEngineTests: XCTestCase {
    private func fixture() -> (PinEngine, FakeEnvironment) {
        let environment = FakeEnvironment()
        return (PinEngine(targetID: "wetype", enabled: true, environment: environment), environment)
    }
    func testRestoresAndDoesNotReselectAnAlreadyPinnedSource() {
        let (pin, environment) = fixture()
        pin.check(at: 10)
        XCTAssertEqual(environment.currentID, "wetype")
        XCTAssertEqual(pin.state, .pinned)
        XCTAssertEqual(pin.restoreCount, 1)
        pin.check(at: 11)
        XCTAssertEqual(environment.selections, ["wetype"])
    }
    func testPausePreventsSelectionAndResumeRestores() {
        let (pin, environment) = fixture()
        pin.enabled = false
        pin.check(at: 10)
        XCTAssertEqual(pin.state, .paused)
        XCTAssertTrue(environment.selections.isEmpty)
        pin.enabled = true
        pin.reset()
        pin.check(at: 10)
        XCTAssertEqual(environment.currentID, "wetype")
    }
    func testSecureInputIsNotOverriddenAndRecovers() {
        let (pin, environment) = fixture()
        environment.isSecure = true
        pin.check(at: 10)
        XCTAssertEqual(pin.state, .secureInput)
        XCTAssertTrue(environment.selections.isEmpty)
        environment.isSecure = false
        pin.check(at: 11)
        XCTAssertEqual(environment.currentID, "wetype")
    }
    func testInactiveSessionAndSleepPreventSelection() {
        let (pin, environment) = fixture()
        pin.sessionActive = false
        pin.check(at: 10)
        XCTAssertEqual(pin.state, .waitingForSession)
        pin.sessionActive = true
        pin.sleeping = true
        pin.check(at: 11)
        XCTAssertTrue(environment.selections.isEmpty)
        pin.sleeping = false
        pin.reset()
        pin.check(at: 12)
        XCTAssertEqual(pin.state, .pinned)
    }
    func testMissingSourceNeverSelectsAndRecoversAfterEnable() {
        let (pin, environment) = fixture()
        environment.available = false
        pin.check(at: 10)
        XCTAssertEqual(pin.state, .unavailable)
        XCTAssertTrue(environment.selections.isEmpty)
        environment.available = true
        pin.check(at: 11)
        XCTAssertEqual(pin.state, .pinned)
    }
    func testDeniedSwitchBacksOffAndCapsAtThirtySeconds() {
        let (pin, environment) = fixture()
        environment.result = -50
        pin.check(at: 10)
        XCTAssertEqual(pin.state, .retrying(-50))
        XCTAssertEqual(pin.nextAttempt, 12)
        pin.check(at: 11)
        XCTAssertEqual(environment.selections.count, 1)
        for time in [12.0, 16, 24, 40, 70] { pin.check(at: time) }
        XCTAssertEqual(pin.nextAttempt, 100)
        environment.result = 0
        pin.check(at: 100)
        XCTAssertEqual(pin.failures, 0)
        XCTAssertEqual(pin.state, .pinned)
    }
    func testSuccessfulReturnCodeWithoutRealChangeIsNotSuccess() {
        let (pin, environment) = fixture()
        environment.acceptsSelection = false
        pin.check(at: 10)
        XCTAssertEqual(pin.state, .retrying(0))
        XCTAssertEqual(pin.restoreCount, 0)
    }
    func testRepeatedCompetingSwitchesAreRateLimited() {
        let (pin, environment) = fixture()
        pin.check(at: 10)
        environment.currentID = "abc"
        pin.check(at: 10.1)
        XCTAssertEqual(environment.selections.count, 1)
        XCTAssertEqual(pin.state, .waitingToRestore)
        pin.check(at: 10.5)
        XCTAssertEqual(environment.selections.count, 2)
    }
    func testTargetChangeAndExplicitResetBypassPreviousBackoff() {
        let (pin, environment) = fixture()
        environment.result = -50
        pin.check(at: 10)
        environment.result = 0
        pin.targetID = "another"
        pin.reset()
        pin.check(at: 10.1)
        XCTAssertEqual(environment.currentID, "another")
    }

    func testSecureInputStateClearsEvenDuringBackoff() {
        let (pin, environment) = fixture()
        environment.result = -50
        pin.check(at: 10)
        environment.isSecure = true
        pin.check(at: 10.1)
        XCTAssertEqual(pin.state, .secureInput)
        environment.isSecure = false
        pin.check(at: 10.2)
        XCTAssertEqual(pin.state, .waitingToRestore)
        XCTAssertEqual(environment.selections.count, 1)
    }
}
