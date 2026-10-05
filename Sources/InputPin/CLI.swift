import AppKit
import Carbon
import Foundation
import SwiftUI

enum CLIError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum CLI {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CLIError.message(message) }
    }
    static func run() throws -> Bool {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else { return false }
        if command == "--preview" || command == "--store-preview" { return false }
        let environment = SystemInputEnvironment()
        switch command {
        case "--list":
            for source in environment.sources { print("\(source.id)\t\(source.name)") }
        case "--current": print(environment.currentID)
        case "--version": print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")
        case "--select":
            try require(args.count == 2, "Usage: InputPin --select INPUT_SOURCE_ID")
            try require(!environment.isSecure, "Secure input is active")
            try require(environment.isAvailable(args[1]), "Unknown or disabled input source")
            let result = environment.select(args[1])
            try require(result == 0 && environment.currentID == args[1], "System rejected input source selection (\(result))")
            print(environment.currentID)
        case "--integration-test": try integrationTest(environment)
        case "--render-panel":
            try require(args.count == 3 && ["light", "dark"].contains(args[2]), "Usage: --render-panel PATH light|dark")
            try renderPanel(path: args[1], dark: args[2] == "dark")
        case "--help": print("InputPin [--list | --current | --version | --select ID | --integration-test | --preview | --render-panel PATH light|dark]")
        default: throw CLIError.message("Unknown option. Use --help")
        }
        return true
    }

    private static func renderPanel(path: String, dark: Bool) throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let model = AppModel.designSnapshot()
        let view = NSHostingView(rootView: PinPanel(model: model, renderWithOpaqueMaterial: true))
        view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: PinPanel.width, height: 300),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: view.fittingSize)
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CLIError.message("Could not create native panel render")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CLIError.message("Could not encode panel PNG")
        }
        try png.write(to: URL(fileURLWithPath: path))
        withExtendedLifetime(window) {}
        print("Native view render: \(path) (presentation fixture, not a live screenshot)")
    }
    private static func integrationTest(_ environment: SystemInputEnvironment) throws {
        let appIDs: Set<String> = ["io.github.kaylaoneal.InputPin",
                                   "io.github.kaylaoneal.InputPin.SandboxProbe",
                                   Bundle.main.bundleIdentifier ?? "io.github.kaylaoneal.InputPin"]
        try require(appIDs.allSatisfy { id in
            NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .allSatisfy { $0.processIdentifier == ProcessInfo.processInfo.processIdentifier }
        },
                    "Quit InputPin and its sandbox probe before running the integration test")
        let abc = "com.apple.keylayout.ABC"
        let weType = SystemInputEnvironment.weTypeID
        try require(!environment.isSecure && environment.isAvailable(abc) && environment.isAvailable(weType),
                    "Enable ABC and WeType and exit secure input first")
        let original = environment.currentID
        defer { _ = environment.select(original) }
        let model = AppModel(preview: true)
        model.engine.targetID = weType
        model.engine.enabled = true
        model.start()
        defer { model.stop() }
        try require(environment.currentID == weType, "Initial pin failed")
        for round in 1...3 {
            let count = model.engine.restoreCount
            let start = ProcessInfo.processInfo.systemUptime
            try require(environment.select(abc) == 0 && environment.currentID == abc, "ABC selection failed")
            let deadline = Date().addingTimeInterval(3)
            while model.engine.restoreCount == count && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
            try require(environment.currentID == weType && model.engine.restoreCount > count, "Automatic restore failed")
            print("restore \(round): PASS (\(Int((ProcessInfo.processInfo.systemUptime - start) * 1000)) ms)")
        }
        model.engine.enabled = false
        _ = environment.select(abc)
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        try require(environment.currentID == abc, "Paused pin switched the source")
        print("pause: PASS")
        model.engine.enabled = true
        model.engine.reset()
        model.check()
        try require(environment.currentID == weType, "Resume failed")
        print("resume: PASS")
        try checkSecureInput(environment, model, abc)
        model.engine.reset()
        model.check()
        try require(environment.currentID == weType, "Secure-input recovery failed")
        print("secure input and recovery: PASS")
        model.engine.targetID = "io.inputpin.nonexistent"
        model.check()
        try require(model.engine.state == .unavailable, "Unavailable source not detected")
        print("unavailable target: PASS")
    }
    private static func checkSecureInput(_ environment: SystemInputEnvironment, _ model: AppModel, _ abc: String) throws {
        try require(EnableSecureEventInput() == 0, "Cannot enable secure input for test")
        defer { DisableSecureEventInput() }
        _ = environment.select(abc)
        model.engine.reset()
        model.check()
        try require(model.engine.state == .secureInput && environment.currentID == abc, "Secure input was not respected")
    }
}
