import Foundation
import SwiftUI

struct ThemeChoiceButton: View {
    let theme: AppearanceThemeID
    let profile: AppearanceProfile
    let isSelected: Bool
    let action: () -> Void

    private var panelAppearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
    }

    private var statusAppearance: ResolvedStatusItemAppearance {
        AppearanceResolver.status(
            profile: profile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                ThemeChoiceChromeThumbnail(
                    panelAppearance: panelAppearance,
                    statusAppearance: statusAppearance
                )

                Text(theme.displayName)
                    .appearanceEditorFont(
                        size: 7,
                        weight: .black,
                        design: .monospaced
                    )
                    .tracking(0.4)
                    .foregroundStyle(
                        panelAppearance.backgroundTextColor.swiftUIColor
                    )
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        panelAppearance.surfaceColor.swiftUIColor
                            .opacity(0.88)
                    )
                    .overlay {
                        Rectangle()
                            .strokeBorder(
                                panelAppearance.outlineColor.swiftUIColor,
                                lineWidth: 1
                            )
                    }
                    .padding(4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .clipped()
            .background {
                Rectangle()
                    .fill(panelAppearance.backgroundColor.swiftUIColor)
                    .shadow(
                        color: BrutalEditorStyle.ink,
                        radius: 0,
                        x: 2,
                        y: 2
                    )
            }
            .overlay {
                Rectangle()
                    .strokeBorder(
                        BrutalEditorStyle.ink,
                        lineWidth: 1.5
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(BrutalEditorStyle.ink)
                        .frame(width: 17, height: 17)
                        .background(
                            BrutalEditorStyle.coral
                        )
                        .overlay {
                            Rectangle()
                                .strokeBorder(
                                    BrutalEditorStyle.ink,
                                    lineWidth: 1
                                )
                        }
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(theme.subtitle)
        .accessibilityLabel("\(theme.displayName)，\(theme.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ThemeChoiceChromeThumbnail: View {
    let panelAppearance: ResolvedPanelAppearance
    let statusAppearance: ResolvedStatusItemAppearance

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                ScaledThemePanelChromePreview(
                    appearance: panelAppearance,
                    targetWidth: proxy.size.width
                )
                .offset(x: 3, y: 3)

                ThemeStatusChromePreview(
                    appearance: statusAppearance
                )
                .scaleEffect(0.48, anchor: .bottomLeading)
                .offset(x: 5, y: -3)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .topLeading
            )
            .background(panelAppearance.backgroundColor.swiftUIColor)
        }
        .accessibilityHidden(true)
    }
}

struct AppearanceEditorSection<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder let content: Content

    init(
        appearance: ResolvedPanelAppearance,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        _ = appearance
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appearanceEditorFont(
                            size: 9,
                            weight: .black,
                            design: .monospaced
                        )
                        .tracking(0.8)
                    if let subtitle {
                        Text(subtitle)
                            .appearanceEditorFont(
                                size: 8,
                                weight: .bold,
                                design: .monospaced
                            )
                            .opacity(0.58)
                    }
                }
            }
            content
        }
        .padding(12)
        .foregroundStyle(BrutalEditorStyle.ink)
        .brutalSectionDivider()
    }
}

struct BrutalSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: (Double) -> String
    let tint: Color
    let thumb: Color
    let onEditingChanged: (Bool) -> Void

    @Environment(\.appearanceEditorFontScale) private var editorFontScale
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private var titleWidth: CGFloat {
        AppearanceEditorTypography.sliderTitleWidth(
            scale: editorFontScale
        )
    }

    private var valueWidth: CGFloat {
        AppearanceEditorTypography.sliderValueWidth(
            scale: editorFontScale
        )
    }

    private var fraction: Double {
        guard range.upperBound > range.lowerBound else {
            return 0
        }
        return min(
            max(
                (value - range.lowerBound)
                    / (range.upperBound - range.lowerBound),
                0
            ),
            1
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .appearanceEditorFont(
                    size: 9,
                    weight: .bold,
                    design: .monospaced
                )
                .lineLimit(1)
                .frame(width: titleWidth, alignment: .leading)

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let thumbSize: CGFloat = 12
                let thumbX = min(
                    max(CGFloat(fraction) * width - thumbSize / 2, 0),
                    max(width - thumbSize, 0)
                )

                ZStack {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(BrutalEditorStyle.ink.opacity(0.15))
                            .frame(height: 6)
                            .overlay {
                                Rectangle()
                                    .strokeBorder(
                                        BrutalEditorStyle.ink,
                                        lineWidth: 1
                                    )
                            }

                        Rectangle()
                            .fill(tint)
                            .frame(
                                width: max(
                                    1,
                                    CGFloat(fraction) * width
                                ),
                                height: 6
                            )
                            .overlay(alignment: .trailing) {
                                if fraction > 0 {
                                    Rectangle()
                                        .fill(BrutalEditorStyle.ink)
                                        .frame(width: 1)
                                }
                            }

                        Rectangle()
                            .fill(thumb)
                            .frame(width: thumbSize, height: thumbSize)
                            .overlay {
                                Rectangle()
                                    .strokeBorder(
                                        BrutalEditorStyle.ink,
                                        lineWidth: 1.5
                                    )
                            }
                            .offset(x: thumbX)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .overlay {
                        if isFocused {
                            Rectangle()
                                .stroke(
                                    Color.accentColor,
                                    lineWidth: 2
                                )
                                .padding(-3)
                        }
                    }

                    Slider(
                        value: $value,
                        in: range,
                        step: step,
                        onEditingChanged: { editing in
                            guard editing != isEditing else { return }
                            isEditing = editing
                            onEditingChanged(editing)
                        }
                    )
                    .labelsHidden()
                    .opacity(0.01)
                    .focused($isFocused)
                    .accessibilityLabel(title)
                    .accessibilityValue(valueText(value))
                    .onDisappear {
                        guard isEditing else { return }
                        isEditing = false
                        onEditingChanged(false)
                    }
                }
            }
            .frame(height: 16)

            Text(valueText(value))
                .appearanceEditorFont(
                    size: 8,
                    weight: .black,
                    design: .monospaced
                )
                .monospacedDigit()
                .opacity(0.64)
                .frame(width: valueWidth, alignment: .trailing)
        }
        .appearanceEditorMinHeight(24)
    }

}

