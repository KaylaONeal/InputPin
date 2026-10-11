import AppKit
import InputPinCore
import ServiceManagement
import SwiftUI

struct NativeMaterial: NSViewRepresentable {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        let opaque = reduceTransparency || contrast == .increased
        view.material = opaque ? .windowBackground : .popover
        view.alphaValue = 1
    }
}

struct PinPanel: View {
    static let width: CGFloat = 252
    @ObservedObject var model: AppModel
    var renderWithOpaqueMaterial = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var color: Color {
        switch model.state {
        case .pinned: return .accentColor
        case .paused: return .secondary
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                PinMark().frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("InputPin").font(.system(size: 15, weight: .semibold, design: .rounded))
                    Label {
                        Text(model.title).foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: model.state == .pinned ? "pin.fill" : model.enabled ? "hourglass" : "pause.fill")
                            .foregroundStyle(color)
                    }
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Menu {
                    Button(Copy.about) {
                        NSApp.orderFrontStandardAboutPanel(options: [
                            .applicationName: "InputPin",
                            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
                            .credits: NSAttributedString(string: "MIT License · github.com/KaylaONeal/InputPin")
                        ])
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    Button("GitHub") { NSWorkspace.shared.open(URL(string: "https://github.com/KaylaONeal/InputPin")!) }
                    Button(Copy.privacyPolicy) {
                        NSWorkspace.shared.open(URL(string: "https://kaylaoneal.github.io/InputPin/privacy.html")!)
                    }
                    Divider()
                    Button(Copy.quit) { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis").font(.system(size: 13, weight: .medium)).frame(width: 24, height: 24) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .fixedSize().accessibilityLabel(Copy.text("More options", "更多选项"))
            }

            VStack(alignment: .leading, spacing: 5) {
                Menu {
                    Picker(Copy.choose, selection: Binding(get: { model.targetID }, set: model.setTarget)) {
                        if !model.sources.contains(where: { $0.id == model.targetID }) {
                            Text(Copy.unavailable).tag(model.targetID)
                        }
                        ForEach(model.sources) { source in Text(source.name).tag(source.id) }
                    }
                    // Keep the choices here rather than creating another submenu.
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 6) {
                        Text(model.targetName).font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .accessibilityLabel(Copy.choose).accessibilityValue(model.targetName)
                .help(model.targetName)
                Text(model.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).frame(minHeight: 26, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Divider().opacity(0.4)
                row(Copy.enabled, description: Copy.toggleDetail) {
                    Toggle(Copy.enabled, isOn: Binding(get: { model.enabled }, set: model.setEnabled))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                row(Copy.login, description: Copy.loginDetail, status: model.loginStateText) {
                    Toggle(Copy.login, isOn: Binding(
                        get: { model.loginStatus == .enabled || model.loginStatus == .requiresApproval },
                        set: model.setLogin
                    )).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        .disabled(model.loginStatus == .notFound)
                        .accessibilityValue(model.loginStateText)
                }
                if model.loginStatus == .requiresApproval {
                    Button(Copy.approve) { SMAppService.openSystemSettingsLoginItems() }
                        .font(.system(size: 11)).buttonStyle(.link)
                }
            }

            VStack(spacing: 6) {
                Divider().opacity(0.4)
                HStack(spacing: 6) {
                    Image(systemName: "keyboard").font(.system(size: 10))
                    Text("\(Copy.current) · \(model.currentName)").font(.system(size: 11))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .help(model.currentName)
                    Spacer(minLength: 4)
                    Button(Copy.settings) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
                    }.buttonStyle(.link).font(.system(size: 11))
                }.foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: Self.width)
        .background {
            if renderWithOpaqueMaterial { Color(nsColor: .windowBackgroundColor) }
            else {
                ZStack {
                    NativeMaterial()
                    if reduceTransparency || contrast == .increased {
                        Color(nsColor: .windowBackgroundColor)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(.primary.opacity(contrast == .increased ? 0.35 : 0.12), lineWidth: 0.5))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.state)
        .alert(Copy.error, isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func row<Control: View>(_ title: String, description: String, status: String? = nil,
                                    @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                if let status {
                    Text(status).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            control().help(description).accessibilityHint(description)
        }
    }
}

/// Original keycap + pin mark; no external font or image assets.
struct PinMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.accentColor.opacity(0.12), lineWidth: 0.5))
            Image(systemName: "pin.fill").font(.system(size: 15, weight: .medium)).foregroundStyle(Color.accentColor)
        }
        .accessibilityHidden(true)
    }
}
