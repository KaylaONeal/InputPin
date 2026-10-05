import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var item: NSStatusItem!
    private var popover: NSPopover!
    private var model: AppModel!
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preview = CommandLine.arguments.contains("--preview")
            || Bundle.main.object(forInfoDictionaryKey: "InputPinPreviewMode") as? Bool == true
        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.kaylaoneal.InputPin"
        if !preview, NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil); return
        }
        model = AppModel(preview: preview)
        if preview {
            NSApp.setActivationPolicy(.regular)
            let view = NSHostingView(rootView: PinPanel(model: model))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 500),
                                  styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "InputPin · Preview"
            window.titlebarAppearsTransparent = true
            window.contentView = view
            window.setContentSize(view.fittingSize)
            window.center()
            window.makeKeyAndOrderFront(nil)
            previewWindow = window
            model.start()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.setAccessibilityLabel("InputPin")
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentViewController = NSHostingController(rootView: PinPanel(model: model))
        popover.delegate = self
        model.onUpdate = { [weak self] in self?.updateIcon() }
        model.start()
        updateIcon()
    }

    private func updateIcon() {
        item?.button?.image = NSImage(systemSymbolName: model.enabled ? "pin.fill" : "pin.slash", accessibilityDescription: model.title)
        item?.button?.toolTip = "InputPin · \(model.title) · \(model.targetName)"
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            model.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) { model?.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        previewWindow != nil
    }
}

do {
    if try !CLI.run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
} catch {
    fputs("InputPin: \(error.localizedDescription)\n", stderr)
    exit(1)
}
