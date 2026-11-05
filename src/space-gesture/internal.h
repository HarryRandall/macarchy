// Undocumented CGEvent fields a Dock swipe uses, as InstantSpaceSwitcher
// found them. Shared by the two sources in this target only.

#ifndef SPACE_GESTURE_INTERNAL_H
#define SPACE_GESTURE_INTERNAL_H

#include <ApplicationServices/ApplicationServices.h>

static const CGEventField kSGFieldEventType = (CGEventField)55;
static const CGEventField kSGFieldGestureHIDType = (CGEventField)110;
static const CGEventField kSGFieldSwipeMask = (CGEventField)115;
static const CGEventField kSGFieldSwipeMotion = (CGEventField)123;
static const CGEventField kSGFieldSwipeProgress = (CGEventField)124;
static const CGEventField kSGFieldSwipePositionX = (CGEventField)125;
static const CGEventField kSGFieldSwipePositionY = (CGEventField)126;
static const CGEventField kSGFieldSwipeVelocityX = (CGEventField)129;
static const CGEventField kSGFieldSwipeVelocityY = (CGEventField)130;
static const CGEventField kSGFieldGesturePhase = (CGEventField)132;
static const CGEventField kSGFieldGesturePhaseAlias = (CGEventField)134;
static const CGEventField kSGFieldZoomDeltaY = (CGEventField)138;
static const CGEventField kSGFieldSourceProcessIDAlias = (CGEventField)169;

/// The swipe with the macOS 27 payload appended, or NULL when the event's
/// serialised form is not one this understands. Released by the caller.
CGEventRef sg_augment_dock_swipe(CGEventRef event);

#endif
