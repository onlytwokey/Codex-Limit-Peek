import Foundation
import SwiftUI

enum StateColorsEditorPreviewState:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case normal
    case warning
    case danger
    case unavailable

    var id: Self { self }

    var title: String {
        switch self {
        case .normal:
            "正常"
        case .warning:
            "警告"
        case .danger:
            "危险"
        case .unavailable:
            "不可用"
        }
    }

    var remainingPercent: Int {
        switch self {
        case .normal:
            68
        case .warning:
            35
        case .danger:
            12
        case .unavailable:
            0
        }
    }

    var displayText: String {
        self == .unavailable
            ? "—"
            : "\(remainingPercent)%"
    }

    var isUnavailable: Bool {
        self == .unavailable
    }

    var showsFailurePattern: Bool {
        self == .unavailable
    }

    func appearance(
        for profile: AppearanceProfile
    ) -> ResolvedStatusItemAppearance {
        AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: remainingPercent,
            weeklyRemainingPercent: 49,
            isUnavailable: isUnavailable,
            showsFailurePattern: showsFailurePattern
        )
    }

    func selectorFill(
        for profile: AppearanceProfile
    ) -> AppearanceColor {
        switch self {
        case .normal:
            profile.palette.normal
        case .warning:
            profile.palette.warning
        case .danger:
            profile.palette.danger
        case .unavailable:
            profile.palette.unavailableBase
        }
    }

    static func previewState(
        for token: AppearanceColorToken
    ) -> Self {
        switch token {
        case .normal:
            .normal
        case .warning:
            .warning
        case .danger:
            .danger
        case .unavailableBase, .unavailableStripe:
            .unavailable
        default:
            .normal
        }
    }
}

struct StateColorsEditorControls: View {
    @ObservedObject var store: AppearanceStore
    @Binding var previewState: StateColorsEditorPreviewState
    let onOpenCustomColor: (AppearanceColorToken) -> Void

    private var resolvedAppearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: store.currentProfile,
            primaryRemainingPercent: 68,
            weeklyRemainingPercent: 18,
            isUnavailable: false
        )
    }

    var body: some View {
        AppearanceEditorSection(
            appearance: resolvedAppearance,
            title: "状态颜色",
            subtitle: "调整时顶部预览会自动切换到对应状态"
        ) {
            VStack(spacing: 10) {
                colorRow(title: "正常", token: .normal)
                colorRow(title: "警告", token: .warning)
                colorRow(title: "危险", token: .danger)
                colorRow(
                    title: "不可用底色",
                    token: .unavailableBase
                )
                colorRow(
                    title: "不可用条纹",
                    token: .unavailableStripe
                )

                AppearanceEditorInlineNote(
                    text: "每套主题分别保存；正常、警告、危险的额度阈值保持不变。"
                )
                .padding(.top, 2)
            }
        }
    }

    private func colorRow(
        title: String,
        token: AppearanceColorToken
    ) -> some View {
        AppearanceColorRow(
            title: title,
            selectedColor: store.color(for: token),
            swatches: AppearanceEditorPalette.swatches(
                for: token,
                theme: store.selectedTheme
            ),
            onSelectSwatch: { color in
                selectPreviewState(for: token)
                store.setColor(color, for: token)
            },
            onOpenCustomColor: {
                selectPreviewState(for: token)
                onOpenCustomColor(token)
            }
        )
    }

    private func selectPreviewState(
        for token: AppearanceColorToken
    ) {
        withAnimation(.easeOut(duration: 0.12)) {
            previewState = StateColorsEditorPreviewState
                .previewState(for: token)
        }
    }
}
