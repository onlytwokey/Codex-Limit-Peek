import Foundation
import SwiftUI

enum AppearanceEditorInitialScrollTarget: Hashable, Sendable {
    case themeSelector
    case panelControls
    case panelColorControls
    case panelGeometryControls
    case panelShadowControls
    case statusItemControls
    case statusItemShadowControls
    case statusItemGeometryControls
    case stateColorControls
}

enum AppearanceEditorDocumentationMetrics {
    static func trailingScrollSpace(
        for target: AppearanceEditorInitialScrollTarget?
    ) -> CGFloat {
        switch target {
        case .panelControls,
             .panelColorControls,
             .panelGeometryControls,
             .panelShadowControls:
            MoreOverlayMetrics.appearanceSize.height
        case .statusItemControls,
             .statusItemShadowControls,
             .statusItemGeometryControls,
             .stateColorControls:
            MoreOverlayMetrics.statusItemSize.height
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

private struct AppearanceEditorDocumentationScrollSpaceKey:
    EnvironmentKey
{
    static let defaultValue = false
}

extension EnvironmentValues {
    var appearanceEditorInitialScrollTarget:
        AppearanceEditorInitialScrollTarget?
    {
        get { self[AppearanceEditorInitialScrollTargetKey.self] }
        set { self[AppearanceEditorInitialScrollTargetKey.self] = newValue }
    }

    var appearanceEditorAddsDocumentationScrollSpace: Bool {
        get { self[AppearanceEditorDocumentationScrollSpaceKey.self] }
        set {
            self[AppearanceEditorDocumentationScrollSpaceKey.self] = newValue
        }
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
    case shadowHorizontalOffset
    case shadowVerticalOffset
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
        case .shadowHorizontalOffset:
            "阴影水平偏移"
        case .shadowVerticalOffset:
            "阴影垂直偏移"
        case .shadowBlur:
            "阴影模糊"
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
        case .shadowHorizontalOffset:
            \.shadowHorizontalOffset
        case .shadowVerticalOffset:
            \.shadowVerticalOffset
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
        case .shadowHorizontalOffset, .shadowVerticalOffset:
            StatusItemGeometry.EditorRange.shadowOffset
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
        switch self {
        case .fontSize:
            "status-item-font-size"
        case .outlineWidth:
            "status-item-outline-width"
        case .cornerRadius:
            "status-item-corner-radius"
        case .shadowHorizontalOffset:
            "status-item-shadow-horizontal-offset"
        case .shadowVerticalOffset:
            "status-item-shadow-vertical-offset"
        case .shadowBlur:
            "status-item-shadow-blur"
        case .horizontalPadding:
            "status-item-horizontal-padding"
        case .tagHeight:
            "status-item-tag-height"
        }
    }

    static var shadowFields: [StatusItemEditorField] {
        [
            .shadowHorizontalOffset,
            .shadowVerticalOffset,
            .shadowBlur
        ]
    }

    static var geometryFields: [StatusItemEditorField] {
        [
            .fontSize,
            .outlineWidth,
            .cornerRadius,
            .horizontalPadding,
            .tagHeight
        ]
    }
}

enum StatusItemEditorPreviewFixture {
    static let primaryRemainingPercent = 81
    static let weeklyRemainingPercent = 49

    static func appearance(
        for profile: AppearanceProfile
    ) -> ResolvedStatusItemAppearance {
        AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: primaryRemainingPercent,
            weeklyRemainingPercent: weeklyRemainingPercent,
            isUnavailable: false,
            showsFailurePattern: false
        )
    }

    static func effectiveColor(
        for token: StatusItemColorToken,
        in appearance: ResolvedStatusItemAppearance
    ) -> AppearanceColor {
        switch token {
        case .primaryText:
            appearance.primaryTextColor
        case .weeklyText:
            appearance.weeklyTextColor
        case .shadow:
            appearance.shadowColor
        }
    }

    static func contrastBackgrounds(
        for profile: AppearanceProfile
    ) -> [AppearanceColor] {
        let states: [(
            primary: Int,
            weekly: Int,
            isUnavailable: Bool,
            showsFailurePattern: Bool
        )] = [
            (81, 49, false, false),
            (35, 35, false, false),
            (10, 10, false, false),
            (0, 0, true, false),
            (63, 38, false, true)
        ]

        return states.flatMap { state in
            let fill = AppearanceResolver.status(
                profile: profile,
                primaryRemainingPercent: state.primary,
                weeklyRemainingPercent: state.weekly,
                isUnavailable: state.isUnavailable,
                showsFailurePattern: state.showsFailurePattern
            ).fillColor
            return [
                fill.composited(over: .white),
                fill.composited(over: .black)
            ]
        }
    }
}

enum AppearanceEditorPalette {
    static func swatches(
        for token: AppearanceColorToken,
        theme: AppearanceThemeID
    ) -> [AppearanceColor] {
        let colors: [AppearanceColor]
        switch token {
        case .background:
            colors = [
                AppearanceColor(hex: 0xFFE36E),
                AppearanceColor(hex: 0xF7F3E8),
                AppearanceColor(
                    hex: 0xDDF3F8,
                    alpha: theme == .frost ? 0.72 : 1
                ),
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
            colors = stateSwatches(
                theme: theme,
                loud: [
                    0x4FC9C1, 0x3B82F6, 0x5DBB63,
                    0x8A6BFF, 0x006B72
                ],
                bold: [
                    0x45C7BB, 0x004C9E, 0x146B32,
                    0x737900, 0x12323A
                ],
                frost: [
                    0x4FC9C1, 0x77A9DF, 0x61A884,
                    0x8B7DD6, 0x3B7180
                ]
            )
        case .warning:
            colors = stateSwatches(
                theme: theme,
                loud: [
                    0xFF9F1C, 0xFFD60A, 0xB99A00,
                    0xFFB48A, 0x8A4B00
                ],
                bold: [
                    0xE8BE3F, 0xFFF6C2, 0x806000,
                    0xC24A12, 0x442800
                ],
                frost: [
                    0xE3BB55, 0xF5E6A1, 0xB28B45,
                    0xE7A17E, 0x7A5935
                ]
            )
        case .danger:
            colors = stateSwatches(
                theme: theme,
                loud: [
                    0xFF676B, 0xD90429, 0xD8327D,
                    0xB743E6, 0x6D1F2A
                ],
                bold: [
                    0xE76B68, 0x9A0030, 0xB50078,
                    0x4F1A78, 0x3A0C16
                ],
                frost: [
                    0xE46D78, 0xB83B58, 0xC94F91,
                    0x8354A7, 0x663844
                ]
            )
        case .unavailableBase:
            colors = stateSwatches(
                theme: theme,
                loud: [
                    0xFFFFFF, 0xC6E6FF, 0xC9DBB7,
                    0xD9C8FF, 0x23252B
                ],
                bold: [
                    0xE9E6DE, 0x9BBFD1, 0xA9C28F,
                    0xC9947E, 0x292A2B
                ],
                frost: [
                    0xEFF4F5, 0xAACBE6, 0x9DC9B0,
                    0xC3A8D8, 0x2A3842
                ]
            )
        case .unavailableStripe:
            colors = stateSwatches(
                theme: theme,
                loud: [
                    0xFF676B, 0x1F5FBF, 0x657300,
                    0x7A4CC2, 0xE8EFF2
                ],
                bold: [
                    0xC55B59, 0x49647A, 0x4F5D2A,
                    0x6D3A2A, 0xB6BEC1
                ],
                frost: [
                    0xCE6670, 0x3E739B, 0x356653,
                    0x5C4088, 0xD4E4EB
                ]
            )
        }
        return colors
    }

    private static func stateSwatches(
        theme: AppearanceThemeID,
        loud: [UInt32],
        bold: [UInt32],
        frost: [UInt32]
    ) -> [AppearanceColor] {
        let hexValues = switch theme {
        case .loud:
            loud
        case .bold:
            bold
        case .frost:
            frost
        }
        return hexValues.map { AppearanceColor(hex: $0) }
    }

    static func statusItemSwatches(
        for token: StatusItemColorToken
    ) -> [AppearanceColor] {
        switch token {
        case .primaryText, .weeklyText:
            [
                .black,
                .white,
                AppearanceColor(hex: 0x20304A),
                AppearanceColor(hex: 0xFF676B),
                AppearanceColor(hex: 0x2F6F69)
            ]
        case .shadow:
            [
                .black,
                AppearanceColor(hex: 0x171717),
                AppearanceColor(hex: 0x20304A),
                AppearanceColor(hex: 0xFF676B),
                AppearanceColor(hex: 0x6D65E8)
            ]
        }
    }
}
