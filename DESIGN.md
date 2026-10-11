# InputPin design system

## Product and quality goal

InputPin pins the input method the user specifies, addressing unwanted automatic input-source switching on a Mac. Automatic restoration explains how pinning works; it is not the headline product positioning. The first decision is always: which source is pinned, and is pinning active? Awwwards, Webby and FWA are aspirational references for craft, originality and coherence, not certifications or claims of awards.

## Direction

Quiet, translucent, native. A 252-point nonactivating NSPanel uses a clear window, a very light `NSVisualEffectView` material, original keycap/pin artwork, system typography and SF Symbols in UI controls. Nothing imitates browser chrome. No decorative animation, third-party fonts, gradients behind text, onboarding account, or permission wall.

The original keycap mark and restrained editorial presentation add identity. Standard controls carry interaction. System materials adapt to the actual desktop, unlike a fixed transparent image.

## Tokens

- Typeface: system San Francisco; rounded semibold wordmark, standard UI body.
- Type sizes: wordmark 15 pt; input-source name 14; control titles 12; supporting copy 11.
- Spacing: 4 pt base; outer padding 12; section gap 10; row gap 8.
- Panel: 252 pt wide, content-driven height; a borderless source menu, two settings rows, quiet footer. Launch at login has an explicit On, Off or Pending approval label. Status labels wrap, and the current-source footer allows two lines. The native source menu truncates long names; complete names are available in tooltips and accessibility values.
- Corners: 16 pt panel outline; 8 pt mark.
- Color: semantic primary/secondary foregrounds. Status text uses primary for legibility; its icon uses native accent for pinned, orange for waiting and neutral for pause. Text and icons both communicate state.
- Material: clear NSPanel and hosting layer. `.popover`, `.behindWindow`, active, at full system material strength so desktop content cannot overwhelm text. Foreground text and native controls remain fully opaque. Reduced transparency or increased contrast uses an opaque `.windowBackground`.
- Motion: 180 ms ease-in-out for state transitions; disabled with Reduce Motion. Panel appearance is immediate.

## Interaction and accessibility

A borderless Menu containing an explicitly inline native Picker, plus native Toggle and buttons retain keyboard navigation and VoiceOver semantics. Every icon-only control has an accessibility label. Supporting copy wraps; source labels are displayed by the native picker. The panel reports the actual current source separately from the pinned target. Pending restoration is never labeled pinned.

The panel closes on outside mouse clicks, loss of key focus or Escape. A temporary mouse-only event monitor exists only while it is open; it never observes global keyboard events. Opening the app again reveals the panel.

Pinning is on by default and can be paused with one toggle. Manual input-source switching is also restored while pinned; the README states this explicitly. Login startup is opt-in. Missing targets, secure input and rejected switches explain the next action.

The first chosen target is saved before monitoring starts. A disabled or removed source keeps its last known name, so people can identify what needs attention. Routine fallback checks do not redraw unchanged controls or reload the login service; pausing, sleep and inactive sessions suspend fallback polling. Source availability is refreshed on enabled-source notifications and when the panel opens, and revalidated before selection. Sources are refreshed after observer registration; unavailable targets are rechecked every five seconds so missed system notifications cannot prevent recovery.

## Review gates

Before publishing UI changes, verify light and dark mode, keyboard-only interaction, VoiceOver labels, long source names, reduced transparency, reduced motion, narrow screens and localization. Do not claim verification from source inspection alone. Record completed and unverified checks in release QA notes. Screenshots must show the actual app, with personal background content excluded.

Reference: [Apple materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

## Store positioning and artwork

The listing names are “InputPin: Input Method Lock” and “InputPin — 输入法固定”. Subtitles and main screenshot headlines describe pinning a chosen input method. Explain restoration in the body copy, followed by the two scope limits: manual input-source changes are restored while pinned, and an input method’s internal Chinese/English mode is outside InputPin’s control.

Three ordered images per locale, using 2560 × 1600 native exports or supported supplied artwork, show the real native panel at a readable scale: chosen input method with pinning on; choose and enable pinning; pause with a different current source. Use a simple light blue background, a restrained illustrative Mac display frame and short direct instructions. Keep the selected name, actual state and toggle legible. Export RGB images from controlled presentation fixtures; do not include personal desktop content or imply the display frame is a real device capture.
