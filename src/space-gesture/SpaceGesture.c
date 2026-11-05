// From InstantSpaceSwitcher's ISS.c, MIT licensed, Copyright (c) 2026
// jurplel. See README.md for the full notice and what was left out.

#include "SpaceGesture.h"
#include "internal.h"

#include <dispatch/dispatch.h>
#include <mach/mach_time.h>
#include <stdatomic.h>

// See IOHIDEventType in IOHIDFamily.
static const uint32_t kIOHIDEventTypeDockSwipe = 23;
static const int64_t kCGSEventGesture = 29;
static const int64_t kCGSEventDockControl = 30;
static const int64_t kGestureMotionHorizontal = 1;

// Upstream's default gesture speed, multiplied by the steps of a jump.
static const double kLegacySpeed = 2000.0;
// The fling on the ended phase is what commits a switch on macOS 27. The
// payload field is 16.16 fixed point, so it tops out near 32767.
static const double kModernFlingVelocity = 9999.0;
// The smallest non-zero 16.16 value: nothing left to animate, direction kept.
static const double kTinyProgress = 0.000016;

bool sg_can_post_events(void) {
    return CGPreflightPostEventAccess();
}

bool sg_request_post_events(void) {
    return CGRequestPostEventAccess();
}

double sg_swipe_progress(SGDirection direction) {
    return direction == SGDirectionRight ? kTinyProgress : -kTinyProgress;
}

// On macOS 27 right is negative, and the Dock reads the posted sign through
// the natural scrolling preference, so it flips again with that off.
double sg_modern_swipe_sign(SGDirection direction, bool naturalScrolling) {
    const double sign = direction == SGDirectionRight ? -1.0 : 1.0;
    return naturalScrolling ? sign : -sign;
}

// The preference, read once and again whenever System Settings says it
// changed. -1 means read it next time.
static _Atomic int naturalScrolling = -1;

static void naturalScrollingChanged(CFNotificationCenterRef center, void *observer,
                                    CFNotificationName name, const void *object,
                                    CFDictionaryRef userInfo) {
    (void)center;
    (void)observer;
    (void)name;
    (void)object;
    (void)userInfo;
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication);
    atomic_store(&naturalScrolling, -1);
}

static bool naturalScrollingOn(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(), (const void *)&naturalScrolling,
            naturalScrollingChanged,
            CFSTR("SwipeScrollDirectionDidChangeNotification"), NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    });
    int cached = atomic_load(&naturalScrolling);
    if (cached < 0) {
        Boolean valid = false;
        Boolean natural = CFPreferencesGetAppBooleanValue(
            CFSTR("com.apple.swipescrolldirection"), kCFPreferencesAnyApplication, &valid);
        // macOS defaults to natural scrolling when the key is absent.
        cached = (!valid || natural) ? 1 : 0;
        atomic_store(&naturalScrolling, cached);
    }
    return cached == 1;
}

static CGEventRef copyModernSwipe(SGPhase phase, SGDirection direction, bool natural) {
    const double sign = sg_modern_swipe_sign(direction, natural);
    CGEventRef event = CGEventCreate(NULL);
    if (!event) {
        return NULL;
    }
    CGEventSetIntegerValueField(event, kSGFieldEventType, kCGSEventDockControl);
    CGEventSetIntegerValueField(event, kSGFieldGestureHIDType, kIOHIDEventTypeDockSwipe);
    CGEventSetIntegerValueField(event, kSGFieldGesturePhase, phase);
    CGEventSetIntegerValueField(event, kSGFieldSwipeMotion, kGestureMotionHorizontal);
    // Full progress switches too, but the previous Space flashes first.
    CGEventSetDoubleValueField(event, kSGFieldSwipeProgress, sign * kTinyProgress);
    // Fields a real trackpad swipe carries, from upstream's traces.
    CGEventSetIntegerValueField(event, kSGFieldGesturePhaseAlias, phase);
    CGEventSetDoubleValueField(event, kSGFieldZoomDeltaY, 3.0);
    CGEventSetDoubleValueField(event, kSGFieldSourceProcessIDAlias, (double)mach_absolute_time());
    CGEventSetDoubleValueField(event, kSGFieldSwipePositionX, 0.1);
    // Only the ended event carries velocity, as a real swipe does.
    if (phase == SGPhaseEnded) {
        CGEventSetDoubleValueField(event, kSGFieldSwipeVelocityX, sign * kModernFlingVelocity);
    }
    CGEventRef augmented = sg_augment_dock_swipe(event);
    CFRelease(event);
    return augmented;
}

