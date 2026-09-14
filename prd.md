# PRD: CountSend — Countdown Auto-Typer App

**Version:** 1.0
**Owner:** [Your Name]
**Platform:** Flutter (Android-first)
**Status:** Draft for build

---

## 1. One-line Summary

An Android app that types a live, auto-updating countdown message ("5d 9h 8m 52s to go 🎉") into the keyboard of whatever app is currently open (WhatsApp, Instagram DM, Telegram, SMS, etc.) and taps Send — without integrating with any of those apps' APIs.

---

## 2. Problem Statement

People want to send a fun, live-updating countdown message (e.g. "3 days to your birthday!") repeatedly to a friend on whatever chat app they use. Doing this manually every few seconds/minutes is tedious. There is no official API access needed if the app simply **acts like a human typing on the keyboard** — it doesn't need to know what WhatsApp or Instagram is; it only needs to know "there's a text field focused, type into it, tap the button that looks like Send."

---

## 3. Goals

- Let a user define a target date/time (e.g., a friend's birthday) and a message template.
- Auto-generate a live countdown string and insert it into a focused text field in ANY app.
- Auto-tap the Send button (best-effort, since layouts vary).
- Fully customizable message text, countdown format, and interval.
- Zero dependency on Meta/WhatsApp/Instagram/Telegram APIs — works purely via system-level input simulation.

## 4. Non-Goals (v1)

- iOS support (not feasible — see Section 9).
- Guaranteed delivery/send confirmation (we can't verify the message was received; only that we tapped something).
- Multi-recipient broadcast in one run (v1 is single target chat window open on screen).
- Working while phone is locked or app is killed by OS (Android background restrictions apply).

---

## 5. Target User

- Everyday individual users who want a lighthearted, personal touch for birthdays / anniversaries / events with a close friend or partner.

## 6. Core User Story

> "As a user, I want to open my friend's WhatsApp chat, tap 'Start Countdown' in CountSend, and have it automatically type and send an updating countdown message every N seconds until the target time hits zero — using my own custom message text."

---

## 7. How It Actually Works (Mechanism)

This is the most important section — it explains *why* this is possible without any messaging API.

### 7.1 Core mechanism: Android AccessibilityService
Android apps built for accessibility (screen readers, auto-fill helpers, "one-tap reply" apps) are granted a special permission called an **AccessibilityService**. Once the user manually enables it in Settings → Accessibility, that service can:
1. **Read the on-screen node tree** of whatever app is in the foreground (find the focused `EditText`/input box).
2. **Inject text** into that focused field programmatically (`ACTION_SET_TEXT` / `ACTION_PASTE`).
3. **Perform a click** (`ACTION_CLICK` or a simulated tap gesture) on a node it identifies as the "Send" button (usually found by content-description, icon resource-id pattern matching, or the last actionable button near the input field).

This is exactly the mechanism used by apps like "AutoText," "Auto Clicker," and accessibility-based automation tools already on the Play Store — so it's a known, allowed *category*, though heavily scrutinized (see Section 12).

### 7.2 What the app does NOT do
- Does not call WhatsApp/Instagram/Telegram APIs.
- Does not need Meta Business API keys or Instagram Graph API tokens.
- Does not know "what app" is open — it only inspects generic UI element types (input field, button).

### 7.3 Fallback mechanism (if Accessibility route is rejected or restricted)
- **Clipboard + notification prompt mode:** the app copies the current countdown string to clipboard every interval and fires a system notification "Tap to paste & send" — user does one manual tap. Lower automation, but zero special-permission risk and 100% Play-Store-safe. Recommended as the *default safe mode*, with full auto-tap as an "Advanced / Experimental" opt-in mode.

---

## 8. Feature List (v1)

| # | Feature | Description |
|---|---------|-------------|
| 1 | Target date/time picker | User picks exact date + time of the event |
| 2 | Message template editor | Free text with placeholders: `{days}`, `{hours}`, `{minutes}`, `{seconds}`, `{friend_name}` |
| 3 | Countdown interval setting | Choose refresh rate: 1s / 5s / 10s / 20s / 60s (1s may be unstable on some devices — recommend 5s default) |
| 4 | Target app field detection | Overlay crosshair / "Set target field" button — user taps once on the chat's text box to register it |
| 5 | Start / Stop / Pause automation | Foreground floating control bubble with Start, Pause, Stop |
| 6 | Auto-tap Send toggle | On/off — if off, text is only typed, user taps send manually |
| 7 | Safe Mode (clipboard) | Optional fallback described in 7.3 — not required as default since app is sideload-only, but useful if a target app's UI briefly breaks auto-tap detection |
| 8 | Countdown-complete message | Custom "final message" sent once timer hits 0 (e.g. "🎉 HAPPY BIRTHDAY!") |
| 9 | History log | Local log of what was typed/sent and at what time, for user's own review |
| 10 | Preview mode | Shows exactly what the message will look like before starting, live-updating in-app |

---

## 9. Platform Feasibility

| Platform | Feasible? | Why |
|---|---|---|
| Android | ✅ Yes | AccessibilityService API permits reading/writing UI nodes of other apps, with explicit user permission grant. |
| iOS | ❌ No | Apple's sandboxing model gives apps zero access to another app's UI tree or input fields. No public API exists for this. Even Shortcuts automation cannot type into third-party app text fields it doesn't control. |

**Recommendation:** Ship Android-only in v1. Mention iOS as "not supported due to OS restrictions" in-app rather than silently failing.

---

## 10. Technical Architecture (Flutter)

Flutter itself has no access to system-wide Accessibility APIs — this must be built as a **hybrid app**:

- **Flutter layer (Dart):** UI — date picker, template editor, settings, history, preview.
- **Native Android layer (Kotlin):** 
  - `AccessibilityService` subclass — the engine that reads/writes the foreground app's UI tree.
  - `MethodChannel` bridge — Flutter sends the current countdown string + config down to the native service; native service reports status (started/stopped/error) back up to Flutter.
  - Foreground Service + persistent notification — required by Android for any long-running background task (also required so Android doesn't kill the timer).
- **Timer logic:** Can live in Dart (via `Timer.periodic`) while app is foregrounded, but must be mirrored in native Kotlin (via a `Handler`/`WorkManager`-safe loop) for when Flutter's engine is backgrounded, since Android increasingly restricts background Dart execution.

### Suggested package structure
```
lib/
  main.dart
  screens/
    home_screen.dart
    template_editor_screen.dart
    target_picker_screen.dart
    history_screen.dart
  models/
    countdown_config.dart
    message_template.dart
  services/
    countdown_engine.dart      // computes d/h/m/s from target
    accessibility_bridge.dart  // MethodChannel wrapper
android/
  app/src/main/kotlin/.../
    CountdownAccessibilityService.kt
    MainActivity.kt
    ForegroundTimerService.kt
```

---

## 11. Message Template Spec

Template string supports placeholders, replaced at render time:

| Placeholder | Example output |
|---|---|
| `{days}` | 5 |
| `{hours}` | 9 |
| `{minutes}` | 8 |
| `{seconds}` | 52 |
| `{friend_name}` | Riya |
| `{event_name}` | Birthday |

**Example template:**
`"Hey {friend_name}! ⏳ {days}d {hours}h {minutes}m {seconds}s left for your {event_name}! 🎂"`

**Rendered:**
`"Hey Riya! ⏳ 5d 9h 8m 52s left for your Birthday! 🎂"`

If seconds-level precision is disabled (interval ≥ 10s), the `{seconds}` field simply reflects the value at that snapshot rather than ticking live — clarify this to the user in the UI ("Updates every 10s, not live-per-second").

---

## 12. Risks & Constraints (Read Before Building)

This is the section most PRDs skip — don't skip it here.

1. **Distribution: sideload-only (confirmed).** This app will NOT be published on the Play Store, so Google's Accessibility API review policy does not apply. You're free to ship full auto-tap automation as the default mode from day one, with no need for a Safe Mode gate or store-facing disclosure screens. Note this doesn't remove the *technical* Android permission dialogs (Accessibility, Overlay, Notifications) — those are OS-level, not store-level, and still show up regardless of distribution method. It also doesn't remove point 2 below (WhatsApp/Instagram ToS risk sits with the account, independent of how the app is distributed).
2. **WhatsApp/Instagram Terms of Service:** Both platforms' ToS restrict automated/bulk messaging through unofficial means. Risk is on the *account*, not the OS — repeated automated sends could trigger anti-spam detection and temporary/permanent account restriction. Recommend the app caps frequency (e.g., minimum 5–10s interval) and displays a one-time warning dialog before first use.
3. **UI-layout fragility:** Every app updates its UI over time. "Auto-tap the Send button" via node-matching is brittle — a WhatsApp UI update can silently break the Send-tap logic. Design for graceful degradation (type-only mode as fallback, alert user "couldn't find Send button, tap manually").
4. **OEM background restrictions:** Xiaomi/Oppo/Vivo/Samsung aggressively kill background services. Foreground Service + persistent notification is mandatory, and users on aggressive-OEM devices may need to manually whitelist the app in battery settings.
5. **Privacy:** AccessibilityService technically *can* read all on-screen text, not just the intended field. The PRD requires the implementation to only ever read/act on the one registered target field and never log or transmit unrelated screen content, and the privacy policy must disclose this scope explicitly.

---

## 13. Permissions Required (Android)

- `BIND_ACCESSIBILITY_SERVICE`
- `FOREGROUND_SERVICE`
- `SYSTEM_ALERT_WINDOW` (for the floating control bubble)
- `POST_NOTIFICATIONS` (Android 13+)

All must be requested with a clear, plain-language explanation screen before the system permission dialog appears (Play Store requires this for sensitive permissions).

---

## 14. Success Metrics

- Countdown accuracy: within ±1 interval-tick of real time.
- Send-tap success rate on top 3 target apps (WhatsApp, Instagram, Telegram) ≥ 90% in manual QA across 5 common device/OEM combinations.
- Crash-free session rate ≥ 99%.
- Users able to complete "set target + start countdown" flow in ≤ 60 seconds (usability test).

---

## 15. Milestones

| Phase | Deliverable | Est. Time |
|---|---|---|
| M1 | Flutter UI shell: target picker, template editor, preview | 3–4 days |
| M2 | Native AccessibilityService: read focused field + inject text | 4–5 days |
| M3 | Auto-tap Send detection logic | 3–4 days |
| M4 | (Optional) Safe Mode fallback for UI-detection failures | 1–2 days |
| M5 | Foreground service + reliability hardening across OEMs | 3–5 days |
| M6 | QA across devices, permission-flow polish, privacy policy | 2–3 days |

**Total estimate: ~3 weeks for a solo/small-team build to a stable v1.**

---

## 16. Out of Scope for v1

- iOS.
- Multi-target simultaneous broadcast.
- Scheduling multiple countdowns for different friends at once (v1 = one active countdown at a time).
- Cloud sync / backup of templates.

---

## 17. Open Decisions (flag before dev starts)

- [x] Distribution: sideload-only APK (confirmed) — no Play Store submission.
- [ ] Default interval: 5s or 10s?
- [ ] Include Safe Mode as an optional fallback, or skip it entirely for v1 and add only if auto-tap detection proves unreliable on your target devices?