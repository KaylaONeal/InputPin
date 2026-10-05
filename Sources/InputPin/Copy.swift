import Foundation

enum Copy {
    static let chinese = (Bundle.main.object(forInfoDictionaryKey: "InputPinScreenshotLocale") as? String
                          ?? Locale.preferredLanguages.first)?.hasPrefix("zh") == true
    static func text(_ english: String, _ chinese: String) -> String { self.chinese ? chinese : english }
    static let subtitle = text("Keep your input in place.", "让输入法，始终如你所选。")
    static let pinned = text("Pinned", "已固定")
    static let paused = text("Paused", "已暂停")
    static let secure = text("Waiting for secure input", "安全输入中")
    static let unavailable = text("Input source unavailable", "输入法不可用")
    static let waiting = text("Waiting for your session", "等待会话恢复")
    static let retrying = text("Waiting to restore", "等待恢复")
    static let target = text("PINNED INPUT SOURCE", "固定的输入法")
    static let choose = text("Choose an input source", "选择输入法")
    static let enabled = text("Keep this input source", "固定此输入法")
    static let enabledDetail = text("Restore it when macOS switches away.", "系统切走后，自动恢复你的选择。")
    static let toggleDetail = text("Pause whenever you need to switch freely.", "需要使用其他输入法时，可随时暂停。")
    static let pausedDetail = text("Switch freely until you resume.", "暂停期间，可以自由切换输入法。")
    static let secureDetail = text("Secure input takes priority. Pinning resumes when it ends.", "优先遵循安全输入，结束后自动恢复固定。")
    static let missingDetail = text("Enable this source in System Settings, or choose another.", "请在系统设置中启用，或选择其他输入法。")
    static let sessionDetail = text("Pinning resumes after wake or sign-in.", "唤醒或重新登录后恢复固定。")
    static let retryDetail = text("macOS has not accepted the switch. Retrying with care.", "系统暂未允许切换，稍后自动重试。")
    static let login = text("Launch at login", "登录时启动")
    static let loginDetail = text("Ready whenever you start your Mac.", "每次开始使用 Mac，都已准备就绪。")
    static let approve = text("Complete approval in System Settings", "在系统设置中完成批准")
    static let privacy = text("No keystrokes. No accounts. No tracking.", "不读取按键，无需账号，无追踪。")
    static let settings = text("Input settings", "输入法设置")
    static let quit = text("Quit InputPin", "退出 InputPin")
    static let error = text("Could not update launch at login", "无法更改登录启动设置")
    static let current = text("Current", "当前")
    static let about = text("About InputPin", "关于 InputPin")
}
