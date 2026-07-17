import AppKit
import Foundation
import SwiftUI

enum AppearanceThemeID: String, CaseIterable, Codable, Sendable {
    case loud
    case bold
    case frost

    var displayName: String {
        rawValue.uppercased()
    }

    var subtitle: String {
        switch self {
        case .loud:
            "高饱和、粗描边、强硬阴影"
        case .bold:
            "克制配色、细描边、硬朗结构"
        case .frost:
            "玻璃材质、柔光与撞色"
        }
    }
}

struct AppearanceColor: Codable, Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xff) / 255
        green = Double((hex >> 8) & 0xff) / 255
        blue = Double(hex & 0xff) / 255
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.sRGB) ?? .black
        red = Double(color.redComponent)
        green = Double(color.greenComponent)
        blue = Double(color.blueComponent)
        alpha = Double(color.alphaComponent)
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    func clamped() -> AppearanceColor {
        AppearanceColor(
            red: min(max(red, 0), 1),
            green: min(max(green, 0), 1),
            blue: min(max(blue, 0), 1),
            alpha: min(max(alpha, 0), 1)
        )
    }

    func withAlpha(_ alpha: Double) -> AppearanceColor {
        var copy = self
        copy.alpha = alpha
        return copy
    }

    func composited(over background: AppearanceColor) -> AppearanceColor {
        let foreground = clamped()
        let base = background.clamped()
        let outputAlpha = foreground.alpha + base.alpha * (1 - foreground.alpha)
        guard outputAlpha > 0 else { return .clear }
        return AppearanceColor(
            red: (
                foreground.red * foreground.alpha
                    + base.red * base.alpha * (1 - foreground.alpha)
            ) / outputAlpha,
            green: (
                foreground.green * foreground.alpha
                    + base.green * base.alpha * (1 - foreground.alpha)
            ) / outputAlpha,
            blue: (
                foreground.blue * foreground.alpha
                    + base.blue * base.alpha * (1 - foreground.alpha)
            ) / outputAlpha,
            alpha: outputAlpha
        )
    }

    var relativeLuminance: Double {
        func linear(_ component: Double) -> Double {
            let component = min(max(component, 0), 1)
            return component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red)
            + 0.7152 * linear(green)
            + 0.0722 * linear(blue)
    }

    func contrastRatio(with other: AppearanceColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func readable(
        on background: AppearanceColor,
        minimumRatio: Double = 4.5
    ) -> AppearanceColor {
        let candidate = clamped().withAlpha(1)
        guard candidate.contrastRatio(with: background) < minimumRatio else {
            return candidate
        }
        return AppearanceColor.black.contrastRatio(with: background)
            >= AppearanceColor.white.contrastRatio(with: background)
            ? .black
            : .white
    }

    func readableAccent(
        on background: AppearanceColor,
        minimumRatio: Double = 4.5
    ) -> AppearanceColor {
        let candidate = clamped().withAlpha(1)
        guard candidate.contrastRatio(with: background) < minimumRatio else {
            return candidate
        }
        let target = AppearanceColor.black.contrastRatio(with: background)
            >= AppearanceColor.white.contrastRatio(with: background)
            ? AppearanceColor.black
            : AppearanceColor.white
        for step in 1...20 {
            let amount = Double(step) / 20
            let mixed = candidate.mixed(with: target, amount: amount)
            if mixed.contrastRatio(with: background) >= minimumRatio {
                return mixed
            }
        }
        return target
    }

    func mixed(
        with other: AppearanceColor,
        amount: Double
    ) -> AppearanceColor {
        let amount = min(max(amount, 0), 1)
        return AppearanceColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount,
            alpha: 1
        )
    }

    static let black = AppearanceColor(hex: 0x000000)
    static let white = AppearanceColor(hex: 0xFFFFFF)
    static let clear = AppearanceColor(red: 0, green: 0, blue: 0, alpha: 0)
}

