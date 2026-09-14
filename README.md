# CountSend

> Automated live countdown messages injected directly into mobile chats via Android Accessibility.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/Platform-Android%208.0%2B-brightgreen.svg)](https://www.android.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## Screenshots

| Home & Countdown Hero | Template Editor | Floating Calibration & Active Typer |
| :---: | :---: | :---: |
| ![Home Screen](docs/screenshots/home.png) | ![Template Editor](docs/screenshots/template_editor.png) | ![Active Countdown Typer](docs/screenshots/countdown_active.png) |

---

## Features

- **Live Countdown Engine**: Precision real-time computation of remaining days, hours, minutes, and seconds down to zero.
- **Direct Chat Input Injection**: Automatically inspects, targets, and sets live countdown text inside third-party chat input fields (WhatsApp, Instagram, Telegram) without requiring private developer APIs.
- **Hardware Touch Gesture Dispatch**: Automatically simulates human tap gestures directly on the Send button using Android's Accessibility touch dispatch.
- **Floating Overlay Controller**: Always-accessible draggable floating pill to start, pause, or stop the countdown auto-typer over active chat threads.
- **Draggable Target Reticle Calibration**: Visual on-screen crosshair to pin and calibrate custom (X, Y) touch coordinates for devices with non-standard chat layouts.
- **Safe Mode**: Test updates and copy live countdown strings to clipboard without injecting into active inputs or auto-tapping.
- **Audit & Activity Log**: Monospace timestamped log recording all dispatch events, field detections, and gesture executions.
- **Refined Design System**: Restrained deep teal accent (`#1A5F4C`), flat 1px neutral borders, clear typographic scale, and seamless Light / Dark theme support.

---

## How It Works

CountSend uses Android's native **AccessibilityService** API (`CountdownAccessibilityService`):
1. When activated, the Accessibility Service monitors window state and accessibility node hierarchies.
2. It locates editable text input fields (`EditText`, `android.widget.TextView`) within active chat apps.
3. It injects the rendered countdown string into the focused field using `AccessibilityNodeInfo.ACTION_SET_TEXT`.
4. It detects the Send button (or uses calibrated custom screen coordinates) and dispatches a hardware-level touch tap via `AccessibilityService.dispatchGesture`.

**No root access, official chat bot tokens, or private APIs required.** Everything runs entirely on-device through standard Android accessibility mechanisms.

---

## Requirements

- **Flutter SDK**: `>=3.19.0`
- **Dart SDK**: `>=3.3.0 <4.0.0`
- **Android OS**: Android 8.0 Oreo (API Level 26) or higher
- **Target Android SDK**: API Level 34 (Android 14)
- **Java Development Kit (JDK)**: OpenJDK 17

---

## Installation & Build

1. Clone the repository:
   ```bash
   git clone https://github.com/kachakaran6/new_app.git
   cd new_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Build the debug or release APK:
   ```bash
   # Debug APK
   flutter build apk --debug

   # Release APK
   flutter build apk --release
   ```
   The generated APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## Usage Walkthrough

1. **Install and Open CountSend**: Launch the app on your Android device.
2. **Grant Permissions**:
   - Tap the settings icon (`Tune`) or the status line to open the **Permissions Guide**.
   - Enable **Accessibility Service** for CountSend in your device settings.
   - Grant **Draw over other apps** (Overlay) permission.
3. **Configure Your Countdown**:
   - Set the target date/time, friend's name, and event name.
   - Tap **Edit** on the Message Template card to customize your template with tags like `{days}`, `{hours}`, `{minutes}`, `{seconds}`, and `{friend_name}`.
   - Choose an interval rate (1s, 5s, 10s, 30s, or 60s).
4. **Calibrate Send Button (Optional)**:
   - If your chat application uses a non-standard Send button layout, tap **Pin Send** on the floating overlay bubble to drag the target crosshair directly over the Send button.
5. **Start Auto-Typing**:
   - Open your desired chat thread (e.g., WhatsApp or Instagram DM).
   - Tap into the text message box.
   - Tap **Start** on CountSend or the floating overlay to begin injecting live countdown messages!

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on code style, branch naming, Conventional Commits, and our pull request process.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Disclaimer

This software automates UI interactions via Android's Accessibility API. It is intended strictly for personal entertainment, celebrations, and countdown reminders. Users are solely responsible for complying with the Terms of Service and Anti-Spam policies of any third-party messaging platforms (including WhatsApp, Instagram, Telegram, and others) used in conjunction with CountSend. The developers assume no liability for account restrictions, suspensions, or misuse resulting from this tool.
