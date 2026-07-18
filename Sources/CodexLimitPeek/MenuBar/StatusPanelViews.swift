import AppKit
import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var store: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var moreOverlayPresenter: MoreOverlayPresenter

    private var appearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent: store.snapshot.remainingPercent,
            weeklyRemainingPercent: store.snapshot.weeklyRemainingPercent,
            isUnavailable: store.snapshot.isUnavailable
        )
    }

    var body: some View {
        ThemePanelComposition(
            appearance: appearance,
            data: displayData,
            headerForeground: (
                store.refreshHealth.showsFailurePattern
                    ? appearance.unavailableStripeColor
                    : appearance.backgroundTextColor
            ).swiftUIColor,
            showsOuterChrome: false
        ) {
            HStack(spacing: 8) {
                RefreshIconButton(appearance: appearance) {
                    store.refresh()
                }

                MoreActionsMenu(
                    store: store,
                    appearanceStore: appearanceStore,
                    appearance: appearance,
                    moreOverlayPresenter: moreOverlayPresenter
                )
            }
        }
        .frame(
            width: PanelMetrics.cardWidth,
            height: PanelMetrics.cardHeight
        )
    }

    private var headerText: String {
        QuotaStatusFormatter.header(
            snapshot: store.snapshot,
            health: store.refreshHealth,
            confirmationAttempt: store.confirmationAttempt
        )
    }

    private var displayData: ThemePanelDisplayData {
        ThemePanelDisplayData(
            headerText: headerText,
            percentText: store.snapshot.percentText,
            primaryQuotaLabel: store.snapshot.primaryQuotaLabel,
            shortResetText: store.snapshot.shortResetText,
            primaryResetDetailText: store.snapshot.primaryResetDetailText,
            displayRemainingPercent: store.snapshot.displayRemainingPercent,
            showsSecondaryQuota: store.snapshot.showsSecondaryQuota,
            weeklyPercentText: store.snapshot.weeklyPercentText,
            weeklyResetDateText: store.snapshot.weeklyResetDateText
        )
    }
}

struct StatusPanelShadowView: View {
    @ObservedObject var store: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore

    private var appearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent: store.snapshot.remainingPercent,
            weeklyRemainingPercent: store.snapshot.weeklyRemainingPercent,
            isUnavailable: store.snapshot.isUnavailable
        )
    }

    var body: some View {
        PanelGlassBackground(appearance: appearance)
            .frame(
                width: PanelMetrics.cardWidth,
                height: PanelMetrics.cardHeight
            )
            .padding(PanelMetrics.shadowInset)
            .frame(
                width: PanelMetrics.shadowWidth,
                height: PanelMetrics.shadowHeight
            )
    }
}

struct PanelGlassBackground: View {
    let appearance: ResolvedPanelAppearance
    var includesShadow = true

    private var shell: ThemeChromeRecipe {
        var shell = appearance.visuals.panelShell
        if !includesShadow {
            shell.shadow = .none
        }
        return shell
    }

    var body: some View {
        ThemeSurfaceBackground(
            appearance: appearance,
            chrome: shell,
            fill: appearance.backgroundColor,
            fillStyle: appearance.visuals.panelFill,
            gradientEnd: appearance.panelGradientEndColor,
            rendersHardShadowExplicitly: includesShadow
        )
    }
}

private extension View {
    func themedIconSurface(
        _ appearance: ResolvedPanelAppearance,
        isPressed: Bool,
        isHovered: Bool
    ) -> some View {
        var chrome = appearance.visuals.actionButton
        if isPressed {
            chrome.shadow = .none
        }
        return themeSurface(
            appearance: appearance,
            chrome: chrome,
            fill: appearance.actionAccentColor
        )
            .offset(y: isPressed ? 1 : (isHovered ? -0.5 : 0))
    }
}

struct RefreshIconButton: View {
    let appearance: ResolvedPanelAppearance
    let action: () -> Void
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            PanelIconFrame(
                systemImage: "arrow.clockwise",
                appearance: appearance,
                isPressed: isPressed,
                isHovered: isHovered
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.08)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isPressed == false {
                        withAnimation(.easeOut(duration: 0.035)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.72)) {
                        isPressed = false
                    }
                }
        )
        .help("刷新")
    }
}

struct PanelIconFrame: View {
    let systemImage: String
    let appearance: ResolvedPanelAppearance
    var isPressed = false
    var isHovered = false