enum AppearanceColorToken: String, CaseIterable, Sendable {
    case background
    case surface
    case textAndOutline
    case actionAccent
    case normal
    case warning
    case danger
    case unavailableBase
    case unavailableStripe
}

struct ThemePalette: Codable, Equatable, Sendable {
    var background: AppearanceColor
    var surface: AppearanceColor
    var textAndOutline: AppearanceColor
    var actionAccent: AppearanceColor
    var normal: AppearanceColor
    var warning: AppearanceColor
    var danger: AppearanceColor
    var unavailableBase: AppearanceColor
    var unavailableStripe: AppearanceColor

    subscript(token: AppearanceColorToken) -> AppearanceColor {
        get {
            switch token {
            case .background:
                background
            case .surface:
                surface
            case .textAndOutline:
                textAndOutline
            case .actionAccent:
                actionAccent
            case .normal:
                normal
            case .warning:
                warning
            case .danger:
                danger
            case .unavailableBase:
                unavailableBase
            case .unavailableStripe:
                unavailableStripe
            }
        }
        set {
            switch token {
            case .background:
                background = newValue
            case .surface:
                surface = newValue
            case .textAndOutline:
                textAndOutline = newValue
            case .actionAccent:
                actionAccent = newValue
            case .normal:
                normal = newValue
            case .warning:
                warning = newValue
            case .danger:
                danger = newValue
            case .unavailableBase:
                unavailableBase = newValue
            case .unavailableStripe:
                unavailableStripe = newValue
            }
        }
    }
}

struct ThemeGeometry: Codable, Equatable, Sendable {
    var fontScale: Double
    var outlineWidth: Double
    var cornerRadius: Double
    var shadowDepth: Double
    var shadowBlur: Double
    var surfaceOpacity: Double

    func clamped() -> ThemeGeometry {
        ThemeGeometry(
            fontScale: min(max(fontScale, 0.8), 1.25),
            outlineWidth: min(max(outlineWidth, 0), 4),
            cornerRadius: min(max(cornerRadius, 0), 28),
            shadowDepth: min(max(shadowDepth, 0), 10),
            shadowBlur: min(max(shadowBlur, 0), 20),
            surfaceOpacity: min(max(surfaceOpacity, 0.55), 1)
        )
    }
}

struct ThemeCapabilities: Codable, Equatable, Sendable {
    var usesMaterial: Bool
    var uppercaseMetadata: Bool
    var roundedPrimaryTypography: Bool
}

struct AppearanceProfile: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var themeID: AppearanceThemeID
    var palette: ThemePalette
    var geometry: ThemeGeometry
    var capabilities: ThemeCapabilities

    func validated(for expectedTheme: AppearanceThemeID) -> AppearanceProfile {
        var copy = self
        copy.schemaVersion = Self.currentSchemaVersion
        copy.themeID = expectedTheme
        copy.palette = ThemePalette(
            background: palette.background.clamped(),
            surface: palette.surface.clamped(),
            textAndOutline: palette.textAndOutline.clamped(),
            actionAccent: palette.actionAccent.clamped(),
            normal: palette.normal.clamped(),
            warning: palette.warning.clamped(),
            danger: palette.danger.clamped(),
            unavailableBase: palette.unavailableBase.clamped(),
            unavailableStripe: palette.unavailableStripe.clamped()
        )
        copy.geometry = geometry.clamped()
        copy.capabilities = Self.default(for: expectedTheme).capabilities
        return copy
    }
}

