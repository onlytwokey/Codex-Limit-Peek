import Foundation
import SwiftUI

struct AppearanceEditorView: View {
    @ObservedObject var store: AppearanceStore
    let onBack: (() -> Void)?
    let onStatusItem: () -> Void
    let onStateColors: () -> Void
    let onOpenCustomColor: (AppearanceColorToken) -> Void

    @Environment(\.appearanceEditorInitialScrollTarget)
    private var initialScrollTarget
    @State private var resetConfirmation =
        AppearanceResetConfirmationState()

    init(
        store: AppearanceStore,
        onBack: (() -> Void)? = nil,
        onStatusItem: @escaping () -> Void,
        onStateColors: @escaping () -> Void,
        onOpenCustomColor:
            @escaping (AppearanceColorToken) -> Void
    ) {
        self.store = store
        self.onBack = onBack
        self.onStatusItem = onStatusItem
        self.onStateColors = onStateColors
        self.onOpenCustomColor = onOpenCustomColor
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        AppearanceLivePreview(profile: store.currentProfile)
                            .padding(12)
                            .brutalSectionDivider()

                        themeSelector
                            .padding(12)
                            .brutalSectionDivider()
                            .id(
                                AppearanceEditorInitialScrollTarget
                                    .themeSelector
                            )

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
                            .id(
                                AppearanceEditorInitialScrollTarget
                                    .panelControls
                            )
                        statusItemSection
                        stateColorsSection
                        resetSection

                        if initialScrollTarget == .panelControls {
                            Color.clear
                                .frame(
                                    height:
                                        AppearanceEditorDocumentationMetrics
                                            .trailingScrollSpace(
                                                for: initialScrollTarget
                                            )
                                )
                                .accessibilityHidden(true)
                        }
                    }
                }
                .scrollIndicators(.visible, axes: .vertical)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .task(id: initialScrollTarget) {
                    guard
                        let target = initialScrollTarget,
                        target == .themeSelector
                            || target == .panelControls
                    else {
                        return
                    }
                    await Task.yield()
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
        .frame(width: 320, height: 548)
        .environment(
            \.appearanceEditorFontScale,
            store.editorFontScale
        )
        .foregroundStyle(BrutalEditorStyle.ink)
        .onChange(of: store.selectedTheme) { _, selectedTheme in
            resetConfirmation.selectedThemeDidChange(to: selectedTheme)
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
                title: "面板字形与几何",
                subtitle: "仅影响展开面板"
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
                title: "面板阴影与材质",
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

    private var statusItemSection: some View {
        Button(action: onStatusItem) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text("状态栏显示层")
                        .appearanceEditorFont(
                            size: 9,
                            weight: .black,
                            design: .monospaced
                        )
                    Spacer(minLength: 8)
                    Text("字体 · 描边 · 阴影 · 尺寸 ›")
                        .appearanceEditorFont(
                            size: 8,
                            weight: .black,
                            design: .monospaced
                        )
                        .opacity(0.72)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("状态栏显示层")
                        .appearanceEditorFont(
                            size: 9,
                            weight: .black,
                            design: .monospaced
                        )
                    Text("字体 · 描边 · 阴影 · 尺寸 ›")
                        .appearanceEditorFont(
                            size: 8,
                            weight: .black,
                            design: .monospaced
                        )
                        .opacity(0.72)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
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
        .accessibilityIdentifier(
            "appearance-status-item-navigation"
        )
        .accessibilityLabel(
            "打开状态栏显示层设置"
        )
        .accessibilityHint(
            "调整当前主题的字体、描边、阴影、留白和高度"
        )
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
            if
                let requestedTheme = resetConfirmation.requestedTheme,
                requestedTheme == store.selectedTheme
            {
                resetConfirmationView(for: requestedTheme)
            } else {
                Button(role: .destructive) {
                    resetConfirmation.request(
                        for: store.selectedTheme,
                        canReset: store.canResetCurrentTheme
                    )
                } label: {
                    Label(
                        store.canResetCurrentTheme
                            ? "恢复当前主题默认值"
                            : "当前主题已是默认设置",
                        systemImage: store.canResetCurrentTheme
                            ? "arrow.counterclockwise"
                            : "checkmark.circle.fill"
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
                            .fill(
                                store.canResetCurrentTheme
                                    ? BrutalEditorStyle.yellow
                                    : BrutalEditorStyle.paper
                            )
                            .shadow(
                                color: BrutalEditorStyle.ink,
                                radius: 0,
                                x: store.canResetCurrentTheme ? 2 : 0,
                                y: store.canResetCurrentTheme ? 2 : 0
                            )
                    }
                    .overlay {
                        Rectangle()
                            .strokeBorder(
                                BrutalEditorStyle.ink,
                                lineWidth: 1.5
                            )
                    }
                    .opacity(store.canResetCurrentTheme ? 1 : 0.58)
                }
                .buttonStyle(.plain)
                .disabled(!store.canResetCurrentTheme)
                .accessibilityIdentifier("appearance-reset-request")
                .accessibilityHint(
                    store.canResetCurrentTheme
                        ? "打开当前主题的恢复确认"
                        : "当前主题没有需要恢复的自定义设置"
                )
            }

            Text(
                "只重置 \(store.selectedTheme.displayName)；另外两套主题和设置页字号会保留。"
            )
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

    private func resetConfirmationView(
        for theme: AppearanceThemeID
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("确认恢复 \(theme.displayName)？")
                .appearanceEditorFont(
                    size: 9,
                    weight: .black,
                    design: .monospaced
                )

            Text("当前主题的颜色、面板和状态栏设置将恢复默认。")
                .appearanceEditorFont(
                    size: 8,
                    weight: .bold,
                    design: .monospaced
                )
                .opacity(0.68)

            HStack(spacing: 8) {
                Button(role: .destructive) {
                    guard
                        resetConfirmation.confirm(
                            for: store.selectedTheme
                        )
                    else {
                        return
                    }
                    store.resetCurrentTheme()
                } label: {
                    Text("确认恢复")
                        .appearanceEditorFont(
                            size: 8,
                            weight: .black,
                            design: .monospaced
                        )
                        .frame(maxWidth: .infinity)
                        .appearanceEditorMinHeight(26)
                        .background(BrutalEditorStyle.coral)
                        .overlay {
                            Rectangle()
                                .strokeBorder(
                                    BrutalEditorStyle.ink,
                                    lineWidth: 1.5
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("appearance-reset-confirm")

                Button {
                    resetConfirmation.cancel()
                } label: {
                    Text("取消")
                        .appearanceEditorFont(
                            size: 8,
                            weight: .black,
                            design: .monospaced
                        )
                        .frame(maxWidth: .infinity)
                        .appearanceEditorMinHeight(26)
                        .background(BrutalEditorStyle.paper)
                        .overlay {
                            Rectangle()
                                .strokeBorder(
                                    BrutalEditorStyle.ink,
                                    lineWidth: 1.5
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("appearance-reset-cancel")
            }
        }
        .padding(9)
        .background(BrutalEditorStyle.yellow.opacity(0.36))
        .overlay {
            Rectangle()
                .strokeBorder(BrutalEditorStyle.ink, lineWidth: 1.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appearance-reset-confirmation")
    }

    private func colorRow(
        title: String,
        token: AppearanceColorToken
    ) -> some View {
        AppearanceColorRow(
            title: title,
            selectedColor: store.color(for: token),
            swatches: AppearanceEditorPalette.swatches(for: token),
            onSelectSwatch: { color in
                store.setColor(color, for: token)
            },
            onOpenCustomColor: {
                onOpenCustomColor(token)
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
