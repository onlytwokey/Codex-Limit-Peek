import AppKit
import Foundation
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct DocumentationPreviewRendererTests {
    @Test @MainActor
    func approvedFixtureMatchesTheSpec() {
        let data = DocumentationPreviewRenderer.panelData

        #expect(data.headerText == "CODEX 示例 · 固定数据")
        #expect(data.percentText == "81%")
        #expect(data.primaryQuotaLabel == "5 小时剩余")
        #expect(data.shortResetText == "1h34m")
        #expect(data.primaryResetDetailText == "19:38")
        #expect(data.displayRemainingPercent == 81)
        #expect(data.showsSecondaryQuota)
        #expect(data.weeklyPercentText == "49%")
        #expect(data.weeklyResetDateText == "7月14日恢复")
    }

    @Test @MainActor
    func approvedStatusFixturesMatchTheSpec() {
        #expect(
            DocumentationPreviewRenderer.quotaFixtures
                .map(\.displayText)
                == [
                    "74% | 3h29m | 82%",
                    "39% | 1h42m | 74%",
                    "12% | 35m | 61%"
                ]
        )
        #expect(
            DocumentationPreviewRenderer.refreshFixtures
                .map(\.displayText)
                == [
                    "61% | 3h8m | 74%",
                    "61% | 3h8m | 74%",
                    "61% | 3h8m | 74%",
                    "5d22h | 69%",
                    "5d22h | 69%",
                    "5d22h | 69%"
                ]
        )
        #expect(
            DocumentationPreviewRenderer.refreshFixtures
                .map(\.health)
                == [
                    .live,
                    .confirmingFailure,
                    .degraded,
                    .live,
                    .confirmingFailure,
                    .degraded
                ]
        )

        let productionFills = DocumentationPreviewRenderer
            .quotaFixtures
            .map { fixture in
                AppearanceResolver.status(
                    profile: .default(for: .loud),
                    primaryRemainingPercent:
                        fixture.snapshot.remainingPercent,
                    weeklyRemainingPercent:
                        fixture.snapshot.weeklyRemainingPercent,
                    isUnavailable:
                        fixture.snapshot.isUnavailable,
                    showsFailurePattern:
                        fixture.health.showsFailurePattern
                )
                .fillColor
            }
        #expect(Set(productionFills).count == 3)
    }

    @Test @MainActor
    func settingsAtlasUsesTheApprovedProductionPages() {
        let cells = DocumentationPreviewRenderer.settingsCells

        #expect(
            cells.map(\.title)
                == [
                    "主题与基础色板",
                    "面板字形、几何、阴影与材质",
                    "状态栏显示层",
                    "高级状态颜色"
                ]
        )
        #expect(
            cells.map(\.page)
                == [
                    .appearance,
                    .appearance,
                    .statusItem,
                    .stateColors
                ]
        )
        #expect(
            cells.map(\.scrollTarget)
                == [
                    .themeSelector,
                    .panelControls,
                    .statusItemControls,
                    .stateColorControls
                ]
        )
        for cell in cells {
            #expect(cell.page.fixedSize != nil)
        }
    }

    @Test @MainActor
    func isolatedStoreUsesOnlyApprovedDefaults() throws {
        let standard = UserDefaults.standard
        let standardThemeBefore = standard.string(
            forKey: AppearancePersistenceKey.selectedTheme
        )
        let standardProfileBefore = standard.data(
            forKey: AppearancePersistenceKey.profile(.loud)
        )

        try DocumentationPreviewRenderer.withIsolatedStores {
            appearanceStore,
            quotaStore in
            #expect(
                standard.string(
                    forKey: AppearancePersistenceKey.selectedTheme
                ) == standardThemeBefore
            )
            #expect(
                standard.data(
                    forKey: AppearancePersistenceKey.profile(.loud)
                ) == standardProfileBefore
            )
            #expect(appearanceStore.selectedTheme == .loud)
            #expect(
                appearanceStore.editorFontScale
                    == AppearanceEditorTypography.defaultScale
            )
            for theme in AppearanceThemeID.allCases {
                #expect(
                    appearanceStore.profile(for: theme)
                        == .default(for: theme)
                )
            }
            #expect(quotaStore.snapshot.remainingPercent == 81)
            #expect(
                quotaStore.snapshot.weeklyRemainingPercent == 49
            )
            #expect(!quotaStore.snapshot.isUnavailable)
        }
        #expect(
            standard.string(
                forKey: AppearancePersistenceKey.selectedTheme
            ) == standardThemeBefore
        )
        #expect(
            standard.data(
                forKey: AppearancePersistenceKey.profile(.loud)
            ) == standardProfileBefore
        )
    }

    @Test @MainActor
    func inMemoryDefaultsStayProcessLocal() throws {
        let marker =
            "DocumentationPreview.InMemory.\(UUID().uuidString)"
        let integerKey = "\(marker).integer"
        let doubleKey = "\(marker).double"
        let dataKey = "\(marker).data"
        let markerData = Data([0x43, 0x4C, 0x50])
        let before = try DocumentationPreviewRenderer
            .preferenceArtifactsForTesting()
        #expect(UserDefaults.standard.object(forKey: marker) == nil)

        let defaults = DocumentationInMemoryUserDefaults(
            values: [
                marker: "seed",
                integerKey: 7,
                doubleKey: 1.25,
                dataKey: markerData
            ]
        )
        #expect(defaults.string(forKey: marker) == "seed")
        #expect(defaults.integer(forKey: integerKey) == 7)
        #expect(defaults.double(forKey: doubleKey) == 1.25)
        #expect(defaults.data(forKey: dataKey) == markerData)

        defaults.set("changed", forKey: marker)
        #expect(defaults.string(forKey: marker) == "changed")
        #expect(UserDefaults.standard.object(forKey: marker) == nil)
        defaults.removeObject(forKey: marker)
        #expect(defaults.object(forKey: marker) == nil)

        try DocumentationPreviewRenderer.withIsolatedStores {
            _,
            _ in
        }
        var receivedExpectedError = false
        do {
            try DocumentationPreviewRenderer.withIsolatedStores {
                _,
                _ in
                throw DocumentationIsolationProbeError.expected
            }
        } catch DocumentationIsolationProbeError.expected {
            receivedExpectedError = true
        }

        #expect(receivedExpectedError)
        #expect(UserDefaults.standard.object(forKey: marker) == nil)
        #expect(
            try DocumentationPreviewRenderer
                .preferenceArtifactsForTesting() == before
        )
    }

}

private enum DocumentationIsolationProbeError: Error {
    case expected
}
