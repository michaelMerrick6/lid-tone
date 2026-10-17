# LidTone

**Sound that moves with your MacBook screen.**

Tilt the screen forward or backward and hear a creaking wooden hinge or a lightsaber-style hum and swoosh. Move faster and the sound responds. Hold still and it fades to silence.

![LidTone live hinge settings](docs/lidtone.png)

## Run it

Requires **macOS 13+** and a MacBook that exposes Apple's HID hinge-angle sensor. Sensor access, live angle changes, and sound following physical screen movement were verified on an **M4 MacBook Air (Mac16,13)** with user confirmation. Compatibility depends on the sensor, not just the chip: some M1/M2 and older models do not expose it. The app reports an unavailable sensor honestly; the preview still works.

Build locally with Xcode or the Swift command line tools. No external dependencies:

```sh
git clone https://github.com/michaelMerrick6/lid-tone.git
cd lid-tone
./scripts/build-app.sh
open dist/LidTone.app
```

Choose **Creaking hinge** or **Lightsaber**, leave motion sounds enabled, and gently adjust the screen within its normal hinge range. The live angle should change. **Preview motion** demonstrates the selected sound using a simulated tilt; the displayed angle always comes from the actual sensor.

The laptop menu bar icon opens settings, previews motion, pauses sounds, or quits. Closing settings leaves the app running. Start at login is optional and uses macOS Login Items. Move the app to a stable location before enabling that option.

With full Xcode installed, build a universal app for Intel and Apple silicon:

```sh
./scripts/build-app.sh --universal
```

Outputs: `dist/LidTone.app` and `dist/LidTone-macOS.zip`. Local and beta builds are **ad-hoc signed, not Apple-notarized**. macOS may restrict downloaded builds; building locally is recommended until Developer ID distribution is available.

## Motion, not a close trigger

The app reads the **actual hinge angle at 30 Hz**, rather than waiting for a lid-close or sleep notification. Angle change produces signed angular velocity; speed sets intensity, angle and direction shape the pitch, and a short envelope prevents clicks. Both effects are generated continuously with original DSP. There are no movie sound samples or sound files to download.

The sensor may quantize readings to whole degrees. Small or very slow tilts can therefore feel stepped. **Response** adjusts the strength of the motion response. It cannot add precision the hardware does not provide.

Audio plays through your current output, subject to system mute/volume. Built-in speakers offer lower latency than Bluetooth. Audio pauses after motion stops and suspends during sleep. There is no audio while the Mac is asleep, no delayed sleep acknowledgement, and no power-setting changes.

## Under the hood

- `HingeSensor`: narrow IOHID matching for Apple vendor `0x05AC`, sensor page `0x20`, orientation usage `0x8A`; reads report 1 and validates its ID, length, and degree range.
- `MotionTracker`: signed velocity, noise threshold, short decay to silence, and safe re-baselining after wake, bad readings, or discontinuities.
- `MotionAudio`: an `AVAudioSourceNode` feeds the system mixer. A small C synthesizer uses lock-free atomic controls; the render callback does not allocate memory, acquire locks, read files, or touch the UI.
- `MotionController`: one sensor queue, 30 Hz sampling, honest sensor errors, reconnect attempts, and main-thread UI updates at 10 Hz.
- Two synthesized voices: friction-like phase-modulated creaking and an electric harmonic hum with motion-dependent air noise.

See [architecture](docs/architecture.md) and [testing](docs/testing.md) for implementation details and practical limits.

## Verify and develop

```sh
swift test
swift run LidTone --check
swift run LidTone --sensor-check
```

`--check` renders both DSP voices offline and verifies finite, bounded, non-silent output. `--sensor-check` reads the real sensor without playing audio or modifying preferences; it intentionally fails on unsupported hardware. CI runs the unit/DSP tests and packages a universal app without requiring a physical hinge sensor.

Tests cover report parsing, startup silence, both movement directions, stopping, jitter, invalid values, sensor jumps, wake gaps, response scaling, audio headroom, zero volume, and fade-out. Passing these tests does not establish perceived sound quality or latency on every Mac; those require physical testing.

## Sensor research credit

The Apple vendor HID report format is not a documented macOS hinge-angle API. [Sam Gold's LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) made this sensor interface discoverable and demonstrated hinge-driven sound. This project implements its own Swift reader, motion mapping, interface, and original audio synthesis. It does not bundle that project's code or audio. Device/report compatibility may change with hardware or macOS updates.

## Privacy and removal

No accounts, network requests, telemetry, microphone access, keyboard monitoring, administrator privileges, or accessibility permission are used. The HID match is restricted to the hinge orientation sensor. Settings are stored locally in UserDefaults under `com.michaelmerrick.LidTone`.

To remove: turn off Start at login, quit, then delete the app. An earlier close-sound prototype could import clips into `~/Library/Application Support/LidTone/CustomSounds`; the motion version does not read or upload those files.

Built by Michael Merrick with AI-assisted implementation. MIT licensed.
