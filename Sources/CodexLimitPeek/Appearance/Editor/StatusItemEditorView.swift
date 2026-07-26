import Foundation
import SwiftUI

enum StatusItemEditorSectionDestination:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case text
    case shadow
    case geometry
    case stateColors

    var id: Self { self }

    var title: String {
        switch self {
        case .text:
            "文字"
        case .shadow:
            "阴影"
        case .geometry:
            "几何"
        case .stateColors:
            "状态颜色"
        }
    }

    var scrollTarget: AppearanceEditorInitialScrollTarget {
        switch self {
        case .text:
            .statusItemControls
        case .shadow:
            .statusItemShadowControls
        case .geometry:
            .statusItemGeometryControls
        case .stateColors:
            .stateColorControls
        }
    }

    var accessibilityIdentifier: String {
        let suffix = switch self {
        case .text, .shadow, .geometry:
            rawValue
        case .stateColors:
            "state-colors"
        }
        return "status-item-section-navigation-\(suffix)"
    }
}

enum StatusDisplayPreviewInteraction {
    static func guidanceText(
        hovered: StateColorsEditorPreviewState?
    ) -> String {
        hovered == nil
            ? "悬停状态查看效果"
            : "点击固定状态显示"
    }

    static func previewState(
        selected: StateColorsEditorPreviewState,
        hovered: StateColorsEditorPreviewState?
    ) -> StateColorsEditorPreviewState {
        hovered ?? selected
    }

    static func hoveredState(
        current: StateColorsEditorPreviewState?,
        target: StateColorsEditorPreviewState,
        isHovering: Bool
    ) -> StateColorsEditorPreviewState? {
        if isHovering {
            return target
        }
        return current == target ? nil : current
    }
}

struct StatusItemEditorView: View {
    @ObservedObject var store: AppearanceStore
    let onBack: () -> Void
    let onReturnToPanel: () -> Void
    let onOpenCustomColor: (AppearanceColorEditTarget) -> Void
    @State private var previewState:
        StateColorsEditorPreviewState = .normal

    init(
        store: AppearanceStore,
        onBack: @escaping () -> Void,
        onReturnToPanel: @escaping () -> Void = {},
        onOpenCustomColor:
            @escaping (AppearanceColorEditTarget) -> Void = { _ in }
    ) {
        self.store = store
        self.onBack = onBack
        self.onReturnToPanel = onReturnToPanel
        self.onOpenCustomColor = onOpenCustomColor
    }

    @Environment(\.appearanceEditorInitialScrollTarget)
    private var initialScrollTarget
    @Environment(\.appearanceEditorAddsDocumentationScrollSpace)
    private var addsDocumentationScrollSpace

