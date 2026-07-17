import AppKit
import SwiftUI

extension ThemeFontWeight {
    var swiftUIFontWeight: Font.Weight {
        switch self {
        case .semibold:
            .semibold
        case .bold:
            .bold
        case .heavy:
            .heavy
        case .black:
            .black
        }
    }
}

extension ThemeFontFamily {
    var swiftUIFontDesign: Font.Design {
        switch self {
        case .system:
            .default
        case .rounded:
            .rounded
        case .monospaced:
            .monospaced
        }
    }
}

enum ThemePanelLayout {
    static let width: CGFloat = 360
    static let height: CGFloat = 220
    static let shadowSafetyInset: CGFloat = 34
    static let contentPadding: CGFloat = 14
    static let verticalSpacing: CGFloat = 12
    static let quotaSpacing: CGFloat = 14
    static let actionSize: CGFloat = 25
    static let actionIconSize: CGFloat = 14
}

struct ThemePanelDisplayData: Equatable, Sendable {
    var headerText: String
    var percentText: String
    var primaryQuotaLabel: String
    var shortResetText: String
    var primaryResetDetailText: String
    var displayRemainingPercent: Int
    var showsSecondaryQuota: Bool
    var weeklyPercentText: String
    var weeklyResetDateText: String

    static func reference(
        for theme: AppearanceThemeID
    ) -> ThemePanelDisplayData {
        ThemePanelDisplayData(
            headerText: theme == .loud
                ? "CODEX 会话 · LIVE"
                : "Codex 会话 · 更新于 18:04",
            percentText: "81%",
            primaryQuotaLabel: "5 小时剩余",
            shortResetText: "1h34m",
            primaryResetDetailText: "19:38",
            displayRemainingPercent: 81,
            showsSecondaryQuota: true,
            weeklyPercentText: "49%",
            weeklyResetDateText: "7月14日恢复"
        )
    }
}

struct ThemePanelComposition<Actions: View>: View {
    let appearance: ResolvedPanelAppearance
    let data: ThemePanelDisplayData
    let headerForeground: Color
    let showsOuterChrome: Bool
    let actions: Actions

    init(
        appearance: ResolvedPanelAppearance,
        data: ThemePanelDisplayData,
        headerForeground: Color,
        showsOuterChrome: Bool = true,
        @ViewBuilder actions: () -> Actions
    ) {
        self.appearance = appearance
        self.data = data
        self.headerForeground = headerForeground
        self.showsOuterChrome = showsOuterChrome
        self.actions = actions()
    }

    private var contentCompression: CGFloat {
        CGFloat(
            max(
                0.65,
                1 - max(appearance.geometry.fontScale - 1, 0) * 1.4
            )
        )
    }

    private var typography: ThemeTypographyRecipe {
        appearance.visuals.typography
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: ThemePanelLayout.verticalSpacing * contentCompression
        ) {
            HStack(alignment: .center, spacing: 8) {
                Text(
                    typography.uppercaseMetadata
                        ? data.headerText.uppercased()
                        : data.headerText
                )
                .font(
                    .system(
                        size: CGFloat(
                            typography.headerSize
                                * appearance.geometry.fontScale
                        ),
                        weight: typography.headerWeight.swiftUIFontWeight,
                        design: typography.headerFamily.swiftUIFontDesign
                    )
                )
                .foregroundStyle(headerForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 8)
                actions
            }

            ThemeQuotaCard(
                appearance: appearance,
                data: data,
                contentCompression: contentCompression
            )
        }
        .padding(ThemePanelLayout.contentPadding)
        .frame(
            width: ThemePanelLayout.width,
            height: ThemePanelLayout.height
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: CGFloat(
                    appearance.visuals.panelShell.cornerRadius
                ),
                style: .continuous
            )
        )
        .background {
            if showsOuterChrome {
                ThemeSurfaceBackground(
                    appearance: appearance,
                    chrome: appearance.visuals.panelShell,
                    fill: appearance.backgroundColor,
                    fillStyle: appearance.visuals.panelFill,
                    gradientEnd: appearance.panelGradientEndColor
                )
            }
        }
    }
}

