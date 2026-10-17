#ifndef LIDTONE_POWER_BRIDGE_H
#define LIDTONE_POWER_BRIDGE_H
#include <IOKit/IOMessage.h>
#include <IOKit/pwr_mgt/IOPM.h>
// These SDK function-like macros do not import into Swift. Let Clang evaluate them.
enum {
    LTMessageClamshellChanged = kIOPMMessageClamshellStateChange,
    LTMessageCanSleep = kIOMessageCanSystemSleep,
    LTMessageWillSleep = kIOMessageSystemWillSleep,
    LTMessageDidWake = kIOMessageSystemHasPoweredOn
};
#endif
