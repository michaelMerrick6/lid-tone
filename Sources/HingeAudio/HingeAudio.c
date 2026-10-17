#include "HingeAudio.h"
#include <math.h>
#include <stdatomic.h>
#include <stdlib.h>

struct Sample { float *data; uint32_t count; double position; };
struct LTVoice {
    _Atomic(float) angle, velocity, intensity, volume;
    _Atomic(int) style;
    double sampleRate, envelopes[3], speed, direction;
    struct Sample samples[5];
};
_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "Audio controls must be lock-free");
static float bounded(float x,float lo,float hi) { return isfinite(x) ? fminf(hi,fmaxf(lo,x)) : lo; }
LTVoice *LTVoiceCreate(double rate) {
    if (!isfinite(rate) || rate<8000 || rate>192000) return NULL;
    LTVoice *v=calloc(1,sizeof(LTVoice));
    if (!v) return NULL;
    v->sampleRate=rate; v->direction=1;
    atomic_init(&v->angle,90); atomic_init(&v->velocity,0);
    atomic_init(&v->intensity,0); atomic_init(&v->volume,.65f); atomic_init(&v->style,0);
    if (!atomic_is_lock_free(&v->angle)) { free(v); return NULL; }
    return v;
}
void LTVoiceDestroy(LTVoice *v) {
    if (!v) return;
    for(int i=0;i<5;i++) free(v->samples[i].data);
    free(v);
}
int LTVoiceLoadSample(LTVoice *v,int slot,const float *data,uint32_t frames) {
    if(!v || slot<0 || slot>=5 || !data || frames<32 || frames>48000*60) return 0;
    float *copy=malloc(sizeof(float)*frames);
    if(!copy) return 0;
    for(uint32_t i=0;i<frames;i++) copy[i]=bounded(data[i],-1,1);
    free(v->samples[slot].data);
    v->samples[slot]=(struct Sample){copy,frames,0};
    return 1;
}
void LTVoiceSet(LTVoice *v,float angle,float velocity,float intensity,float volume,int style) {
    atomic_store_explicit(&v->angle,bounded(angle,0,360),memory_order_relaxed);
    atomic_store_explicit(&v->velocity,bounded(velocity,-400,400),memory_order_relaxed);
    atomic_store_explicit(&v->intensity,bounded(intensity,0,1),memory_order_relaxed);
    atomic_store_explicit(&v->volume,bounded(volume,0,1),memory_order_relaxed);
    atomic_store_explicit(&v->style,style>=0 && style<=2 ? style : 0,memory_order_relaxed);
}
static double interpolate(const struct Sample *s,double position) {
    uint32_t index=(uint32_t)position;
    uint32_t next=index+1<s->count ? index+1 : index;
    double fraction=position-index;
    return s->data[index]*(1-fraction)+s->data[next]*fraction;
}
static double play(struct Sample *s,double rate,double sampleRate) {
    if(!s->data || s->count<32) return 0;
    double overlap=fmin(sampleRate*.12,s->count*.15);
    double seam=s->count-overlap;
    double value=interpolate(s,s->position);
    if(s->position>=seam) {
        double blend=(s->position-seam)/overlap;
        value=value*(1-blend)+interpolate(s,s->position-seam)*blend;
    }
    s->position+=rate*48000/sampleRate;
    while(s->position>=s->count) s->position-=seam;
    return value;
}
void LTVoiceRender(LTVoice *v,float *out,uint32_t count) {
    double velocity=atomic_load_explicit(&v->velocity,memory_order_relaxed);
    double intensity=atomic_load_explicit(&v->intensity,memory_order_relaxed);
    double target=pow(intensity,.48)*atomic_load_explicit(&v->volume,memory_order_relaxed);
    int style=atomic_load_explicit(&v->style,memory_order_relaxed);
    double attack=1-exp(-1/(v->sampleRate*.025));
    double release=1-exp(-1/(v->sampleRate*.055));
    double glide=1-exp(-1/(v->sampleRate*.06));
    for(uint32_t i=0;i<count;i++) {
        v->speed+=(fabs(velocity)-v->speed)*glide;
        if(velocity!=0) v->direction+=((velocity>0 ? 1 : 0)-v->direction)*glide;
        double sum=0;
        for(int mode=0;mode<3;mode++) {
            double goal=mode==style ? target : 0;
            v->envelopes[mode]+=(goal-v->envelopes[mode])*(goal>v->envelopes[mode] ? attack : release);
            if(v->envelopes[mode]<.000001) continue;
            double signal;
            if(mode==0) {
                signal=play(&v->samples[0],.82+fmin(v->speed/140,.36),v->sampleRate);
            } else if(mode==1) {
                double hum=play(&v->samples[1],.98+fmin(v->speed/400,.08),v->sampleRate);
                double swing=play(&v->samples[2],.85+fmin(v->speed/90,.4),v->sampleRate);
                double swingMix=fmin(v->speed/60,.9);
                signal=hum*(.8-.35*swingMix)+swing*swingMix;
            } else {
                double open=play(&v->samples[3],1,v->sampleRate);
                double close=play(&v->samples[4],1,v->sampleRate);
                signal=open*v->direction+close*(1-v->direction);
            }
            sum+=signal*v->envelopes[mode];
        }
        out[i]=(float)(.68*tanh(sum*2));
    }
}