private struct ThemeQuotaCard: View {
    let appearance: ResolvedPanelAppearance
    let data: ThemePanelDisplayData
    let contentCompression: CGFloat

    private var typography: ThemeTypographyRecipe {
        appearance.visuals.typography
    }

    var body: some View {
        Group {
            if data.showsSecondaryQuota {
                content
                    .padding(
                        ThemePanelLayout.contentPadding * contentCompression
                    )
                    .themeSurface(
                        appearance: appearance,
                        chrome: appearance.visuals.quotaCard,
                        fill: appearance.surfaceColor
                    )
            } else {
                content
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(
                        ThemePanelLayout.contentPadding * contentCompression
                    )
                    .themeSurface(
                        appearance: appearance,
                        chrome: appearance.visuals.quotaCard,
                        fill: appearance.surfaceColor
                    )
            }
        }
        .foregroundStyle(appearance.textColor.swiftUIColor)
    }

    private var content: some View {
        VStack(
            alignment: .leading,
            spacing: ThemePanelLayout.quotaSpacing * contentCompression
        ) {
            HStack(alignment: .firstTextBaseline) {
                VStack(
                    alignment: .leading,
                    spacing: 2 * contentCompression
                ) {
                    Text(data.percentText)
                        .font(
                            .system(
                                size: CGFloat(
                                    typography.percentSize
                                        * appearance.geometry.fontScale
                                ),
                                weight: typography.percentWeight
                                    .swiftUIFontWeight,
                                design: typography.percentFamily
                                    .swiftUIFontDesign
                            )
                        )
                        .tracking(CGFloat(typography.percentTracking))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(data.primaryQuotaLabel)
                        .font(
                            .system(
                                size: CGFloat(
                                    typography.labelSize
                                        * appearance.geometry.fontScale
                                ),
                                weight: typography.labelWeight
                                    .swiftUIFontWeight,
                                design: .monospaced
                            )
                        )
                        .opacity(typography.secondaryOpacity)
                }

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 3 * contentCompression
                ) {
                    Text(data.shortResetText)
                        .font(
                            .system(
                                size: CGFloat(
                                    typography.countdownSize
                                        * appearance.geometry.fontScale
                                ),
                                weight: typography.countdownWeight
                                    .swiftUIFontWeight,
                                design: typography.percentFamily
                                    .swiftUIFontDesign
                            )
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(data.primaryResetDetailText)
                        .font(
                            .system(
                                size: CGFloat(
                                    typography.metadataSize
                                        * appearance.geometry.fontScale
                                ),
                                weight: typography.metadataWeight
                                    .swiftUIFontWeight,
                                design: .monospaced
                            )
                        )
                        .opacity(typography.secondaryOpacity)
                }
            }

            ThemeProgressBar(
                percent: data.displayRemainingPercent,
                tint: appearance.primaryStateColor,
                appearance: appearance
            )

            if data.showsSecondaryQuota {
                Rectangle()
                    .fill(appearance.outlineColor.swiftUIColor)
                    .frame(
                        height: CGFloat(
                            appearance.visuals.weeklyDividerWidth
                        )
                    )
                    .padding(.vertical, contentCompression)

                ThemeSecondaryQuotaRow(
                    title: "周额度",
                    percentText: data.weeklyPercentText,
                    trailing: data.weeklyResetDateText,
                    appearance: appearance
                )
            }
        }
    }
}

private struct ThemeSecondaryQuotaRow: View {
    let title: String
    let percentText: String
    let trailing: String
    let appearance: ResolvedPanelAppearance

