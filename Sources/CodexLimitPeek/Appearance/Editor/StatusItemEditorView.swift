import Foundation
import SwiftUI

struct StatusItemEditorView: View {
    @ObservedObject var store: AppearanceStore
    let onBack: () -> Void
    let onOpenCustomColor: (StatusItemColorToken) -> Void

    init(
        store: AppearanceStore,
        onBack: @escaping () -> Void,
        onOpenCustomColor: @escaping (StatusItemColorToken) -> Void = { _ in }
    ) {
        self.store = store
        self.onBack = onBack
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
                    VStack(
                        alignment: .leading,
                        spacing: 0
                    ) {
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
                        geometrySection

                        Text(
                            "最终尺寸会根据系统菜单栏高度自动适配；水平阴影不会因高度被压缩。"
                        )
                        .appearanceEditorFont(
                            size: 8,
                            weight: .bold,
                            design: .monospaced
                        )
                        .padding(12)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .background(
                            BrutalEditorStyle.paleTeal
                        )

                        if
                            addsDocumentationScrollSpace,
                            initialScrollTarget == .statusItemControls
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
                    guard initialScrollTarget == .statusItemControls else {
                        return
                    }
                    await Task.yield()
                    proxy.scrollTo(
                        AppearanceEditorInitialScrollTarget
                            .statusItemControls,
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
        VStack(
            alignment: .leading,
            spacing: 9
        ) {
            Text("实时预览")
                .appearanceEditorFont(
                    size: 9,
                    weight: .black,
                    design: .monospaced
                )
            HStack {
                Spacer()
                ThemeStatusChromePreview(
                    appearance: statusAppearance
                )
                Spacer()
            }
        }
        .padding(12)
        .brutalSectionDivider()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(
            "status-item-live-preview"
        )
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
                onOpenCustomColor(token)
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
                Text("状态栏显示层")
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
