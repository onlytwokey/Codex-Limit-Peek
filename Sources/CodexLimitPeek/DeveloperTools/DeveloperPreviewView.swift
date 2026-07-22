#if DEVELOPER_TOOLS
import AppKit
import SwiftUI

struct DeveloperPreviewView: View {
    @ObservedObject var coordinator: DeveloperPreviewCoordinator

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            stage
        }
        .frame(
            width: DeveloperPreviewCoordinator.contentSize.width,
            height: DeveloperPreviewCoordinator.contentSize.height
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("开发者预览")
                    .font(.system(size: 17, weight: .semibold))
                Text("固定数据 · 不写入正式设置")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("DEVELOPMENT", systemImage: "hammer.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.orange)
                .accessibilityLabel("开发构建")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                controlGroup(title: "主题") {
                    Picker(
                        "主题",
                        selection: themeBinding
                    ) {
                        ForEach(
                            AppearanceThemeID.allCases,
                            id: \.self
                        ) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                controlGroup(title: "实现") {
                    Picker(
                        "实现",
                        selection: implementationBinding
                    ) {
                        ForEach(
                            DeveloperPreviewImplementation.allCases
                        ) { implementation in
                            Text(implementation.title)
                                .tag(implementation)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }

            controlGroup(title: "场景") {
                Picker(
                    "场景",
                    selection: scenarioBinding
                ) {
                    ForEach(DeveloperPreviewScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var stage: some View {
        VStack(spacing: 0) {
            statusItemInspectionStrip
            Divider()

            ZStack {
                Color(nsColor: .underPageBackgroundColor)

                DeveloperPreviewPanelSurface(
                    quotaStore: coordinator.environment.quotaStore,
                    appearanceStore:
                        coordinator.environment.appearanceStore,
                    moreOverlayPresenter:
                        coordinator.moreOverlayPresenter,
                    implementation:
                        coordinator.selection.implementation
                )
                .id(ObjectIdentifier(coordinator.environment))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("面板预览舞台")
    }

    private var statusItemInspectionStrip: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("真实状态栏")
                    .font(.system(size: 11, weight: .semibold))
                Text("CompactStatusItemView · 实际菜单栏高度")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            DeveloperPreviewStatusItemView(
                quotaStore: coordinator.environment.quotaStore,
                appearanceStore:
                    coordinator.environment.appearanceStore,
                referenceDate:
                    coordinator.environment.referenceDate
            )
            .id(ObjectIdentifier(coordinator.environment))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("真实状态栏检查条")
        .accessibilityIdentifier(
            "developer-preview-status-item-strip"
        )
    }

    private func controlGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var themeBinding: Binding<AppearanceThemeID> {
        Binding(
            get: { coordinator.selection.theme },
            set: { coordinator.selectTheme($0) }
        )
    }

    private var scenarioBinding: Binding<DeveloperPreviewScenario> {
        Binding(
            get: { coordinator.selection.scenario },
            set: { coordinator.selectScenario($0) }
        )
    }

    private var implementationBinding:
        Binding<DeveloperPreviewImplementation>
    {
        Binding(
            get: { coordinator.selection.implementation },
            set: { coordinator.selectImplementation($0) }
        )
    }
}
#endif
