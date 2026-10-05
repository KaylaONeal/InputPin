# InputPin design system

## Product and quality goal

InputPin is a small native macOS utility for people who want a stable input source across apps. The first decision is always: which source is pinned, and is pinning active? Awwwards, Webby and FWA are aspirational references for craft, originality and coherence, not certifications or claims of awards.

## Direction

Quiet, translucent, native. A 360-point popover uses AppKit's standard `NSVisualEffectView` popover material, a continuous rounded inset, original keycap/pin artwork, system typography and SF Symbols in UI controls. Nothing imitates browser chrome. No decorative animation, third-party fonts, gradients behind text, onboarding account, or permission wall.

The original keycap mark and restrained editorial presentation add identity. Standard controls carry interaction. System materials adapt to the actual desktop, unlike a fixed transparent image.

## Tokens

- Typeface: system San Francisco; rounded semibold wordmark, standard UI body.
- Type sizes: wordmark 20 pt; control titles 13; supporting copy 11–12; section labels 10 with 1.2 pt tracking.
- Spacing: 4 pt base; outer padding 24; section gap 22; inset padding 18; row gap 18.
- Panel: 360 pt wide, content-driven height; one main target card, two settings rows, quiet footer.
- Corners: native outer popover; target card 16 pt; mark 11 pt.
- Color: semantic primary/secondary foregrounds, native accent for pinned, orange for waiting, neutral for pause. Text and icons both communicate state.
- Material: `.popover`, `.behindWindow`, active. Reduced transparency uses `.windowBackground`.
- Motion: 180 ms ease-in-out for state transitions; disabled with Reduce Motion. Popover animation follows the same system preference.

## Interaction and accessibility

Native Picker, Toggle, Menu and buttons retain keyboard navigation and VoiceOver semantics. Every icon-only control has an accessibility label. Supporting copy wraps; source labels are displayed by the native picker. The panel reports the actual current source separately from the pinned target. Pending restoration is never labeled pinned.

Pinning is on by default and can be paused with one toggle. Manual input-source switching is also restored while pinned; the README states this explicitly. Login startup is opt-in. Missing targets, secure input and rejected switches explain the next action.

## Review gates

Before publishing UI changes, verify light and dark mode, keyboard-only interaction, VoiceOver labels, long source names, reduced transparency, reduced motion, narrow screens and localization. Do not claim verification from source inspection alone. Record completed and unverified checks in release QA notes. Screenshots must show the actual app, with personal background content excluded.

Reference: [Apple materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).
