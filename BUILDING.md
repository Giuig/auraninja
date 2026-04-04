# Building Auraninja

## Prerequisites

- Flutter SDK 3.41.5 (see `flutter-version` file)
- Android SDK with command-line tools
- JDK 17

## Build

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

Output APKs will be in:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## CI/CD

This project uses a shared GitHub workflow from [ninja_material](https://github.com/Giuig/ninja_material) for building releases.
