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
        #expect(loud.shadowDepth == 3)
        #expect(loud.fontFamily == .monospaced)
        #expect(loud.fontWeight == .heavy)

        #expect(bold.cornerRadius == 5)
        #expect(bold.outlineWidth == 1.5)
        #expect(bold.shadowDepth == 2)
        #expect(bold.fillColor == AppearanceColor(hex: 0xB9EFE5))

        #expect(frost.cornerRadius == 7)
        #expect(frost.outlineWidth == 1.5)
        #expect(frost.shadowDepth == 2)
        #expect(frost.shadowBlur == 0)
        #expect(frost.fillColor.alpha == 0.3)

        #expect(loud.weeklyTextColor == loud.primaryTextColor)
        #expect(bold.weeklyTextColor == bold.primaryTextColor)
        #expect(frost.weeklyTextColor == frost.primaryTextColor)
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
        compact.shadowDepth = 0

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
        expanded.shadowDepth = 2
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
    func softShadowBlurReservesBothHorizontalBleedEdges() {
        let view = CompactStatusItemView()
        var appearance = AppearanceResolver.status(
            profile: .default(for: .frost),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        appearance.shadowDepth = 0
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
