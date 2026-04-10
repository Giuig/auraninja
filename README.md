# auraninja

Ambient sound and focus app built with Flutter. Mix nature sounds, binaural beats, white noise, and internet radio stations to create your perfect sound environment.


## Features

- **Nature Sounds** — rain, forest, fire, ocean, and more, mixable simultaneously
- **Binaural Beats** — focus, relaxation, and sleep frequencies
- **White / Brown / Pink Noise** — classic noise profiles for concentration
- **Internet Radio** — search and add any station via the Radio Browser directory
- **Custom Stations** — add radio streams by URL or search by name
- **Station Logos** — automatic artwork fetched from Radio Browser
- **Volume Per Sound** — independent volume slider on every card
- **Playback-aware Visualizer** — animated ribbons that react to what is playing
- **Lock Screen Controls** — media notification with track metadata
- **Material You** — dynamic color theming, light and dark mode
- **Google-Free** — no Google Play Services required, fully FOSS

## Try it Online

**[Launch auraninja](https://giuig.github.io/auraninja/)**


## Download

Get the latest APK from the [Releases page](https://github.com/Giuig/auraninja/releases/latest).

| APK | Notes |
|---|---|
| `auraninja-X.X.X.apk` | Universal — works on any device |
| `auraninja-X.X.X-arm64-v8a.apk` | Most modern Android phones |
| `auraninja-X.X.X-armeabi-v7a.apk` | Older 32-bit devices |
| `auraninja-X.X.X-x86_64.apk` | Emulators |

### Install via Obtainium

Add `https://github.com/Giuig/auraninja` in [Obtainium](https://github.com/ImranR98/Obtainium) to receive automatic updates. Use the APK filter `auraninja-\d` to select the universal build.


### Install via IzzyOnDroid

[<img src="https://gitlab.com/IzzyOnDroid/repo/-/raw/master/assets/IzzyOnDroid.png" alt="Get it on IzzyOnDroid" height="80">](https://apt.izzysoft.de/fdroid/index/apk/io.github.giuig.auraninja)


## Support

I make FOSS apps in my free time, a coffee would help me keep them going! ☕

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/giuig)

## Build

```bash
# Prerequisites: Flutter SDK 3.41.5+
flutter pub get
flutter build apk --release --split-per-abi --no-tree-shake-icons --split-debug-info=build/debug-info
flutter build web --base-href=/auraninja/ --release
```

## Part of the ninja apps family

| App | Description |
|---|---|
| [tvninja](https://github.com/Giuig/tvninja) | IPTV / M3U8 player |
| [decisioninja](https://github.com/Giuig/decisioninja) | Decision-making app - dice, coin flip, spinner |
| [ninja_material](https://github.com/Giuig/ninja_material) | Shared Flutter library powering all ninja apps |

## License

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](./LICENSE)

This project is licensed under the [GNU General Public License v3.0](./LICENSE).
