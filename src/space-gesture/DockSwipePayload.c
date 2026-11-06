// From InstantSpaceSwitcher's event_serialize.c, MIT licensed,
// Copyright (c) 2026 jurplel. See README.md for the full notice.
//
// macOS 27 ignores a synthetic Dock swipe unless the event carries the
// IOHID fluid gesture a real trackpad sends. CGEvent has no public field for
// it, so the event's serialised form gets one more tagged field appended
// and is read back. The layouts below are undocumented and checked here
// only by size, so a macOS update can change them.

#include "SpaceGesture.h"
#include "internal.h"

#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

#pragma pack(push, 1)

typedef struct {
    uint32_t size;
    uint32_t type;
    uint32_t options;
    uint8_t depth;
    uint8_t reserved[3];
} IOHIDEventBase;

typedef struct {
    IOHIDEventBase base;
    int32_t positionX;
    int32_t positionY;
    int32_t positionZ;
    uint32_t swipeMask;
    uint16_t gestureMotion;
    uint16_t gestureFlavor;
    int32_t swipeProgress;
} IOHIDFluidTouchGestureData;

typedef struct {
    IOHIDEventBase base;
    int32_t velocityX;
    int32_t velocityY;
    int32_t velocityZ;
} IOHIDVelocityEventData;

typedef struct {
    uint64_t timestamp;
    uint64_t senderID;
    uint32_t options;
    uint32_t attributeLength;
    uint32_t eventCount;
} IOHIDSystemQueueElementHeader;

#pragma pack(pop)

_Static_assert(sizeof(IOHIDEventBase) == 16, "unexpected IOHID event base layout");
_Static_assert(sizeof(IOHIDFluidTouchGestureData) == 40, "unexpected IOHID fluid gesture layout");
_Static_assert(sizeof(IOHIDVelocityEventData) == 28, "unexpected IOHID velocity layout");
_Static_assert(sizeof(IOHIDSystemQueueElementHeader) == 28, "unexpected IOHID queue header layout");

static const uint32_t kIOHIDEventTypeVelocity = 9;
static const uint32_t kIOHIDEventTypeFluidTouchGesture = 23;
static const uint16_t kIOHIDGestureFlavorDockPrimary = 3;
// The serialised field that carries the payload.
static const uint16_t kPayloadFieldID = 4205;

// The smallest non-zero value stays non-zero, so a tiny progress keeps its
// direction.
static int32_t fixed1616(double value) {
    int32_t fixed = (int32_t)(value * 65536.0);
    if (fixed == 0 && value != 0.0) {
        return value > 0.0 ? 1 : -1;
    }
    return fixed;
}

