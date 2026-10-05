import AppKit
import SwiftUI

/// A clear native window keeps system popover chrome from adding an opaque backing.
final class InputPanel: NSPanel {
    var onDismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onDismiss?() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var item: NSStatusItem!
    private var panel: InputPanel!
    private var outsideClick: Any?
    private var model: AppModel!
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preview = CommandLine.arguments.contains("--preview")
            || Bundle.main.object(forInfoDictionaryKey: "InputPinPreviewMode") as? Bool == true
        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.kaylaoneal.InputPin"
        if !preview, NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil); return
        }
        model = preview ? AppModel.designSnapshot() : AppModel()
        if preview {
            NSApp.setActivationPolicy(.regular)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
                                  styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "InputPin · Glass preview"
            window.titlebarAppearsTransparent = true
            // A controlled backdrop demonstrates glass without exposing personal desktop content.
            window.contentView = NSHostingView(rootView: ZStack {
                Color(nsColor: .windowBackgroundColor)
                HStack(spacing: 0) {
                    Color(red: 0.65, green: 0.78, blue: 0.86)
                    Color(red: 0.86, green: 0.76, blue: 0.64)
                    Color(red: 0.73, green: 0.83, blue: 0.75)
                }.opacity(0.55)
            })
            window.center()
            window.makeKeyAndOrderFront(nil)
            previewWindow = window
            configurePanel()
            let frame = window.frame
            let size = panel.contentView!.fittingSize
            panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                                  width: size.width, height: size.height), display: true)
            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.setAccessibilityLabel("InputPin")
        configurePanel()
        model.onUpdate = { [weak self] in
            self?.updateIcon()
            DispatchQueue.main.async { self?.positionPanelIfVisible() }
        }
        model.start()
        updateIcon()
    }

    private func updateIcon() {
        item?.button?.image = NSImage(systemSymbolName: model.enabled ? "pin.fill" : "pin.slash", accessibilityDescription: model.title)
        item?.button?.toolTip = "InputPin · \(model.title) · \(model.targetName)"
    }

    private func configurePanel() {
        panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: PinPanel.width, height: 280),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary, .moveToActiveSpace]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.onDismiss = { [weak self] in self?.closePanel() }
        let view = NSHostingView(rootView: PinPanel(model: model).fixedSize(horizontal: false, vertical: true))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = view
        panel.setContentSize(view.fittingSize)
    }

    private func positionPanelIfVisible() {
        guard panel.isVisible, previewWindow == nil, let button = item?.button, let window = button.window else { return }
        panel.contentView?.layoutSubtreeIfNeeded()
        let size = panel.contentView!.fittingSize
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = window.screen ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? anchor.insetBy(dx: -size.width, dy: -size.height)
        let x = min(max(anchor.midX - size.width / 2, bounds.minX + 8), bounds.maxX - size.width - 8)
        let y = max(bounds.minY + 8, anchor.minY - size.height - 6)
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    @objc private func togglePanel() {
        if panel.isVisible { closePanel() }
        else {
            model.refresh()
            panel.orderFront(nil)
            positionPanelIfVisible()
            panel.makeKey()
            // Only mouse clicks dismiss the panel; no global keyboard events are observed.
            outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePanel()
            }
        }
    }

    private func closePanel(force: Bool = false) {
        // An error sheet can take key focus from its parent. Keep it visible until answered.
        if !force, model?.errorMessage != nil || panel?.attachedSheet != nil { return }
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        outsideClick = nil
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        if previewWindow == nil { closePanel() }
    }

    func applicationWillTerminate(_ notification: Notification) { closePanel(force: true); model?.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if previewWindow == nil, panel != nil, !panel.isVisible { togglePanel() }
        return true
    }
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
