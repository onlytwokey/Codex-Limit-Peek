import Foundation
import SwiftUI

struct StateColorsEditorView: View {
    @ObservedObject var store: AppearanceStore
    let onBack: () -> Void
    let onOpenCustomColor: (AppearanceColorToken) -> Void

    @Environment(\.appearanceEditorInitialScrollTarget)
    private var initialScrollTarget

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

            ScrollViewReader { proxy in
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
                        .id(
                            AppearanceEditorInitialScrollTarget
                                .stateColorControls
                        )

                        if initialScrollTarget == .stateColorControls {
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
                    guard initialScrollTarget == .stateColorControls else {
                        return
                    }
                    await Task.yield()
                    proxy.scrollTo(
                        AppearanceEditorInitialScrollTarget
                            .stateColorControls,
                        anchor: .top
                    )
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
}
