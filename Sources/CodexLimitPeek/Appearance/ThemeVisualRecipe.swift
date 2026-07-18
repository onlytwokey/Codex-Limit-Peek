import Foundation

enum ThemeShadowRecipe: Equatable, Sendable {
    case none
    case hard(depth: Double, opacity: Double = 1)
    case soft(depth: Double, blur: Double, opacity: Double)

    var depth: Double {
        switch self {
        case .none:
            0
        case let .hard(depth, _), let .soft(depth, _, _):
            depth
        }
    }

    var blur: Double {
        if case let .soft(_, blur, _) = self {
            return blur
        }
        return 0
    }

    var opacity: Double {
        switch self {
        case .none:
            0
        case let .hard(_, opacity), let .soft(_, _, opacity):
            opacity
        }
    }

    fileprivate func resolved(
        depthScale: Double,
        blur: Double
    ) -> ThemeShadowRecipe {
        switch self {
        case .none:
            .none
        case let .hard(depth, opacity), let .soft(depth, _, opacity):
            if blur > 0 {
                .soft(
                    depth: depth * depthScale,
                    blur: blur,
                    opacity: opacity
                )
            } else {
                .hard(depth: depth * depthScale, opacity: opacity)
            }
        }
    }
}

struct ThemeChromeRecipe: Equatable, Sendable {
    var outlineWidth: Double
    var cornerRadius: Double
    var shadow: ThemeShadowRecipe

    fileprivate func resolved(
        outlineScale: Double,
        cornerDelta: Double,
        shadowScale: Double,
        shadowBlur: Double
    ) -> ThemeChromeRecipe {
        ThemeChromeRecipe(
            outlineWidth: outlineWidth * outlineScale,
            cornerRadius: max(0, cornerRadius + cornerDelta),
            shadow: shadow.resolved(
                depthScale: shadowScale,
                blur: shadowBlur
            )
        )
    }
}

struct ThemeProgressRecipe: Equatable, Sendable {
    var track: ThemeChromeRecipe
    var height: Double
    var trackColor: AppearanceColor
    var trackTintOpacity: Double
    var fillDividerWidth: Double
}

enum ThemeFontFamily: Equatable, Sendable {
    case system
    case rounded
    case monospaced
}

enum ThemeFontWeight: Equatable, Sendable {
    case semibold
    case bold
    case heavy
    case black
}

enum ThemePanelFill: Equatable, Sendable {
    case solid
    case materialGradient
}

struct ThemeTypographyRecipe: Equatable, Sendable {
    var statusSize: Double
    var statusWeight: ThemeFontWeight
    var statusFamily: ThemeFontFamily
    var headerSize: Double
    var headerWeight: ThemeFontWeight
    var headerFamily: ThemeFontFamily
    var percentSize: Double
    var percentWeight: ThemeFontWeight
    var percentFamily: ThemeFontFamily
    var percentTracking: Double
    var labelSize: Double
    var labelWeight: ThemeFontWeight
    var countdownSize: Double
    var countdownWeight: ThemeFontWeight
    var metadataSize: Double
    var metadataWeight: ThemeFontWeight
    var secondaryPercentSize: Double
    var uppercaseMetadata: Bool
    var secondaryOpacity: Double
}

struct ThemeVisualRecipe: Equatable, Sendable {
    var panelShell: ThemeChromeRecipe
    var quotaCard: ThemeChromeRecipe
    var actionButton: ThemeChromeRecipe
    var menuRow: ThemeChromeRecipe
    var progress: ThemeProgressRecipe
    var weeklyDividerWidth: Double
    var statusChip: ThemeChromeRecipe
    var statusReferenceColor: AppearanceColor?
    var statusFillOpacity: Double
    var statusLightening: Double
    var statusHorizontalPadding: Double
    var statusTagHeight: Double
    var panelFill: ThemePanelFill
    var panelGradientStartColor: AppearanceColor?
    var panelGradientEndColor: AppearanceColor?
    var quotaSurfaceOpacity: Double
    var actionSurfaceOpacity: Double
    var typography: ThemeTypographyRecipe

