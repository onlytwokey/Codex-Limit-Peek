#if DEVELOPER_TOOLS
import AppKit
import SwiftUI

struct DeveloperPreviewStatusItemProjection: Equatable {
    let title: String
    let weeklyTitle: String?
    let appearance: ResolvedStatusItemAppearance
    let showsFailurePattern: Bool
    let tooltip: String
    let statusBarThickness: CGFloat

    @MainActor
    init(
        quotaStore: QuotaStore,
        appearanceStore: AppearanceStore,
        referenceDate: Date,
        statusBarThickness: CGFloat = NSStatusBar.system.thickness
    ) {
        let snapshot = quotaStore.snapshot
        let health = quotaStore.refreshHealth
        let showsFailurePattern = health.showsFailurePattern

        title = snapshot.menuBarTitle(relativeTo: referenceDate)
        weeklyTitle = snapshot.menuBarTrailingTitle
        appearance = AppearanceResolver.status(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent: snapshot.remainingPercent,
            weeklyRemainingPercent: snapshot.weeklyRemainingPercent,
            isUnavailable: snapshot.isUnavailable,
            showsFailurePattern: showsFailurePattern
        )
        .fitted(to: Double(statusBarThickness))
        self.showsFailurePattern = showsFailurePattern
        tooltip = "固定演示数据"
        self.statusBarThickness = statusBarThickness
    }

    @MainActor
    func apply(to view: CompactStatusItemView) {
        view.update(
            title: title,
            weeklyTitle: weeklyTitle,
            appearance: appearance,
            showsFailurePattern: showsFailurePattern,
            tooltip: tooltip,
            statusBarThickness: statusBarThickness
        )
        view.setAccessibilityIdentifier(
            "developer-preview-compact-status-item"
        )
    }
}

@MainActor
struct DeveloperPreviewStatusItemView: View {
    @ObservedObject var quotaStore: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    let referenceDate: Date

    private var projection: DeveloperPreviewStatusItemProjection {
        DeveloperPreviewStatusItemProjection(
            quotaStore: quotaStore,
            appearanceStore: appearanceStore,
            referenceDate: referenceDate
        )
    }

    var body: some View {
        DeveloperPreviewStatusItemRepresentable(
            projection: projection
        )
        .fixedSize()
        .accessibilityIdentifier(
            "developer-preview-status-item-renderer"
        )
    }

    static func makeStatusItemViewForTesting(
        projection: DeveloperPreviewStatusItemProjection
    ) -> CompactStatusItemView {
        let view = CompactStatusItemView()
        projection.apply(to: view)
        return view
    }
}

@MainActor
private struct DeveloperPreviewStatusItemRepresentable:
    NSViewRepresentable
{
    let projection: DeveloperPreviewStatusItemProjection

    func makeNSView(context: Context) -> CompactStatusItemView {
        DeveloperPreviewStatusItemView.makeStatusItemViewForTesting(
            projection: projection
        )
    }

    func updateNSView(
        _ nsView: CompactStatusItemView,
        context: Context
    ) {
        projection.apply(to: nsView)
        nsView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: CompactStatusItemView,
        context: Context
    ) -> CGSize? {
        nsView.frame.size
    }
}
#endif
