import AppKit
import Foundation
import SwiftUI

private enum BrutalEditorStyle {
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

struct AppearanceEditorView: View {
    @ObservedObject var store: AppearanceStore
    let onBack: (() -> Void)?
    let onStateColors: () -> Void

    @State private var showsResetConfirmation = false

    init(
        store: AppearanceStore,
        onBack: (() -> Void)? = nil,
        onStateColors: @escaping () -> Void
    ) {
        self.store = store
        self.onBack = onBack
        self.onStateColors = onStateColors
    }

    private var resolvedAppearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: store.currentProfile,
            primaryRemainingPercent: 68,
            weeklyRemainingPercent: 38,
            isUnavailable: false
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppearanceLivePreview(profile: store.currentProfile)
                        .padding(12)
                        .brutalSectionDivider()

                    themeSelector
                        .padding(12)
                        .brutalSectionDivider()

                    AppearanceEditorSection(
                        appearance: resolvedAppearance,
                        title: "基础色板",
                        subtitle: "面板与状态栏实时共用"
                    ) {
                        VStack(spacing: 10) {
                            colorRow(
                                title: "背景",
                                token: .background
                            )
                            colorRow(
                                title: "表面",
                                token: .surface
                            )
                            colorRow(
                                title: "文字与描边",
                                token: .textAndOutline
                            )
                            colorRow(
                                title: "操作控件",
                                token: .actionAccent
                            )
                        }
                    }

                    if resolvedAppearance.hasContrastSubstitution {
                        Label(
                            "当前文字对比度不足，实际显示会自动改用黑色或白色。",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .appearanceEditorFont(
                            size: 11,
                            weight: .medium
                        )
                        .foregroundStyle(Color.orange)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            BrutalEditorStyle.yellow.opacity(0.28)
                        )
                        .brutalSectionDivider()
                    }

