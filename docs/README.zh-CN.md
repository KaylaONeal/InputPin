# InputPin · 输入法固定

让输入法，始终如你所选。

一个轻量、原生、透明的 macOS 菜单栏工具。系统切换到其他输入法时，自动恢复你选定的输入法。支持微信输入法、ABC，以及系统中已启用的其他键盘输入源。

[安装方式](#安装) · [English](../README.md)

## 安装

**当前状态：**brew 源码安装已发布并通过实际安装测试。Apple 正在处理公证，DMG 与二进制 Cask 尚未公开。

安装后，菜单栏的图钉可选择目标输入法、暂停固定或设置登录启动。公证包通过验证后会发布到 [Releases](https://github.com/KaylaONeal/InputPin/releases)。

```sh
brew install kaylaoneal/tap/inputpin
```

使用项目自己的 Homebrew tap，不代表已进入 Homebrew 官方仓库。安装包包含 Apple Silicon 和 Intel 两种架构，要求 macOS 13 Ventura 及以上。二进制包将在完成 Developer ID 签名、Apple 公证与票据装订后发布。源码安装需要本机 Xcode 15+；安装后运行 `open "$(brew --prefix inputpin)/InputPin.app"` 打开应用。[测试记录与未验证项](QA.md)。

## 行为

开启固定后，手动切换到其他输入法也会被恢复。临时使用其他输入法时先暂停。微信输入法内部的中英文模式切换不受影响。

安全输入、休眠和非活动登录会话期间暂停自动切换。安全输入结束后重新检查。某些 App 持续开启安全输入时，固定会等待。目标输入法不可用时，会提示在系统设置中启用；系统拒绝切换时会逐步延长重试间隔，最多 30 秒。

默认优先选择已安装的微信输入法，否则使用当前输入法。登录启动为可选项。本工具不运行在系统登录界面，也不替你安装输入法。

## 隐私与卸载

不读取按键、文档或密码；无账号、追踪、网络请求，也无需辅助功能、输入监控或管理员权限。

卸载前先关闭登录启动，然后退出。`brew uninstall inputpin` 保留设置。公证 Cask 发布后，还可使用 `brew install --cask kaylaoneal/tap/inputpin` 直接安装。

## 开发与社区

```sh
git clone https://github.com/KaylaONeal/InputPin.git
cd InputPin
swift test
bash build.sh
open build/InputPin.app
```

[贡献指南](../CONTRIBUTING.md) · [设计规范](../DESIGN.md) · [安全政策](../SECURITY.md) · [更新记录](../CHANGELOG.md) · [MIT 许可证](../LICENSE)

项目独立开发，与 Apple、腾讯无隶属关系。不包含微信输入法本身，第三方输入法仍遵循各自许可证。
