# Verification

## Automated checks

`swift test` exercises pure state transitions and the acknowledgement race/watchdog. `LidTone --check` decodes all bundled sounds and checks their duration. The packaging script verifies the app's code signature. CI builds arm64 and x86_64 into a universal app.

These checks do not close a real lid or establish audible playback during the hardware's sleep transition.

## Physical MacBook checklist

Record Mac model, chip, macOS version, output route, and the observations below when testing. Do not mark hardware behavior verified without actually trying it.

- [ ] First launch shows settings and detects the laptop lid.
- [ ] Preview each built-in through the current audio output.
- [ ] Choose Wooden door. Close and reopen the lid; hear one short sound.
- [ ] Repeat for each sound, including closing shortly after a preview.
- [ ] Leave the lid open and choose Apple menu → Sleep; hear no lid sound.
- [ ] Pause lid sounds, close/reopen, then resume; no stale sound should play.
- [ ] Wake normally and verify no duplicate sound plays on wake.
- [ ] Test while connected to an external display in supported clamshell mode.
- [ ] Test built-in speakers, headphones, and Bluetooth separately; note any truncation/latency.
- [ ] Import a short clip, restart the app, and confirm it still previews.
- [ ] Reject an overlong clip and an oversized file with a readable message.
- [ ] Turn Start at login on/off and confirm macOS Login Items reflects the change.
- [ ] Quit while a clip is playing; the process exits and normal sleep remains available.

## Distribution

For local validation, run the packaged executable's `--check` after copying the app away from the source checkout. This catches a missing resource bundle that might otherwise be hidden by SwiftPM's development resource path. Never disable system sleep or change `pmset` to test this utility.
