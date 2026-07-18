import Foundation
import SwiftUI

enum AppearanceEditorInitialScrollTarget: Hashable, Sendable {
    case themeSelector
    case panelControls
    case statusItemControls
    case stateColorControls
}

enum AppearanceEditorDocumentationMetrics {
    static func trailingScrollSpace(
        for target: AppearanceEditorInitialScrollTarget?
    ) -> CGFloat {
        switch target {
        case .panelControls, .statusItemControls:
            MoreOverlayMetrics.statusItemSize.height
        case .stateColorControls:
            MoreOverlayMetrics.stateColorsSize.height
        case nil, .themeSelector:
            0
        }
    }
}

private struct AppearanceEditorInitialScrollTargetKey:
    EnvironmentKey
{
    static let defaultValue:
        AppearanceEditorInitialScrollTarget? = nil
}

extension EnvironmentValues {
    var appearanceEditorInitialScrollTarget:
        AppearanceEditorInitialScrollTarget?
    {
        get { self[AppearanceEditorInitialScrollTargetKey.self] }
        set { self[AppearanceEditorInitialScrollTargetKey.self] = newValue }
    }
}

enum BrutalEditorStyle {
    static var ink: Color {
        AppearanceColor(hex: 0x171717).swiftUIColor
    }

    static var paper: Color {
        AppearanceColor.white.swiftUIColor
    }

    static var coral: Color {
        AppearanceColor(hex: 0xFF716F).swiftUIColor
    }

    static var paleTeal: Color {
        AppearanceColor(hex: 0xEEF9F7).swiftUIColor
    }

    static var yellow: Color {
        AppearanceColor(hex: 0xFFE36E).swiftUIColor
    }

    static var savedGreen: Color {
        AppearanceColor(hex: 0x2F6F69).swiftUIColor
    }

    static var savingOrange: Color {
        AppearanceColor(hex: 0x9A4D00).swiftUIColor
    }
}

enum AppearanceEditorMetrics {
    static let colorControlHeight: CGFloat = 21
    static let customColorControlWidth: CGFloat = 25
}

struct AppearanceResetConfirmationState: Equatable, Sendable {
    private(set) var requestedTheme: AppearanceThemeID?

    mutating func request(
        for theme: AppearanceThemeID,
        canReset: Bool
    ) {
        requestedTheme = canReset ? theme : nil
    }

    mutating func selectedThemeDidChange(
        to theme: AppearanceThemeID
    ) {
        guard requestedTheme != theme else { return }
        requestedTheme = nil
    }

    mutating func confirm(
        for selectedTheme: AppearanceThemeID
    ) -> Bool {
        defer { requestedTheme = nil }
        return requestedTheme == selectedTheme
    }

    mutating func cancel() {
        requestedTheme = nil
    }
}

enum StatusItemEditorField:
    String,
    CaseIterable,
    Identifiable
{
    case fontSize
    case outlineWidth
    case cornerRadius
    case shadowDepth
    case shadowBlur
    case horizontalPadding
    case tagHeight

    var id: Self { self }

    var title: String {
        switch self {
        case .fontSize:
            "状态栏字体大小"
        case .outlineWidth:
            "显示层描边"
        case .cornerRadius:
            "显示层圆角"
        case .shadowDepth:
            "显示层阴影深度"
        case .shadowBlur:
            "显示层阴影模糊"
        case .horizontalPadding:
            "显示层横向留白"
        case .tagHeight:
            "显示层高度"
        }
    }

    var keyPath:
        WritableKeyPath<StatusItemGeometry, Double>
    {
        switch self {
        case .fontSize:
            \.fontSize
        case .outlineWidth:
            \.outlineWidth
        case .cornerRadius:
            \.cornerRadius
        case .shadowDepth:
            \.shadowDepth
        case .shadowBlur:
            \.shadowBlur
        case .horizontalPadding:
            \.horizontalPadding
        case .tagHeight:
            \.tagHeight
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .fontSize:
            StatusItemGeometry.EditorRange.fontSize
        case .outlineWidth:
            StatusItemGeometry.EditorRange.outlineWidth
        case .cornerRadius:
            StatusItemGeometry.EditorRange.cornerRadius
        case .shadowDepth:
            StatusItemGeometry.EditorRange.shadowDepth
        case .shadowBlur:
            StatusItemGeometry.EditorRange.shadowBlur
        case .horizontalPadding:
            StatusItemGeometry.EditorRange.horizontalPadding
        case .tagHeight:
            StatusItemGeometry.EditorRange.tagHeight
        }
    }

    var step: Double {
        switch self {
        case .outlineWidth:
            0.25
        case .cornerRadius:
            1
        default:
            0.5
        }
    }

    var fractionDigits: Int {
        switch self {
        case .outlineWidth:
            2
        case .cornerRadius:
            0
        default:
            1
        }
    }

    var accessibilityIdentifier: String {
        "status-item-\(rawValue)"
    }
}

