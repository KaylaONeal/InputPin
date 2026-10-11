import AppKit
import Carbon
import InputPinCore
import ServiceManagement
import SwiftUI

final class AppModel: ObservableObject {
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var state: PinState = .paused
    @Published private(set) var currentID = ""
    @Published private(set) var enabled = false
    @Published private(set) var targetID = ""
    @Published private(set) var loginStatus: SMAppService.Status = .notRegistered
    @Published var errorMessage: String?
    let engine: PinEngine
    private let environment: InputSourceProviding
    private let loginItem: LoginItemManaging
    private let workspaceNotifications: NotificationCenter
    private let inputNotifications: NotificationCenter
    private let uptime: () -> TimeInterval
    private let defaults: UserDefaults
    private let persistPreferences: Bool
    private var lastTargetName: String
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    private var started = false
    private var nextSourceRefresh: TimeInterval = 0
    private var presentationOnly = false
    var onUpdate: (() -> Void)?
    var targetName: String {
        sources.first { $0.id == targetID }?.name
            ?? (lastTargetName.isEmpty ? (targetID.isEmpty ? Copy.choose : Copy.unavailable) : lastTargetName)
    }
    var currentName: String { sources.first { $0.id == currentID }?.name ?? Copy.unknownSource }

    init(preview: Bool = false, environment: InputSourceProviding = SystemInputEnvironment(),
         defaults: UserDefaults? = nil, loginItem: LoginItemManaging = SystemLoginItem(),
         workspaceNotifications: NotificationCenter = NSWorkspace.shared.notificationCenter,
         inputNotifications: NotificationCenter = DistributedNotificationCenter.default(),
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.environment = environment
        self.loginItem = loginItem
        self.workspaceNotifications = workspaceNotifications
        self.inputNotifications = inputNotifications
        self.uptime = uptime
        self.persistPreferences = !preview
        let preferences = defaults ?? (preview
            ? UserDefaults(suiteName: "io.github.kaylaoneal.InputPin.preview." + UUID().uuidString)!
            : .standard)
        self.defaults = preferences
        #if APP_STORE
        let old: [String: Any]? = nil
        #else
        let old = preview || defaults != nil ? nil : UserDefaults.standard.persistentDomain(forName: "local.inputpin")
        #endif
        let savedTarget = preferences.string(forKey: "targetID") ?? old?["targetID"] as? String
        let target = savedTarget.flatMap { $0.isEmpty ? nil : $0 }
            ?? (environment.isAvailable(SystemInputEnvironment.weTypeID) ? SystemInputEnvironment.weTypeID : environment.currentID)
        let enabled = preferences.object(forKey: "enabled") as? Bool ?? old?["enabled"] as? Bool ?? true
        lastTargetName = preferences.string(forKey: "targetName") ?? ""
        engine = PinEngine(targetID: target, enabled: enabled, environment: environment)
        refresh()
        // Persist the initial choice too, so relaunching cannot silently change it.
        if persistPreferences {
            if !target.isEmpty { preferences.set(target, forKey: "targetID") }
            preferences.set(enabled, forKey: "enabled")
        }
    }

    var title: String {
        switch state {
        case .pinned: return Copy.pinned
        case .paused: return Copy.paused
        case .secureInput: return Copy.secure
        case .unavailable: return Copy.unavailable
        case .waitingForSession: return Copy.waiting
        case .retrying: return Copy.retrying
        case .waitingToRestore: return Copy.restoring
        }
    }

    var detail: String {
        switch state {
        case .pinned: return Copy.enabledDetail
        case .paused: return Copy.pausedDetail
        case .secureInput: return Copy.secureDetail
        case .unavailable: return Copy.missingDetail
        case .waitingForSession: return Copy.sessionDetail
        case .retrying(0): return Copy.confirmationDetail
        case .retrying: return Copy.retryDetail
        case .waitingToRestore: return Copy.restoreDetail
        }
    }

    var loginStateText: String {
        switch loginStatus {
        case .enabled: return Copy.on
        case .requiresApproval: return Copy.pendingApproval
        case .notRegistered: return Copy.off
        case .notFound: return Copy.loginUnavailable
        @unknown default: return Copy.loginUnavailable
        }
    }

