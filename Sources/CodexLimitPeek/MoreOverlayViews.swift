import AppKit
import SwiftUI

struct MoreOverlayInteractionView: View {
    @ObservedObject var quotaStore: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    let page: MoreOverlayPage
    let onNavigate: (MoreOverlayPage) -> Void
    let onOpenCustomColor: (AppearanceColorToken) -> Void

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
            ActionsPopover(
                store: quotaStore,
                appearanceStore: appearanceStore,
                appearance: appearance,
                onShowAppearance: {
                    onNavigate(.appearance)
                }
            )
            .frame(width: MoreOverlayMetrics.actionsWidth)
        case .appearance:
            AppearanceEditorView(
                store: appearanceStore,
                onBack: { onNavigate(.actions) },
                onStatusItem: { onNavigate(.statusItem) },
                onStateColors: { onNavigate(.stateColors) },
                onOpenCustomColor: onOpenCustomColor
            )
        case .statusItem:
            StatusItemEditorView(
                store: appearanceStore,
                onBack: { onNavigate(.appearance) }
            )
        case .stateColors:
            StateColorsEditorView(
                store: appearanceStore,
                onBack: { onNavigate(.appearance) },
                onOpenCustomColor: onOpenCustomColor
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