    static func `default`(
        for theme: AppearanceThemeID
    ) -> ThemeVisualRecipe {
        switch theme {
        case .loud:
            ThemeVisualRecipe(
                panelShell: ThemeChromeRecipe(
                    outlineWidth: 3,
                    cornerRadius: 0,
                    shadow: .hard(depth: 8)
                ),
                quotaCard: ThemeChromeRecipe(
                    outlineWidth: 3,
                    cornerRadius: 0,
                    shadow: .hard(depth: 5)
                ),
                actionButton: ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 0,
                    shadow: .hard(depth: 2)
                ),
                menuRow: ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 0,
                    shadow: .hard(depth: 2)
                ),
                progress: ThemeProgressRecipe(
                    track: ThemeChromeRecipe(
                        outlineWidth: 2,
                        cornerRadius: 0,
                        shadow: .none
                    ),
                    height: 9,
                    trackColor: AppearanceColor(hex: 0xD8F5F1),
                    trackTintOpacity: 0.78,
                    fillDividerWidth: 2
                ),
                weeklyDividerWidth: 2,
                statusChip: ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 0,
                    shadow: .hard(depth: 3)
                ),
                statusReferenceColor: nil,
                statusFillOpacity: 1,
                statusLightening: 0,
                statusHorizontalPadding: 7,
                statusTagHeight: 18,
                panelFill: .solid,
                panelGradientStartColor: nil,
                panelGradientEndColor: nil,
                quotaSurfaceOpacity: 1,
                actionSurfaceOpacity: 1,
                typography: ThemeTypographyRecipe(
                    statusSize: 10,
                    statusWeight: .heavy,
                    statusFamily: .monospaced,
                    headerSize: 10,
                    headerWeight: .heavy,
                    headerFamily: .monospaced,
                    percentSize: 46,
                    percentWeight: .black,
                    percentFamily: .system,
                    percentTracking: -3,
                    labelSize: 10,
                    labelWeight: .heavy,
                    countdownSize: 24,
                    countdownWeight: .black,
                    metadataSize: 10,
                    metadataWeight: .bold,
                    secondaryPercentSize: 16,
                    uppercaseMetadata: true,
                    secondaryOpacity: 1
                )
            )
        case .bold:
            ThemeVisualRecipe(
                panelShell: ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 10,
                    shadow: .hard(depth: 5, opacity: 0.9)
                ),
                quotaCard: ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 7,
                    shadow: .none
                ),
                actionButton: ThemeChromeRecipe(
                    outlineWidth: 1.5,
                    cornerRadius: 4,
                    shadow: .hard(depth: 1.5)
                ),
                menuRow: ThemeChromeRecipe(
                    outlineWidth: 1.5,
                    cornerRadius: 4,
                    shadow: .none
                ),
                progress: ThemeProgressRecipe(
                    track: ThemeChromeRecipe(
                        outlineWidth: 1.5,
                        cornerRadius: 4,
                        shadow: .none
                    ),
                    height: 9,
                    trackColor: AppearanceColor(hex: 0xDCE9E7),
                    trackTintOpacity: 0.7,
                    fillDividerWidth: 1.5
                ),
                weeklyDividerWidth: 1.5,
                statusChip: ThemeChromeRecipe(
                    outlineWidth: 1.5,
                    cornerRadius: 5,
                    shadow: .hard(depth: 2)
                ),
                statusReferenceColor: AppearanceColor(hex: 0xB9EFE5),
                statusFillOpacity: 1,
                statusLightening: 0.65,
                statusHorizontalPadding: 7,
                statusTagHeight: 18,
                panelFill: .solid,
                panelGradientStartColor: nil,
                panelGradientEndColor: nil,
                quotaSurfaceOpacity: 1,
                actionSurfaceOpacity: 1,
                typography: ThemeTypographyRecipe(
                    statusSize: 10,
                    statusWeight: .bold,
                    statusFamily: .monospaced,
                    headerSize: 10,
                    headerWeight: .bold,
                    headerFamily: .monospaced,
                    percentSize: 46,
                    percentWeight: .black,
                    percentFamily: .system,
                    percentTracking: -3,
                    labelSize: 10,
                    labelWeight: .bold,
                    countdownSize: 24,
                    countdownWeight: .black,
                    metadataSize: 10,
                    metadataWeight: .bold,
                    secondaryPercentSize: 16,
                    uppercaseMetadata: false,
                    secondaryOpacity: 0.86
                )
            )
        case .frost:
            ThemeVisualRecipe(
                panelShell: ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 16,
                    shadow: .hard(depth: 5, opacity: 0.78)
                ),
                quotaCard: ThemeChromeRecipe(
                    outlineWidth: 2,
                    cornerRadius: 10,
                    shadow: .none
                ),
                actionButton: ThemeChromeRecipe(
                    outlineWidth: 1.5,
                    cornerRadius: 6,
                    shadow: .hard(depth: 1.5)
                ),
                menuRow: ThemeChromeRecipe(
                    outlineWidth: 1.5,
                    cornerRadius: 6,
                    shadow: .none
                ),
                progress: ThemeProgressRecipe(
                    track: ThemeChromeRecipe(
                        outlineWidth: 1.5,
                        cornerRadius: 5,
                        shadow: .none
                    ),
                    height: 9,
                    trackColor: AppearanceColor(
                        hex: 0xFFFFFF,
                        alpha: 0.55
                    ),
                    trackTintOpacity: 0.55,
                    fillDividerWidth: 1.5
                ),
                weeklyDividerWidth: 1.5,
                statusChip: ThemeChromeRecipe(
                    outlineWidth: 1.5,
                    cornerRadius: 7,
                    shadow: .hard(depth: 2, opacity: 0.72)
                ),
                statusReferenceColor: nil,
                statusFillOpacity: 0.3,
                statusLightening: 0,
                statusHorizontalPadding: 7,
                statusTagHeight: 18,
                panelFill: .materialGradient,
                panelGradientStartColor: AppearanceColor(
                    hex: 0xFFFFFF,
                    alpha: 0.78
                ),
                panelGradientEndColor: AppearanceColor(
                    hex: 0xB4E8F5,
                    alpha: 0.62
                ),
                quotaSurfaceOpacity: 0.38,
                actionSurfaceOpacity: 0.72,
                typography: ThemeTypographyRecipe(
                    statusSize: 10,
                    statusWeight: .bold,
                    statusFamily: .monospaced,
                    headerSize: 10,
                    headerWeight: .bold,
                    headerFamily: .monospaced,
                    percentSize: 46,
                    percentWeight: .black,
                    percentFamily: .rounded,
                    percentTracking: -3,
                    labelSize: 10,
                    labelWeight: .bold,
                    countdownSize: 24,
                    countdownWeight: .black,
                    metadataSize: 10,
                    metadataWeight: .bold,
                    secondaryPercentSize: 16,
                    uppercaseMetadata: false,
                    secondaryOpacity: 0.82
                )
            )
        }
    }

    func resolved(
        using geometry: ThemeGeometry,
        theme: AppearanceThemeID
    ) -> ThemeVisualRecipe {
        let geometry = geometry.clamped()
        let defaults = AppearanceProfile.default(for: theme).geometry
        let outlineScale = defaults.outlineWidth > 0
            ? geometry.outlineWidth / defaults.outlineWidth
            : 1
        let shadowScale = defaults.shadowDepth > 0
            ? geometry.shadowDepth / defaults.shadowDepth
            : 1
        let cornerDelta = geometry.cornerRadius - defaults.cornerRadius
        let surfaceScale = defaults.surfaceOpacity > 0
            ? geometry.surfaceOpacity / defaults.surfaceOpacity
            : 1

        var copy = self
        copy.panelShell = panelShell.resolved(
            outlineScale: outlineScale,
            cornerDelta: cornerDelta,
            shadowScale: shadowScale,
            shadowBlur: geometry.shadowBlur
        )
        copy.quotaCard = quotaCard.resolved(
            outlineScale: outlineScale,
            cornerDelta: cornerDelta,
            shadowScale: shadowScale,
            shadowBlur: geometry.shadowBlur
        )
        copy.actionButton = actionButton.resolved(
            outlineScale: outlineScale,
            cornerDelta: cornerDelta,
            shadowScale: shadowScale,
            shadowBlur: geometry.shadowBlur
        )
        copy.menuRow = menuRow.resolved(
            outlineScale: outlineScale,
            cornerDelta: cornerDelta,
            shadowScale: shadowScale,
            shadowBlur: geometry.shadowBlur
        )
        copy.progress.track = progress.track.resolved(
            outlineScale: outlineScale,
            cornerDelta: cornerDelta,
            shadowScale: shadowScale,
            shadowBlur: geometry.shadowBlur
        )
        copy.progress.fillDividerWidth *= outlineScale
        copy.weeklyDividerWidth *= outlineScale
        copy.statusChip = statusChip.resolved(
            outlineScale: outlineScale,
            cornerDelta: cornerDelta,
            shadowScale: shadowScale,
            shadowBlur: geometry.shadowBlur
        )
        copy.quotaSurfaceOpacity = min(
            max(quotaSurfaceOpacity * surfaceScale, 0),
            1
        )
        copy.actionSurfaceOpacity = min(
            max(actionSurfaceOpacity * surfaceScale, 0),
            1
        )
        copy.progress.trackColor = progress.trackColor.withAlpha(
            min(max(progress.trackColor.alpha * surfaceScale, 0), 1)
        )
        copy.panelGradientStartColor = panelGradientStartColor.map {
            $0.withAlpha(
                min(max($0.alpha * surfaceScale, 0), 1)
            )
        }
        copy.panelGradientEndColor = panelGradientEndColor.map {
            $0.withAlpha(
                min(max($0.alpha * surfaceScale, 0), 1)
            )
        }
        return copy
    }
}

