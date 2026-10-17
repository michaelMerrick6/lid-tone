# Verification

## Automated

`swift test` covers HID report validation, startup silence, opening/closing direction, stillness, jitter suppression, wake gaps, invalid values, sensor jumps, response scaling, and DSP signal bounds, mute, and fade-out.

`LidTone --check` renders both effects offline. `LidTone --sensor-check` separately opens only the hinge sensor and prints its live angle. CI does not require that hardware-dependent check because hosted macOS runners may not expose a hinge sensor.

The packaging script verifies the app signature; CI verifies that the executable contains both arm64 and x86_64.

## Physical test

Sensor connection and a 91° reading were verified on an M4 MacBook Air (Mac16,13), macOS 15.6.1. During physical testing, the user confirmed that the angle changes and sound follows screen movement. The captured settings image also shows a live 72° reading and closing motion. Other checks below remain unverified unless marked.

- [x] Confirm the displayed angle changes when gently tilting the screen.
- [x] Select Creaking hinge: sound should follow motion in both directions.
- [ ] Select Lightsaber: pitch/texture should follow motion, with stronger response to faster movement.
- [ ] Hold the screen still: sound should fade to silence within roughly 200 ms.
- [ ] Try slow small adjustments; note whole-degree sensor stepping.
- [ ] Preview motion: hear a short synthetic movement demo; live angle stays real.
- [ ] Pause: actual motion is silent; preview remains available by explicit action.
- [ ] Resume: no stale accumulated movement sound.
- [ ] Sleep/wake normally: reconnect and baseline without a wake swoosh.
- [ ] Test built-in speakers and Bluetooth separately; note output latency.
- [ ] Test Start at login on/off from a stable app location.

Move the screen only within its normal range. Fully closed/sleeping playback is not a feature of this version. No `pmset` changes or sleep prevention are needed.
