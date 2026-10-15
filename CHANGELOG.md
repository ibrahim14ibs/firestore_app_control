# Changelog

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/).

## 1.1.1

### Added
- **Diagnostic Runtime Logging (`AppControlLogger`)**:
  - Added structured diagnostic console logging for Firestore document fetch/snapshots, version evaluation, state transitions, and store launch events.
  - Added `enableLogging` and `logHandler` parameters to `FirestoreAppControl`, `AppControlCubit`, and `FirestoreConfigDataSourceImpl`.
  - Added `AppControlLogger.enableLogging` global switch and `AppControlLogger.customHandler` for custom sinks (e.g., Sentry, Firebase Crashlytics).
  - Added typed log levels (`AppControlLogLevel.debug`, `info`, `warning`, `error`).
- **Enhanced Builder Display Modes**:
  - `forceUpdateBuilder` and `maintenanceBuilder` now respect `AppControlDisplayMode.dialog` (rendering inside the modal dialog overlay while keeping the host application mounted in the background).
  - `optionalUpdateBuilder` now uses `OptionalUpdateWidgetBuilder = Widget Function(...)`, enabling custom widgets to render directly in the in-stack overlay while supporting all `OptionalUpdateDisplayMode` styles (`dialog`, `snackBar`, `fullScreen`) and `optionalUpdateDelay`.
- **Directionality Resilience**:
  - Added automatic fallback `Directionality` handling in `FirestoreAppControl` so the widget tree never throws `No Directionality widget found` when wrapped outside `MaterialApp`.
- **Comprehensive Interactive Showcase (`example/`)**:
  - Added full interactive example connected to Firebase via FlutterFire CLI with live Firestore presets pusher, app version simulator, display mode switcher, custom builder toggles, and live diagnostics log console.

## 1.1.0

### Added
- **Display Modes (`AppControlDisplayMode`)**:
  - Added support for switching between full-screen view (`AppControlDisplayMode.fullScreen`) and non-dismissible modal dialog (`AppControlDisplayMode.dialog`) for maintenance and force update modes.
- **Optional Update Modes (`OptionalUpdateDisplayMode`)**:
  - Added support for displaying optional updates as a modal dialog (`OptionalUpdateDisplayMode.dialog`), floating bottom snackbar (`OptionalUpdateDisplayMode.snackBar`), or full-screen view (`OptionalUpdateDisplayMode.fullScreen`).
- **Security & Pop Protection (`PopScope`)**:
  - Enforced `PopScope(canPop: false)` across all blocking modes (maintenance and force update, both full-screen, dialog, and custom builder variants) to prevent back navigation and exit gestures on Android and iOS.
- **New UI Components**:
  - `DefaultMaintenanceDialog`: Non-dismissible dialog for maintenance mode.
  - `DefaultForceUpdateDialog`: Non-dismissible dialog with store launch and version badges for force updates.
  - `DefaultOptionalUpdateSnackBar`: In-stack floating Material 3 banner/snackbar for non-intrusive update prompts.
  - `DefaultOptionalUpdateView`: Full-screen optional update view with a continue/skip option.

## 1.0.0

### Added
- Initial release.
- Real-time application control via Firebase Firestore (`Maintenance Mode`, `Force Update`, `Optional Update`).
- Offline cache resilience and fallback defaults.
- Root stack overlay optional update dialog.
- Bilingual (Arabic/English) support with automatic RTL/LTR detection.
