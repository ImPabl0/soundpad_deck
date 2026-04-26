# Soundpad Deck

Soundpad Deck is a two-part project to remotely control Soundpad from your local network.

- C++ server (Windows tray app) exposing an HTTP API on port 1209
- Flutter client app to discover the server, list sounds, play/pause/stop, upload, and delete audio

## Repository Structure

- api/: C++ HTTP server and tray integration with Soundpad
- app/: Flutter client (Android, iOS, Windows, Linux, macOS, Web)
- build_api.bat: helper script to build the Windows server in Release mode

## Features

- Automatic API discovery in local network
- Audio grid with playback controls
- Drag-and-drop floating media control widget in the app
- Audio upload to Soundpad Deck storage
- Audio delete support
- Custom app icon generated from ico.ico

## Requirements

### Server

- Windows 10/11
- CMake 3.20+
- MSVC Build Tools (Visual Studio C++ toolchain)
- Installed Soundpad (named pipe: \\.\pipe\sp_remote_control)

### Flutter App

- Flutter SDK (stable)
- Dart SDK (bundled with Flutter)
- Android SDK/NDK if building Android

## Local Build

### Build server (Windows)

```powershell
cmake -S . -B build
cmake --build build --config Release --target soundpad_deck
```

Expected output:

- build/Release/soundpad_deck.exe

You can also use:

```powershell
./build_api.bat
```

### Build Flutter app (Android release)

```powershell
cd app
flutter pub get
flutter build apk --release
```

Expected output:

- app/build/app/outputs/flutter-apk/app-release.apk

## Internationalization

The Flutter app is localized with Flutter l10n and currently supports:

- English (en)
- Portuguese (pt)

Localization files:

- app/lib/l10n/app_en.arb
- app/lib/l10n/app_pt.arb

## GitHub Release Workflow

This repository includes a GitHub Actions workflow that:

1. Builds the Windows C++ server
2. Builds the Flutter Android APK
3. Creates/updates a GitHub Release and uploads artifacts

Workflow location:

- .github/workflows/release.yml

Trigger release by creating a tag like:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

## API Endpoints

Main endpoints exposed by the server:

- GET /health
- GET /list
- GET|POST /play
- GET|POST /pause
- GET|POST /stop
- GET|POST /delete
- POST /upload

## Notes

- The server must be running on Windows where Soundpad is installed.
- The mobile app and server machine must be reachable on the same network.