    private var typography: ThemeTypographyRecipe {
        appearance.visuals.typography
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(
                    .system(
                        size: CGFloat(
                            typography.metadataSize
                                * appearance.geometry.fontScale
                        ),
                        weight: typography.metadataWeight
                            .swiftUIFontWeight,
                        design: .monospaced
                    )
                )
                .opacity(typography.secondaryOpacity)

            Spacer()

            Text(percentText)
                .font(
                    .system(
                        size: CGFloat(
                            typography.secondaryPercentSize
                                * appearance.geometry.fontScale
                        ),
                        weight: typography.metadataWeight
                            .swiftUIFontWeight,
                        design: .monospaced
                    )
                )
                .monospacedDigit()
                .foregroundStyle(appearance.weeklyStateColor.swiftUIColor)

            Text(trailing)
                .font(
                    .system(
                        size: CGFloat(
                            typography.metadataSize
                                * appearance.geometry.fontScale
                        ),
                        weight: typography.metadataWeight
                            .swiftUIFontWeight,
                        design: .monospaced
                    )
                )
                .monospacedDigit()
                .opacity(typography.secondaryOpacity)
                .frame(width: 86, alignment: .trailing)
        }
    }
}

struct ThemeShadowModifier: ViewModifier {
    let recipe: ThemeShadowRecipe
    let color: AppearanceColor

    @ViewBuilder
    func body(content: Content) -> some View {
        switch recipe {
        case .none:
            content
        case let .hard(depth, opacity):
            content.shadow(
                color: color.swiftUIColor.opacity(opacity),
                radius: 0,
                x: CGFloat(depth),
                y: CGFloat(depth)
            )
        case let .soft(depth, blur, opacity):
            content.shadow(
                color: color.swiftUIColor.opacity(opacity),
                radius: CGFloat(blur),
                x: CGFloat(depth),
                y: CGFloat(depth)
            )
        }
    }
}

extension ThemeShadowRecipe {
    var visualInsets: EdgeInsets {
        let blur = CGFloat(self.blur)
        let depth = CGFloat(max(self.depth, 0))
        return EdgeInsets(
            top: blur,
            leading: blur,
            bottom: blur + depth,
            trailing: blur + depth
        )
    }
}

struct ThemeSurfaceBackground: View {
    let fill: AppearanceColor
    let outline: AppearanceColor
    let chrome: ThemeChromeRecipe
    let fillStyle: ThemePanelFill
    let gradientEnd: AppearanceColor?

    init(
        fill: AppearanceColor,
        outline: AppearanceColor,
        chrome: ThemeChromeRecipe,
        fillStyle: ThemePanelFill = .solid,
        gradientEnd: AppearanceColor? = nil
    ) {
        self.fill = fill
        self.outline = outline
        self.chrome = chrome
        self.fillStyle = fillStyle
        self.gradientEnd = gradientEnd
    }

    init(
        appearance: ResolvedPanelAppearance,
        chrome: ThemeChromeRecipe,
        fill: AppearanceColor,
        fillStyle: ThemePanelFill = .solid,
        gradientEnd: AppearanceColor? = nil
    ) {
        self.init(
            fill: fill,
            outline: appearance.outlineColor,
            chrome: chrome,
            fillStyle: fillStyle,
            gradientEnd: gradientEnd
        )
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: CGFloat(chrome.cornerRadius),
            style: .continuous
        )

        ZStack {
            switch fillStyle {
            case .solid:
                shape.fill(fill.swiftUIColor)
            case .materialGradient:
                shape.fill(.ultraThinMaterial)
                shape.fill(
                    LinearGradient(
                        colors: [
                            fill.swiftUIColor,
                            (gradientEnd ?? fill).swiftUIColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }

            if chrome.outlineWidth > 0 {
                shape.strokeBorder(
                    outline.swiftUIColor,
                    lineWidth: CGFloat(chrome.outlineWidth)
                )
            }
        }
        .clipShape(shape)
        .modifier(
            ThemeShadowModifier(
                recipe: chrome.shadow,
                color: outline
            )
        )
    }
}

extension View {
    func themeSurface(
        appearance: ResolvedPanelAppearance,
        chrome: ThemeChromeRecipe,
        fill: AppearanceColor,
        fillStyle: ThemePanelFill = .solid,
        gradientEnd: AppearanceColor? = nil
    ) -> some View {
        background {
            ThemeSurfaceBackground(
                appearance: appearance,
                chrome: chrome,
                fill: fill,
                fillStyle: fillStyle,
                gradientEnd: gradientEnd
            )
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: CGFloat(chrome.cornerRadius),
                style: .continuous
            )
        )
    }
}

struct ThemeProgressBar: View {
    let percent: Int
    let tint: Color
    let appearance: ResolvedPanelAppearance

