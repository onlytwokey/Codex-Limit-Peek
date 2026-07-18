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
    func isolatedStoreUsesOnlyApprovedDefaults() throws {
        try DocumentationPreviewRenderer.withIsolatedStores {
            appearanceStore,
            quotaStore in
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
                    "panel-preview.png"
                ]
        )
        #expect(
            second.map(\.lastPathComponent).sorted()
                == first.map(\.lastPathComponent).sorted()
        )

        let approved: [String: (Int, Int)] = [
            "panel-preview.png": (2_400, 900),
            "appearance-settings-loud.png": (1_440, 1_200)
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

        let anchoredSettings = try await DocumentationPreviewRenderer
            .renderSettingsPreviewForTesting(
                appearanceScrollTarget: .themeSelector,
                statusScrollTarget: .statusItemControls
            )
        let appearanceAtDefault = try await DocumentationPreviewRenderer
            .renderSettingsPreviewForTesting(
                appearanceScrollTarget: nil,
                statusScrollTarget: .statusItemControls
            )
        let statusAtDefault = try await DocumentationPreviewRenderer
            .renderSettingsPreviewForTesting(
                appearanceScrollTarget: .themeSelector,
                statusScrollTarget: nil
            )

        #expect(anchoredSettings != appearanceAtDefault)
        #expect(anchoredSettings != statusAtDefault)
    }
}
