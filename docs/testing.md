# Verification

## Automated

`swift test` covers HID report validation, startup silence, opening/closing direction, stillness, jitter suppression, wake gaps, invalid values, sensor jumps, response scaling, slow whole-degree movement without dropouts, persistent sample cursors, and audio signal bounds, mute, and fade-out.

`LidTone --check` decodes the six bundled recordings and renders all three continuous modes offline. `LidTone --sensor-check` separately opens only the hinge sensor and prints its live angle. CI does not require that hardware-dependent check because hosted macOS runners may not expose a hinge sensor.

The packaging script verifies the app signature; CI verifies that the executable contains both arm64 and x86_64.

## Physical test

Sensor connection and a 91° reading were verified on an M4 MacBook Air (Mac16,13), macOS 15.6.1. During physical testing, the user confirmed that the angle changes and sound follows screen movement. The captured settings image also shows a live 72° reading and closing motion. Other checks below remain unverified unless marked.

- [x] Confirm the displayed angle changes when gently tilting the screen.
- [x] Select Creaking hinge: sound should follow motion in both directions.
- [ ] Select Lightsaber: pitch/texture should follow motion, with stronger response to faster movement.
- [ ] Hold the screen still: sound should fade out after the cadence-aware release tail (roughly 0.3–0.6 seconds).
- [ ] Slowly move one degree at a time: sustained movement should not produce repeating cutoffs.
- [ ] Accordion: opening and closing should pump different chords with a sampled reed timbre.
- [ ] Compare the new recorded wood and saber effects with the earlier oscillator version; ask the listener about realism and repetition.
- [ ] Try slow small adjustments; note whole-degree sensor stepping.
- [ ] Preview motion: hear a short synthetic movement demo; live angle stays real.
- [ ] Pause: actual motion is silent; preview remains available by explicit action.
- [ ] Resume: no stale accumulated movement sound.
- [ ] Sleep/wake normally: reconnect and baseline without a wake swoosh.
- [ ] Test built-in speakers and Bluetooth separately; note output latency.
- [ ] Test Start at login on/off from a stable app location.

Move the screen only within its normal range. Lightsaber power-down starts just before full closure, with a bounded sleep acknowledgement window; audio still stops when the hardware actually sleeps. No `pmset` changes or sleep prevention are needed.

The recorded-audio update was approved in listening testing on this Mac. The lightsaber power-down addition was also physically tested: the user confirmed that closing the lid plays the power-down exactly once.

## Power-down addition

- [x] In Lightsaber mode, close and reopen the lid: hear one power-down (user confirmed).
- [ ] Slowly cross 10° and wiggle below 20°: no repeated shutdown effect.
- [ ] Open beyond 20°, then close: the effect re-arms.
- [ ] Close quickly: the sleep-notification fallback should cover a skipped angle sample.
- [ ] Close in Wood/Accordion mode or while paused: no lightsaber shutdown.
- [ ] Apple-menu/idle sleep with an open lid: no shutdown effect.
- [ ] Start/wake with an already closed lid: no stale close effect.
- [ ] The power-button preview plays the short clip once.

Automated close tests cover hysteresis, startup/wake silence, skipped-sample fallback, duplicate notifications, mode/disabled gating, acknowledgement races, teardown and watchdog completion. These do not establish physical sleep/audio timing.
