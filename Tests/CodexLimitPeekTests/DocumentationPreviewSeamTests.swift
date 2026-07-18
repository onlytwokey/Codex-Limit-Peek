import SwiftUI
import Testing
@testable import CodexLimitPeek

struct DocumentationPreviewSeamTests {
    private let sharedData = ThemePanelDisplayData(
        headerText: "CODEX 示例 · 固定数据",
        percentText: "81%",
        primaryQuotaLabel: "5 小时剩余",
        shortResetText: "1h34m",
        primaryResetDetailText: "19:38",
        displayRemainingPercent: 81,
        showsSecondaryQuota: true,
        weeklyPercentText: "49%",
        weeklyResetDateText: "7月14日恢复"
    )

    @Test @MainActor
    func panelPreviewsAcceptSharedDisplayData() {
        let appearance = AppearanceResolver.panel(
            profile: .default(for: .bold),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
        let full = ThemePanelChromePreview(
            appearance: appearance,
            data: sharedData
        )
        let scaled = ScaledThemePanelChromePreview(
            appearance: appearance,
            data: sharedData,
            targetWidth: 360
        )
        let reference = ThemePanelDisplayData.reference(for: .bold)
        let defaultFull = ThemePanelChromePreview(
            appearance: appearance
        )
        let defaultScaled = ScaledThemePanelChromePreview(
            appearance: appearance,
            targetWidth: 360
        )

        #expect(full.data == sharedData)
        #expect(scaled.data == sharedData)
        #expect(defaultFull.data == reference)
        #expect(defaultScaled.data == reference)
    }

    @Test
    func documentationOverridesAreDefaultOff() {
        var environment = EnvironmentValues()

        #expect(environment.themeStatusBarThicknessOverride == nil)
        #expect(environment.appearanceEditorInitialScrollTarget == nil)

        environment.themeStatusBarThicknessOverride = 22
        environment.appearanceEditorInitialScrollTarget = .themeSelector

        #expect(environment.themeStatusBarThicknessOverride == 22)
        #expect(
            environment.appearanceEditorInitialScrollTarget
                == .themeSelector
        )
    }

    @Test
    func statusItemAnchorAddsOnlyDocumentationTrailingSpace() {
        #expect(
            AppearanceEditorDocumentationMetrics.trailingScrollSpace(
                for: nil
            ) == 0
        )
        #expect(
            AppearanceEditorDocumentationMetrics.trailingScrollSpace(
                for: .themeSelector
            ) == 0
        )
        #expect(
            AppearanceEditorDocumentationMetrics.trailingScrollSpace(
                for: .statusItemControls
            ) >= MoreOverlayMetrics.statusItemSize.height
        )
    }
}