    func start() {
        guard !presentationOnly, !started else { return }
        started = true
        let distributed = inputNotifications
        observe(distributed, Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged! as String)) { [weak self] _ in
            self?.schedule()
        }
        observe(distributed, Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged! as String)) { [weak self] _ in
            self?.refresh(reloadSources: true, refreshLogin: false)
            self?.schedule()
        }
        let workspace = workspaceNotifications
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observe(workspace, name) { [weak self] notification in
                guard let self else { return }
                switch notification.name {
                case NSWorkspace.willSleepNotification: self.engine.sleeping = true
                case NSWorkspace.didWakeNotification: self.engine.sleeping = false; self.engine.reset()
                case NSWorkspace.sessionDidResignActiveNotification: self.engine.sessionActive = false
                case NSWorkspace.sessionDidBecomeActiveNotification: self.engine.sessionActive = true; self.engine.reset()
                default: break
                }
                self.schedule()
            }
        }
        // Close the gap between initial enumeration and observer registration.
        refresh(reloadSources: true, refreshLogin: false)
        check()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, handler: @escaping (Notification) -> Void) {
        observers.append((center, center.addObserver(forName: name, object: nil, queue: .main, using: handler)))
    }

    func stop() {
        started = false
        pending?.cancel()
        pending = nil
        timer?.invalidate()
        timer = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
    }

    deinit {
        pending?.cancel()
        timer?.invalidate()
        observers.forEach { $0.0.removeObserver($0.1) }
    }

    private func updateFallbackTimer() {
        let needsTimer = started && engine.enabled && engine.sessionActive && !engine.sleeping
        if !needsTimer {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.check() }
            timer.tolerance = 0.25
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    private func schedule(after delay: TimeInterval = 0.12) {
        guard started else { return }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.started else { return }
            self.check()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func check() {
        guard !presentationOnly else { return }
        pending?.cancel()
        pending = nil
        let now = uptime()
        if engine.enabled, engine.sessionActive, !engine.sleeping, !environment.isSecure,
           engine.state == .unavailable, now >= nextSourceRefresh {
            // Distributed notifications may be dropped. Revalidate missing sources
            // without re-enumerating on every healthy fallback check.
            refresh(reloadSources: true, refreshLogin: false)
            nextSourceRefresh = now + 5
        }
        engine.check(at: now)
        refresh(reloadSources: false, refreshLogin: false)
        updateFallbackTimer()
        switch engine.state {
        case .retrying, .waitingToRestore:
            let remaining = engine.nextAttempt - uptime()
            if remaining > 0 { schedule(after: remaining) }
        default: break
        }
    }

    func refresh(reloadSources: Bool = true, refreshLogin: Bool = true) {
        guard !presentationOnly else { return }
        var changed = false
        if reloadSources {
            environment.invalidateSources()
            let sources = environment.sources
            if self.sources != sources { self.sources = sources; changed = true }
        }
        let current = environment.currentID
        if currentID != current { currentID = current; changed = true }
        if state != engine.state { state = engine.state; changed = true }
        if enabled != engine.enabled { enabled = engine.enabled; changed = true }
        if targetID != engine.targetID { targetID = engine.targetID; changed = true }
        if let name = sources.first(where: { $0.id == targetID })?.name, name != lastTargetName {
            lastTargetName = name
            if persistPreferences { defaults.set(name, forKey: "targetName") }
            changed = true
        }
        if refreshLogin {
            let login = loginItem.status
            if loginStatus != login { loginStatus = login; changed = true }
        }
        if changed { onUpdate?() }
    }

    func setEnabled(_ value: Bool) {
        if presentationOnly {
            engine.enabled = value
            enabled = value
            state = value ? .pinned : .paused
            return
        }
        engine.enabled = value
        if persistPreferences { defaults.set(value, forKey: "enabled") }
        check()
    }

    func setTarget(_ id: String) {
        if presentationOnly {
            guard sources.contains(where: { $0.id == id }) else { return }
            engine.targetID = id
            targetID = id
            currentID = id
            return
        }
        environment.invalidateSources()
        guard environment.isAvailable(id) else { refresh(); return }
        engine.targetID = id
        lastTargetName = sources.first(where: { $0.id == id })?.name ?? ""
        if persistPreferences {
            defaults.set(id, forKey: "targetID")
            defaults.set(lastTargetName, forKey: "targetName")
        }
        refresh()
        check()
    }

    func setLogin(_ value: Bool) {
        if presentationOnly { loginStatus = value ? .enabled : .notRegistered; return }
        let status = loginItem.status
        let requested = status == .enabled || status == .requiresApproval
        guard value != requested else { refresh(); return }
        do { try loginItem.setEnabled(value) }
        catch { errorMessage = error.localizedDescription }
        refresh()
    }

    /// A deterministic presentation fixture; it never starts source switching.
    static func designSnapshot(state: PinState = .pinned,
                               loginStatus: SMAppService.Status = .notRegistered,
                               longNames: Bool = false) -> AppModel {
        let model = AppModel(preview: true)
        model.presentationOnly = true
        model.engine.targetID = SystemInputEnvironment.weTypeID
        model.targetID = SystemInputEnvironment.weTypeID
        model.engine.enabled = state != .paused
        model.enabled = model.engine.enabled
        model.sources = [InputSource(id: SystemInputEnvironment.weTypeID,
                                     name: longNames ? "A very long keyboard input source name — 输入法名称可完整查看" : "微信输入法"),
                         InputSource(id: "com.apple.keylayout.ABC", name: "ABC")]
        model.lastTargetName = model.sources[0].name
        if state == .unavailable { model.sources.removeFirst() }
        model.currentID = state == .pinned ? SystemInputEnvironment.weTypeID : "com.apple.keylayout.ABC"
        model.state = state
        model.loginStatus = loginStatus
        return model
    }
}