struct AppearanceColorRow: View {
    let title: String
    let selectedColor: AppearanceColor
    let swatches: [AppearanceColor]
    let onSelectSwatch: (AppearanceColor) -> Void
    let onOpenCustomColor: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .appearanceEditorFont(
                    size: 9,
                    weight: .bold,
                    design: .monospaced
                )
                .lineLimit(1)
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 0)

            ForEach(Array(swatches.prefix(5).enumerated()), id: \.offset) {
                _, color in
                let isSelected = selectedColor.clamped() == color.clamped()
                Button {
                    onSelectSwatch(color)
                } label: {
                    Rectangle()
                        .fill(color.swiftUIColor)
                        .frame(width: 21, height: 21)
                        .overlay {
                            Rectangle()
                                .stroke(
                                    BrutalEditorStyle.ink,
                                    lineWidth: isSelected ? 2.5 : 1.5
                                )
                        }
                        .shadow(
                            color: BrutalEditorStyle.ink,
                            radius: 0,
                            x: 1,
                            y: 1
                        )
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .black))
                                    .foregroundStyle(
                                        color.readable(
                                            on: color.composited(over: .white),
                                            minimumRatio: 3
                                        )
                                        .swiftUIColor
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(color.editorHexLabel)
                .accessibilityLabel("选择颜色 \(color.editorHexLabel)")
                .accessibilityAddTraits(
                    isSelected ? .isSelected : []
                )
            }

            AppearanceCustomColorButton(
                title: title,
                color: selectedColor,
                action: onOpenCustomColor
            )
        }
        .appearanceEditorMinHeight(30)
    }
}

struct AppearanceCustomColorButton: View {
    let title: String
    let color: AppearanceColor
    let action: () -> Void

    private var iconColor: Color {
        let background = color
            .clamped()
            .composited(over: .white)
        return AppearanceColor.black
            .readable(on: background, minimumRatio: 3)
            .swiftUIColor
    }

    var body: some View {
        Button(action: action) {
            Rectangle()
                .fill(color.clamped().swiftUIColor)
                .frame(
                    width:
                        AppearanceEditorMetrics
                            .customColorControlWidth,
                    height:
                        AppearanceEditorMetrics
                            .colorControlHeight
                )
                .overlay {
                    Rectangle()
                        .strokeBorder(
                            BrutalEditorStyle.ink,
                            lineWidth: 1.5
                        )
                }
                .overlay {
                    Image(systemName: "plus")
                        .font(
                            .system(
                                size: 8,
                                weight: .black
                            )
                        )
                        .foregroundStyle(iconColor)
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: BrutalEditorStyle.ink,
                    radius: 0,
                    x: 1,
                    y: 1
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(
            width:
                AppearanceEditorMetrics
                    .customColorControlWidth,
            height:
                AppearanceEditorMetrics
                    .colorControlHeight
        )
        .contentShape(Rectangle())
        .help("自定义取色…")
        .accessibilityLabel("自定义\(title)颜色")
    }
}

extension View {
    func brutalSectionDivider() -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(BrutalEditorStyle.ink)
                .frame(height: 1.5)
        }
    }
}

private extension AppearanceColor {
    var editorHexLabel: String {
        let color = clamped()
        return String(
            format: "#%02X%02X%02X",
            Int((color.red * 255).rounded()),
            Int((color.green * 255).rounded()),
            Int((color.blue * 255).rounded())
        )
    }
}