    init(
        percent: Int,
        tint: AppearanceColor,
        appearance: ResolvedPanelAppearance
    ) {
        self.percent = percent
        self.tint = tint.swiftUIColor
        self.appearance = appearance
    }

    init(
        percent: Int,
        tint: Color,
        appearance: ResolvedPanelAppearance
    ) {
        self.percent = percent
        self.tint = tint
        self.appearance = appearance
    }

    var body: some View {
        let progress = appearance.visuals.progress
        let chrome = progress.track
        let fraction = min(max(Double(percent) / 100, 0), 1)

        GeometryReader { proxy in
            let outlineWidth = CGFloat(chrome.outlineWidth)
            let innerWidth = max(0, proxy.size.width - outlineWidth * 2)
            let innerHeight = max(0, proxy.size.height - outlineWidth * 2)
            let fillWidth = innerWidth * CGFloat(fraction)
            let innerRadius = max(
                0,
                CGFloat(chrome.cornerRadius) - outlineWidth
            )
            let trackShape = RoundedRectangle(
                cornerRadius: CGFloat(chrome.cornerRadius),
                style: .continuous
            )
            let innerShape = RoundedRectangle(
                cornerRadius: innerRadius,
                style: .continuous
            )

            ZStack(alignment: .topLeading) {
                trackShape.fill(appearance.progressTrackColor.swiftUIColor)

                if fillWidth > 0, innerHeight > 0 {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(tint)
                            .frame(width: fillWidth)

                        if fraction < 1, progress.fillDividerWidth > 0 {
                            Rectangle()
                                .fill(appearance.outlineColor.swiftUIColor)
                                .frame(
                                    width: CGFloat(
                                        progress.fillDividerWidth
                                    )
                                )
                                .offset(
                                    x: max(
                                        0,
                                        fillWidth - CGFloat(
                                            progress.fillDividerWidth
                                        )
                                    )
                                )
                        }
                    }
                    .frame(
                        width: innerWidth,
                        height: innerHeight,
                        alignment: .leading
                    )
                    .clipShape(innerShape)
                    .offset(x: outlineWidth, y: outlineWidth)
                }

                if chrome.outlineWidth > 0 {
                    trackShape.strokeBorder(
                        appearance.outlineColor.swiftUIColor,
                        lineWidth: outlineWidth
                    )
                }
            }
            .modifier(
                ThemeShadowModifier(
                    recipe: chrome.shadow,
                    color: appearance.outlineColor
                )
            )
        }
        .frame(height: CGFloat(progress.height))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("额度剩余")
        .accessibilityValue("\(percent)%")
    }
}

struct ThemePanelChromePreview: View {
    let appearance: ResolvedPanelAppearance

    private var shadowInsets: EdgeInsets {
        appearance.visuals.panelShell.shadow.visualInsets
    }

    var body: some View {
        ThemePanelComposition(
            appearance: appearance,
            data: .reference(for: appearance.themeID),
            headerForeground: appearance.backgroundTextColor.swiftUIColor
        ) {
            HStack(spacing: 8) {
                previewAction(systemImage: "arrow.clockwise")
                previewAction(systemImage: "ellipsis")
            }
        }
        .padding(shadowInsets)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("当前额度面板主题预览")
    }