                    geometrySection
                    stateColorsSection
                    resetSection
                }
            }
        }
        .frame(width: 320, height: 548)
        .environment(
            \.appearanceEditorFontScale,
            store.editorFontScale
        )
        .foregroundStyle(BrutalEditorStyle.ink)
        .confirmationDialog(
            "重置 \(store.selectedTheme.displayName)？",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                "恢复 \(store.selectedTheme.displayName) 默认值",
                role: .destructive
            ) {
                store.resetCurrentTheme()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会重置当前主题，另外两套主题的设置会保留。")
        }
    }

    private var header: some View {
        let showsSaved = store.saveFeedbackState == .saved

        return HStack(spacing: 8) {
            if let onBack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .appearanceEditorFont(
                            size: 12,
                            weight: .bold
                        )
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("返回更多")
                .accessibilityLabel("返回更多")
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("外观")
                    .appearanceEditorFont(
                        size: 14,
                        weight: .bold
                    )
                Text(store.selectedTheme.displayName)
                    .appearanceEditorFont(
                        size: 9,
                        weight: .bold,
                        design: .monospaced
                    )
                    .tracking(0.8)
                    .opacity(0.64)
            }

            Spacer()

            Label(
                showsSaved ? "已保存" : "正在保存",
                systemImage: showsSaved
                    ? "checkmark.circle.fill"
                    : "circle.dotted"
            )
            .appearanceEditorFont(
                size: 9,
                weight: .black,
                design: .monospaced
            )
            .foregroundStyle(
                showsSaved
                    ? BrutalEditorStyle.savedGreen
                    : BrutalEditorStyle.savingOrange
            )
            .animation(.easeOut(duration: 0.15), value: showsSaved)
        }
        .foregroundStyle(BrutalEditorStyle.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .appearanceEditorMinHeight(44)
        .background(BrutalEditorStyle.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(BrutalEditorStyle.ink)
                .frame(height: 2)
        }
    }

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("主题")
                .appearanceEditorFont(
                    size: 9,
                    weight: .black,
                    design: .monospaced
                )
                .tracking(0.8)

            HStack(spacing: 8) {
                ForEach(AppearanceThemeID.allCases, id: \.self) { theme in
                    ThemeChoiceButton(
                        theme: theme,
                        profile: store.profile(for: theme),
                        isSelected: store.selectedTheme == theme
                    ) {
                        withAnimation(.easeOut(duration: 0.14)) {
                            store.select(theme)
                        }
                    }
                }
            }
        }
    }

    private var geometrySection: some View {
        VStack(spacing: 0) {
            AppearanceEditorSection(
                appearance: resolvedAppearance,
                title: "字形与几何",
                subtitle: "状态栏会自动使用更严格的尺寸上限"
            ) {
                VStack(spacing: 11) {
                    BrutalSlider(
                        title: "面板字体大小",
                        value: geometryBinding(\.fontScale),
                        range: 0.8...1.25,
                        step: 0.01,
                        valueText: { "\(Int(($0 * 100).rounded()))%" },
                        tint: resolvedAppearance.primaryStateColor.swiftUIColor,
                        thumb: resolvedAppearance.actionAccentColor.swiftUIColor,
                        onEditingChanged: { store.sliderEditingChanged($0) }
                    )
                    BrutalSlider(
                        title: "设置页字体大小",
                        value: Binding(
                            get: { store.editorFontScale },
                            set: { store.setEditorFontScale($0) }
                        ),
                        range: AppearanceEditorTypography.allowedScale,
                        step: AppearanceEditorTypography.scaleStep,
                        valueText: { "\(Int(($0 * 100).rounded()))%" },
                        tint: resolvedAppearance.primaryStateColor.swiftUIColor,
                        thumb: resolvedAppearance.actionAccentColor.swiftUIColor,
                        onEditingChanged: { store.sliderEditingChanged($0) }
                    )
                    .accessibilityIdentifier("appearance-editor-font-scale")

                    Text("全局 · 仅影响设置页面")
                        .appearanceEditorFont(
                            size: 8,
                            weight: .bold,
                            design: .monospaced
                        )
                        .opacity(0.58)

                    BrutalSlider(
                        title: "描边",
                        value: geometryBinding(\.outlineWidth),
                        range: 0...4,
                        step: 0.25,
                        valueText: { Self.points($0, fractionDigits: 2) },
                        tint: resolvedAppearance.primaryStateColor.swiftUIColor,
                        thumb: resolvedAppearance.actionAccentColor.swiftUIColor,
                        onEditingChanged: { store.sliderEditingChanged($0) }
                    )
                    BrutalSlider(
                        title: "圆角",
                        value: geometryBinding(\.cornerRadius),
                        range: 0...28,
                        step: 1,
                        valueText: { Self.points($0) },
                        tint: resolvedAppearance.primaryStateColor.swiftUIColor,
                        thumb: resolvedAppearance.actionAccentColor.swiftUIColor,
                        onEditingChanged: { store.sliderEditingChanged($0) }
                    )
                }
            }

            AppearanceEditorSection(
                appearance: resolvedAppearance,
                title: "阴影与材质",
                subtitle: nil
            ) {
                VStack(spacing: 11) {
                    BrutalSlider(
                        title: "阴影深度",
                        value: geometryBinding(\.shadowDepth),
                        range: 0...10,
                        step: 1,
                        valueText: { Self.points($0) },
                        tint: resolvedAppearance.primaryStateColor.swiftUIColor,
                        thumb: resolvedAppearance.actionAccentColor.swiftUIColor,
                        onEditingChanged: { store.sliderEditingChanged($0) }
                    )
                    BrutalSlider(
                        title: "阴影模糊",
                        value: geometryBinding(\.shadowBlur),
                        range: 0...20,
                        step: 1,
                        valueText: { Self.points($0) },
                        tint: resolvedAppearance.primaryStateColor.swiftUIColor,
                        thumb: resolvedAppearance.actionAccentColor.swiftUIColor,
                        onEditingChanged: { store.sliderEditingChanged($0) }
                    )
                    BrutalSlider(
                        title: "表面不透明度",
                        value: geometryBinding(\.surfaceOpacity),
                        range: 0.55...1,
                        step: 0.01,
                        valueText: { "\(Int(($0 * 100).rounded()))%" },
                        tint: resolvedAppearance.primaryStateColor.swiftUIColor,
                        thumb: resolvedAppearance.actionAccentColor.swiftUIColor,
                        onEditingChanged: { store.sliderEditingChanged($0) }
                    )
                }
            }
        }
    }

    private var stateColorsSection: some View {
        Button {
            onStateColors()
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text("高级状态颜色")
                        .appearanceEditorFont(
                            size: 9,
                            weight: .black,
                            design: .monospaced
                        )
                        .tracking(0.4)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    Text("正常 · 警告 · 危险 · 不可用 ›")
                        .appearanceEditorFont(
                            size: 8,
                            weight: .black,
                            design: .monospaced
                        )
                        .opacity(0.72)
                        .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("高级状态颜色")
                        .appearanceEditorFont(
                            size: 9,
                            weight: .black,
                            design: .monospaced
                        )
                        .tracking(0.4)
                    Text("正常 · 警告 · 危险 · 不可用 ›")
                        .appearanceEditorFont(
                            size: 8,
                            weight: .black,
                            design: .monospaced
                        )
                        .opacity(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(BrutalEditorStyle.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .appearanceEditorMinHeight(38)
            .contentShape(Rectangle())
            .background(BrutalEditorStyle.paleTeal)
            .brutalSectionDivider()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开高级状态颜色")
        .accessibilityHint("分别设置当前主题的正常、警告、危险和不可用颜色")
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Label(
                    "恢复当前主题默认值",
                    systemImage: "arrow.counterclockwise"
                )
                .appearanceEditorFont(
                    size: 9,
                    weight: .black,
                    design: .monospaced
                )
                .foregroundStyle(BrutalEditorStyle.ink)
                .frame(maxWidth: .infinity)
                .appearanceEditorMinHeight(30)
                .background {
                    Rectangle()
                        .fill(BrutalEditorStyle.yellow)
                        .shadow(
                            color: BrutalEditorStyle.ink,
                            radius: 0,
                            x: 2,
                            y: 2
                        )
                }
                .overlay {
                    Rectangle()
                        .strokeBorder(BrutalEditorStyle.ink, lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("只重置 \(store.selectedTheme.displayName)，其他主题保持不变")

            Text("只重置 \(store.selectedTheme.displayName)，另外两套主题的设置会保留。")
                .appearanceEditorFont(
                    size: 8,
                    weight: .bold,
                    design: .monospaced
                )
                .opacity(0.58)
        }
        .padding(12)
        .padding(.bottom, 2)
    }

    private func colorRow(
        title: String,
        token: AppearanceColorToken
    ) -> some View {
        AppearanceColorRow(
            title: title,
            selection: colorBinding(for: token),
            selectedColor: store.color(for: token),
            swatches: AppearanceEditorPalette.swatches(for: token)
        ) { color in
            store.setColor(color, for: token)
        }
    }

    private func colorBinding(
        for token: AppearanceColorToken
    ) -> Binding<Color> {
        Binding(
            get: {
                store.color(for: token).swiftUIColor
            },
            set: { color in
                store.setColor(
                    AppearanceColor(nsColor: NSColor(color)),
                    for: token
                )
            }
        )
    }

    private func geometryBinding(
        _ keyPath: WritableKeyPath<ThemeGeometry, Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                store.currentProfile.geometry[keyPath: keyPath]
            },
            set: { value in
                store.updateCurrent {
                    $0.geometry[keyPath: keyPath] = value
                }
            }
        )
    }

    private static func points(
        _ value: Double,
        fractionDigits: Int = 0
    ) -> String {
        String(format: "%.\(fractionDigits)f pt", value)
    }
}

struct StateColorsEditorView: View {
    @ObservedObject var store: AppearanceStore
    let onBack: () -> Void

    private var resolvedAppearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: store.currentProfile,
            primaryRemainingPercent: 68,
            weeklyRemainingPercent: 18,
            isUnavailable: false
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("主题")
                            .appearanceEditorFont(
                                size: 9,
                                weight: .black,
                                design: .monospaced
                            )
                            .tracking(0.8)

                        HStack(spacing: 8) {
                            ForEach(
                                AppearanceThemeID.allCases,
                                id: \.self
                            ) { theme in
                                ThemeChoiceButton(
                                    theme: theme,
                                    profile: store.profile(for: theme),
                                    isSelected: store.selectedTheme == theme
                                ) {
                                    withAnimation(.easeOut(duration: 0.14)) {
                                        store.select(theme)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .brutalSectionDivider()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("选择要编辑状态颜色的主题")

                    Text("每套主题分别保存；正常、警告、危险的额度阈值保持不变。")
                        .appearanceEditorFont(
                            size: 9,
                            weight: .bold,
                            design: .monospaced
                        )
                        .opacity(0.64)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BrutalEditorStyle.paleTeal)
                        .brutalSectionDivider()

                    AppearanceEditorSection(
                        appearance: resolvedAppearance,
                        title: "额度与失败状态",
                        subtitle: "状态栏会自动保证文字对比度"
                    ) {
                        VStack(spacing: 10) {
                            colorRow(title: "正常", token: .normal)
                            colorRow(title: "警告", token: .warning)
                            colorRow(title: "危险", token: .danger)
                            colorRow(
                                title: "不可用底色",
                                token: .unavailableBase
                            )
                            colorRow(
                                title: "不可用条纹",
                                token: .unavailableStripe
                            )
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: 430)
        .environment(
            \.appearanceEditorFontScale,
            store.editorFontScale
        )
        .foregroundStyle(BrutalEditorStyle.ink)
    }

    private var header: some View {
        let showsSaved = store.saveFeedbackState == .saved

        return HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .appearanceEditorFont(
                        size: 12,
                        weight: .bold
                    )
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("返回外观")
            .accessibilityLabel("返回外观")

            VStack(alignment: .leading, spacing: 1) {
                Text("状态颜色")
                    .appearanceEditorFont(
                        size: 14,
                        weight: .bold
                    )
                Text(store.selectedTheme.displayName)
                    .appearanceEditorFont(
                        size: 9,
                        weight: .bold,
                        design: .monospaced
                    )
                    .tracking(0.8)
                    .opacity(0.64)
            }

            Spacer()

            Label(
                showsSaved ? "已保存" : "正在保存",
                systemImage: showsSaved
                    ? "checkmark.circle.fill"
                    : "circle.dotted"
            )
            .appearanceEditorFont(
                size: 9,
                weight: .black,
                design: .monospaced
            )
            .foregroundStyle(
                showsSaved
                    ? BrutalEditorStyle.savedGreen
                    : BrutalEditorStyle.savingOrange
            )
            .animation(.easeOut(duration: 0.15), value: showsSaved)
        }
        .foregroundStyle(BrutalEditorStyle.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .appearanceEditorMinHeight(44)
        .background(BrutalEditorStyle.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(BrutalEditorStyle.ink)
                .frame(height: 2)
        }
    }

    private func colorRow(
        title: String,
        token: AppearanceColorToken
    ) -> some View {
        AppearanceColorRow(
            title: title,
            selection: colorBinding(for: token),
            selectedColor: store.color(for: token),
            swatches: AppearanceEditorPalette.swatches(for: token)
        ) { color in
            store.setColor(color, for: token)
        }
    }

    private func colorBinding(
        for token: AppearanceColorToken
    ) -> Binding<Color> {
        Binding(
            get: { store.color(for: token).swiftUIColor },
            set: { color in
                store.setColor(
                    AppearanceColor(nsColor: NSColor(color)),
                    for: token
                )
            }
        )
    }
}

private struct AppearanceLivePreview: View {
    let profile: AppearanceProfile

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
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                Text("实时预览")
                    .appearanceEditorFont(
                        size: 9,
                        weight: .black,
                        design: .monospaced
                    )
                    .tracking(0.8)

                Spacer(minLength: 8)

                ThemeStatusChromePreview(
                    appearance: statusAppearance
                )
            }

            ScaledThemePanelChromePreview(
                appearance: panelAppearance,
                targetWidth: 296
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("当前主题的面板与菜单栏实时预览")
    }
}

private struct ThemeChoiceButton: View {
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

private struct AppearanceEditorSection<Content: View>: View {
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

private struct BrutalSlider: View {
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

private struct AppearanceColorRow: View {
    let title: String
    @Binding var selection: Color
    let selectedColor: AppearanceColor
    let swatches: [AppearanceColor]
    let onSelectSwatch: (AppearanceColor) -> Void

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

            ColorPicker(
                "",
                selection: $selection,
                supportsOpacity: true
            )
            .labelsHidden()
            .frame(width: 25, height: 21)
            .background(BrutalEditorStyle.ink.opacity(0.08))
            .overlay {
                Rectangle()
                    .strokeBorder(
                        BrutalEditorStyle.ink,
                        lineWidth: 1.5
                    )
            }
            .shadow(
                color: BrutalEditorStyle.ink,
                radius: 0,
                x: 1,
                y: 1
            )
            .clipped()
            .help("打开系统颜色选择器")
            .accessibilityLabel("\(title)系统颜色选择器")
        }
        .appearanceEditorMinHeight(30)
    }
}

private extension View {
    func brutalSectionDivider() -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(BrutalEditorStyle.ink)
                .frame(height: 1.5)
        }
    }
}

private enum AppearanceEditorPalette {
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
