import Combine
import AppKit
import InputPinCore
import ServiceManagement
import XCTest
@testable import InputPin

private final class TestInputEnvironment: InputSourceProviding {
    var selectedID = "abc"
    var currentReads = 0
    var sourceReads = 0
    var selections: [String] = []
    var availableSources = [InputSource(id: "abc", name: "ABC")]
    var cacheSources = false
    private var cachedSources: [InputSource]?
    var currentID: String { currentReads += 1; return selectedID }
    var isSecure = false
    private var selectable: [InputSource] {
        if !cacheSources { return availableSources }
        if let cachedSources { return cachedSources }
        cachedSources = availableSources
        return availableSources
    }
    var sources: [InputSource] { sourceReads += 1; return selectable }
    func invalidateSources() { cachedSources = nil }
    func isAvailable(_ id: String) -> Bool { selectable.contains { $0.id == id } }
    func select(_ id: String) -> Int32 {
        selections.append(id)
        selectedID = id
        return 0
    }
}

private final class TestLoginItem: LoginItemManaging {
    var storedStatus: SMAppService.Status = .notRegistered
    var statusReads = 0
    var requests: [Bool] = []
    var failure: Error?
    var status: SMAppService.Status { statusReads += 1; return storedStatus }
    func setEnabled(_ enabled: Bool) throws {
        requests.append(enabled)
        if let failure { throw failure }
        storedStatus = enabled ? .enabled : .notRegistered
    }
}

final class AppModelTests: XCTestCase {
    private var preferences: UserDefaults!
    private var suite: String!
    private var notifications: NotificationCenter!

    override func setUp() {
        super.setUp()
        notifications = NotificationCenter()
        suite = "InputPin.tests." + UUID().uuidString
        preferences = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        preferences.removePersistentDomain(forName: suite)
        preferences = nil
        notifications = nil
        super.tearDown()
    }

    func testFirstChoiceSurvivesRelaunchAndNewlyEnabledWeType() {
        let environment = TestInputEnvironment()
        let first = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        XCTAssertEqual(first.targetID, "abc")
        environment.availableSources.append(InputSource(id: SystemInputEnvironment.weTypeID, name: "WeType"))
        let second = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        XCTAssertEqual(second.targetID, "abc")
        XCTAssertTrue(environment.selections.isEmpty)
    }

    func testUnavailableTargetRetainsItsNameAcrossRelaunch() {
        let environment = TestInputEnvironment()
        _ = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        environment.availableSources = []
        let model = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        model.check()
        XCTAssertEqual(model.state, .unavailable)
        XCTAssertEqual(model.targetName, "ABC")
        XCTAssertTrue(environment.selections.isEmpty)
    }

