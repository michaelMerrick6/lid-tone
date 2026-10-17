#include "HingeAudio.h"
#include <math.h>
#include <stdatomic.h>
#include <stdlib.h>

struct LTVoice {
    _Atomic(float) angle, velocity, intensity, volume;
    _Atomic(int) style;
    double sampleRate, phase, grain, envelope;
    float noise;
    uint32_t random;
};
_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "Audio control atomics must be lock-free");

LTVoice *LTVoiceCreate(double rate) {
    if (!isfinite(rate) || rate < 8000 || rate > 192000) return NULL;
    LTVoice *v = calloc(1, sizeof(LTVoice));
    if (!v) return NULL;
    v->sampleRate = rate; v->random = 0x41c6ce57;
    atomic_init(&v->angle, 90); atomic_init(&v->velocity, 0);
    atomic_init(&v->intensity, 0); atomic_init(&v->volume, .65f); atomic_init(&v->style, 0);
    if (!atomic_is_lock_free(&v->angle)) { free(v); return NULL; }
    return v;
}
void LTVoiceDestroy(LTVoice *v) { free(v); }
static float bounded(float x, float lo, float hi) { return isfinite(x) ? fminf(hi, fmaxf(lo,x)) : lo; }
void LTVoiceSet(LTVoice *v, float angle, float velocity, float intensity, float volume, int style) {
    atomic_store_explicit(&v->angle, bounded(angle,0,360), memory_order_relaxed);
    atomic_store_explicit(&v->velocity, bounded(velocity,-400,400), memory_order_relaxed);
    atomic_store_explicit(&v->intensity, bounded(intensity,0,1), memory_order_relaxed);
    atomic_store_explicit(&v->volume, bounded(volume,0,1), memory_order_relaxed);
    atomic_store_explicit(&v->style, style == 1 ? 1 : 0, memory_order_relaxed);
}
void LTVoiceRender(LTVoice *v, float *out, uint32_t count) {
    const double tau = 6.283185307179586;
    float angle = atomic_load_explicit(&v->angle,memory_order_relaxed);
    float velocity = atomic_load_explicit(&v->velocity,memory_order_relaxed);
    float target = atomic_load_explicit(&v->intensity,memory_order_relaxed) * atomic_load_explicit(&v->volume,memory_order_relaxed);
    int style = atomic_load_explicit(&v->style,memory_order_relaxed);
    double speed = fabs(velocity);
    double frequency = style ? 82 + angle*.37 + speed*1.5 : 140 + angle*1.4 + speed*.65;
    frequency += velocity < 0 ? -12 : 12;
    double phaseStep = tau * frequency / v->sampleRate;
    double grainStep = tau * (style ? 6 + speed*.04 : 17 + speed*.4) / v->sampleRate;
    double attack = 1-exp(-1/(v->sampleRate*.008));
    double release = 1-exp(-1/(v->sampleRate*.028));
    for (uint32_t i=0;i<count;i++) {
        v->envelope += (target-v->envelope) * (target > v->envelope ? attack : release);
        v->random ^= v->random << 13; v->random ^= v->random >> 17; v->random ^= v->random << 5;
        float noise = ((float)(v->random & 0xffff)/32767.5f)-1;
        v->noise += .13f*(noise-v->noise);
        v->phase += phaseStep; if(v->phase >= tau) v->phase -= tau;
        v->grain += grainStep; if(v->grain >= tau) v->grain -= tau;
        double signal;
        if (style) {
            double hum = .48*sin(v->phase) + .24*sin(2*v->phase+.2*sin(v->grain)) + .12*sin(3*v->phase);
            double air = v->noise * (.5 + fmin(speed/100,1));
            signal = hum*(.85+.15*sin(v->grain)) + air;
        } else {
            double friction = .50*sin(v->phase + 1.1*sin(v->grain)) + .24*sin(2.03*v->phase) + .12*sin(3.97*v->phase);
            double stickSlip = .45 + .55*pow(.5+.5*sin(v->grain),2);
            signal = friction*stickSlip + .30*v->noise;
        }
        out[i] = (float)(.68*tanh(signal*v->envelope*1.6));
    }
}
