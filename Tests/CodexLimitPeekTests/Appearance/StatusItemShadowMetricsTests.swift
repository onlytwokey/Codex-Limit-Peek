import Testing
@testable import CodexLimitPeek

struct StatusItemShadowMetricsTests {
    @Test
    func positiveOffsetsReserveTrailingAndBottomBleed() {
        let metrics = StatusItemShadowMetrics(
            horizontalOffset: 4,
            verticalOffset: 3,
            blur: 2
        )

        #expect(metrics.leading == 0)
        #expect(metrics.trailing == 6)
        #expect(metrics.top == 0)
        #expect(metrics.bottom == 5)
        #expect(metrics.horizontalBleed == 6)
        #expect(metrics.verticalBleed == 5)
    }

    @Test
    func negativeOffsetsReserveLeadingAndTopBleed() {
        let metrics = StatusItemShadowMetrics(
            horizontalOffset: -4,
            verticalOffset: -3,
            blur: 2
        )

        #expect(metrics.leading == 6)
        #expect(metrics.trailing == 0)
        #expect(metrics.top == 5)
        #expect(metrics.bottom == 0)
        #expect(metrics.horizontalBleed == 6)
        #expect(metrics.verticalBleed == 5)
    }

    @Test
    func transparentShadowProducesNoLayoutBleed() {
        var appearance = AppearanceResolver.status(
            profile: .default(for: .frost),
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
        appearance.shadowHorizontalOffset = 8
        appearance.shadowVerticalOffset = -7
        appearance.shadowBlur = 6
        appearance.shadowOpacity = 0

        let metrics = StatusItemShadowMetrics(appearance: appearance)

        #expect(metrics.leading == 0)
        #expect(metrics.trailing == 0)
        #expect(metrics.top == 0)
        #expect(metrics.bottom == 0)
    }

    @Test
    func invalidInputsCannotProduceInvalidBleed() {
        let metrics = StatusItemShadowMetrics(
            horizontalOffset: .infinity,
            verticalOffset: .nan,
            blur: -.infinity
        )

        #expect(metrics.leading == 0)
        #expect(metrics.trailing == 0)
        #expect(metrics.top == 0)
        #expect(metrics.bottom == 0)
    }
}