    func testSourceEnabledBeforeObserverRegistrationRecoversAtStart() {
        preferences.set("other", forKey: "targetID")
        let environment = TestInputEnvironment()
        environment.cacheSources = true
        let model = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(),
                             workspaceNotifications: notifications, inputNotifications: notifications)
        environment.availableSources.append(InputSource(id: "other", name: "Other"))
        model.start()
        defer { model.stop() }
        XCTAssertEqual(model.state, .pinned)
        XCTAssertEqual(environment.selections, ["other"])
    }

    func testMissingSourceRecoversWithoutNotificationWithThrottledRefresh() {
        preferences.set("other", forKey: "targetID")
        let environment = TestInputEnvironment()
        environment.cacheSources = true
        var now: TimeInterval = 10
        let model = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(),
                             workspaceNotifications: notifications, inputNotifications: notifications,
                             uptime: { now })
        model.check()
        model.check()
        XCTAssertEqual(model.state, .unavailable)
        let reads = environment.sourceReads
        environment.availableSources.append(InputSource(id: "other", name: "Other"))
        now = 11
        model.check()
        XCTAssertEqual(model.state, .unavailable)
        XCTAssertEqual(environment.sourceReads, reads)
        now = 15
        model.check()
        XCTAssertEqual(model.state, .pinned)
        XCTAssertEqual(model.targetName, "Other")
        XCTAssertEqual(environment.selections, ["other"])
        XCTAssertEqual(environment.sourceReads, reads + 1)
    }

    func testChangingTargetWhilePausedWaitsForResume() {
        let environment = TestInputEnvironment()
        environment.availableSources.append(InputSource(id: "other", name: "Other"))
        let model = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        model.setEnabled(false)
        model.setTarget("other")
        XCTAssertFalse(model.enabled)
        XCTAssertEqual(model.targetID, "other")
        XCTAssertEqual(model.currentID, "abc")
        XCTAssertTrue(environment.selections.isEmpty)
        model.setEnabled(true)
        XCTAssertEqual(model.state, .pinned)
        XCTAssertEqual(model.currentID, "other")
        XCTAssertEqual(environment.selections, ["other"])
    }

    func testUnchangedFallbackCheckDoesNotPublishOrReloadSystemServices() {
        let environment = TestInputEnvironment()
        let login = TestLoginItem()
        let model = AppModel(environment: environment, defaults: preferences, loginItem: login, workspaceNotifications: notifications, inputNotifications: notifications)
        model.check()
        let sourceReads = environment.sourceReads
        let loginReads = login.statusReads
        var publications = 0
        let subscription = model.objectWillChange.sink { publications += 1 }
        model.check()
        model.check()
        XCTAssertEqual(publications, 0)
        XCTAssertEqual(environment.sourceReads, sourceReads)
        XCTAssertEqual(login.statusReads, loginReads)
        withExtendedLifetime(subscription) {}
    }

    func testPausedAppDoesNotPollInBackground() {
        let environment = TestInputEnvironment()
        let model = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        model.setEnabled(false)
        model.start()
        defer { model.stop() }
        let reads = environment.currentReads
        RunLoop.main.run(until: Date().addingTimeInterval(1.4))
        XCTAssertEqual(environment.currentReads, reads)
        XCTAssertTrue(environment.selections.isEmpty)
    }

    func testLoginFailureKeepsActualStatusAndPresentsError() {
        let login = TestLoginItem()
        login.failure = NSError(domain: "InputPinTests", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Registration failed"])
        let model = AppModel(environment: TestInputEnvironment(), defaults: preferences, loginItem: login, workspaceNotifications: notifications, inputNotifications: notifications)
        model.setLogin(true)
        XCTAssertEqual(model.loginStatus, .notRegistered)
        XCTAssertEqual(model.errorMessage, "Registration failed")
        XCTAssertEqual(login.requests, [true])
    }

    func testPendingLoginApprovalIsExplicitAndCanBeCancelled() {
        let login = TestLoginItem()
        login.storedStatus = .requiresApproval
        let model = AppModel(environment: TestInputEnvironment(), defaults: preferences, loginItem: login, workspaceNotifications: notifications, inputNotifications: notifications)
        XCTAssertEqual(model.loginStateText, Copy.pendingApproval)
        model.setLogin(true)
        XCTAssertTrue(login.requests.isEmpty)
        model.setLogin(false)
        XCTAssertEqual(login.requests, [false])
        XCTAssertEqual(model.loginStatus, .notRegistered)
    }

    func testPreviewPreferencesRemainUntouched() {
        preferences.set("abc", forKey: "targetID")
        preferences.set(false, forKey: "enabled")
        let environment = TestInputEnvironment()
        environment.availableSources.append(InputSource(id: "other", name: "Other"))
        let model = AppModel(preview: true, environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        model.setTarget("other")
        model.setEnabled(true)
        XCTAssertEqual(preferences.string(forKey: "targetID"), "abc")
        XCTAssertEqual(preferences.object(forKey: "enabled") as? Bool, false)
        XCTAssertNil(preferences.object(forKey: "targetName"))
    }

    func testStoppingCancelsPendingSourceRestoration() {
        let environment = TestInputEnvironment()
        let model = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        model.start()
        environment.selectedID = "other"
        notifications.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        model.stop()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(environment.selections.isEmpty)
        XCTAssertEqual(environment.selectedID, "other")
    }

    func testSimulatedSleepSuspendsPollingAndWakeRestores() {
        let environment = TestInputEnvironment()
        let model = AppModel(environment: environment, defaults: preferences, loginItem: TestLoginItem(), workspaceNotifications: notifications, inputNotifications: notifications)
        model.start()
        defer { model.stop() }
        notifications.post(name: NSWorkspace.willSleepNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(model.state, .waitingForSession)
        let reads = environment.currentReads
        RunLoop.main.run(until: Date().addingTimeInterval(1.4))
        XCTAssertEqual(environment.currentReads, reads)
        environment.selectedID = "other"
        notifications.post(name: NSWorkspace.didWakeNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(model.state, .pinned)
        XCTAssertEqual(environment.selections, ["abc"])
    }
}
