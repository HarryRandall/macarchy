import SwiftUI
import Macarchy

struct RootView: View {
    @Environment(AppModel.self) private var model

    /// Layout follows this, not `@AppStorage` directly. A change written
    /// straight to stored defaults comes back through UserDefaults on its own,
    /// outside the transaction that asked for it, so `withAnimation` had
    /// nothing to animate and the collapse always snapped.
    @State private var sidebarVisible =
        UserDefaults.standard.object(forKey: "sidebarVisible") as? Bool ?? true
    /// Whether the window is wide enough to show the console beside a pane.
    @State private var hasRoomForPanel = true

    /// Wide enough for a 20 pt glyph and its highlight, and no wider.
    static let railWidth: CGFloat = 56
    /// Room across the top-left corner for the close, minimise and zoom
    /// buttons, which `TrafficLights` lays out inside it.
    static let trafficLightGutter: CGFloat = 78
    /// Where the button row starts, matching the system's own inset.
    private static let trafficLightLeading: CGFloat = 20

    var body: some View {
        // The sidebar runs the full height of the window, so its edge is one
        // line from top to bottom and the lights sit on the sidebar itself
        // rather than on a strip laid across everything.
        HStack(spacing: 0) {
            Sidebar(isVisible: $sidebarVisible)
                .frame(
                    width: sidebarVisible
                        ? DesignSettings.shared.values.sidebarWidth : Self.railWidth
                )
                // A frame does not clip. Mid-collapse the sidebar's contents
                // are still laid out at the old width, and the overflow — row
                // labels, the rules between groups — was drawing across the
                // pane beside it.
                .clipped()
            VStack(spacing: 0) {
                ContentBar()
                // On a narrow window the console takes the pane rather than
                // squeezing a column in beside it.
                if model.showingSetup {
                    SetupView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else if model.consoleOpen, !hasRoomForPanel {
                    ConsolePanel(asPage: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .id(model.selection)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 6)),
                                removal: .opacity))
                }
                if let error = DesignSettings.shared.reloadError {
                    Text(error).font(.meta).foregroundStyle(.orange).padding(Metrics.small)
                }
            }
            if model.consoleOpen, hasRoomForPanel {
                ConsolePanel()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: { width in
            hasRoomForPanel = width >= ConsolePanel.minimumWidthForPanel
        }
        .overlay(alignment: .topLeading) { corner }
        .ignoresSafeArea(.container, edges: .top)
        .motion(Motion.snappy, value: model.consoleOpen)
        .motion(Motion.smooth, value: model.selection)
        .tint(model.interfaceAccent)
        .frame(minWidth: 720, minHeight: 600)
        // The page behind a dialog must not respond to hover or gestures.
        .allowsHitTesting(model.modal.content == nil)
        .overlay(ModalHost(router: model.modal, contentOffset: searchOffset))
        .hoverHelpHost()
        .background(WindowRefresh().frame(width: 0, height: 0))
        .onChange(of: sidebarVisible) { _, isVisible in
            UserDefaults.standard.set(isVisible, forKey: "sidebarVisible")
        }
        .task { await DesignSettings.shared.watch() }
    }

    /// The top-left box: the window's buttons at the leading edge and the
    /// controls that act on the pane gathered against the sidebar's line.
    ///
    /// Its width is the sidebar's open width whether the sidebar is open or
    /// not, so collapsing takes the line away without shifting a single
    /// button sideways.
    private var corner: some View {
        HStack(spacing: 2) {
            Color.clear
                .frame(width: Self.trafficLightGutter)
                .background(TrafficLights(leading: Self.trafficLightLeading))

            Spacer(minLength: Metrics.small)

            SidebarToggle(isVisible: $sidebarVisible)
            BarButton(
                symbol: "arrow.left", help: "Back", enabled: model.canGoBack,
                action: model.goBack)
            BarButton(
                symbol: "arrow.right", help: "Forward", enabled: model.canGoForward,
                action: model.goForward)
        }
        .padding(.trailing, Metrics.small)
        .frame(width: cornerWidth, height: ContentBar.height)
    }

    /// Open, the box is as wide as the sidebar, so the controls sit against
    /// its line. Collapsed, there is no line to sit against, so it shrinks to
    /// what it holds and the controls come back towards the lights — the
    /// width is animated, so they slide rather than jump.
    private var cornerWidth: CGFloat {
        sidebarVisible
            ? DesignSettings.shared.values.sidebarWidth
            : Self.trafficLightGutter + Self.controlsWidth + Metrics.small * 2
    }

