# InputPin — 输入法固定

固定指定输入法，避免自动切换。

Mac 经常自动切换输入法，打断你的输入节奏。InputPin 让你指定并固定一个输入法，让 Mac 保持使用你的选择。

在菜单栏中选择要固定的输入法，开启固定即可。点击输入法名称即可直接展开选项。当系统切换到其他输入源时，InputPin 会自动恢复你指定的输入法。需要使用其他输入法时，随时暂停固定。支持微信输入法、ABC，以及系统中已启用的其他键盘输入源。

[安装方式](#安装) · [English](../README.md)

## 安装

**当前状态：**brew 源码安装已发布并通过实际安装测试。Apple 正在处理公证，DMG 与二进制 Cask 尚未公开。

安装后，菜单栏的图钉可选择目标输入法、暂停固定或设置登录启动。公证包通过验证后会发布到 [Releases](https://github.com/KaylaONeal/InputPin/releases)。

```sh
brew install kaylaoneal/tap/inputpin
```

使用项目自己的 Homebrew tap，不代表已进入 Homebrew 官方仓库。安装包包含 Apple Silicon 和 Intel 两种架构，要求 macOS 13 Ventura 及以上。二进制包将在完成 Developer ID 签名、Apple 公证与票据装订后发布。源码安装需要本机 Xcode 15+；安装后运行 `open "$(brew --prefix inputpin)/InputPin.app"` 打开应用。[测试记录与未验证项](QA.md)。

## 行为

开启固定后，手动切换到其他输入法也会被恢复。临时使用其他输入法时先暂停。固定对象是 macOS 输入源，不控制同一个输入法内部的中英文模式。

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

## Mac App Store

2026 年 10 月 11 日只读查询 Apple API，1.0.2（构建 4）的状态已为 `READY_FOR_SALE`。已配置的美国区基准价格为 0.99 美元一次性购买；各地区可用性和实际付费安装仍未验证。改进版 1.0.3（构建 5）已于 10 月 11 日提交审核，当前为等待审核，并设置审核通过后自动发布。源码及 Homebrew 源码安装继续免费。签名、上传、定价、截图和提审脚本见 [商店发布说明](APP_STORE.md)，密钥保留在维护者的 Mac 上。