size_t sg_dock_swipe_payload(CGEventRef event, uint8_t *buffer, size_t capacity) {
    int64_t phase = CGEventGetIntegerValueField(event, kSGFieldGesturePhase);
    int64_t motion = CGEventGetIntegerValueField(event, kSGFieldSwipeMotion);
    double progress = CGEventGetDoubleValueField(event, kSGFieldSwipeProgress);
    double positionX = CGEventGetDoubleValueField(event, kSGFieldSwipePositionX);
    double positionY = CGEventGetDoubleValueField(event, kSGFieldSwipePositionY);
    double velocityX = CGEventGetDoubleValueField(event, kSGFieldSwipeVelocityX);
    double velocityY = CGEventGetDoubleValueField(event, kSGFieldSwipeVelocityY);
    int64_t swipeMask = CGEventGetIntegerValueField(event, kSGFieldSwipeMask);

    bool withVelocity = velocityX != 0.0 || velocityY != 0.0 || phase == SGPhaseEnded;
    size_t length = sizeof(IOHIDSystemQueueElementHeader) + sizeof(IOHIDFluidTouchGestureData);
    if (withVelocity) {
        length += sizeof(IOHIDVelocityEventData);
    }
    if (!buffer || capacity < length) {
        return 0;
    }
    memset(buffer, 0, length);

    IOHIDSystemQueueElementHeader header = {0};
    header.timestamp = CGEventGetTimestamp(event);
    if (header.timestamp == 0) {
        header.timestamp = mach_absolute_time();
    }
    header.eventCount = withVelocity ? 2 : 1;
    memcpy(buffer, &header, sizeof(header));

    IOHIDFluidTouchGestureData fluid = {0};
    fluid.base.size = sizeof(IOHIDFluidTouchGestureData);
    fluid.base.type = kIOHIDEventTypeFluidTouchGesture;
    fluid.base.options = (uint32_t)((phase & 0xFF) << 24);
    fluid.positionX = fixed1616(positionX);
    fluid.positionY = fixed1616(positionY);
    fluid.swipeMask = (uint32_t)swipeMask;
    fluid.gestureMotion = (uint16_t)motion;
    fluid.gestureFlavor = kIOHIDGestureFlavorDockPrimary;
    fluid.swipeProgress = fixed1616(progress);
    memcpy(buffer + sizeof(header), &fluid, sizeof(fluid));

    if (withVelocity) {
        IOHIDVelocityEventData velocity = {0};
        velocity.base.size = sizeof(IOHIDVelocityEventData);
        velocity.base.type = kIOHIDEventTypeVelocity;
        velocity.base.depth = 1;
        velocity.velocityX = fixed1616(velocityX);
        velocity.velocityY = fixed1616(velocityY);
        memcpy(buffer + sizeof(header) + sizeof(fluid), &velocity, sizeof(velocity));
    }
    return length;
}

CGEventRef sg_augment_dock_swipe(CGEventRef event) {
    if (!event) {
        return NULL;
    }
    CFDataRef data = CGEventCreateData(kCFAllocatorDefault, event);
    if (!data) {
        return NULL;
    }
    const uint8_t *bytes = CFDataGetBytePtr(data);
    CFIndex length = CFDataGetLength(data);

    // Only format version 2 is understood: the first four bytes 00 00 00 02.
    if (length < 4 || bytes[0] != 0 || bytes[1] != 0 || bytes[2] != 0 || bytes[3] != 2) {
        CFRelease(data);
        return NULL;
    }

    uint8_t payload[128];
    size_t payloadLength = sg_dock_swipe_payload(event, payload, sizeof(payload));
    CFMutableDataRef augmented = payloadLength == 0 ? NULL : CFDataCreateMutableCopy(kCFAllocatorDefault, 0, data);
    CFRelease(data);
    if (!augmented) {
        return NULL;
    }

    // A tag of two big-endian words, the payload's length and the field it
    // fills, then the payload itself.
    const uint8_t tag[4] = {
        (uint8_t)((payloadLength >> 8) & 0xFF), (uint8_t)(payloadLength & 0xFF),
        (uint8_t)((kPayloadFieldID >> 8) & 0xFF), (uint8_t)(kPayloadFieldID & 0xFF),
    };
    CFDataAppendBytes(augmented, tag, sizeof(tag));
    CFDataAppendBytes(augmented, payload, (CFIndex)payloadLength);

    CGEventRef result = CGEventCreateFromData(kCFAllocatorDefault, augmented);
    CFRelease(augmented);
    return result;
}

bool sg_requires_event_augmentation(void) {
    // The answer never changes while running, so a race only repeats the check.
    static _Atomic int cached = -1;
    if (cached != -1) {
        return cached == 1;
    }
    const char *forced = getenv("ISS_FORCE_EVENT_AUGMENTATION");
    if (forced) {
        cached = strcmp(forced, "1") == 0 ? 1 : 0;
        return cached == 1;
    }
    char version[32] = {0};
    size_t size = sizeof(version);
    int major = 0;
    if (sysctlbyname("kern.osproductversion", version, &size, NULL, 0) != 0
        || sscanf(version, "%d", &major) != 1) {
        cached = 0;
        return false;
    }
    cached = major >= 27 ? 1 : 0;
    return cached == 1;
}
