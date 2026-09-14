# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-09-15

### Added
- Native Android `CountdownAccessibilityService` with automated chat input injection for WhatsApp, Instagram Direct, and Telegram.
- High-precision draggable reticle overlay with real-time screen coordinate HUD (`liveX, liveY`) for custom Send button calibration.
- Micro-stroke hardware touch gesture dispatcher (100ms path) to ensure compatibility across OEM digitizers (Vivo, iQOO, Samsung, Xiaomi).
- Dynamic vertical alignment matching input field bounds during soft keyboard state transitions.
- Permissions guide screen for step-by-step Accessibility and System Alert Window setup.
- Execution history tracking and real-time floating timer overlay.

## [0.1.0] - 2026-09-15

### Added
- Core countdown engine supporting dynamic intervals (1s, 5s, 10s, 30s, 60s).
- Template editor with preview token interpolation (`{days}`, `{hours}`, `{minutes}`, `{seconds}`, `{event_name}`).
- Compact, professional Tickr design system (`#FAFAF9` light / `#121212` dark, `#1A5F4C` teal accent, flat 1px borders, Space Grotesk / Inter typography).
- Local configuration persistence using `shared_preferences`.
- Project documentation: README, MIT License, CONTRIBUTING, CODE_OF_CONDUCT, issue/PR templates, and GitHub Actions CI.