extension AppearanceProfile {
    static func `default`(for theme: AppearanceThemeID) -> AppearanceProfile {
        switch theme {
        case .loud:
            AppearanceProfile(
                schemaVersion: currentSchemaVersion,
                themeID: .loud,
                palette: ThemePalette(
                    background: AppearanceColor(hex: 0xFFE36E),
                    surface: AppearanceColor(hex: 0xFFFFFF),
                    textAndOutline: AppearanceColor(hex: 0x171717),
                    actionAccent: AppearanceColor(hex: 0xFF676B),
                    normal: AppearanceColor(hex: 0x4FC9C1),
                    warning: AppearanceColor(hex: 0xFF9F1C),
                    danger: AppearanceColor(hex: 0xFF676B),
                    unavailableBase: AppearanceColor(hex: 0xFFFFFF),
                    unavailableStripe: AppearanceColor(hex: 0xFF676B)
                ),
                geometry: ThemeGeometry(
                    fontScale: 1,
                    outlineWidth: 3,
                    cornerRadius: 0,
                    shadowDepth: 8,
                    shadowBlur: 0,
                    surfaceOpacity: 1
                ),
                capabilities: ThemeCapabilities(
                    usesMaterial: false,
                    uppercaseMetadata: true,
                    roundedPrimaryTypography: false
                )
            )
        case .bold:
            AppearanceProfile(
                schemaVersion: currentSchemaVersion,
                themeID: .bold,
                palette: ThemePalette(
                    background: AppearanceColor(hex: 0xF7F3E8),
                    surface: AppearanceColor(hex: 0xFFFFFF),
                    textAndOutline: AppearanceColor(hex: 0x191919),
                    actionAccent: AppearanceColor(hex: 0xFF8A82),
                    normal: AppearanceColor(hex: 0x45C7BB),
                    warning: AppearanceColor(hex: 0xE8BE3F),
                    danger: AppearanceColor(hex: 0xE76B68),
                    unavailableBase: AppearanceColor(hex: 0xE9E6DE),
                    unavailableStripe: AppearanceColor(hex: 0xC55B59)
                ),
                geometry: ThemeGeometry(
                    fontScale: 1,
                    outlineWidth: 2,
                    cornerRadius: 10,
                    shadowDepth: 5,
                    shadowBlur: 0,
                    surfaceOpacity: 1
                ),
                capabilities: ThemeCapabilities(
                    usesMaterial: false,
                    uppercaseMetadata: false,
                    roundedPrimaryTypography: false
                )
            )
        case .frost:
            AppearanceProfile(
                schemaVersion: currentSchemaVersion,
                themeID: .frost,
                palette: ThemePalette(
                    background: AppearanceColor(
                        hex: 0xDDF3F8,
                        alpha: 0.72
                    ),
                    surface: AppearanceColor(hex: 0xFFFFFF),
                    textAndOutline: AppearanceColor(hex: 0x172027),
                    actionAccent: AppearanceColor(hex: 0xFF676B),
                    normal: AppearanceColor(hex: 0x4FC9C1),
                    warning: AppearanceColor(hex: 0xE3BB55),
                    danger: AppearanceColor(hex: 0xE46D78),
                    unavailableBase: AppearanceColor(hex: 0xEFF4F5),
                    unavailableStripe: AppearanceColor(hex: 0xCE6670)
                ),
                geometry: ThemeGeometry(
                    fontScale: 1,
                    outlineWidth: 2,
                    cornerRadius: 16,
                    shadowDepth: 5,
                    shadowBlur: 0,
                    surfaceOpacity: 0.55
                ),
                capabilities: ThemeCapabilities(
                    usesMaterial: true,
                    uppercaseMetadata: false,
                    roundedPrimaryTypography: true
                )
            )
        }
    }
}

enum QuotaAppearanceState: Equatable, Sendable {
    case normal
    case warning
    case danger
    case unavailable
}

struct ResolvedPanelAppearance: Equatable, Sendable {
    var themeID: AppearanceThemeID
    var backgroundColor: AppearanceColor
    var surfaceColor: AppearanceColor
    var actionAccentColor: AppearanceColor
    var progressTrackColor: AppearanceColor
    var panelGradientEndColor: AppearanceColor?
    var backgroundTextColor: AppearanceColor
    var textColor: AppearanceColor
    var outlineColor: AppearanceColor
    var primaryStateColor: AppearanceColor
    var weeklyStateColor: AppearanceColor
    var unavailableBaseColor: AppearanceColor
    var unavailableStripeColor: AppearanceColor
    var geometry: ThemeGeometry
    var capabilities: ThemeCapabilities
    var visuals: ThemeVisualRecipe
    var hasContrastSubstitution: Bool
}

