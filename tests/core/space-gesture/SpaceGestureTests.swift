import CoreGraphics
import Foundation
import SpaceGesture
import Testing

/// The parts of the Space gesture that build events without posting them.
/// Nothing here reaches the Dock.
struct SpaceGestureTests {
    private let tiny = 0.000016

    @Test func progressKeepsDirectionAndStaysTiny() {
        #expect(sg_swipe_progress(SGDirectionRight) == tiny)
        #expect(sg_swipe_progress(SGDirectionLeft) == -tiny)
    }

    @Test func modernSignIsNegativeForRightAndFlipsWithoutNaturalScrolling() {
        #expect(sg_modern_swipe_sign(SGDirectionRight, true) == -1)
        #expect(sg_modern_swipe_sign(SGDirectionLeft, true) == 1)
        #expect(sg_modern_swipe_sign(SGDirectionRight, false) == 1)
        #expect(sg_modern_swipe_sign(SGDirectionLeft, false) == -1)
    }

    @Test func legacySwipeCarriesSignedVelocityOnEveryPhase() throws {
        for phase in [SGPhaseBegan, SGPhaseChanged, SGPhaseEnded] {
            let left = try #require(sg_copy_swipe_event(phase, SGDirectionLeft, false, true, 4000))
            #expect(left.getIntegerValueField(try field(132)) == Int64(phase.rawValue))
            #expect(left.getIntegerValueField(try field(55)) == 30)
            #expect(left.getDoubleValueField(try field(129)) == -4000)
            // The event keeps it as a float.
            #expect(abs(left.getDoubleValueField(try field(124)) + tiny) < 1e-9)
        }
    }

    @Test func modernEndedPayloadHoldsTheGestureAndTheFling() throws {
        let event = try modern(SGPhaseEnded, SGDirectionRight)
        let payload = try #require(Self.payload(of: event))
        // Queue header, fluid gesture, velocity.
        #expect(payload.count == 28 + 40 + 28)
        #expect(payload.uint32(at: 24) == 2)

        let fluid = 28
        #expect(payload.uint32(at: fluid) == 40)
        #expect(payload.uint32(at: fluid + 4) == 23)
        #expect(payload.uint32(at: fluid + 8) == UInt32(SGPhaseEnded.rawValue) << 24)
        #expect(payload.int32(at: fluid + 16) == Int32(0.1 * 65536))
        #expect(payload.uint16(at: fluid + 32) == 1)
        #expect(payload.uint16(at: fluid + 34) == 3)
        // Too small for 16.16, so it rounds away from zero to keep its sign.
        #expect(payload.int32(at: fluid + 36) == -1)

        let velocity = fluid + 40
        #expect(payload.uint32(at: velocity) == 28)
        #expect(payload.uint32(at: velocity + 4) == 9)
        #expect(payload[velocity + 12] == 1)
        #expect(payload.int32(at: velocity + 16) == Int32(-9999 * 65536))
    }

    @Test func modernBeganPayloadHasNoVelocity() throws {
        let payload = try #require(Self.payload(of: try modern(SGPhaseBegan, SGDirectionLeft)))
        #expect(payload.count == 28 + 40)
        #expect(payload.uint32(at: 24) == 1)
        #expect(payload.int32(at: 28 + 36) == 1)
    }

    @Test func payloadRefusesABufferTooSmall() throws {
        let event = try modern(SGPhaseEnded, SGDirectionRight)
        var buffer = [UInt8](repeating: 0, count: 95)
        #expect(sg_dock_swipe_payload(event, &buffer, buffer.count) == 0)
    }

    /// The augmented event must still carry the appended field once macOS
    /// has read it back, or the Dock never sees the gesture.
    @Test func augmentedEventKeepsThePayloadField() throws {
        let event = try modern(SGPhaseEnded, SGDirectionRight)
        let data = try #require(event.data as Data?)
        // 96 bytes long, field 4205, both big-endian.
        let tag: [UInt8] = [0x00, 0x60, 0x10, 0x6D]
        #expect(data.range(of: Data(tag)) != nil)
    }

    @Test func overlaysAreToldApartByTheDockLayers() {
        let normal = [Self.dock(-2_147_483_624), Self.dock(-2_147_483_624)]
        #expect(!sg_mission_control_in_window_list(normal as CFArray))
        #expect(!sg_expose_in_window_list(normal as CFArray))

        let expose = [Self.dock(20), Self.dock(20), Self.dock(18), Self.dock(18)]
        #expect(sg_expose_in_window_list(expose as CFArray))
        #expect(!sg_mission_control_in_window_list(expose as CFArray))

        let missionControl = [Self.dock(20), Self.dock(20), Self.dock(20), Self.dock(18)]
        #expect(sg_mission_control_in_window_list(missionControl as CFArray))
        #expect(!sg_expose_in_window_list(missionControl as CFArray))

        let others: [[String: Any]] = [
            ["kCGWindowOwnerName": "WindowServer", "kCGWindowLayer": 18],
            ["kCGWindowOwnerName": "WindowServer", "kCGWindowLayer": 20]
        ]
        #expect(!sg_mission_control_in_window_list(others as CFArray))
        #expect(!sg_expose_in_window_list(others as CFArray))
        #expect(!sg_expose_in_window_list([Self.dock(20), Self.dock(20)] as CFArray))
    }

    /// An undocumented field, by the number `internal.h` gives it.
    private func field(_ number: UInt32) throws -> CGEventField {
        try #require(CGEventField(rawValue: number))
    }

    private func modern(_ phase: SGPhase, _ direction: SGDirection) throws -> CGEvent {
        try #require(sg_copy_swipe_event(phase, direction, true, true, 0))
    }

    private static func payload(of event: CGEvent) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: 128)
        let length = sg_dock_swipe_payload(event, &buffer, buffer.count)
        return length == 0 ? nil : Array(buffer.prefix(length))
    }

    private static func dock(_ layer: Int) -> [String: Any] {
        ["kCGWindowOwnerName": "Dock", "kCGWindowLayer": layer]
    }
}

extension [UInt8] {
    fileprivate func uint16(at offset: Int) -> UInt16 {
        withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
    }

    fileprivate func uint32(at offset: Int) -> UInt32 {
        withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }

    fileprivate func int32(at offset: Int) -> Int32 {
        withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) }
    }
}