extension ResolvedStatusItemAppearance {
    func fitted(
        to menuBarHeight: Double
    ) -> ResolvedStatusItemAppearance {
        let availableHeight = max(menuBarHeight - 1, 1)
        let originalOccupiedHeight = (
            tagHeight
                + shadowDepth
                + shadowBlur * 2
                + outlineWidth
        )
        guard originalOccupiedHeight > availableHeight else {
            return self
        }

        let minimumFontSize = min(fontSize, 8)
        let minimumTagHeight = min(
            tagHeight,
            max(minimumFontSize + 4, 12)
        )
        let uniformScale = availableHeight / originalOccupiedHeight
        let legibilityScale = tagHeight > 0
            ? minimumTagHeight / tagHeight
            : 1
        let geometryScale = min(
            1,
            max(uniformScale, legibilityScale)
        )

        var copy = self
        copy.fontSize = max(minimumFontSize, fontSize * geometryScale)
        copy.outlineWidth *= geometryScale
        copy.cornerRadius *= geometryScale
        copy.shadowDepth *= geometryScale
        copy.shadowBlur *= geometryScale
        copy.horizontalPadding *= geometryScale
        copy.tagHeight *= geometryScale

        let fixedHeight = copy.tagHeight + copy.outlineWidth
        guard fixedHeight <= availableHeight else {
            // Only reachable for an abnormally short status bar. Keep every
            // drawable inside the available rectangle even if the normal
            // 8-point legibility floor cannot be honored.
            let emergencyScale = availableHeight / fixedHeight
            copy.fontSize = min(
                copy.fontSize,
                max(1, copy.tagHeight * emergencyScale - 2)
            )
            copy.outlineWidth *= emergencyScale
            copy.cornerRadius *= emergencyScale
            copy.horizontalPadding *= emergencyScale
            copy.tagHeight *= emergencyScale
            copy.shadowDepth = 0
            copy.shadowBlur = 0
            return copy
        }

        let shadowHeight = copy.shadowDepth + copy.shadowBlur * 2
        let shadowBudget = max(0, availableHeight - fixedHeight)
        if shadowHeight > shadowBudget, shadowHeight > 0 {
            let shadowScale = shadowBudget / shadowHeight
            copy.shadowDepth *= shadowScale
            copy.shadowBlur *= shadowScale
        }
        return copy
    }
}
