# QR App — Flutter QR Scanner & Generator

A beautiful, professional QR code scanner and generator built with Flutter.

## ✨ Features

-
-
-

---

## 📁 Project Structure

```
lib/
├── main.dart                     # App entry point & theme
├── screens/
│   ├── home_screen.dart          # Bottom nav shell
│   ├── scanner_screen.dart       # Camera + scan overlay + result sheet
│   ├── generator_screen.dart     # QR code generator
│   └── history_screen.dart       # Scan history list
├── models/
│   └── scan_result_model.dart    # Data model for scan history
└── services/
    └── history_service.dart      # SharedPreferences persistence
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0
- Android Studio / Vscode

### Run the app

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build for release (Android)
flutter build apk --release


```

---

## 🔐 Permissions

### Android
- `CAMERA` — For QR scanning
- `FLASHLIGHT` — For torch toggle
- `INTERNET` — For launching URLs

---

*Built with Flutter 💙*
