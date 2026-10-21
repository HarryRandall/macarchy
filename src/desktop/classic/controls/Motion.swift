import SwiftUI

/// The app's motion vocabulary.
///
/// Four curves, named by what they are for, all under 400 ms. Springs are the
/// default because they absorb interruption: a card that is still settling
/// when you move away should bend toward the new state rather than restart.
///
/// Everything here collapses to `nil` under Reduce Motion, so a single check
/// at the call site is enough.
enum Motion {
    /// State that flips: selection, expansion, a filter change.
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.85)
    /// Pointer feedback. Short enough to feel attached to the cursor.
    static let hover = Animation.easeOut(duration: 0.14)
    /// Content arriving or leaving.
    static let smooth = Animation.spring(response: 0.42, dampingFraction: 0.9)
    /// A deliberate flourish: a value landing, a success.
    static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.62)

    /// Stagger step between neighbouring items in a list or grid.
    static let stagger: Double = 0.028
    /// Items past this index arrive together, so a long grid never crawls.
    static let staggerCap = 12
}

extension View {
    /// Applies an animation unless the reader has asked for less motion.
    func motion<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }

    /// Lifts a card toward the reader under the pointer.
    ///
    /// Scale is kept tiny on purpose — a grid of cards that jump reads as
    /// noise. The shadow does most of the work.
    func hoverLift(scale: CGFloat = 1.012, lift: CGFloat = 2) -> some View {
        modifier(HoverLift(scale: scale, lift: lift))
    }

    /// Fades and rises into place, offset by position so a grid arrives as a
    /// wave rather than all at once.
    func appearStagger(_ index: Int) -> some View {
        modifier(AppearStagger(index: index))
    }

    /// A subtle pulse, for a value that changed because of something offscreen.
    func attentionPulse(_ trigger: some Equatable) -> some View {
        modifier(AttentionPulse(trigger: AnyHashableEquatable(trigger)))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    let animation: Animation?
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

private struct HoverLift: ViewModifier {
    let scale: CGFloat
    let lift: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering && !reduceMotion ? scale : 1, anchor: .center)
            .offset(y: hovering && !reduceMotion ? -lift : 0)
            .shadow(
                color: .black.opacity(hovering ? 0.22 : 0),
                radius: hovering ? 14 : 0,
                y: hovering ? 6 : 0
            )
            .animation(reduceMotion ? nil : Motion.hover, value: hovering)
            .onHover { hovering = $0 }
    }
}

private struct AppearStagger: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            // Animate the entrance, not the content's layout constraints.
            .transaction { $0.animation = nil }
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .animation(reduceMotion ? nil : Motion.smooth, value: shown)
            .task {
                guard !shown else { return }
                guard !reduceMotion else {
                    shown = true
                    return
                }
                let step = Double(min(index, Motion.staggerCap)) * Motion.stagger
                do { try await Task.sleep(for: .seconds(step)) } catch { return }
                guard !Task.isCancelled else { return }
                shown = true
            }
    }
}

private struct AttentionPulse: ViewModifier {
    let trigger: AnyHashableEquatable
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.phaseAnimator([1.0, 1.08, 1.0], trigger: trigger) { view, phase in
            view.scaleEffect(reduceMotion ? 1 : phase)
        } animation: { _ in
            reduceMotion ? nil : Motion.bouncy
        }
    }
}

/// Lets `attentionPulse` take any equatable trigger without making the
/// modifier generic at every call site.
private struct AnyHashableEquatable: Equatable {
    private let value: AnyHashable

    init(_ value: some Equatable) {
        self.value = AnyHashable(String(describing: value))
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.value == rhs.value }
}
