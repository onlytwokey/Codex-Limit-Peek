import AppKit
import SwiftUI

struct MoreOverlayInteractionView: View {
    @ObservedObject var quotaStore: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    @Environment(\.appearanceEditorInitialScrollTarget)
    private var inheritedInitialScrollTarget
    let page: MoreOverlayPage
    let onNavigate: (
        MoreOverlayPage,
        AppearanceEditorInitialScrollTarget?
    ) -> Void
    let onOpenCustomColor: (AppearanceColorEditTarget) -> Void
    var initialScrollTarget:
        AppearanceEditorInitialScrollTarget? = nil
#if DEVELOPER_TOOLS
    var onOpenDeveloperPreview: (@MainActor () -> Void)? = nil
#endif

    private var appearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent:
                quotaStore.snapshot.remainingPercent,
            weeklyRemainingPercent:
                quotaStore.snapshot.weeklyRemainingPercent,
            isUnavailable: quotaStore.snapshot.isUnavailable
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: CGFloat(
                appearance.visuals.panelShell.cornerRadius
            ),
            style: .continuous
        )
    }

    private var resolvedInitialScrollTarget:
        AppearanceEditorInitialScrollTarget?
    {
        initialScrollTarget ?? inheritedInitialScrollTarget
    }

    var body: some View {
        pageContent
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    appearance.outlineColor.swiftUIColor,
                    lineWidth: CGFloat(
                        appearance.visuals.panelShell.outlineWidth
                    )
                )
            }
            .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .actions:
#if DEVELOPER_TOOLS
            ActionsPopover(
                store: quotaStore,
                appearanceStore: appearanceStore,
                appearance: appearance,
                onShowAppearance: { destination in
                    onNavigate(
                        destination.page,
                        destination.initialScrollTarget
                    )
                },
                onOpenDeveloperPreview: onOpenDeveloperPreview
            )
            .frame(width: MoreOverlayMetrics.actionsWidth)
#else
            ActionsPopover(
                store: quotaStore,
                appearanceStore: appearanceStore,
                appearance: appearance,
                onShowAppearance: { destination in
                    onNavigate(
                        destination.page,
                        destination.initialScrollTarget
                    )
                }
            )
            .frame(width: MoreOverlayMetrics.actionsWidth)
#endif
        case .appearance:
            AppearanceEditorView(
                store: appearanceStore,
                onBack: { onNavigate(.actions, nil) },
                onOpenCustomColor: { token in
                    onOpenCustomColor(.palette(token))
                }
            )
            .environment(
                \.appearanceEditorInitialScrollTarget,
                resolvedInitialScrollTarget
            )
        case .statusItem:
            StatusItemEditorView(
                store: appearanceStore,
                onBack: { onNavigate(.appearance, nil) },
                onOpenCustomColor: { token in
                    onOpenCustomColor(.statusItem(token))
                }
            )
            .environment(
                \.appearanceEditorInitialScrollTarget,
                resolvedInitialScrollTarget
            )
        case .stateColors:
            StateColorsEditorView(
                store: appearanceStore,
                onBack: { onNavigate(.appearance, nil) },
                onOpenCustomColor: { token in
                    onOpenCustomColor(.palette(token))
                }
            )
            .environment(
                \.appearanceEditorInitialScrollTarget,
                resolvedInitialScrollTarget
            )
        }
    }
}

struct MoreOverlayDecorationView: View {
    @ObservedObject var quotaStore: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    let contentSize: NSSize

    private var appearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent:
                quotaStore.snapshot.remainingPercent,
            weeklyRemainingPercent:
                quotaStore.snapshot.weeklyRemainingPercent,
            isUnavailable: quotaStore.snapshot.isUnavailable
        )
    }

    private var decorationChrome: ThemeChromeRecipe {
        var chrome = appearance.visuals.panelShell
        chrome.outlineWidth = 0
        return chrome
    }

    var body: some View {
        ThemeSurfaceBackground(
            appearance: appearance,
            chrome: decorationChrome,
            fill: appearance.backgroundColor,
            fillStyle: appearance.visuals.panelFill,
            gradientEnd: appearance.panelGradientEndColor
        )
        .frame(
            width: contentSize.width,
            height: contentSize.height
        )
        .padding(MoreOverlayMetrics.shadowSafetyInset)
    }
}