struct ResolvedStatusItemAppearance: Equatable, Sendable {
    var themeID: AppearanceThemeID
    var fontSize: Double
    var fontFamily: ThemeFontFamily
    var fontWeight: ThemeFontWeight
    var fillColor: AppearanceColor
    var primaryTextColor: AppearanceColor
    var weeklyTextColor: AppearanceColor
    var outlineColor: AppearanceColor
    var unavailableBaseColor: AppearanceColor
    var unavailableStripeColor: AppearanceColor
    var outlineWidth: Double
    var cornerRadius: Double
    var shadowDepth: Double
    var shadowBlur: Double
    var shadowOpacity: Double
    var horizontalPadding: Double
    var tagHeight: Double
}

enum AppearanceResolver {
    static func state(
        remainingPercent: Int,
        isUnavailable: Bool
    ) -> QuotaAppearanceState {
        guard !isUnavailable else { return .unavailable }
        switch remainingPercent {
        case 0...20:
            return .danger
        case 21...45:
            return .warning
        default:
            return .normal
        }
    }

    static func color(
        for state: QuotaAppearanceState,
        palette: ThemePalette
    ) -> AppearanceColor {
        switch state {
        case .normal:
            palette.normal
        case .warning:
            palette.warning
        case .danger:
            palette.danger
        case .unavailable:
            palette.unavailableBase
        }
    }

    static func panel(
        profile: AppearanceProfile,
        primaryRemainingPercent: Int,
        weeklyRemainingPercent: Int,
        isUnavailable: Bool
    ) -> ResolvedPanelAppearance {
        let profile = profile.validated(for: profile.themeID)
        let visuals = ThemeVisualRecipe.default(for: profile.themeID)
            .resolved(using: profile.geometry, theme: profile.themeID)
        let defaultGeometry = AppearanceProfile.default(
            for: profile.themeID
        ).geometry
        let surfaceScale = defaultGeometry.surfaceOpacity > 0
            ? profile.geometry.surfaceOpacity
                / defaultGeometry.surfaceOpacity
            : 1
        let usesReferenceGradientStart = (
            visuals.panelFill == .materialGradient
                && profile.palette.background
                    == AppearanceProfile.default(
                        for: profile.themeID
                    ).palette.background
        )
        let backgroundColor = usesReferenceGradientStart
            ? visuals.panelGradientStartColor
                ?? profile.palette.background
            : profile.palette.background.withAlpha(
                visuals.panelFill == .materialGradient
                    ? min(
                        profile.palette.background.alpha * surfaceScale,
                        1
                    )
                    : profile.palette.background.alpha
            )
        let surfaceOpacity = visuals.quotaSurfaceOpacity
            * profile.palette.surface.alpha
        let actionOpacity = min(
            profile.palette.actionAccent.alpha,
            visuals.actionSurfaceOpacity
        )
        let defaultPalette = AppearanceProfile.default(
            for: profile.themeID
        ).palette
        let usesReferenceTrack = (
            profile.palette.normal == defaultPalette.normal
                && profile.palette.surface == defaultPalette.surface
        )
        let progressTrackColor: AppearanceColor
        if usesReferenceTrack {
            progressTrackColor = visuals.progress.trackColor
        } else if visuals.panelFill == .materialGradient {
            progressTrackColor = profile.palette.surface.withAlpha(
                visuals.progress.trackColor.alpha
            )
        } else {
            progressTrackColor = profile.palette.normal
                .mixed(
                    with: profile.palette.surface,
                    amount: visuals.progress.trackTintOpacity
                )
                .withAlpha(visuals.progress.trackColor.alpha)
        }
        let effectiveSurface = profile.palette.surface
            .withAlpha(surfaceOpacity)
            .composited(over: backgroundColor)
            .composited(over: .white)
        let effectiveBackground = backgroundColor
            .composited(over: .white)
        let text = profile.palette.textAndOutline.readable(on: effectiveSurface)
        let backgroundText = profile.palette.textAndOutline.readable(
            on: effectiveBackground
        )
        return ResolvedPanelAppearance(
            themeID: profile.themeID,
            backgroundColor: backgroundColor,
            surfaceColor: profile.palette.surface.withAlpha(surfaceOpacity),
            actionAccentColor: profile.palette.actionAccent.withAlpha(
                actionOpacity
            ),
            progressTrackColor: progressTrackColor,
            panelGradientEndColor: visuals.panelGradientEndColor,
            backgroundTextColor: backgroundText,
            textColor: text,
            outlineColor: profile.palette.textAndOutline,
            primaryStateColor: color(
                for: state(
                    remainingPercent: primaryRemainingPercent,
                    isUnavailable: isUnavailable
                ),
                palette: profile.palette
            ),
            weeklyStateColor: color(
                for: state(
                    remainingPercent: weeklyRemainingPercent,
                    isUnavailable: isUnavailable
                ),
                palette: profile.palette
            ),
            unavailableBaseColor: profile.palette.unavailableBase,
            unavailableStripeColor: profile.palette.unavailableStripe,
            geometry: profile.geometry,
            capabilities: profile.capabilities,
            visuals: visuals,
            hasContrastSubstitution: (
                text != profile.palette.textAndOutline.withAlpha(1)
                    || backgroundText
                        != profile.palette.textAndOutline.withAlpha(1)
            )
        )
    }

