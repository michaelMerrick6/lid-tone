# Implementation notes

The interesting constraint is the time between the lid sensor changing and macOS suspending the audio device. LidTone starts playback at the first notification and acknowledges sleep promptly after the remaining clip. It cannot promise that an audio driver will remain active.

## Event path

```text
IOPMrootDomain general-interest notification
    → clamshell bitfield
    → LidTransition.observe(closed, enabled)
    → one preloaded AVAudioPlayer starts

IORegisterForSystemPower notification
    → idle sleep: acknowledge immediately
    → will sleep: read lid state as fallback, compute remaining lid audio
    → acknowledge after min(remaining + 25ms, 950ms)
    → independent 950ms watchdog races normal completion (exactly once)
    → wake: stop stale audio and silently synchronize state
```

Both notification ports deliver to one serial queue. Audio players and the transition state are confined to that queue. UI changes enqueue configurations; event status changes return to the main queue. The watchdog has its own queue and a lock-protected, one-shot acknowledgement. It never needs to wait for the UI.

The watchdog is scheduled before reading the registry or attempting playback in the sleep callback. Cleanup acknowledges any outstanding event before closing the IOKit connection. Timers retain only the one-shot acknowledgement; a late timer cannot acknowledge again after cleanup.

The time limit bounds the scheduled delay once the sleep callback runs. This is not a real-time guarantee: an OS scheduler stall, a hung process, or a callback that never reaches the process remains outside the app's control. macOS also has its own notification timeout.

## Lid state, not sleep guessing

`AppleClamshellState` provides the initial state. `kIOPMMessageClamshellStateChange` supplies subsequent state in bit zero. The other bit describes whether lid close causes sleep; changes to that policy can emit another notification with the same lid state. Therefore duplicate suppression is necessary even in normal docked operation.

`LidTransition` accepts only a known open → closed transition. Launching with an already closed lid is silent. On machines without a lid property, previews work and settings report that no lid was detected. A genuine subsequent open notification can establish state.

`SystemWillSleep` also reads the lid property, covering a missed or differently ordered clamshell event. The same transition gate prevents double playback. Open-lid idle/manual sleep produces no new sound. Only an active **lid** sound can delay acknowledgement; a settings preview cannot.

## Audio and packaging

Four mono PCM WAV files are decoded and prepared at launch. Playback does not fetch files or start a subprocess. The app volume scales playback without altering system volume or switching the user's output device. Custom files are limited before copying and decoded before becoming the selection.

SwiftPM packages resources separately from the executable. The build script places the resource bundle in `Contents/Resources`; `SoundResources` resolves that location before falling back to SwiftPM's development accessor. The package has no third-party dependencies.

The tiny C target evaluates public SDK message macros, whose nested C macros do not import directly into Swift. No private framework is linked. Launch at login uses the user-controlled `SMAppService.mainApp` API.

## Tradeoffs

- Short clips preserve sleep responsiveness but limit elaborate effects.
- Current output respects headphones and system mute; it cannot guarantee external speakers.
- A paused app continues monitoring notifications but starts no lid audio.
- Original modal/noise synthesis makes the sound assets reproducible and redistributable; recorded Foley can sound more realistic and can be imported by the user.
- The app is an unsandboxed, ad-hoc-signed local build. Public notarized distribution requires the maintainer's own Developer ID and notarization credentials, which are not included.
