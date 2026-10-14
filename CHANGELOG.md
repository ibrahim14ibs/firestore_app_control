# Changelog

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/).

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
