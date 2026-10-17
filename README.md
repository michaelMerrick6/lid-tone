# LidTone

**Give your MacBook a satisfying closing sound.**

A tiny native macOS menu bar app: close your laptop and hear a wooden door, a soft latch, a book closing, or a space hatch. Pick a favorite, shuffle the built-ins, or bring a short sound of your own.

![LidTone settings](docs/lidtone.png)

## Get started

Requires a MacBook with **macOS 13 Ventura or later**. Apple silicon and Intel builds are supported. You need Xcode or its Swift command line tools to build from source; there are no external package dependencies.

```sh
git clone https://github.com/michaelMerrick6/lid-tone.git
cd lid-tone
./scripts/build-app.sh
open dist/LidTone.app
```

The first launch opens settings. After that, use the **laptop icon in the menu bar** to open settings, preview a sound, pause playback, or quit. Keep the app running, choose **Wooden door**, and close your lid. Closing the settings window leaves the menu bar app running.

For both chip families in one app:

```sh
./scripts/build-app.sh --universal
```

The script produces `dist/LidTone.app` and `dist/LidTone-macOS.zip`, checks all four audio resources, and verifies the app's signature. Local builds use an ad-hoc signature. Downloaded release builds are **not Apple-notarized**; macOS may restrict opening them. Building locally is the recommended route until a Developer ID distribution is available.

## Make it yours

- **Four original sounds:** wooden door, soft latch, book close, and space hatch.
- **Preview buttons:** hear each option before choosing it.
- **Volume:** independent app volume, still subject to your Mac's output volume and mute state.
- **Shuffle:** choose a random built-in on each close.
- **Custom audio:** import WAV, AIFF, M4A, or MP3, up to **0.85 seconds / 2 MB**. Imported audio is copied locally so moving the original file won't break it.
- **Start at login:** an opt-in macOS login item. Leave it off if you only want to run LidTone occasionally. Move the app to a stable location, such as Applications, before enabling it.

Audio uses the **currently selected output**. If headphones or Bluetooth audio are connected, the sound goes there; Bluetooth latency can make the short playback window less reliable.

## How lid close works

LidTone subscribes to IOKit's `kIOPMMessageClamshellStateChange` on `IOPMrootDomain`. The notification arrives before a lid-triggered sleep and carries the actual closed/open state. This also handles normal closed-lid use with an external display, where closing the lid may not put the Mac to sleep.

Audio is preloaded. An open → closed transition starts one sound; duplicate notifications are ignored. Ordinary idle sleep or Apple-menu sleep with the lid open stays silent. Wake synchronizes state without replaying the previous close.

When macOS delivers `kIOMessageSystemWillSleep`, LidTone acknowledges the event after any remaining lid audio, with a **0.95-second maximum scheduled delay**. A separate watchdog queue acknowledges even if the audio queue stalls. Idle sleep is acknowledged immediately. The app never vetoes sleep, changes power settings, installs a privileged helper, or polls the lid sensor.

**This is best-effort audio before sleep, not a guarantee of playback while asleep.** Hardware and macOS may suspend an audio device before the sound completes. The scheduler itself can also be delayed under load. Short local clips and built-in speakers give it the best chance. Physical lid-close behavior needs checking on each Mac model; unit tests cannot reproduce the hardware's sleep timing.

Read [the implementation notes](docs/architecture.md) and [hardware test checklist](docs/testing.md). Apple's [sleep/wake notification guide](https://developer.apple.com/library/archive/qa/qa1340/_index.html) explains the power callback contract. The clamshell message and keys are defined in the macOS SDK's `IOKit/pwr_mgt/IOPM.h`.

## Development

```sh
swift test
swift run LidTone --check
./scripts/build-app.sh
```

The tests cover state transitions, duplicate suppression, startup/wake behavior, disabled mode, invalid durations, concurrent acknowledgement, and the watchdog. `--check` decodes every bundled audio file without playing audio or changing preferences. CI runs the tests and packages a universal app.

The original sound generator uses only Python's standard library:

```sh
python3 scripts/generate_sounds.py
```

It combines damped resonances, shaped noise, and short synthesized creaks. These are synthesized Foley, not recordings of real doors. The generator and WAV files share this repository's MIT license. Custom audio remains yours and is never uploaded.

## Project layout

```text
Sources/LidTone/          SwiftUI settings, menu bar app, audio, IOKit monitor
Sources/LidToneCore/      Testable lid transition and sleep acknowledgement logic
Sources/PowerBridge/     Clang bridge for SDK macros Swift cannot import
Tests/                   Behavior and concurrency tests
scripts/                 App packaging, icon drawing, reproducible sound generation
packaging/               App metadata
```

## Privacy and removal

No accounts, network requests, analytics, microphone access, or accessibility permission are needed. Preferences stay in macOS UserDefaults for `com.michaelmerrick.LidTone`; imported clips live in `~/Library/Application Support/LidTone/CustomSounds`.

To remove it: turn off **Start at login**, quit LidTone, and delete the app. You can remove that Application Support folder and the app's preferences if you also want to clear your choices.

Built by Michael Merrick with AI-assisted implementation. MIT licensed.
