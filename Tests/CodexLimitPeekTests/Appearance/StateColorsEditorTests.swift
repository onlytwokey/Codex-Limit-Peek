import Testing
@testable import CodexLimitPeek

struct StateColorsEditorTests {
    @Test
    func previewFixturesCoverAllFourQuotaStatesInOrder() {
        let states = StateColorsEditorPreviewState.allCases

        #expect(
            states.map(\.title) == [
                "正常",
                "警告",
                "危险",
                "不可用"
            ]
        )
        #expect(states.map(\.remainingPercent) == [68, 35, 12, 0])
        #expect(
            states.map {
                AppearanceResolver.state(
                    remainingPercent: $0.remainingPercent,
                    isUnavailable: $0.isUnavailable
                )
            } == [
                .normal,
                .warning,
                .danger,
                .unavailable
            ]
        )
        #expect(states.map(\.showsFailurePattern) == [
            false,
            false,
            false,
            true
        ])
    }

    @Test
    func unavailablePreviewUsesBothConfiguredFailureColors() {
        var profile = AppearanceProfile.default(for: .loud)
        let base = AppearanceColor(hex: 0x123456)
        let stripe = AppearanceColor(hex: 0xFEDCBA)
        profile.palette.unavailableBase = base
        profile.palette.unavailableStripe = stripe

        let appearance = StateColorsEditorPreviewState
            .unavailable
            .appearance(for: profile)

        #expect(appearance.unavailableBaseColor == base)
        #expect(appearance.unavailableStripeColor == stripe)
        #expect(
            StateColorsEditorPreviewState.unavailable
                .showsFailurePattern
        )
    }

    @Test
    func compactPreviewTextMatchesItsFixture() {
        #expect(
            StateColorsEditorPreviewState.allCases.map(\.displayText)
                == ["68%", "35%", "12%", "—"]
        )
        #expect(
            ThemeStatusDisplayData.reference
                .accessibilityValue
                == "81%，1小时34分钟，周额度49%"
        )
    }
}
