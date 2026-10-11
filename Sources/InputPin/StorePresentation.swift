import AppKit
import SwiftUI

/// Store artwork with real native controls and example state in an illustrative display frame.
/// Preview-only: never starts the pinning engine or changes preferences.
struct StorePresentation: View {
    @ObservedObject var model: AppModel
    var page = 1
    private let supporting = Color(red: 0.28, green: 0.36, blue: 0.44)

    private var heading: String {
        switch page {
        case 2: return Copy.text("Choose it. Pin it. Keep typing.", "选好输入法，开启固定")
        case 3: return Copy.text("Pause pinning. Switch freely.", "需要切换，随时暂停")
        default: return Copy.text("Pin your chosen input method.", "固定你指定的输入法")
        }
    }

    private var introduction: String {
        switch page {
        case 2: return Copy.text("Choose an input method from the menu bar and turn pinning on.",
                                 "在菜单栏中指定输入法，开启固定即可。")
        case 3: return Copy.text("Turn pinning off whenever you want to switch input methods.",
                                 "暂停固定后，即可自由切换输入法。")
        default: return Copy.text("Keep your Mac on the input method you choose.",
                                   "解决 Mac 自动切换输入法的困扰，让输入法保持在你的选择。")
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.85, green: 0.91, blue: 0.96)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    PinMark().frame(width: 34, height: 34)
                    Text("InputPin").font(.system(size: 24, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(Copy.text("INPUT METHOD LOCK", "输入法固定"))
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(supporting)
                }
                Text(heading).font(.system(size: Copy.chinese ? 46 : 43, weight: .bold))
                    .tracking(Copy.chinese ? 0 : -1).padding(.top, 28)
                    .fixedSize(horizontal: false, vertical: true)
                Text(introduction).font(.system(size: 21)).foregroundStyle(supporting)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 13)
                HStack(alignment: .top, spacing: 34) {
                    desktop.frame(width: 834, height: 510)
                    explanation.frame(width: 284, alignment: .leading).padding(.top, 38)
                }.padding(.top, 38)
            }.padding(.horizontal, 64).padding(.top, 40)
        }
        .foregroundStyle(Color(red: 0.09, green: 0.17, blue: 0.24))
        .frame(width: 1280, height: 800)
        .environment(\.colorScheme, .light)
        .environment(\.controlActiveState, .key)
    }

    private var desktop: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28).fill(Color(red: 0.10, green: 0.12, blue: 0.15))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.6), lineWidth: 2))
            ZStack(alignment: .topTrailing) {
                Color(red: 0.74, green: 0.84, blue: 0.93)
                VStack(spacing: 0) {
                    HStack(spacing: 17) {
                        Text("InputPin").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: model.enabled ? "pin.fill" : "pin.slash")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 24)
                            .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100")
                    }
                    .font(.system(size: 13)).padding(.horizontal, 20).frame(height: 30)
                    .background(.white.opacity(0.3))
                    Spacer()
                }
                PinPanel(model: model, renderWithOpaqueMaterial: true)
                    .fixedSize()
                    .scaleEffect(1.85, anchor: .topTrailing)
                    .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
                    .padding(.top, 44).padding(.trailing, 28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(14).padding(.bottom, 9)
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
    }

    @ViewBuilder private var explanation: some View {
        switch page {
        case 2:
            VStack(alignment: .leading, spacing: 32) {
                step("1", title: Copy.text("Choose your input method", "指定输入法"),
                     detail: Copy.text("Click its name to see the choices directly.", "点击输入法名称，直接展开选项。"))
                step("2", title: Copy.text("Turn pinning on", "开启固定"),
                     detail: Copy.text("Turn on “Keep this input source”.", "打开“固定此输入法”开关。"))
            }
        case 3:
            VStack(alignment: .leading, spacing: 26) {
                Label(Copy.text("Pinning paused", "固定已暂停"), systemImage: "pause.fill")
                    .font(.system(size: 25, weight: .semibold))
                Divider()
                Text(Copy.text("Switch to ABC or another input method while paused.",
                               "暂停期间，可以切换到 ABC 或其他输入法。"))
                    .font(.system(size: 19)).foregroundStyle(supporting)
                Text(Copy.text("Resume to pin your choice again.", "重新开启，即可继续固定你的选择。"))
                    .font(.system(size: 19)).foregroundStyle(supporting)
            }.fixedSize(horizontal: false, vertical: true)
        default:
            VStack(alignment: .leading, spacing: 24) {
                Text(Copy.text("Your chosen input method", "你指定的输入法"))
                    .font(.system(size: 17)).foregroundStyle(supporting)
                Text(model.targetName).font(.system(size: 29, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                Label(Copy.text("Pinning is on", "固定已开启"), systemImage: "pin.fill")
                    .font(.system(size: 25, weight: .semibold)).foregroundStyle(Color.accentColor)
                Text(Copy.text("If macOS switches away, InputPin restores your selection.",
                               "系统切换到其他输入源时，自动恢复你指定的输入法。"))
                    .font(.system(size: 19)).foregroundStyle(supporting)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func step(_ number: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(number).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(Color.accentColor, in: Circle())
            Text(title).font(.system(size: 25, weight: .semibold))
            Text(detail).font(.system(size: 19)).foregroundStyle(supporting)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