    static func status(
        profile: AppearanceProfile,
        primaryRemainingPercent: Int,
        weeklyRemainingPercent: Int,
        isUnavailable: Bool,
        showsFailurePattern: Bool
    ) -> ResolvedStatusItemAppearance {
        let profile = profile.validated(for: profile.themeID)
        let visuals = ThemeVisualRecipe.default(for: profile.themeID)
            .resolved(using: profile.geometry, theme: profile.themeID)
        let primaryState = state(
            remainingPercent: primaryRemainingPercent,
            isUnavailable: isUnavailable || showsFailurePattern
        )
        let semanticFill = showsFailurePattern
            ? profile.palette.unavailableBase
            : color(for: primaryState, palette: profile.palette)
        let usesReferenceNormal = (
            showsFailurePattern == false
                && primaryState == .normal
                && profile.palette.normal
                    == AppearanceProfile.default(
                        for: profile.themeID
                    ).palette.normal
        )
        let fill = primaryState == .unavailable
            ? semanticFill
            : (
                usesReferenceNormal
                    ? visuals.statusReferenceColor
                    : nil
            ) ?? semanticFill
                .mixed(
                    with: .white,
                    amount: visuals.statusLightening
                )
                .withAlpha(
                    min(semanticFill.alpha, visuals.statusFillOpacity)
                )
        let effectiveFill = fill.composited(over: .white)
        let primaryText = profile.palette.textAndOutline.readable(
            on: effectiveFill
        )
        return ResolvedStatusItemAppearance(
            themeID: profile.themeID,
            fontSize: min(
                max(
                    visuals.typography.statusSize
                        * profile.geometry.fontScale,
                    9
                ),
                12.5
            ),
            fontFamily: visuals.typography.statusFamily,
            fontWeight: visuals.typography.statusWeight,
            fillColor: fill,
            primaryTextColor: primaryText,
            weeklyTextColor: primaryText,
            outlineColor: profile.palette.textAndOutline.readable(
                on: effectiveFill
            ),
            unavailableBaseColor: profile.palette.unavailableBase,
            unavailableStripeColor: profile.palette.unavailableStripe,
            outlineWidth: visuals.statusChip.outlineWidth,
            cornerRadius: visuals.statusChip.cornerRadius,
            shadowDepth: visuals.statusChip.shadow.depth,
            shadowBlur: visuals.statusChip.shadow.blur,
            shadowOpacity: visuals.statusChip.shadow.opacity,
            horizontalPadding: visuals.statusHorizontalPadding,
            tagHeight: visuals.statusTagHeight
        )
    }
}