    private var panelAppearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: store.currentProfile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false
        )
    }

    private var statusAppearance:
        ResolvedStatusItemAppearance
    {
        StatusItemEditorPreviewFixture.appearance(
            for: store.currentProfile
        )
    }

    var lowContrastLabels: [String] {
        let backgrounds = StatusItemEditorPreviewFixture
            .contrastBackgrounds(for: store.currentProfile)
        return [
            (.primaryText, "主额度"),
            (.weeklyText, "周额度")
        ].compactMap { token, label in
            guard
                let color = store.statusColor(for: token),
                backgrounds.contains(where: {
                    color.contrastRatio(with: $0) < 4.5
                })
            else {
                return nil
            }
            return label
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            livePreview

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 0,
                        pinnedViews: [.sectionHeaders]
                    ) {
                        themeSelector

                        Section {
                            textColorSection
                                .id(
                                    AppearanceEditorInitialScrollTarget
                                        .statusItemControls
                                )

                            if !lowContrastLabels.isEmpty {
                                Label(
                                    "\(lowContrastLabels.joined(separator: "、"))在部分额度状态或菜单栏背景下对比度低于 4.5:1；仍会按所选颜色显示。",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                .appearanceEditorFont(
                                    size: 9,
                                    weight: .bold,
                                    design: .monospaced
                                )
                                .foregroundStyle(Color.orange)
                                .padding(10)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .background(
                                    BrutalEditorStyle.yellow.opacity(0.28)
                                )
                                .brutalSectionDivider()
                                .accessibilityIdentifier(
                                    "status-item-low-contrast-warning"
                                )
                            }

                            shadowSection
                                .id(
                                    AppearanceEditorInitialScrollTarget
                                        .statusItemShadowControls
                                )
                            geometrySection
                                .id(
                                    AppearanceEditorInitialScrollTarget
                                        .statusItemGeometryControls
                                )

                            StateColorsEditorControls(
                                store: store,
                                previewState: $previewState,
                                onOpenCustomColor: { token in
                                    onOpenCustomColor(.palette(token))
                                }
                            )
                            .id(
                                AppearanceEditorInitialScrollTarget
                                    .stateColorControls
                            )

                            if
                                addsDocumentationScrollSpace,
                                isStatusEditorScrollTarget(
                                    initialScrollTarget
                                )
                            {
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
                        } header: {
                            sectionNavigation(proxy: proxy)
                        }
                    }
                }
                .scrollIndicators(
                    .visible,
                    axes: .vertical
                )
                .scrollBounceBehavior(
                    .basedOnSize,
                    axes: .vertical
                )
                .task(id: initialScrollTarget) {
                    guard
                        let initialScrollTarget,
                        isStatusEditorScrollTarget(initialScrollTarget)
                    else {
                        return
                    }
                    await Task.yield()
                    proxy.scrollTo(
                        initialScrollTarget,
                        anchor: .top
                    )
                }
            }
        }
        .frame(
            width: MoreOverlayMetrics.statusItemSize.width,
            height: MoreOverlayMetrics.statusItemSize.height
        )
        .environment(
            \.appearanceEditorFontScale,
            store.editorFontScale
        )
        .foregroundStyle(BrutalEditorStyle.ink)
        .accessibilityIdentifier("status-item-editor")
    }

    private var livePreview: some View {
        StatusDisplayLivePreview(
            profile: store.currentProfile,
            selectedState: $previewState
        )
        .padding(12)
        .brutalSectionDivider()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(
            "status-item-live-preview"
        )
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
        .accessibilityLabel("选择要编辑状态显示的主题")
    }

    private func sectionNavigation(
        proxy: ScrollViewProxy
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(StatusItemEditorSectionDestination.allCases) {
                destination in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(
                            destination.scrollTarget,
                            anchor: .top
                        )
                    }
                } label: {
                    Text(destination.title)
                        .appearanceEditorFont(
                            size: 8,
                            weight: .black,
                            design: .monospaced
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .appearanceEditorMinHeight(22)
                        .background(BrutalEditorStyle.paper)
                        .overlay {
                            Rectangle()
                                .strokeBorder(
                                    BrutalEditorStyle.ink,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .help("跳转到\(destination.title)设置")
                .accessibilityLabel(
                    "跳转到\(destination.title)设置"
                )
                .accessibilityIdentifier(
                    destination.accessibilityIdentifier
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(BrutalEditorStyle.paleTeal)
        .brutalSectionDivider()
        .zIndex(2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("设置区域快速导航")
    }

    private func isStatusEditorScrollTarget(
        _ target: AppearanceEditorInitialScrollTarget?
    ) -> Bool {
        switch target {
        case .statusItemControls,
             .statusItemShadowControls,
             .statusItemGeometryControls,
             .stateColorControls:
            true
        case .themeSelector,
             .panelControls,
             .panelColorControls,
             .panelGeometryControls,
             .panelShadowControls,
             nil:
            false
        }
    }

    private var textColorSection: some View {
        AppearanceEditorSection(
            appearance: panelAppearance,
            title: "文字",
            subtitle: "主额度与周额度可分别设置"
        ) {
            VStack(spacing: 10) {
                statusColorRow(
                    title: "主额度",
                    token: .primaryText,
                    accessibilityIdentifier:
                        "status-item-primary-text-color"
                )
                statusColorRow(
                    title: "周额度",
                    token: .weeklyText,
                    accessibilityIdentifier:
                        "status-item-weekly-text-color"
                )
            }
        }
    }

    private var shadowSection: some View {
        AppearanceEditorSection(
            appearance: panelAppearance,
            title: "阴影",
            subtitle: "水平负值向左，垂直正值向下"
        ) {
            VStack(spacing: 11) {
                statusColorRow(
                    title: "阴影颜色",
                    token: .shadow,
                    accessibilityIdentifier:
                        "status-item-shadow-color"
                )

                BrutalSlider(
                    title: "阴影透明度",
                    value: statusStyleBinding(\.shadowOpacity),
                    range: 0...1,
                    step: 0.05,
                    valueText: Self.percent,
                    tint: panelAppearance.primaryStateColor.swiftUIColor,
                    thumb: panelAppearance.actionAccentColor.swiftUIColor,
                    onEditingChanged: store.sliderEditingChanged,
                    controlAccessibilityIdentifier:
                        "status-item-shadow-opacity"
                )

                ForEach(StatusItemEditorField.shadowFields) { field in
                    statusSlider(field)
                }
            }
        }
    }

    private var geometrySection: some View {
        AppearanceEditorSection(
            appearance: panelAppearance,
            title: "几何",
            subtitle: "字号、轮廓与标签尺寸"
        ) {
            VStack(spacing: 11) {
                ForEach(StatusItemEditorField.geometryFields) { field in
                    statusSlider(field)
                }

                AppearanceEditorInlineNote(
                    text: "最终尺寸会根据系统菜单栏高度自动适配；水平阴影不会因高度被压缩。"
                )
                .padding(.top, 2)
            }
        }
    }

    private func statusColorRow(
        title: String,
        token: StatusItemColorToken,
        accessibilityIdentifier: String
    ) -> some View {
        let explicitColor = store.statusColor(for: token)
        let effectiveColor = StatusItemEditorPreviewFixture.effectiveColor(
            for: token,
            in: statusAppearance
        )
        return AppearanceColorRow(
            title: title,
            selectedColor: effectiveColor,
            swatches: AppearanceEditorPalette.statusItemSwatches(
                for: token
            ),
            isInherited: explicitColor == nil,
            accessibilityIdentifier: accessibilityIdentifier,
            onSelectSwatch: { color in
                store.setStatusColor(
                    color.withAlpha(1),
                    for: token
                )
            },
            onOpenCustomColor: {
                onOpenCustomColor(.statusItem(token))
            },
            onResetToInherited: {
                store.setStatusColor(nil, for: token)
            }
        )
    }

    private func statusSlider(
        _ field: StatusItemEditorField
    ) -> some View {
        BrutalSlider(
            title: field.title,
            value: statusGeometryBinding(field),
            range: field.range,
            step: field.step,
            valueText: {
                Self.points(
                    $0,
                    fractionDigits: field.fractionDigits
                )
            },
            tint: panelAppearance.primaryStateColor.swiftUIColor,
            thumb: panelAppearance.actionAccentColor.swiftUIColor,
            onEditingChanged: store.sliderEditingChanged,
            controlAccessibilityIdentifier:
                field.accessibilityIdentifier
        )
    }

    private var header: some View {
        let showsSaved =
            store.saveFeedbackState == .saved
        return HStack(spacing: 8) {
            HStack(spacing: 0) {
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
                .help("返回主面板设置")
                .accessibilityLabel("返回主面板设置")
                .accessibilityIdentifier(
                    "status-item-back-to-panel-settings"
                )

                Button(action: onReturnToPanel) {
                    Image(systemName: "macwindow")
                        .appearanceEditorFont(
                            size: 10,
                            weight: .bold
                        )
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("返回面板视图")
                .accessibilityLabel("返回面板视图")
                .accessibilityIdentifier(
                    "status-item-return-to-panel-view"
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("状态栏设置")
                    .appearanceEditorFont(
                        size: 14,
                        weight: .bold
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
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

    func statusGeometryBinding(
        _ field: StatusItemEditorField
    ) -> Binding<Double> {
        Binding(
            get: {
                let stored = store.currentProfile
                    .statusItemGeometry[
                        keyPath: field.keyPath
                    ]
                guard stored.isFinite else {
                    return field.range.lowerBound
                }
                return min(
                    max(stored, field.range.lowerBound),
                    field.range.upperBound
                )
            },
            set: { value in
                guard value.isFinite else { return }
                let editedValue = min(
                    max(value, field.range.lowerBound),
                    field.range.upperBound
                )
                store.updateCurrent {
                    $0.statusItemGeometry[
                        keyPath: field.keyPath
                    ] = editedValue
                }
            }
        )
    }

    func statusStyleBinding(
        _ keyPath: WritableKeyPath<StatusItemStyle, Double>,
        range: ClosedRange<Double> = 0...1
    ) -> Binding<Double> {
        Binding(
            get: {
                let stored = store.currentProfile.statusItemStyle[
                    keyPath: keyPath
                ]
                guard stored.isFinite else {
                    return range.lowerBound
                }
                return min(
                    max(stored, range.lowerBound),
                    range.upperBound
                )
            },
            set: { value in
                guard value.isFinite else { return }
                let editedValue = min(
                    max(value, range.lowerBound),
                    range.upperBound
                )
                store.updateCurrent {
                    $0.statusItemStyle[keyPath: keyPath] = editedValue
                }
            }
        )
    }

    private static func points(
        _ value: Double,
        fractionDigits: Int
    ) -> String {
        String(
            format: "%.\(fractionDigits)f pt",
            value
        )
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

private struct StatusDisplayLivePreview: View {
    let profile: AppearanceProfile
    @Binding var selectedState: StateColorsEditorPreviewState
    @State private var hoveredState:
        StateColorsEditorPreviewState?

    private var previewState: StateColorsEditorPreviewState {
        StatusDisplayPreviewInteraction.previewState(
            selected: selectedState,
            hovered: hoveredState
        )
    }

    private var appearance: ResolvedStatusItemAppearance {
        previewState.appearance(for: profile)
    }

    private var displayData: ThemeStatusDisplayData {
        ThemeStatusDisplayData(
            primaryText: previewState.displayText,
            resetText: previewState.isUnavailable ? nil : "1h34m",
            weeklyText: previewState.isUnavailable ? nil : "49%"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("实时预览")
                    .appearanceEditorFont(
                        size: 9,
                        weight: .black,
                        design: .monospaced
                    )
                    .tracking(0.8)

                Spacer(minLength: 8)

                Text(
                    StatusDisplayPreviewInteraction.guidanceText(
                        hovered: hoveredState
                    )
                )
                    .appearanceEditorFont(
                        size: 8,
                        weight: .bold,
                        design: .monospaced
                    )
                    .opacity(0.58)
            }

            HStack {
                Spacer(minLength: 0)
                ThemeStatusChromePreview(
                    appearance: appearance,
                    data: displayData,
                    showsFailurePattern:
                        previewState.showsFailurePattern
                )
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                ForEach(
                    StateColorsEditorPreviewState.allCases
                ) { state in
                    stateButton(state)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("状态栏设置实时预览")
    }

    private func stateButton(
        _ state: StateColorsEditorPreviewState
    ) -> some View {
        let isPreviewed = previewState == state
        let isSelected = selectedState == state
        let stateAppearance = state.appearance(for: profile)
        return Button {
            withAnimation(.easeOut(duration: 0.12)) {
                selectedState = state
            }
        } label: {
            ZStack {
                if isPreviewed {
                    Rectangle()
                        .fill(BrutalEditorStyle.ink)
                        .frame(
                            width: stateControlWidth(state),
                            height: 18
                        )
                        .offset(x: 2, y: 2)
                }

                Rectangle()
                    .fill(stateAppearance.fillColor.swiftUIColor)
                    .frame(
                        width: stateControlWidth(state),
                        height: 18
                    )
                    .overlay {
                        Rectangle()
                            .strokeBorder(
                                BrutalEditorStyle.ink,
                                lineWidth: isPreviewed ? 2 : 1
                            )
                    }

                Text(state.title)
                    .appearanceEditorFont(
                        size: 7.5,
                        weight: .black,
                        design: .monospaced
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(
                        stateAppearance.outlineColor.swiftUIColor
                    )
            }
            .frame(
                width: stateControlWidth(state) + 2,
                height: 24
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            withAnimation(.easeOut(duration: 0.1)) {
                hoveredState = StatusDisplayPreviewInteraction
                    .hoveredState(
                        current: hoveredState,
                        target: state,
                        isHovering: isHovering
                    )
            }
        }
        .help("悬停预览\(state.title)状态")
        .accessibilityLabel("\(state.title)状态")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(
            "status-display-preview-state-\(state.rawValue)"
        )
    }

    private func stateControlWidth(
        _ state: StateColorsEditorPreviewState
    ) -> CGFloat {
        state == .unavailable ? 50 : 42
    }
}