    private var searchOffset: CGFloat {
        let sidebar = sidebarVisible ? DesignSettings.shared.values.sidebarWidth : Self.railWidth
        let console: CGFloat = model.consoleOpen && hasRoomForPanel ? ConsolePanel.width : 0
        return (sidebar - console) / 2
    }

    /// Three 28 pt buttons with 2 pt between them.
    private static let controlsWidth: CGFloat = 28 * 3 + 2 * 2

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .home: HomePane()
        case .workshop: WorkshopPane()
        case .plugins: PluginsPane()
        case .layout: LayoutPane()
        case .themes: ThemesPane()
        case .advanced: AdvancedPane()
        case .borders: BordersPane()
        case .menuBar: MenuBarPane()
        case .rules: RulesPane()
        case .shortcuts: ShortcutsPane()
        case .health: HealthPane()
        case .report: ReportPane()
        case nil: ContentUnavailableView("Select a section", systemImage: "sidebar.left")
        }
    }
}

/// The plain glyph button the bar is made of: one size, one hit area, one
/// look whether it is enabled or not.
struct BarButton: View {
    let symbol: String
    let help: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(Motion.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall))
        }
        .buttonStyle(BarButtonStyle())
        .focusEffectDisabled()
        .disabled(!enabled)
        .hoverHelp(help)
        .accessibilityLabel(help)
    }
}

private struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Binding var isVisible: Bool
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The lights are drawn over this, by the root view.
            Color.clear.frame(height: ContentBar.height)
            header
            navigation
            Spacer(minLength: 0)
        }
        .background(.bar)
        // Collapsed, the lights sit across where this line would run, so it
        // starts below the bar instead of cutting between them.
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.cardBorder)
                .frame(width: 1)
                .padding(.top, isVisible ? 0 : ContentBar.height)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onMoveCommand(perform: move)
        .accessibilityLabel("Sections")
    }

    /// The app's name and the control that collapses the list sit above the
    /// list itself, rather than in the window's bar, where they read as a
    /// heading for the navigation instead of as chrome.
    private var header: some View {
        HStack(spacing: Metrics.small) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 14))
                .foregroundStyle(model.interfaceAccent)
                .frame(width: 20)
            if isVisible {
                Text("Macarchy")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Metrics.small)
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: isVisible ? .leading : .center)
    }

    private var navigation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.large) {
                VStack(spacing: 2) {
                    ForEach(Pane.overview) { pane in row(pane) }
                }
                ForEach(Pane.Group.allCases) { group in
                    VStack(alignment: .leading, spacing: Metrics.xs) {
                        groupLabel(group)
                        VStack(spacing: 2) {
                            ForEach(group.panes) { pane in row(pane) }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.small)
            .padding(.top, Metrics.medium)
            .padding(.bottom, Metrics.small)
        }
        .scrollIndicators(.never)
    }

    /// The heading and the rule that replaces it share one slot, so collapsing
    /// crossfades instead of reflowing the whole list.
    private func groupLabel(_ group: Pane.Group) -> some View {
        ZStack(alignment: .leading) {
            Text(group.rawValue.uppercased())
                .eyebrowStyle()
                .padding(.horizontal, Metrics.medium)
                .opacity(isVisible ? 1 : 0)
            Divider()
                .padding(.horizontal, Metrics.medium)
                .opacity(isVisible ? 0 : 1)
        }
        .frame(height: 14)
    }

    private func row(_ pane: Pane) -> some View {
        let isSelected = model.selection == pane
        return Button {
            withAnimation(Motion.snappy) { model.selection = pane }
            focused = true
        } label: {
            HStack(spacing: Metrics.small) {
                Image(systemName: pane.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? model.interfaceAccent : .secondary)
                    .frame(width: 20)
                // The label leaves the layout in the rail rather than being
                // hidden inside it. Keeping it with `fixedSize` forced its full
                // width into a 56 pt row, which pushed the icon past the clip
                // and left the collapsed sidebar looking empty.
                if isVisible {
                    Text(pane.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.primary : .secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Metrics.small)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: isVisible ? .leading : .center)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
                        .fill(model.interfaceAccent.opacity(0.20))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusControl))
        .hoverHelp(pane.title, enabled: !isVisible && !isSelected, placement: .right)
        .accessibilityLabel(pane.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Arrow keys walk the list the way they do in a system sidebar.
    private func move(_ direction: MoveCommandDirection) {
        let order = Pane.navigationOrder
        guard let current = model.selection, let index = order.firstIndex(of: current) else {
            model.selection = order.first
            return
        }
        withAnimation(Motion.snappy) {
            switch direction {
            case .up where index > 0: model.selection = order[index - 1]
            case .down where index < order.count - 1: model.selection = order[index + 1]
            default: break
            }
        }
    }
}
