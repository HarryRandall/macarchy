import SwiftUI

/// Keeps dialog content mounted until its presentation layer has faded out.
@MainActor
@Observable
final class ModalRouter {
    private(set) var content: AnyView?
    private(set) var isPresented = false
    private(set) var presentationID = 0
    private(set) var inContent = false

    func present(inContent: Bool = false, @ViewBuilder _ builder: () -> some View) {
        self.inContent = inContent
        presentationID += 1
        content = AnyView(builder())
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    func finishDismissal(for presentation: Int) {
        guard !isPresented, presentationID == presentation else { return }
        content = nil
    }
}

struct ModalHost: View {
    let router: ModalRouter
    var contentOffset: CGFloat = 0

    var body: some View {
        ZStack {
            if let content = router.content {
                ModalPresentation(
                    router: router, content: content, presentationID: router.presentationID,
                    contentOffset: router.inContent ? contentOffset : 0
                )
                .id(router.presentationID)
                // The presentation owns its animation; inserting or removing
                // its container must not inherit a page's spring transition.
                .transition(.identity)
            }
        }
    }
}

private struct ModalPresentation: View {
    let router: ModalRouter
    let content: AnyView
    let presentationID: Int
    let contentOffset: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    private let shape = RoundedRectangle(
        cornerRadius: Metrics.radiusCard, style: .continuous)

    var body: some View {
        ZStack {
            Button(action: router.dismiss) {
                Color.black.opacity(visible ? 0.32 : 0)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
            }
            .buttonStyle(ModalBackdropStyle())
            .accessibilityLabel("Close dialog")

            content
                // Keep layout and loading state out of the entrance animation.
                .transaction { $0.animation = nil }
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
                .compositingGroup()
                .opacity(visible ? 1 : 0)
                .scaleEffect(visible || reduceMotion ? 1 : 0.985)
                .offset(y: visible || reduceMotion ? 0 : 8)
                .offset(x: contentOffset)
                .allowsHitTesting(router.isPresented)
                .onExitCommand(perform: router.dismiss)
        }
        .task {
            // Mount the final layout at zero opacity before beginning its fade.
            await Task.yield()
            guard !Task.isCancelled, router.isPresented else { return }
            withAnimation(.easeOut(duration: 0.28)) { visible = true }
        }
        .onChange(of: router.isPresented) { _, presented in
            guard !presented else { return }
            withAnimation(.easeInOut(duration: 0.22), completionCriteria: .removed) {
                visible = false
            } completion: {
                router.finishDismissal(for: presentationID)
            }
        }
    }
}

/// A backdrop must keep its current opacity while pressed. The standard
/// plain button style changes its label's opacity before the fade starts.
private struct ModalBackdropStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
