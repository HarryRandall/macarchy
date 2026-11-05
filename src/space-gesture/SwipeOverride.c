// From InstantSpaceSwitcher's swipe override in ISS.c, MIT licensed,
// Copyright (c) 2026 jurplel. See README.md for the full notice.
//
// An event tap sees the trackpad's sideways swipe between Spaces before the
// Dock does. The first event that shows a direction becomes one instant
// switch, and the rest of the gesture is held back so the Dock never
// animates it. Unlike upstream, a swipe begun in Mission Control as well as
// App Exposé goes to the Dock untouched, so swiping there works as usual.

#include "SpaceGesture.h"
#include "internal.h"

#include <mach/mach_time.h>
#include <stdatomic.h>

static const int64_t kPhaseBegan = SGPhaseBegan;
static const int64_t kPhaseChanged = SGPhaseChanged;
static const int64_t kPhaseEnded = SGPhaseEnded;
static const int64_t kPhaseCancelled = 8;

SGSwipeAction sg_swipe_decide(SGSwipeState *state, SGSwipeEvent event, bool modern,
                              bool (*overlayOpen)(void), int *outSwitch) {
    *outSwitch = -1;
    if (event.eventType != kSGEventDockControl && event.eventType != kSGEventGesture) {
        return SGSwipePass;
    }
    // Another process's synthetic swipe on macOS 26; the trackpad's come
    // from the kernel, with no process.
    if (event.sourcePid != 0) {
        return SGSwipePass;
    }
    // The companion events a swipe sends alongside its Dock events.
    if (event.eventType == kSGEventGesture) {
        return state->tracking ? SGSwipeSwallow : SGSwipePass;
    }
    if (event.hidType != kSGHIDDockSwipe || event.motion != kSGMotionHorizontal) {
        return SGSwipePass;
    }

    switch (event.phase) {
    case kPhaseBegan:
        if (overlayOpen && overlayOpen()) {
            return SGSwipePass;
        }
        state->tracking = true;
        state->fired = false;
        return SGSwipeSwallow;
    case kPhaseChanged:
        if (!state->tracking) {
            return SGSwipePass;
        }
        if (!state->fired && event.progress != 0.0) {
            *outSwitch = event.progress > 0.0 ? SGDirectionRight : SGDirectionLeft;
            state->fired = true;
        }
        return SGSwipeSwallow;
    case kPhaseEnded:
        if (!state->tracking) {
            return SGSwipePass;
        }
        // A flick too short to report progress still has a velocity.
        if (!state->fired && event.velocity != 0.0) {
            *outSwitch = event.velocity > 0.0 ? SGDirectionRight : SGDirectionLeft;
        }
        state->tracking = false;
        state->fired = false;
        return modern ? SGSwipePassStill : SGSwipeSwallow;
    case kPhaseCancelled:
        if (!state->tracking) {
            return SGSwipePass;
        }
        state->tracking = false;
        state->fired = false;
        return SGSwipeSwallow;
    default:
        return state->tracking ? SGSwipeSwallow : SGSwipePass;
    }
}

// Only touched on the main thread, where the tap runs.
static CFMachPortRef tap = NULL;
static CFRunLoopSourceRef source = NULL;
static SGSwipeState state = {false, false};
static SGSwipeHandler handler = NULL;

// Posting happens off the main thread too, so these are atomic.
static _Atomic bool intercepting = false;
static _Atomic unsigned int ownPending = 0;
static _Atomic uint64_t lastOwnPost = 0;

void sg_note_own_events(unsigned int count) {
    if (!atomic_load(&intercepting)) {
        return;
    }
    atomic_store(&lastOwnPost, mach_absolute_time());
    atomic_fetch_add(&ownPending, count);
}

// Own events come back within milliseconds. A count left after a second
// is for events that never arrived, and would let the trackpad's through.
static bool ownEventsRecent(void) {
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    uint64_t elapsed = mach_absolute_time() - atomic_load(&lastOwnPost);
    return elapsed * timebase.numer / timebase.denom < 1000000000ULL;
}

static bool overlayOpen(void) {
    return sg_overlay_open();
}

static CGEventRef callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    (void)proxy;
    (void)refcon;
    // macOS turns a tap off when it is slow or on some input; turn it back on.
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (tap) {
            CGEventTapEnable(tap, true);
        }
        atomic_store(&ownPending, 0);
        return event;
    }

    int64_t eventType = CGEventGetIntegerValueField(event, kSGFieldEventType);
    if (eventType == kSGEventDockControl || eventType == kSGEventGesture) {
        unsigned int pending = atomic_load(&ownPending);
        if (pending > 0) {
            if (!ownEventsRecent()) {
                atomic_store(&ownPending, 0);
            } else if (atomic_compare_exchange_strong(&ownPending, &pending, pending - 1)) {
                return event;
            }
        }
    }

    SGSwipeEvent fields = {
        .eventType = eventType,
        .hidType = CGEventGetIntegerValueField(event, kSGFieldGestureHIDType),
        .motion = CGEventGetIntegerValueField(event, kSGFieldSwipeMotion),
        .phase = CGEventGetIntegerValueField(event, kSGFieldGesturePhase),
        .progress = CGEventGetDoubleValueField(event, kSGFieldSwipeProgress),
        .velocity = CGEventGetDoubleValueField(event, kSGFieldSwipeVelocityX),
        .sourcePid = CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID),
    };
    int direction = -1;
    SGSwipeAction action =
        sg_swipe_decide(&state, fields, sg_requires_event_augmentation(), overlayOpen, &direction);
    if (direction >= 0 && handler) {
        handler((SGDirection)direction);
    }
    switch (action) {
    case SGSwipeSwallow:
        return NULL;
    case SGSwipePassStill:
        CGEventSetDoubleValueField(event, kSGFieldSwipeProgress, 0.0);
        CGEventSetDoubleValueField(event, kSGFieldSwipeVelocityX, 0.0);
        CGEventSetDoubleValueField(event, kSGFieldSwipeVelocityY, 0.0);
        return event;
    case SGSwipePass:
    default:
        return event;
    }
}

bool sg_swipe_override_start(SGSwipeHandler newHandler) {
    handler = newHandler;
    if (tap) {
        return true;
    }
    CGEventMask mask = (1ULL << kSGEventGesture) | (1ULL << kSGEventDockControl);
    tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
                           mask, callback, NULL);
    if (!tap) {
        return false;
    }
    source = CFMachPortCreateRunLoopSource(NULL, tap, 0);
    if (!source) {
        CFRelease(tap);
        tap = NULL;
        return false;
    }
    state = (SGSwipeState){false, false};
    atomic_store(&ownPending, 0);
    atomic_store(&intercepting, true);
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    CGEventTapEnable(tap, true);
    return true;
}

void sg_swipe_override_stop(void) {
    atomic_store(&intercepting, false);
    atomic_store(&ownPending, 0);
    handler = NULL;
    state = (SGSwipeState){false, false};
    if (!tap) {
        return;
    }
    CGEventTapEnable(tap, false);
    if (source) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
        CFRelease(source);
        source = NULL;
    }
    CFRelease(tap);
    tap = NULL;
}
