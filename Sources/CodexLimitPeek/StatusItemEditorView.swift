import Foundation
import SwiftUI

struct StatusItemEditorView: View {
    @ObservedObject var store: AppearanceStore
    let onBack: () -> Void

    @Environment(\.appearanceEditorInitialScrollTarget)
    private var initialScrollTarget

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
        AppearanceResolver.status(
            profile: store.currentProfile,
            primaryRemainingPercent: 81,
            weeklyRemainingPercent: 49,
            isUnavailable: false,
            showsFailurePattern: false
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 0
                    ) {
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
                        .accessibilityIdentifier(
                            "status-item-live-preview"
                        )

                        AppearanceEditorSection(
                            appearance: panelAppearance,
                            title: "状态栏显示层",
                            subtitle: "当前主题独立保存"
                        ) {
                            VStack(spacing: 11) {
                                ForEach(
                                    StatusItemEditorField.allCases
                                ) { field in
                                    BrutalSlider(
                                        title: field.title,
                                        value:
                                            statusGeometryBinding(
                                                field
                                            ),
                                        range: field.range,
                                        step: field.step,
                                        valueText: {
                                            Self.points(
                                                $0,
                                                fractionDigits:
                                                    field
                                                        .fractionDigits
                                            )
                                        },
                                        tint: panelAppearance
                                            .primaryStateColor
                                            .swiftUIColor,
                                        thumb: panelAppearance
                                            .actionAccentColor
                                            .swiftUIColor,
                                        onEditingChanged: {
                                            store
                                                .sliderEditingChanged(
                                                    $0
                                                )
                                        }
                                    )
                                    .accessibilityIdentifier(
                                        field
                                            .accessibilityIdentifier
                                    )
                                }
                            }
                        }
                        .id(
                            AppearanceEditorInitialScrollTarget
                                .statusItemControls
                        )

                        Text(
                            "最终尺寸会根据系统菜单栏高度自动适配"
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

                        if initialScrollTarget == .statusItemControls {
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

    private static func points(
        _ value: Double,
        fractionDigits: Int
    ) -> String {
        String(
            format: "%.\(fractionDigits)f pt",
            value
        )
    }
}
