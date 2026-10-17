#ifndef LIDTONE_HINGE_AUDIO_H
#define LIDTONE_HINGE_AUDIO_H
#include <stdint.h>
typedef struct LTVoice LTVoice;
LTVoice *LTVoiceCreate(double sampleRate);
void LTVoiceDestroy(LTVoice *voice);
// Control thread writes lock-free atomics; the audio callback owns oscillator state.
void LTVoiceSet(LTVoice *voice, float angle, float velocity, float intensity, float volume, int style);
void LTVoiceRender(LTVoice *voice, float *output, uint32_t frames);
#endif