    private func previewAction(
        systemImage: String
    ) -> some View {
        Image(systemName: systemImage)
            .font(
                .system(
                    size: ThemePanelLayout.actionIconSize
                        * appearance.geometry.fontScale,
                    weight: .black
                )
            )
            .frame(
                width: ThemePanelLayout.actionSize,
                height: ThemePanelLayout.actionSize
            )
            .foregroundStyle(
                appearance.outlineColor.readable(
                    on: appearance.actionAccentColor
                        .composited(over: appearance.backgroundColor)
                        .composited(over: .white)
                ).swiftUIColor
            )
            .themeSurface(
                appearance: appearance,
                chrome: appearance.visuals.actionButton,
                fill: appearance.actionAccentColor
            )
    }
}

struct ScaledThemePanelChromePreview: View {
    let appearance: ResolvedPanelAppearance
    let targetWidth: CGFloat

    private var shadowInsets: EdgeInsets {
        appearance.visuals.panelShell.shadow.visualInsets
    }

    private var naturalWidth: CGFloat {
        ThemePanelLayout.width
            + shadowInsets.leading
            + shadowInsets.trailing
    }

    private var naturalHeight: CGFloat {
        ThemePanelLayout.height
            + shadowInsets.top
            + shadowInsets.bottom
    }

    private var scale: CGFloat {
        min(max(targetWidth / naturalWidth, 0), 1)
    }

    var body: some View {
        ThemePanelChromePreview(appearance: appearance)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(
                width: naturalWidth * scale,
                height: naturalHeight * scale,
                alignment: .topLeading
            )
    }
}

struct ThemeStatusChromePreview: View {
    let appearance: ResolvedStatusItemAppearance

    private var fittedAppearance: ResolvedStatusItemAppearance {
        appearance.fitted(to: Double(NSStatusBar.system.thickness))
    }

    private var chrome: ThemeChromeRecipe {
        ThemeChromeRecipe(
            outlineWidth: fittedAppearance.outlineWidth,
            cornerRadius: fittedAppearance.cornerRadius,
            shadow: shadowRecipe
        )
    }

    private var shadowRecipe: ThemeShadowRecipe {
        guard
            fittedAppearance.shadowDepth > 0
                || fittedAppearance.shadowBlur > 0
        else {
            return .none
        }
        if fittedAppearance.shadowBlur > 0 {
            return .soft(
                depth: fittedAppearance.shadowDepth,
                blur: fittedAppearance.shadowBlur,
                opacity: fittedAppearance.shadowOpacity
            )
        }
        return .hard(
            depth: fittedAppearance.shadowDepth,
            opacity: fittedAppearance.shadowOpacity
        )
    }

    private var shadowInsets: EdgeInsets {
        shadowRecipe.visualInsets
    }

    var body: some View {
        Text("81% | 1h34m | 49%")
            .font(
                .system(
                    size: CGFloat(fittedAppearance.fontSize),
                    weight: fittedAppearance.fontWeight.swiftUIFontWeight,
                    design: fittedAppearance.fontFamily.swiftUIFontDesign
                )
            )
            .tracking(-0.2)
            .monospacedDigit()
            .foregroundStyle(
                fittedAppearance.primaryTextColor.swiftUIColor
            )
            .padding(
                .horizontal,
                CGFloat(
                    fittedAppearance.horizontalPadding
                        + fittedAppearance.outlineWidth
                )
            )
            .frame(
                height: CGFloat(
                    fittedAppearance.tagHeight
                        + fittedAppearance.outlineWidth
                )
            )
            .fixedSize(horizontal: true, vertical: false)
            .background {
                ThemeSurfaceBackground(
                    fill: fittedAppearance.fillColor,
                    outline: fittedAppearance.outlineColor,
                    chrome: chrome
                )
            }
            .padding(shadowInsets)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("菜单栏状态预览")
            .accessibilityValue("81%，1小时34分钟，周额度49%")
    }
}
