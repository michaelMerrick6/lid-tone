#ifndef LIDTONE_HINGE_AUDIO_H
#define LIDTONE_HINGE_AUDIO_H
#include <stdint.h>
typedef struct LTVoice LTVoice;
LTVoice *LTVoiceCreate(double sampleRate);
void LTVoiceDestroy(LTVoice *voice);
// Copies PCM into owned immutable storage. Call only BEFORE rendering starts.
// Slots: wood=0, saber hum=1, saber swings=2, accordion open=3, close=4.
int LTVoiceLoadSample(LTVoice *voice, int slot, const float *samples, uint32_t frames);
void LTVoiceSet(LTVoice *voice, float angle, float velocity, float intensity, float volume, int style);
void LTVoiceRender(LTVoice *voice, float *output, uint32_t frames);
#endif
