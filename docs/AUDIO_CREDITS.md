# Audio sources and processing

All bundled recordings below are offered by their creators under **CC0 1.0**:
https://creativecommons.org/publicdomain/zero/1.0/
The application code is MIT licensed; the recordings retain their own CC0 dedication.

| Bundled asset | Original recording and creator | Processing |
| --- | --- | --- |
| `wood-creaks.wav` | [Wooden Door Creaking — Mr_KeybOred](https://freesound.org/people/Mr_KeybOred/sounds/414493/) | Public high-quality preview, mono mix, selected long creaks (0.15–6.8s and 8–16.7s), 48 kHz resampling, DC removal, peak normalization, endpoint fades. |
| `saber-hum.wav`, `saber-swings.wav` | [Lightsaber Hum and Swings 2 — Sheyvan](https://freesound.org/people/Sheyvan/sounds/703384/) | Public high-quality preview, portions 32–38s / 42–51.8s, mono 48 kHz PCM, DC removal, peak normalization, endpoint fades. The creator recorded a moving microphone in front of a speaker to recreate a cinematic lightsaber effect. These are independently created effects, not official film audio. |
| `accordion-open.wav`, `accordion-close.wav` | [FreePats Button Accordion HN, 2024-03-29](https://freepats.zenvoid.org/Organ/accordion.html) | Hohner samples recorded by Jeff Stauffer (November 2023), shared with Piotr Barz's help, processed by michael02022. Sustain regions and tuning from the supplied SFZ; C-major and G-major chord mixes, bass layer, seam overlap, 48 kHz resampling and normalization. |

FreePats source archive:
https://github.com/freepats/button-accordion-HN/releases/download/2024-03-29/ButtonAccordionHN-SFZ%2BWAV-20240329.7z

The source license is preserved in `licenses/FreePats-CC0.txt`.
`scripts/prepare-audio.py` reproduces the edited assets from decoded source WAVs and the extracted sound bank. It requires NumPy for preparation only; the app has no third-party runtime dependencies. MP3 sources were decoded with macOS `afconvert -f WAVE -d LEI16 input.mp3 output.wav`.

Playback uses long recordings with crossfaded loop seams. It preserves the cursor across motion updates instead of restarting the sample on each sensor reading. No network requests or downloads occur at runtime.
