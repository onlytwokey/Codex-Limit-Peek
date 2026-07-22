#if DEVELOPER_TOOLS
import SwiftUI

enum DeveloperPreviewImplementation:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case current
    case candidate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current:
            "Current"
        case .candidate:
            "Candidate"
        }
    }
}

struct DeveloperPreviewSelection: Equatable, Sendable {
    var theme: AppearanceThemeID = .loud
    var scenario: DeveloperPreviewScenario = .healthyDual
    var implementation: DeveloperPreviewImplementation = .current
}

struct DeveloperPreviewPanelSurface: View {
    @ObservedObject var quotaStore: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var moreOverlayPresenter: MoreOverlayPresenter
    let implementation: DeveloperPreviewImplementation

    var body: some View {
        switch implementation {
        case .current:
            productionPanel
        case .candidate:
            DeveloperPreviewCandidatePanel(
                quotaStore: quotaStore,
                appearanceStore: appearanceStore,
                moreOverlayPresenter: moreOverlayPresenter
            )
        }
    }

    private var productionPanel: some View {
        DeveloperPreviewProductionPanel(
            quotaStore: quotaStore,
            appearanceStore: appearanceStore,
            moreOverlayPresenter: moreOverlayPresenter
        )
    }
}

private struct DeveloperPreviewCandidatePanel: View {
    @ObservedObject var quotaStore: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var moreOverlayPresenter: MoreOverlayPresenter

    var body: some View {
        // Future experiments replace only this development-only surface.
        DeveloperPreviewProductionPanel(
            quotaStore: quotaStore,
            appearanceStore: appearanceStore,
            moreOverlayPresenter: moreOverlayPresenter
        )
    }
}

private struct DeveloperPreviewProductionPanel: View {
    @ObservedObject var quotaStore: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var moreOverlayPresenter: MoreOverlayPresenter

    var body: some View {
        ZStack {
            StatusPanelShadowView(
                store: quotaStore,
                appearanceStore: appearanceStore
            )

            StatusPanelView(
                store: quotaStore,
                appearanceStore: appearanceStore,
                moreOverlayPresenter: moreOverlayPresenter
            )
        }
        .frame(
            width: PanelMetrics.shadowWidth,
            height: PanelMetrics.shadowHeight
        )
    }
}
#endif
