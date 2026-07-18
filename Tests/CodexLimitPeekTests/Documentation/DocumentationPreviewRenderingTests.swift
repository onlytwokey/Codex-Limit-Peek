import AppKit
import Foundation
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct DocumentationPreviewRenderingTests {
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
