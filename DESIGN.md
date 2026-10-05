# InputPin design system

## Product and quality goal

InputPin is a small native macOS utility for people who want a stable input source across apps. The first decision is always: which source is pinned, and is pinning active? Awwwards, Webby and FWA are aspirational references for craft, originality and coherence, not certifications or claims of awards.

## Direction

Quiet, translucent, native. A 252-point nonactivating NSPanel uses a clear window, a very light `NSVisualEffectView` material, original keycap/pin artwork, system typography and SF Symbols in UI controls. Nothing imitates browser chrome. No decorative animation, third-party fonts, gradients behind text, onboarding account, or permission wall.

The original keycap mark and restrained editorial presentation add identity. Standard controls carry interaction. System materials adapt to the actual desktop, unlike a fixed transparent image.

## Tokens

- Typeface: system San Francisco; rounded semibold wordmark, standard UI body.
- Type sizes: wordmark 15 pt; input-source name 14; control titles 12; supporting copy 11.
- Spacing: 4 pt base; outer padding 12; section gap 10; row gap 8.
- Panel: 252 pt wide, content-driven height; a borderless transparent source menu, two single-line settings rows, quiet footer. Supporting setting copy is available in tooltips and accessibility hints.
- Corners: 16 pt panel outline; 8 pt mark.
- Color: semantic primary/secondary foregrounds, native accent for pinned, orange for waiting, neutral for pause. Text and icons both communicate state.
- Material: clear NSPanel and hosting layer. `.popover`, `.behindWindow`, active, at 8% effect opacity over a 4% semantic tint. Foreground text and native controls remain fully opaque. Reduced transparency or increased contrast uses an opaque `.windowBackground`.
- Motion: 180 ms ease-in-out for state transitions; disabled with Reduce Motion. Panel appearance is immediate.

## Interaction and accessibility

A borderless Menu containing a native Picker, plus native Toggle and buttons retain keyboard navigation and VoiceOver semantics. Every icon-only control has an accessibility label. Supporting copy wraps; source labels are displayed by the native picker. The panel reports the actual current source separately from the pinned target. Pending restoration is never labeled pinned.

The panel closes on outside mouse clicks, loss of key focus or Escape. A temporary mouse-only event monitor exists only while it is open; it never observes global keyboard events. Opening the app again reveals the panel.

Pinning is on by default and can be paused with one toggle. Manual input-source switching is also restored while pinned; the README states this explicitly. Login startup is opt-in. Missing targets, secure input and rejected switches explain the next action.

## Review gates

Before publishing UI changes, verify light and dark mode, keyboard-only interaction, VoiceOver labels, long source names, reduced transparency, reduced motion, narrow screens and localization. Do not claim verification from source inspection alone. Record completed and unverified checks in release QA notes. Screenshots must show the actual app, with personal background content excluded.

Reference: [Apple materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).