enum AppearanceEditorPalette {
    static func swatches(
        for token: AppearanceColorToken
    ) -> [AppearanceColor] {
        let colors: [AppearanceColor]
        switch token {
        case .background:
            colors = [
                AppearanceColor(hex: 0xFFE36E),
                AppearanceColor(hex: 0xF7F3E8),
                AppearanceColor(hex: 0xDDF3F8, alpha: 0.72),
                AppearanceColor(hex: 0xFFDDE5),
                AppearanceColor(hex: 0xE7DFFF)
            ]
        case .surface:
            colors = [
                .white,
                AppearanceColor(hex: 0xF6F1E7),
                AppearanceColor(hex: 0xE8F6F7),
                AppearanceColor(hex: 0xFFF1D2),
                AppearanceColor(hex: 0x242424)
            ]
        case .textAndOutline:
            colors = [
                AppearanceColor(hex: 0x171717),
                .black,
                AppearanceColor(hex: 0x172027),
                AppearanceColor(hex: 0x20304A),
                .white
            ]
        case .actionAccent:
            colors = [
                AppearanceColor(hex: 0xFF676B),
                AppearanceColor(hex: 0xFF8A82),
                AppearanceColor(hex: 0xE46D78),
                AppearanceColor(hex: 0xFF9F1C),
                AppearanceColor(hex: 0xC659FF)
            ]
        case .normal:
            colors = [
                AppearanceColor(hex: 0x4FC9C1),
                AppearanceColor(hex: 0x44C7B7),
                AppearanceColor(hex: 0x55B8FF),
                AppearanceColor(hex: 0x66CF72),
                AppearanceColor(hex: 0xB5D94C)
            ]
        case .warning:
            colors = [
                AppearanceColor(hex: 0xFF9F1C),
                AppearanceColor(hex: 0xE8BE3F),
                AppearanceColor(hex: 0xFFD15C),
                AppearanceColor(hex: 0xFFB36B),
                AppearanceColor(hex: 0xD5A7FF)
            ]
        case .danger:
            colors = [
                AppearanceColor(hex: 0xFF676B),
                AppearanceColor(hex: 0xE76B68),
                AppearanceColor(hex: 0xE46D78),
                AppearanceColor(hex: 0xFF5A9D),
                AppearanceColor(hex: 0xC659FF)
            ]
        case .unavailableBase:
            colors = [
                .white,
                AppearanceColor(hex: 0xE9E6DE),
                AppearanceColor(hex: 0xEFF4F5),
                AppearanceColor(hex: 0xD8D8D8),
                AppearanceColor(hex: 0x242424)
            ]
        case .unavailableStripe:
            colors = [
                AppearanceColor(hex: 0xFF676B),
                AppearanceColor(hex: 0xC55B59),
                AppearanceColor(hex: 0xCE6670),
                AppearanceColor(hex: 0xFF9F1C),
                AppearanceColor(hex: 0x6D65E8)
            ]
        }
        return colors
    }
}
