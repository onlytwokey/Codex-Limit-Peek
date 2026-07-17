import SwiftUI

enum AppearanceEditorTypography {
    static let defaultScale = 1.15
    static let allowedScale = 0.90...1.50
    static let scaleStep = 0.05

    static func validatedScale(_ value: Double) -> Double {
        guard value.isFinite else { return defaultScale }
        return min(
            max(value, allowedScale.lowerBound),
            allowedScale.upperBound
        )
    }

    static func size(_ base: CGFloat, scale: Double) -> CGFloat {
        base * CGFloat(validatedScale(scale))
    }

    static func sliderTitleWidth(scale: Double) -> CGFloat {
        max(82, 63 * CGFloat(validatedScale(scale)))
    }

    static func sliderValueWidth(scale: Double) -> CGFloat {
        max(46, 40 * CGFloat(validatedScale(scale)))
    }

    static func minimumHeight(
        _ base: CGFloat,
        scale: Double
    ) -> CGFloat {
        base * CGFloat(max(1, validatedScale(scale)))
    }
}

private struct AppearanceEditorFontScaleKey: EnvironmentKey {
    static let defaultValue = AppearanceEditorTypography.defaultScale
}

extension EnvironmentValues {
    var appearanceEditorFontScale: Double {
        get { self[AppearanceEditorFontScaleKey.self] }
        set {
            self[AppearanceEditorFontScaleKey.self] =
                AppearanceEditorTypography.validatedScale(newValue)
        }
    }
}

private struct AppearanceEditorFontModifier: ViewModifier {
    @Environment(\.appearanceEditorFontScale) private var scale
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(
            .system(
                size: AppearanceEditorTypography.size(
                    baseSize,
                    scale: scale
                ),
                weight: weight,
                design: design
            )
        )
    }
}

private struct AppearanceEditorMinHeightModifier: ViewModifier {
    @Environment(\.appearanceEditorFontScale) private var scale
    let baseHeight: CGFloat

    func body(content: Content) -> some View {
        content.frame(
            minHeight: AppearanceEditorTypography.minimumHeight(
                baseHeight,
                scale: scale
            )
        )
    }
}

extension View {
    func appearanceEditorFont(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design = .default
    ) -> some View {
        modifier(
            AppearanceEditorFontModifier(
                baseSize: size,
                weight: weight,
                design: design
            )
        )
    }

    func appearanceEditorMinHeight(_ baseHeight: CGFloat) -> some View {
        modifier(
            AppearanceEditorMinHeightModifier(baseHeight: baseHeight)
        )
    }
}
