# Theory Studies (לימודי תיאוריה)

A study app for the Israeli driving-theory exam, built from the official
Ministry of Transport question bank. Practice by topic, random practice,
weak-question review, and a full timed mock exam — with Hebrew text-to-speech
and voice answering.

Runs on **Windows**, **Linux**, and **Android** — same Flutter codebase, one
folder per platform.

| Folder | Platform | Output |
| --- | --- | --- |
| `theory_desktop/` | Windows | `.exe` + Inno Setup installer |
| `theory_linux/` | Linux (Ubuntu/Mint) | AppImage |
| `theory_android/` | Android | `.apk` |

## Features

- Full official question bank (1,800+ questions), per licence (B / A / C1 / D)
- Practice by category, 50-question rotating random practice, weak-question review
- Timed mock exam (30 questions / 40 min / pass at 26) with a question navigator
- Official traffic-sign images bundled offline
- Hebrew text-to-speech with an extensive pronunciation-fix list
  - Desktop: Microsoft Edge neural voice (`he-IL-AvriNeural`) via a local Python sidecar
  - Android: the phone's built-in Hebrew TTS
- Voice answering (say the answer number) via Groq Whisper
- Light / dark theme, adjustable speech rate, progress tracking

## Building

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable).

Voice answering uses the Groq Whisper API. The key is **not** stored in the
source — pass it at build time with `--dart-define`. Get a free key at
<https://console.groq.com>. Without a key the app still works; only voice
answering is disabled.

### Windows (`theory_desktop/`)

```bash
cd theory_desktop
flutter build windows --release --dart-define=GROQ_API_KEY=YOUR_KEY
```

The neural voice also needs Python with `edge-tts` + `aiohttp` (the packaged
installer bundles an embedded Python so end users need nothing).

### Android (`theory_android/`)

```bash
cd theory_android
flutter build apk --release --dart-define=GROQ_API_KEY=YOUR_KEY
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

### Linux (`theory_linux/`)

Must be built **on** a Linux machine (Flutter cannot cross-compile desktop
Linux from Windows). A helper script installs dependencies, builds, and
packages an AppImage:

```bash
cd theory_linux
chmod +x build_linux.sh
./build_linux.sh
```

To include the key, add `--dart-define` to the `flutter build linux` line in
`build_linux.sh`.

## Releases & updates

Built binaries are published under **[Releases](../../releases)** — download
the installer/APK/AppImage for your platform there. The app checks this repo's
latest release and notifies you when a newer version is available.

## Data

Questions come from the Israeli Ministry of Transport public theory-exam data.
`theoryexamhe-data.xml` is the raw source; `questions_normalized.json` is the
parsed form bundled into each app.

## Note on the API key

The Groq key is a client-side key compiled into the app binary. If you
distribute builds publicly and want to keep the key private, rotate it in the
Groq console and rebuild.