static CGEventRef copyLegacySwipe(SGPhase phase, SGDirection direction, double velocity) {
    CGEventRef event = CGEventCreate(NULL);
    if (!event) {
        return NULL;
    }
    const double signedVelocity = direction == SGDirectionRight ? velocity : -velocity;
    CGEventSetIntegerValueField(event, kSGFieldEventType, kCGSEventDockControl);
    CGEventSetIntegerValueField(event, kSGFieldGestureHIDType, kIOHIDEventTypeDockSwipe);
    CGEventSetIntegerValueField(event, kSGFieldGesturePhase, phase);
    CGEventSetDoubleValueField(event, kSGFieldSwipeProgress, sg_swipe_progress(direction));
    CGEventSetIntegerValueField(event, kSGFieldSwipeMotion, kGestureMotionHorizontal);
    CGEventSetDoubleValueField(event, kSGFieldSwipeVelocityX, signedVelocity);
    CGEventSetDoubleValueField(event, kSGFieldSwipeVelocityY, signedVelocity);
    return event;
}

CGEventRef sg_copy_swipe_event(SGPhase phase, SGDirection direction, bool modern,
                               bool naturalScrolling, double velocity) {
    return modern ? copyModernSwipe(phase, direction, naturalScrolling)
                  : copyLegacySwipe(phase, direction, velocity);
}

static bool postSwipe(SGPhase phase, SGDirection direction, bool modern, bool natural,
                      double velocity) {
    CGEventRef event = sg_copy_swipe_event(phase, direction, modern, natural, velocity);
    if (!event) {
        return false;
    }
    // On macOS 27 the Dock ignores a DockControl event without a companion
    // gesture event after it.
    CGEventRef companion = NULL;
    if (modern) {
        companion = CGEventCreate(NULL);
        if (!companion) {
            CFRelease(event);
            return false;
        }
        CGEventSetIntegerValueField(companion, kSGFieldEventType, kCGSEventGesture);
    }
    CGEventPost(kCGSessionEventTap, event);
    CFRelease(event);
    if (companion) {
        CGEventPost(kCGSessionEventTap, companion);
        CFRelease(companion);
    }
    return true;
}

bool sg_switch(SGDirection direction, unsigned int steps) {
    const bool modern = sg_requires_event_augmentation();
    const bool natural = modern && naturalScrollingOn();
    // A faster fling for a longer jump, as upstream does on macOS 26.
    const double velocity = kLegacySpeed * steps;
    for (unsigned int step = 0; step < steps; step++) {
        // All three phases: with only two, Mission Control stops working.
        if (!postSwipe(SGPhaseBegan, direction, modern, natural, velocity)
            || !postSwipe(SGPhaseChanged, direction, modern, natural, velocity)
            || !postSwipe(SGPhaseEnded, direction, modern, natural, velocity)) {
            return false;
        }
    }
    return true;
}

static void countDockLayers(CFArrayRef windowList, int *layer18, int *layer20) {
    *layer18 = 0;
    *layer20 = 0;
    if (!windowList) {
        return;
    }
    CFIndex count = CFArrayGetCount(windowList);
    for (CFIndex i = 0; i < count; i++) {
        CFDictionaryRef info = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, i);
        if (!info || CFGetTypeID(info) != CFDictionaryGetTypeID()) {
            continue;
        }
        CFStringRef owner = (CFStringRef)CFDictionaryGetValue(info, kCGWindowOwnerName);
        if (!owner || CFGetTypeID(owner) != CFStringGetTypeID() || !CFEqual(owner, CFSTR("Dock"))) {
            continue;
        }
        int layer = 0;
        CFNumberRef number = (CFNumberRef)CFDictionaryGetValue(info, kCGWindowLayer);
        if (number && CFGetTypeID(number) == CFNumberGetTypeID()) {
            CFNumberGetValue(number, kCFNumberIntType, &layer);
        }
        if (layer == 18) {
            (*layer18)++;
        } else if (layer == 20) {
            (*layer20)++;
        }
    }
}

// Both read the Dock's overlay windows: layer 18 covers each display while
// either is open, and Mission Control shows more layer 20 windows than
// there are overlays, App Exposé as many or fewer. Upstream found this from
// window list probes; it is empirical.
bool sg_mission_control_in_window_list(CFArrayRef windowList) {
    int layer18 = 0;
    int layer20 = 0;
    countDockLayers(windowList, &layer18, &layer20);
    return layer18 > 0 && layer20 > layer18;
}

bool sg_expose_in_window_list(CFArrayRef windowList) {
    int layer18 = 0;
    int layer20 = 0;
    countDockLayers(windowList, &layer18, &layer20);
    return layer18 > 0 && layer20 > 0 && layer20 <= layer18;
}

bool sg_overlay_open(void) {
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    if (!windowList) {
        return false;
    }
    bool open = sg_mission_control_in_window_list(windowList) || sg_expose_in_window_list(windowList);
    CFRelease(windowList);
    return open;
}
