import AppKit
import SwiftUI
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

    @Test @MainActor
    func customColorButtonDoesNotHostANativeColorWell() {
        let host = NSHostingView(
            rootView: AppearanceCustomColorButton(
                title: "背景",
                color: AppearanceColor(hex: 0xFFE36E),
                action: {}
            )
        )
        host.frame = NSRect(x: 0, y: 0, width: 40, height: 32)
        host.layoutSubtreeIfNeeded()

        func containsColorWell(_ view: NSView) -> Bool {
            if view is NSColorWell {
                return true
            }
            return view.subviews.contains(where: containsColorWell)
        }

        #expect(!containsColorWell(host))
    }
}
