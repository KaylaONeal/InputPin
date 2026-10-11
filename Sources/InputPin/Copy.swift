import Foundation

enum Copy {
    static let chinese: Bool = {
        let renderLocale = ["--render-panel", "--render-store"].contains(CommandLine.arguments.dropFirst().first ?? "")
            ? ProcessInfo.processInfo.environment["INPUTPIN_RENDER_LOCALE"] : nil
        return (renderLocale ?? Bundle.main.object(forInfoDictionaryKey: "InputPinScreenshotLocale") as? String
                ?? Locale.preferredLanguages.first)?.hasPrefix("zh") == true
    }()
    static func text(_ english: String, _ chinese: String) -> String { self.chinese ? chinese : english }
    static let subtitle = text("Pin your chosen input method", "固定指定输入法，避免自动切换")
    static let pinned = text("Pinned", "已固定")
    static let paused = text("Paused", "已暂停")
    static let secure = text("Waiting for secure input", "安全输入中")
    static let unavailable = text("Input source unavailable", "输入法不可用")
    static let waiting = text("Waiting for your session", "等待会话恢复")
    static let retrying = text("Retrying", "正在重试")
    static let restoring = text("Restoring", "正在恢复")
    static let target = text("PINNED INPUT METHOD", "固定的输入法")
    static let choose = text("Choose an input method", "选择输入法")
    static let enabled = text("Keep this input source", "固定此输入法")
    static let enabledDetail = text("Restore it when macOS switches away.", "系统切换后，自动恢复指定输入法。")
    static let toggleDetail = text("Pause whenever you need to switch freely.", "需要使用其他输入法时，可随时暂停。")
    static let pausedDetail = text("Switch freely until you resume.", "暂停期间，可以自由切换输入法。")
    static let secureDetail = text("Secure input takes priority. Pinning resumes when it ends.", "优先遵循安全输入，结束后自动恢复固定。")
    static let missingDetail = text("Enable this source in System Settings, or choose another.", "请在系统设置中启用，或选择其他输入法。")
    static let sessionDetail = text("Pinning resumes after wake or sign-in.", "唤醒或重新登录后恢复固定。")
    static let retryDetail = text("macOS has not accepted the switch. Retrying with care.", "系统暂未允许切换，稍后自动重试。")
    static let restoreDetail = text("Restoring your chosen input source.", "正在恢复你选择的输入法。")
    static let confirmationDetail = text("Waiting for macOS to confirm the switch. Retrying automatically.", "等待系统确认切换，稍后自动重试。")
    static let login = text("Launch at login", "登录时启动")
    static let loginDetail = text("Ready whenever you start your Mac.", "每次开始使用 Mac，都已准备就绪。")
    static let approve = text("Complete approval in System Settings", "在系统设置中完成批准")
    static let on = text("On", "已开启")
    static let off = text("Off", "已关闭")
    static let pendingApproval = text("Pending approval", "等待批准")
    static let loginUnavailable = text("Unavailable", "不可用")
    static let unknownSource = text("Unavailable", "不可用")
    static let privacyPolicy = text("Privacy policy", "隐私政策")
    static let privacy = text("No keystrokes. No accounts. No tracking.", "不读取按键，无需账号，无追踪。")
    static let settings = text("Input settings", "输入法设置")
    static let quit = text("Quit InputPin", "退出 InputPin")
    static let error = text("Could not update launch at login", "无法更改登录启动设置")
    static let current = text("Current", "当前")
    static let about = text("About InputPin", "关于 InputPin")
}