    var body: some View {
        Image(systemName: systemImage)
            .font(
                .system(
                    size: CGFloat(
                        ThemePanelLayout.actionIconSize
                            * appearance.geometry.fontScale
                    ),
                    weight: .black
                )
            )
            .frame(
                width: ThemePanelLayout.actionSize,
                height: ThemePanelLayout.actionSize
            )
            .contentShape(Rectangle())
            .foregroundStyle(
                appearance.outlineColor.readable(
                    on: appearance.actionAccentColor
                        .composited(over: appearance.backgroundColor)
                        .composited(over: .white)
                ).swiftUIColor
            )
            .themedIconSurface(
                appearance,
                isPressed: isPressed,
                isHovered: isHovered
            )
    }
}

struct MoreActionsMenu: View {
    @ObservedObject var store: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    let appearance: ResolvedPanelAppearance
    @ObservedObject var moreOverlayPresenter: MoreOverlayPresenter
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button {
            moreOverlayPresenter.toggle()
        } label: {
            PanelIconFrame(
                systemImage: "ellipsis",
                appearance: appearance,
                isPressed:
                    isPressed || moreOverlayPresenter.isPresented,
                isHovered:
                    isHovered || moreOverlayPresenter.isPresented
            )
        }
        .buttonStyle(.plain)
        .background {
            MoreOverlayAnchorReader { anchor in
                moreOverlayPresenter.setAnchorView(anchor)
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.08)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isPressed == false {
                        withAnimation(.easeOut(duration: 0.035)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.72)) {
                        isPressed = false
                    }
                }
        )
        .help("更多")
        .accessibilityLabel("更多")
    }
}

struct ActionsPopover: View {
    @ObservedObject var store: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    let appearance: ResolvedPanelAppearance
    let onShowAppearance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                store.toggleVoiceBroadcast()
            } label: {
                ActionMenuRow(
                    systemImage: store.voiceBroadcastEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    title: store.voiceBroadcastEnabled ? "关闭播报" : "开启播报",
                    trailing: store.voiceBroadcastEnabled ? nil : "\(store.voiceBroadcastIntervalMinutes) 分钟",
                    appearance: appearance
                )
            }
            .buttonStyle(.plain)

            if store.voiceBroadcastEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("播报间隔")
                        .font(
                            .system(
                                size: CGFloat(
                                    11 * appearance.geometry.fontScale
                                ),
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            appearance.backgroundTextColor.swiftUIColor
                                .opacity(0.72)
                        )
                        .padding(.horizontal, 6)

                    BroadcastIntervalButton(
                        minutes: 1,
                        store: store,
                        appearance: appearance
                    )
                    BroadcastIntervalButton(
                        minutes: 5,
                        store: store,
                        appearance: appearance
                    )
                    BroadcastIntervalButton(
                        minutes: 10,
                        store: store,
                        appearance: appearance
                    )
                }
            }

            Divider()

            Button {
                withAnimation(.easeOut(duration: 0.12)) {
                    onShowAppearance()
                }
            } label: {
                ActionMenuRow(
                    systemImage: "paintpalette.fill",
                    title: "外观",
                    trailing: appearanceStore.selectedTheme.displayName,
                    appearance: appearance
                )
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                ActionMenuRow(
                    systemImage: "power",
                    title: "退出应用",
                    trailing: nil,
                    appearance: appearance
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
    }
}

struct BroadcastIntervalButton: View {
    let minutes: Int
    @ObservedObject var store: QuotaStore
    let appearance: ResolvedPanelAppearance

    var body: some View {
        Button {
            store.setVoiceBroadcastInterval(minutes: minutes)
        } label: {
            ActionMenuRow(
                systemImage: store.voiceBroadcastIntervalMinutes == minutes ? "checkmark.circle.fill" : "circle",
                title: "\(minutes) 分钟",
                trailing: nil,
                appearance: appearance
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActionMenuRow: View {
    let systemImage: String
    let title: String
    let trailing: String?
    let appearance: ResolvedPanelAppearance

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(
                    .system(
                        size: CGFloat(
                            13 * appearance.geometry.fontScale
                        ),
                        weight: .bold
                    )
                )
                .frame(width: 18)
            Text(title)
                .font(
                    .system(
                        size: CGFloat(
                            13 * appearance.geometry.fontScale
                        ),
                        weight: .semibold
                    )
                )
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(
                        .system(
                            size: CGFloat(
                                11 * appearance.geometry.fontScale
                            ),
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        appearance.textColor.swiftUIColor.opacity(0.72)
                    )
            }
        }
        .foregroundStyle(appearance.textColor.swiftUIColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .themeSurface(
            appearance: appearance,
            chrome: appearance.visuals.menuRow,
            fill: appearance.surfaceColor
        )
    }
}
