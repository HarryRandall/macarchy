// Switches Spaces with no slide by sending the Dock a synthetic trackpad
// swipe fast enough that there is nothing left to animate.
//
// Trimmed from InstantSpaceSwitcher by jurplel, MIT licensed; see README.md
// beside this folder's sources for the upstream commit and what was left out.
// Nothing here keeps state between calls apart from the natural scrolling
// preference, so the caller owns where a burst of switches is heading.

#ifndef SPACE_GESTURE_H
#define SPACE_GESTURE_H

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum {
    SGDirectionLeft = 0,
    SGDirectionRight = 1,
} SGDirection;

typedef enum {
    SGPhaseBegan = 1,
    SGPhaseChanged = 2,
    SGPhaseEnded = 4,
} SGPhase;

/// Whether this process may post events, which needs Accessibility. A tool
/// run by skhd is covered by skhd's own permission.
bool sg_can_post_events(void);

/// Asks macOS for permission to post events, showing its prompt once.
bool sg_request_post_events(void);

/// Posts `steps` switch gestures towards `direction`, back to back, for the
/// display under the pointer. The caller must not ask for more steps than
/// there are Spaces that way: overshooting on macOS 27 can leave the Dock
/// black until it times out. Returns false when an event could not be made,
/// with any earlier gestures already posted.
bool sg_switch(SGDirection direction, unsigned int steps);

/// Whether Mission Control or App Exposé is showing, read from the Dock's
/// windows. Swipes then move within the overlay instead of switching.
bool sg_overlay_open(void);

/// macOS 27 and later accept a synthetic swipe only with the raw IOHID
/// payload written into the event. ISS_FORCE_EVENT_AUGMENTATION=1 or =0
/// overrides the version check, as upstream allows.
bool sg_requires_event_augmentation(void);

// The pure parts, exposed for tests. None of them posts an event.

/// The signed progress every phase of a gesture carries on macOS 26.
double sg_swipe_progress(SGDirection direction);

/// The sign macOS 27 reads for `direction`, which flips again with natural
/// scrolling off.
double sg_modern_swipe_sign(SGDirection direction, bool naturalScrolling);

/// The swipe event before posting: the macOS 27 form, augmented, when
/// `modern` is true, otherwise the macOS 26 form. Released by the caller.
CGEventRef sg_copy_swipe_event(SGPhase phase, SGDirection direction, bool modern,
                               bool naturalScrolling, double velocity) CF_RETURNS_RETAINED;

/// The IOHID payload macOS 27 needs for `event`, in `buffer` of `capacity`
/// bytes. Returns its length, or 0 when it does not fit.
size_t sg_dock_swipe_payload(CGEventRef event, uint8_t *buffer, size_t capacity);

/// Mission Control or App Exposé, judged from a CGWindowListCopyWindowInfo
/// result.
bool sg_mission_control_in_window_list(CFArrayRef windowList);
bool sg_expose_in_window_list(CFArrayRef windowList);

// Instant trackpad swipes: the trackpad's sideways swipe between Spaces is
// caught before the Dock animates it, and the handler switches instead.

/// Called on the main thread with the direction of a swipe to switch for.
typedef void (*SGSwipeHandler)(SGDirection direction);

/// Starts catching the trackpad's sideways swipes, on the main run loop.
/// Needs Accessibility; returns false without it. Call on the main thread.
bool sg_swipe_override_start(SGSwipeHandler handler);

/// Lets swipes through to the Dock again. Call on the main thread.
void sg_swipe_override_stop(void);

/// What happens to one gesture event.
typedef enum {
    SGSwipePass = 0,
    SGSwipeSwallow = 1,
    /// Let through with its motion zeroed: on macOS 27 the Dock needs the
    /// real ended event to finish the gesture, but must not switch again.
    SGSwipePassStill = 2,
} SGSwipeAction;

/// Where one swipe has got to, between its events.
typedef struct {
    bool tracking;
    bool fired;
} SGSwipeState;

/// The fields of a gesture event the decision reads.
typedef struct {
    int64_t eventType;
    int64_t hidType;
    int64_t motion;
    int64_t phase;
    double progress;
    double velocity;
    int64_t sourcePid;
} SGSwipeEvent;

/// Decides one gesture event, for the interception and for tests.
/// `overlayOpen` is asked only as a swipe begins: one begun in Mission
/// Control or App Exposé goes to the Dock untouched. `outSwitch` is set to
/// the direction to switch, or -1 for none.
SGSwipeAction sg_swipe_decide(SGSwipeState *state, SGSwipeEvent event, bool modern,
                              bool (*overlayOpen)(void), int *outSwitch);

#endif
