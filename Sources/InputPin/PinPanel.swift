import AppKit
import InputPinCore
import ServiceManagement
import SwiftUI

struct NativeMaterial: NSViewRepresentable {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = reduceTransparency ? .windowBackground : .popover
    }
}

struct PinPanel: View {
    @ObservedObject var model: AppModel
    var renderWithOpaqueMaterial = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var color: Color {
        switch model.state {
        case .pinned: return .accentColor
        case .paused: return .secondary
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 12) {
                PinMark().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("InputPin").font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(Copy.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
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
                    Divider()
                    Button(Copy.quit) { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium)).frame(width: 28, height: 28) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .fixedSize().accessibilityLabel(Copy.text("More options", "更多选项"))
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: model.state == .pinned ? "pin.fill" : model.enabled ? "hourglass" : "pause.fill")
                    Text(model.title).fontWeight(.medium)
                    Spacer()
                }
                .font(.system(size: 12)).foregroundStyle(color)
                Text(Copy.target).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Picker(Copy.choose, selection: Binding(get: { model.targetID }, set: model.setTarget)) {
                    if !model.sources.contains(where: { $0.id == model.targetID }) {
                        Text(Copy.unavailable).tag(model.targetID)
                    }
                    ForEach(model.sources) { source in Text(source.name).tag(source.id) }
                }
                .labelsHidden().pickerStyle(.menu).controlSize(.large)
                .accessibilityLabel(Copy.choose)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(model.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).frame(minHeight: 30, alignment: .topLeading)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.primary.opacity(0.07), lineWidth: 0.5))

            VStack(spacing: 18) {
                row(Copy.enabled, description: Copy.toggleDetail) {
                    Toggle(Copy.enabled, isOn: Binding(get: { model.enabled }, set: model.setEnabled))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                Divider().opacity(0.5)
                row(Copy.login, description: Copy.loginDetail) {
                    Toggle(Copy.login, isOn: Binding(
                        get: { model.loginStatus == .enabled || model.loginStatus == .requiresApproval },
                        set: model.setLogin
                    )).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                if model.loginStatus == .requiresApproval {
                    Button(Copy.approve) { SMAppService.openSystemSettingsLoginItems() }
                        .font(.system(size: 11)).buttonStyle(.link)
                }
            }
            .padding(.horizontal, 2)

            VStack(spacing: 12) {
                Divider().opacity(0.5)
                HStack(spacing: 6) {
                    Image(systemName: "keyboard").font(.system(size: 10))
                    Text("\(Copy.current) · \(model.currentName)").font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    Button(Copy.settings) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
                    }.buttonStyle(.link).font(.system(size: 11))
                }.foregroundStyle(.secondary)
                Text(Copy.privacy).font(.system(size: 10)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background {
            if renderWithOpaqueMaterial { Color(nsColor: .windowBackgroundColor) }
            else { NativeMaterial() }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.state)
        .alert(Copy.error, isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func row<Control: View>(_ title: String, description: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(description).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            control()
        }
    }
}

/// Original keycap + pin mark; no external font or image assets.
struct PinMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.accentColor.opacity(0.15), lineWidth: 0.5))
            Image(systemName: "pin.fill").font(.system(size: 19, weight: .medium)).foregroundStyle(Color.accentColor)
        }
        .accessibilityHidden(true)
    }
}
