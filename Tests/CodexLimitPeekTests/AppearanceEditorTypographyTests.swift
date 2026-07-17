import Testing
@testable import CodexLimitPeek

struct AppearanceEditorTypographyTests {
    @Test
    func scaleValidationUsesApprovedDefaultAndBounds() {
        #expect(
            AppearanceEditorTypography.validatedScale(.nan)
                == AppearanceEditorTypography.defaultScale
        )
        #expect(
            AppearanceEditorTypography.validatedScale(.infinity)
                == AppearanceEditorTypography.defaultScale
        )
        #expect(AppearanceEditorTypography.validatedScale(0.4) == 0.9)
        #expect(AppearanceEditorTypography.validatedScale(2.0) == 1.5)
        #expect(AppearanceEditorTypography.validatedScale(1.35) == 1.35)
    }

    @Test
    func adaptiveMetricsProtectLargeLabelsAndHitTargets() {
        #expect(
            AppearanceEditorTypography.sliderTitleWidth(scale: 0.9) == 82
        )
        #expect(
            AppearanceEditorTypography.sliderTitleWidth(scale: 1.5) >= 94
        )
        #expect(
            AppearanceEditorTypography.sliderValueWidth(scale: 1.5) >= 60
        )
        #expect(
            AppearanceEditorTypography.minimumHeight(44, scale: 0.9) == 44
        )
        #expect(
            AppearanceEditorTypography.minimumHeight(44, scale: 1.5) == 66
        )
    }

    @Test
    func customColorControlKeepsAVisibleHitTarget() {
        #expect(
            AppearanceEditorMetrics.customColorControlWidth >= 25
        )
        #expect(AppearanceEditorMetrics.colorControlHeight >= 21)
    }
}
