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
    func productionStatusViewKeepsQuotaTextAcrossRefreshHealth() async throws {
        let fixture = try #require(
            DocumentationPreviewRenderer.refreshFixtures.first
        )
        let live = try await DocumentationPreviewRenderer
            .renderStatusItemForTesting(
                snapshot: fixture.snapshot,
                health: .live,
                referenceDate: fixture.referenceDate
            )
        let confirming = try await DocumentationPreviewRenderer
            .renderStatusItemForTesting(
                snapshot: fixture.snapshot,
                health: .confirmingFailure,
                referenceDate: fixture.referenceDate
            )
        let confirmed = try await DocumentationPreviewRenderer
            .renderStatusItemForTesting(
                snapshot: fixture.snapshot,
                health: .degraded,
                referenceDate: fixture.referenceDate
            )

        #expect(live == confirming)
        #expect(live != confirmed)

        let accessibilityValues = [
            RefreshHealth.live,
            .confirmingFailure,
            .degraded
        ].map { health in
            DocumentationPreviewRenderer
                .makeStatusItemViewForTesting(
                    snapshot: fixture.snapshot,
                    health: health,
                    referenceDate: fixture.referenceDate
                )
                .accessibilityValue() as? String
        }
        #expect(
            accessibilityValues
                == [
                    fixture.displayText,
                    fixture.displayText,
                    fixture.displayText
                ]
        )

        var changedSnapshot = fixture.snapshot
        changedSnapshot.resetDate = changedSnapshot.resetDate
            .addingTimeInterval(60)
        let changedText = try await DocumentationPreviewRenderer
            .renderStatusItemForTesting(
                snapshot: changedSnapshot,
                health: .live,
                referenceDate: fixture.referenceDate
            )
        #expect(live != changedText)

        var quotaStatePixels: [Data] = []
        for quotaFixture in DocumentationPreviewRenderer
            .quotaFixtures
        {
            quotaStatePixels.append(
                try await DocumentationPreviewRenderer
                    .renderStatusItemForTesting(
                        snapshot: quotaFixture.snapshot,
                        health: quotaFixture.health,
                        referenceDate:
                            quotaFixture.referenceDate
                    )
            )
        }
        #expect(Set(quotaStatePixels).count == 3)

        let weeklyFixture = try #require(
            DocumentationPreviewRenderer.refreshFixtures
                .dropFirst(3)
                .first
        )
        let weekly = try await DocumentationPreviewRenderer
            .renderStatusItemForTesting(
                snapshot: weeklyFixture.snapshot,
                health: weeklyFixture.health,
                referenceDate: weeklyFixture.referenceDate
            )
        #expect(live != weekly)
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

    @Test @MainActor
    func rendersApprovedAssets() async throws {
        let environment = ProcessInfo.processInfo.environment
        let configured = environment[
            "CODEX_LIMIT_PEEK_DOC_PREVIEW_OUTPUT_DIR"
        ]
        let fileManager = FileManager.default
        let temporary = fileManager.temporaryDirectory
            .appendingPathComponent(
                "CodexLimitPeekPreview.\(UUID().uuidString)",
                isDirectory: true
            )
        let output = configured.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? temporary
        let repeatOutput = fileManager.temporaryDirectory
            .appendingPathComponent(
                "CodexLimitPeekPreviewRepeat.\(UUID().uuidString)",
                isDirectory: true
            )

        defer {
            if configured == nil {
                try? fileManager.removeItem(at: output)
            }
            try? fileManager.removeItem(at: repeatOutput)
        }

        let first = try await DocumentationPreviewRenderer
            .renderAll(to: output)
        let second = try await DocumentationPreviewRenderer
            .renderAll(to: repeatOutput)

        #expect(
            first.map(\.lastPathComponent).sorted()
                == [
                    "appearance-settings-loud.png",
                    "panel-preview.png",
                    "quota-states-loud.png",
                    "refresh-states-loud.png"
                ]
        )
        #expect(
            second.map(\.lastPathComponent).sorted()
                == first.map(\.lastPathComponent).sorted()
        )

        let approved: [String: (Int, Int)] = [
            "panel-preview.png": (2_400, 900),
            "quota-states-loud.png": (1_840, 720),
            "refresh-states-loud.png": (1_840, 1_350),
            "appearance-settings-loud.png": (1_440, 2_400)
        ]
        var combinedBytes = 0

        for firstURL in first {
            let expected = try #require(
                approved[firstURL.lastPathComponent]
            )
            let metadata = try DocumentationPreviewRenderer
                .metadata(for: firstURL)
            let secondURL = repeatOutput
                .appendingPathComponent(
                    firstURL.lastPathComponent
                )
            let firstData = try Data(contentsOf: firstURL)
            let secondData = try Data(contentsOf: secondURL)

            #expect(metadata.width == expected.0)
            #expect(metadata.height == expected.1)
            #expect(abs(metadata.dpiWidth - 144) < 0.5)
            #expect(abs(metadata.dpiHeight - 144) < 0.5)
            #expect(metadata.isPNG)
            #expect(metadata.isSRGB)
            #expect(metadata.byteCount <= 3 * 1_024 * 1_024)
            #expect(firstData == secondData)
            combinedBytes += metadata.byteCount
        }

        #expect(combinedBytes <= 5 * 1_024 * 1_024)
    }

    @Test @MainActor
    func offscreenRenderingExercisesEveryInjectedSeam() async throws {
        let preferenceArtifactsBefore =
            try DocumentationPreviewRenderer
                .preferenceArtifactsForTesting()
        let baselineTheme = try await DocumentationPreviewRenderer
            .renderThemePreviewForTesting(
                data: DocumentationPreviewRenderer.panelData,
                statusBarThickness:
                    DocumentationPreviewRenderer.statusBarThickness
            )
        var alternateData = DocumentationPreviewRenderer.panelData
        alternateData.headerText = "DIFFERENT FIXTURE"
        let alternateFixture = try await DocumentationPreviewRenderer
            .renderThemePreviewForTesting(
                data: alternateData,
                statusBarThickness:
                    DocumentationPreviewRenderer.statusBarThickness
            )
        let alternateThickness = try await DocumentationPreviewRenderer
            .renderThemePreviewForTesting(
                data: DocumentationPreviewRenderer.panelData,
                statusBarThickness: 14
            )

        #expect(baselineTheme != alternateFixture)
        #expect(baselineTheme != alternateThickness)

        let themeSelector = try await DocumentationPreviewRenderer
            .renderOverlayPageForTesting(
                page: .appearance,
                scrollTarget: .themeSelector
            )
        let panelControls = try await DocumentationPreviewRenderer
            .renderOverlayPageForTesting(
                page: .appearance,
                scrollTarget: .panelControls
            )
        let statusControls = try await DocumentationPreviewRenderer
            .renderOverlayPageForTesting(
                page: .statusItem,
                scrollTarget: .statusItemControls
            )
        let statusAtDefault = try await DocumentationPreviewRenderer
            .renderOverlayPageForTesting(
                page: .statusItem,
                scrollTarget: nil
            )
        let stateColors = try await DocumentationPreviewRenderer
            .renderOverlayPageForTesting(
                page: .stateColors,
                scrollTarget: .stateColorControls
            )
        let stateColorsAtDefault = try await DocumentationPreviewRenderer
            .renderOverlayPageForTesting(
                page: .stateColors,
                scrollTarget: nil
            )

        #expect(themeSelector != panelControls)
        #expect(statusControls != statusAtDefault)
        #expect(statusControls != stateColors)
        #expect(stateColors != stateColorsAtDefault)
        #expect(
            try DocumentationPreviewRenderer
                .preferenceArtifactsForTesting()
                == preferenceArtifactsBefore
        )
    }
}

private enum DocumentationIsolationProbeError: Error {
    case expected
}
