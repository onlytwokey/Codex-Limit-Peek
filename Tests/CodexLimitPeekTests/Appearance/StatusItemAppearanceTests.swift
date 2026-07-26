import AppKit
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct StatusItemAppearanceTests {
    @Test
    func statusDefaultsRemainVisuallyDistinct() {
        let loud = resolvedStatus(for: .loud)
        let bold = resolvedStatus(for: .bold)
        let frost = resolvedStatus(for: .frost)

        #expect(loud.cornerRadius == 0)
        #expect(loud.outlineWidth == 2)
        #expect(loud.shadowHorizontalOffset == 3)
        #expect(loud.shadowVerticalOffset == 3)
        #expect(loud.fontFamily == .monospaced)
        #expect(loud.fontWeight == .heavy)

        #expect(bold.cornerRadius == 5)
        #expect(bold.outlineWidth == 1.5)
        #expect(bold.shadowHorizontalOffset == 2)
        #expect(bold.shadowVerticalOffset == 2)
        #expect(bold.fillColor == AppearanceColor(hex: 0xB9EFE5))

        #expect(frost.cornerRadius == 7)
        #expect(frost.outlineWidth == 1.5)
        #expect(frost.shadowHorizontalOffset == 2)
        #expect(frost.shadowVerticalOffset == 2)
        #expect(frost.shadowBlur == 0)
        #expect(
            frost.fillColor
                == AppearanceProfile.default(for: .frost).palette.normal
        )
        #expect(frost.fillColor.alpha == 1)

        #expect(loud.weeklyTextColor == loud.primaryTextColor)
        #expect(bold.weeklyTextColor == bold.primaryTextColor)
        #expect(frost.weeklyTextColor == frost.primaryTextColor)
    }

    @Test
    func frostStatusUsesRawSemanticColorsWithoutWallpaperTransparency() {
        let profile = AppearanceProfile.default(for: .frost)
        let cases: [(remainingPercent: Int, expected: AppearanceColor)] = [
            (81, profile.palette.normal),
            (35, profile.palette.warning),
            (12, profile.palette.danger)
        ]

        for item in cases {
            let resolved = AppearanceResolver.status(
                profile: profile,
                primaryRemainingPercent: item.remainingPercent,
                weeklyRemainingPercent: 49,
                isUnavailable: false,
                showsFailurePattern: false
            )

            #expect(resolved.fillColor == item.expected)
            #expect(resolved.fillColor.alpha == 1)
        }
    }

    @Test
    func frostStatusPreservesCustomColorAlphaBelowRecipeCap() {
        var profile = AppearanceProfile.default(for: .frost)
        let customNormal = AppearanceColor(hex: 0x77A9DF, alpha: 0.42)
        profile.palette.normal = customNormal

        let resolved = AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )

        #expect(resolved.fillColor == customNormal)
        #expect(resolved.fillColor.alpha == 0.42)
    }

    @Test @MainActor
    func largerFontAndShadowReserveAdditionalWidth() {
        let view = CompactStatusItemView()
        var compact = AppearanceResolver.status(
            profile: .default(for: .bold),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        compact.fontSize = 11
        compact.shadowHorizontalOffset = 0

        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: compact,
            showsFailurePattern: false,
            tooltip: "Compact"
        )
        let compactWidth = view.frame.width

        var expanded = compact
        expanded.fontSize = 13
        expanded.shadowHorizontalOffset = 2
        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: expanded,
            showsFailurePattern: false,
            tooltip: "Expanded"
        )

        #expect(view.frame.width > compactWidth)
        #expect(view.frame.height == NSStatusBar.system.thickness)
    }

    @Test @MainActor
    func documentationCanFixStatusBarThickness() {
        let view = CompactStatusItemView()

        view.update(
            title: "74% | 3h29m",
            weeklyTitle: "82%",
            appearance: resolvedStatus(for: .loud),
            showsFailurePattern: false,
            tooltip: "Fixed documentation height",
            statusBarThickness: 22
        )

        #expect(view.frame.height == 22)
    }

    @Test @MainActor
    func profileStatusGeometryDrivesRenderedWidth() {
        let view = CompactStatusItemView()
        var profile = AppearanceProfile.default(for: .bold)

        let compact = AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        view.update(
            title: "81% | 1h34m",
            weeklyTitle: "49%",
            appearance: compact,
            showsFailurePattern: false,
            tooltip: "Compact"
        )
        let compactWidth = view.frame.width

        profile.statusItemGeometry.fontSize = 14
        profile.statusItemGeometry.horizontalPadding = 14
        profile.statusItemGeometry.shadowBlur = 8
        let expanded = AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        .fitted(to: Double(NSStatusBar.system.thickness))
        view.update(
            title: "81% | 1h34m",
            weeklyTitle: "49%",
            appearance: expanded,
            showsFailurePattern: false,
            tooltip: "Expanded"
        )

        #expect(view.frame.width > compactWidth)
        #expect(view.frame.height == NSStatusBar.system.thickness)
    }

    @Test @MainActor
    func softShadowBlurReservesBothHorizontalBleedEdges() {
        let view = CompactStatusItemView()
        var appearance = AppearanceResolver.status(
            profile: .default(for: .frost),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        appearance.shadowHorizontalOffset = 0
        appearance.shadowVerticalOffset = 0
        appearance.shadowBlur = 0

        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: appearance,
            showsFailurePattern: false,
            tooltip: "No blur"
        )
        let widthWithoutBlur = view.frame.width

        appearance.shadowBlur = 4
        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: appearance,
            showsFailurePattern: false,
            tooltip: "Soft shadow"
        )

        #expect(view.frame.width >= widthWithoutBlur + 8)
        #expect(view.frame.height == NSStatusBar.system.thickness)
    }

    @Test @MainActor
    func signedHorizontalOffsetsReserveTheDirectionalBleed() {
        let view = CompactStatusItemView()
        var appearance = AppearanceResolver.status(
            profile: .default(for: .bold),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        appearance.shadowVerticalOffset = 0
        appearance.shadowBlur = 1.5
        appearance.shadowHorizontalOffset = 0
        let centeredMetrics = StatusItemShadowMetrics(
            appearance: appearance
        )

        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: appearance,
            showsFailurePattern: false,
            tooltip: "Centered shadow"
        )
        let centeredWidth = view.frame.width

        appearance.shadowHorizontalOffset = -6
        let offsetMetrics = StatusItemShadowMetrics(
            appearance: appearance
        )
        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: appearance,
            showsFailurePattern: false,
            tooltip: "Left shadow"
        )
        let leftWidth = view.frame.width

        appearance.shadowHorizontalOffset = 6
        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: appearance,
            showsFailurePattern: false,
            tooltip: "Right shadow"
        )

        let expectedWidthIncrease =
            offsetMetrics.horizontalBleed
                - centeredMetrics.horizontalBleed
        #expect(
            abs(
                (leftWidth - centeredWidth)
                    - expectedWidthIncrease
            ) <= 1
        )
        #expect(view.frame.width == leftWidth)
    }

    @Test @MainActor
    func everyThemeProducesValidStatusItemDimensions() {
        let view = CompactStatusItemView()

        for theme in AppearanceThemeID.allCases {
            let showsFailurePattern = theme == .frost
            let appearance = AppearanceResolver.status(
                profile: .default(for: theme),
                primaryRemainingPercent: 64,
                weeklyRemainingPercent: 18,
                isUnavailable: showsFailurePattern,
                showsFailurePattern: showsFailurePattern
            )

            view.update(
                title: "64% | 1h 42m",
                weeklyTitle: "18%",
                appearance: appearance,
                showsFailurePattern: showsFailurePattern,
                tooltip: theme.displayName
            )

            #expect(view.frame.width.isFinite)
            #expect(view.frame.width > 0)
            #expect(view.frame.height.isFinite)
            #expect(view.frame.height == NSStatusBar.system.thickness)
        }
    }

    @Test @MainActor
    func detachedRendererProducesVisibleNonTemplatePixels() throws {
        let view = CompactStatusItemView()
        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: resolvedStatus(for: .loud),
            showsFailurePattern: false,
            tooltip: "额度状态"
        )

        let image = try #require(view.renderedStatusImage())
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let hasVisiblePixel = (0 ..< bitmap.pixelsHigh).contains { y in
            (0 ..< bitmap.pixelsWide).contains { x in
                (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01
            }
        }

        #expect(!image.isTemplate)
        #expect(hasVisiblePixel)
    }

    @Test @MainActor
    func customStatusViewExposesButtonAccessibilityAndPressAction() {
        let view = CompactStatusItemView()
        var didPress = false
        view.onClick = {
            didPress = true
        }
        view.update(
            title: "81% | 2h 8m",
            weeklyTitle: "49%",
            appearance: resolvedStatus(for: .loud),
            showsFailurePattern: false,
            tooltip: "额度状态"
        )

        #expect(view.isAccessibilityElement())
        #expect(view.accessibilityRole() == .button)
        #expect(view.accessibilityLabel() == "Codex Limit Peek")
        #expect(
            view.accessibilityValue() as? String
                == "81% | 2h 8m | 49%"
        )
        #expect(view.accessibilityPerformPress())
        #expect(didPress)
    }

    private func resolvedStatus(
        for theme: AppearanceThemeID
    ) -> ResolvedStatusItemAppearance {
        AppearanceResolver.status(
            profile: .default(for: theme),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
    }
}
