# X-pense

A modern Flutter expense tracker focused on speed, clarity, and secure personal finance management.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![State Management](https://img.shields.io/badge/State-Provider-0A7EA4)](https://pub.dev/packages/provider)
[![Storage](https://img.shields.io/badge/Storage-SharedPreferences-5C6BC0)](https://pub.dev/packages/shared_preferences)

## Overview

X-pense helps you track income and expenses, visualize trends, and protect sensitive data with app lock controls. The app is built with clean separation across models, services, viewmodels, and views.

## Features

- Add, edit, and delete transactions with running balance recalculation.
- Filter transactions by type, month, year, and category.
- View analytics and spending insights.
- Import and export transactions using CSV.
- Share exported CSV files directly from the app.
- Manage custom categories and default category behavior.
- Hide or reveal balance data on demand.
- Enable app lock with passcode and biometric authentication support.
- Light and dark theme support with smooth transitions.

## Tech Stack

- Flutter and Dart
- Provider for state management
- Shared Preferences for local persistence
- local_auth for biometric authentication
- fl_chart for analytics visualizations
- csv, file_picker, path_provider, and share_plus for import/export workflows

## Project Structure

<details>
<summary>Expand structure</summary>

```text
lib/
	main.dart
	app_theme.dart
	models/
	services/
		storage_service.dart
		csv_service.dart
	viewmodels/
		transaction_viewmodel.dart
		theme_viewmodel.dart
		app_lock_viewmodel.dart
	views/
		home/
		transaction/
		analytics/
		lock/
		widgets/
```

</details>

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK (included with Flutter)
- Android Studio or VS Code with Flutter extensions
- A connected device or emulator

### Installation

```bash
git clone https://github.com/<your-username>/X-pense.git
cd X-pense
flutter pub get
flutter run
```

## Configuration Notes

- App data is stored locally on-device.
- Biometric unlock availability depends on device hardware and user enrollment.
- CSV imports expect the export-compatible column format.

## Build Commands

```bash
# Debug run
flutter run

# Analyze code
flutter analyze

# Run tests
flutter test

# Android release APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

## Screenshots

Add your screenshots to a folder such as `assets/screenshots/` and reference them here:

```md
![Home](assets/screenshots/home.png)
![Analytics](assets/screenshots/analytics.png)
![Transactions](assets/screenshots/transactions.png)
```

Tip: Use image widths around 1080 px for clear rendering on GitHub across desktop and mobile.

## Contribution

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Commit your changes.
4. Open a pull request with a clear description.

## License

No license file is currently included. Add a `LICENSE` file if you plan to open-source with specific terms.
