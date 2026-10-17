#ifndef LIDTONE_POWER_MESSAGES_H
#define LIDTONE_POWER_MESSAGES_H
#include <IOKit/IOMessage.h>
// Clang evaluates public SDK macros that Swift cannot import directly.
enum {
    LTPowerCanSleep = kIOMessageCanSystemSleep,
    LTPowerWillSleep = kIOMessageSystemWillSleep,
    LTPowerDidWake = kIOMessageSystemHasPoweredOn
};
#endif
