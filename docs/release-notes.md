InputPin keeps your chosen macOS input source in place, with a small native translucent popover.

- Select any enabled keyboard input source; WeType is preferred when installed.
- Pause or resume with one switch, and optionally launch at login.
- Secure input and inactive sessions take priority.
- English and Simplified Chinese; light/dark and system accessibility preferences.
- No key capture, accounts, analytics, network access, or Accessibility permission.

## Install

Download **InputPin-1.0.0-universal.dmg**, open it, drag InputPin into Applications and launch it. The app and installer are Developer ID signed, Apple notarized and stapled. Apple Silicon and Intel binaries are included; macOS 13 Ventura or later is required.

```sh
brew install --cask kaylaoneal/tap/inputpin
```

A ZIP and SHA256SUMS are available for users who prefer archives and independent verification. While pinning is enabled, intentional source changes are also restored: pause first to use another source. InputPin does not lock WeType's internal Chinese/English mode and does not run on the system login screen.

See [release QA](https://github.com/KaylaONeal/InputPin/blob/main/docs/QA.md) for tested cases and compatibility limits.
