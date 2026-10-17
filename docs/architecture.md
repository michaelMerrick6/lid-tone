# Motion audio architecture

```text
Apple hinge orientation sensor
    → feature report 1, ID + little-endian angle in degrees
    → 30 Hz serial sampling
    → validated angle + monotonic timestamp
    → signed angular velocity, noise threshold, decay
    → lock-free sample-engine controls
    → AVAudioSourceNode → system output

Actual angle and motion status → main thread → SwiftUI at 10 Hz
```

## Sensor access

The reader uses public IOKit HID functions, but Apple's vendor sensor protocol is undocumented. It matches only vendor 0x05AC / usage page 0x20 / usage 0x8A and opens the sensor without seizing it. It never opens keyboard or pointer devices. Access was verified on an M4 MacBook Air without administrator privileges or additional permissions.

A report must contain at least three bytes, start with report ID 1, and decode to 0–360 degrees. The tested hardware returned `[1, 91, 0]` at 91°. Degrees are used directly; no unverified hundredths-of-degree conversion is applied. The actual physical hinge has a narrower normal range; the app never asks users to force it past that range.

Sampling stays off the UI thread. Failed connections are retried every three seconds and failed reads silence the audio. Pausing sounds closes the sensor handle. Sleep suspends the reader and audio engine; wake reconnects and re-baselines. This version does not intercept, veto, or delay sleep.

## Motion mapping

The initial sample is silent. Angle differences over elapsed monotonic time yield signed velocity. Changes smaller than 0.35° are ignored. Velocity is estimated over the interval between actual angle changes, not the 30 Hz polling interval. An adaptive 120–420 ms hold bridges the repeated values emitted by a whole-degree sensor; a short decay follows. This trades a roughly 0.3–0.6 second release tail for smoother slow movement. Gaps of 0.5 seconds or more, non-monotonic timestamps, invalid values, or jumps above 35° establish a new silent baseline.

Intensity is a bounded square-root mapping of speed with adjustable response. Direction changes are reflected immediately instead of averaging opening and closing into silence. Quantization of whole-degree readings remains a physical limitation, especially during slow movement.

Preview uses a separate simulated motion trace. It never replaces the displayed live angle. After the preview the real tracker resets so a sensor change accumulated during the demonstration cannot cause a stale swoosh.

## Audio thread

The control queue publishes motion, volume, and mode through lock-free C atomics. All five recordings are decoded and copied to immutable, owned PCM buffers before rendering starts. The render thread owns the playback cursors and envelopes. It performs no allocation, blocking locks, file or network I/O, or UI work.

Wood uses a 15.35-second selection of real door creaks, with a gently speed-dependent playback rate. Saber blends a six-second recorded hum and a 9.8-second selection of recorded microphone swings; faster motion increases the swing layer. These are independently created CC0 effects, not official movie assets. Accordion uses six-second chord mixes from sampled Hohner reeds: opening blends toward C major and closing toward G major. Direction changes glide between chords.

Loops overlap their last 120 ms with the beginning instead of making a hard cut. Cursors persist across sensor samples, mode changes, and short pauses. A 25 ms attack / 55 ms release smooths volume; mode changes crossfade and the output is soft limited. The audio engine pauses after 250 ms without intensity and restarts on movement. Preparation steps and original creator credits are in AUDIO_CREDITS.md.

## Compatibility and tests

The offline tests run independently of HID hardware or audio output devices. They validate behavior and the numerical audio signal, not perceived sound quality. The optional `--sensor-check` tests real HID access. The UI reports missing/restricted sensors rather than pretending movement works on unsupported models.
