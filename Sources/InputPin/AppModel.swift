import AppKit
import Carbon
import InputPinCore
import ServiceManagement
import SwiftUI

final class AppModel: ObservableObject {
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var state: PinState = .paused
    @Published private(set) var currentID = ""
    @Published private(set) var loginStatus: SMAppService.Status = .notRegistered
    @Published var errorMessage: String?
    let engine: PinEngine
    private let environment: SystemInputEnvironment
    private let defaults: UserDefaults
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    var onUpdate: (() -> Void)?
    var enabled: Bool { engine.enabled }
    var targetID: String { engine.targetID }
    var targetName: String { sources.first { $0.id == targetID }?.name ?? Copy.choose }
    var currentName: String { sources.first { $0.id == currentID }?.name ?? currentID }

    init(preview: Bool = false) {
        let environment = SystemInputEnvironment()
        self.environment = environment
        defaults = preview ? UserDefaults(suiteName: "io.github.kaylaoneal.InputPin.preview")! : .standard
        #if APP_STORE
        // Store preferences stay in this app's sandbox; no prototype-domain migration.
        let old: [String: Any]? = nil
        #else
        let old = preview ? nil : UserDefaults.standard.persistentDomain(forName: "local.inputpin")
        #endif
        let target = defaults.string(forKey: "targetID") ?? old?["targetID"] as? String
            ?? (environment.isAvailable(SystemInputEnvironment.weTypeID) ? SystemInputEnvironment.weTypeID : environment.currentID)
        let enabled = defaults.object(forKey: "enabled") as? Bool ?? old?["enabled"] as? Bool ?? true
        engine = PinEngine(targetID: target, enabled: enabled, environment: environment)
        refresh()
    }

    var title: String {
        switch state {
        case .pinned: return Copy.pinned
        case .paused: return Copy.paused
        case .secureInput: return Copy.secure
        case .unavailable: return Copy.unavailable
        case .waitingForSession: return Copy.waiting
        case .retrying, .waitingToRestore: return Copy.retrying
        }
    }

    var detail: String {
        switch state {
        case .pinned: return Copy.enabledDetail
        case .paused: return Copy.pausedDetail
        case .secureInput: return Copy.secureDetail
        case .unavailable: return Copy.missingDetail
        case .waitingForSession: return Copy.sessionDetail
        case .retrying, .waitingToRestore: return Copy.retryDetail
        }
    }

    func start() {
        guard timer == nil else { return }
        let distributed = DistributedNotificationCenter.default()
        for name in [kTISNotifySelectedKeyboardInputSourceChanged!, kTISNotifyEnabledKeyboardInputSourcesChanged!] {
            observe(distributed, Notification.Name(name as String)) { [weak self] _ in self?.schedule() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
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
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.check() }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        check()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, handler: @escaping (Notification) -> Void) {
        observers.append((center, center.addObserver(forName: name, object: nil, queue: .main, using: handler)))
    }

    func stop() {
        pending?.cancel()
        pending = nil
        timer?.invalidate()
        timer = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
    }

    private func schedule(after delay: TimeInterval = 0.12) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.check() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func check() {
        engine.check(at: ProcessInfo.processInfo.systemUptime)
        refresh()
        if engine.enabled, !environment.isSecure, environment.currentID != engine.targetID,
           environment.isAvailable(engine.targetID), engine.sessionActive, !engine.sleeping {
            let remaining = engine.nextAttempt - ProcessInfo.processInfo.systemUptime
            if remaining > 0 { schedule(after: remaining) }
        }
    }

    func refresh() {
        let sources = environment.sources
        if self.sources != sources { self.sources = sources }
        if currentID != environment.currentID { currentID = environment.currentID }
        if state != engine.state { state = engine.state }
        let login = SMAppService.mainApp.status
        if loginStatus != login { loginStatus = login }
        objectWillChange.send()
        onUpdate?()
    }

    func setEnabled(_ value: Bool) {
        engine.enabled = value
        defaults.set(value, forKey: "enabled")
        engine.reset()
        check()
    }

    func setTarget(_ id: String) {
        guard environment.isAvailable(id) else { return }
        engine.targetID = id
        defaults.set(id, forKey: "targetID")
        engine.reset()
        check()
    }

    func setLogin(_ value: Bool) {
        do {
            if value {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            } else { try SMAppService.mainApp.unregister() }
        } catch { errorMessage = error.localizedDescription }
        refresh()
    }

    /// A deterministic presentation fixture; it never starts source switching.
    static func designSnapshot() -> AppModel {
        let model = AppModel(preview: true)
        model.engine.targetID = SystemInputEnvironment.weTypeID
        model.engine.enabled = true
        model.sources = [InputSource(id: SystemInputEnvironment.weTypeID, name: "微信输入法"),
                         InputSource(id: "com.apple.keylayout.ABC", name: "ABC")]
        model.currentID = SystemInputEnvironment.weTypeID
        model.state = .pinned
        return model
    }
}
