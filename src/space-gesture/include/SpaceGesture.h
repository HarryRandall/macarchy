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

#endif
