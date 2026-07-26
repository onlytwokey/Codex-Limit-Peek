import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CodexLimitPeek

struct StatusItemEditorTests {
    @Test
    func guidanceInvitesPinningOnlyWhileAStateIsHovered() {
        #expect(
            StatusDisplayPreviewInteraction.guidanceText(
                hovered: nil
            ) == "悬停状态查看效果"
        )
        #expect(
            StatusDisplayPreviewInteraction.guidanceText(
                hovered: .warning
            ) == "点击固定状态显示"
        )
    }

    @Test
    func hoverTemporarilyOverridesAndThenRestoresTheSelectedState() {
        #expect(
            StatusDisplayPreviewInteraction.previewState(
                selected: .normal,
                hovered: .danger
            ) == .danger
        )
        #expect(
            StatusDisplayPreviewInteraction.previewState(
                selected: .warning,
                hovered: nil
            ) == .warning
        )

        let entered = StatusDisplayPreviewInteraction.hoveredState(
            current: nil,
            target: .danger,
            isHovering: true
        )
        #expect(entered == .danger)
        #expect(
            StatusDisplayPreviewInteraction.hoveredState(
                current: entered,
                target: .warning,
                isHovering: false
            ) == .danger
        )
        #expect(
            StatusDisplayPreviewInteraction.hoveredState(
                current: entered,
                target: .danger,
                isHovering: false
            ) == nil
        )
    }

    @Test
    func sectionNavigationUsesTheApprovedOrderAnchorsAndIdentifiers() {
        let destinations = StatusItemEditorSectionDestination.allCases

        #expect(
            destinations.map(\.title) == [
                "文字",
                "阴影",
                "几何",
                "状态颜色"
            ]
        )
        #expect(
            destinations.map(\.scrollTarget) == [
                .statusItemControls,
                .statusItemShadowControls,
                .statusItemGeometryControls,
                .stateColorControls
            ]
        )
        #expect(
            destinations.map(\.accessibilityIdentifier) == [
                "status-item-section-navigation-text",
                "status-item-section-navigation-shadow",
                "status-item-section-navigation-geometry",
                "status-item-section-navigation-state-colors"
            ]
        )
    }

    @Test
    func exposesAllEightApprovedFieldsInOrder() {
        #expect(
            StatusItemEditorField.allCases.map(\.title) == [
                "状态栏字体大小",
                "显示层描边",
                "显示层圆角",
                "阴影水平偏移",
                "阴影垂直偏移",
                "阴影模糊",
                "显示层横向留白",
                "显示层高度"
            ]
        )
        #expect(
            StatusItemEditorField.allCases.map(\.range) == [
                8...14,
                0...4,
                0...12,
                -10...10,
                -10...10,
                0...8,
                2...14,
                14...22
            ]
        )
        #expect(
            StatusItemEditorField.allCases.map(\.step) == [
                0.5,
                0.25,
                1,
                0.5,
                0.5,
                0.5,
                0.5,
                0.5
            ]
        )
        #expect(
            StatusItemEditorField.allCases.map(\.fractionDigits) == [
                1,
                2,
                0,
                1,
                1,
                1,
                1,
                1
            ]
        )
        #expect(
            StatusItemEditorField.allCases.map(
                \.accessibilityIdentifier
            ) == [
                "status-item-font-size",
                "status-item-outline-width",
                "status-item-corner-radius",
                "status-item-shadow-horizontal-offset",
                "status-item-shadow-vertical-offset",
                "status-item-shadow-blur",
                "status-item-horizontal-padding",
                "status-item-tag-height"
            ]
        )
        #expect(
            StatusItemEditorField.shadowFields == [
                .shadowHorizontalOffset,
                .shadowVerticalOffset,
                .shadowBlur
            ]
        )
        #expect(
            StatusItemEditorField.geometryFields == [
                .fontSize,
                .outlineWidth,
                .cornerRadius,
                .horizontalPadding,
                .tagHeight
            ]
        )
    }

    @Test @MainActor
    func shadowOpacityBindingIsClampedAndDoesNotChangePanelGeometry() {
        let suite = "StatusItemEditorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppearanceStore(defaults: defaults)
        let editor = StatusItemEditorView(store: store, onBack: {})
        let originalPanelGeometry = store.currentProfile.geometry

        editor.statusStyleBinding(\.shadowOpacity).wrappedValue = 2

        #expect(store.currentProfile.statusItemStyle.shadowOpacity == 1)
        #expect(store.currentProfile.geometry == originalPanelGeometry)

        editor.statusStyleBinding(\.shadowOpacity).wrappedValue = -1
        #expect(store.currentProfile.statusItemStyle.shadowOpacity == 0)
    }

    @Test @MainActor
    func explicitLowContrastTextIsReportedWithoutChangingItsColor() {
        let suite = "StatusItemEditorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppearanceStore(defaults: defaults)
        let weakColor = AppearanceColor(hex: 0x78CFC8)
        store.setStatusColor(weakColor, for: .primaryText)
        let editor = StatusItemEditorView(store: store, onBack: {})

        #expect(editor.lowContrastLabels.contains("主额度"))
        #expect(store.statusColor(for: .primaryText) == weakColor)
        #expect(!editor.lowContrastLabels.contains("周额度"))
    }

    @Test @MainActor
    func everySliderBindingChangesOnlyStatusGeometry() {
        let suite = "StatusItemEditorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppearanceStore(defaults: defaults)
        let editor = StatusItemEditorView(
            store: store,
            onBack: {}
        )
        let originalPanelGeometry = store.currentProfile.geometry

        for field in StatusItemEditorField.allCases {
            editor.statusGeometryBinding(field).wrappedValue =
                field.range.upperBound
        }

        #expect(store.currentProfile.geometry == originalPanelGeometry)
        for field in StatusItemEditorField.allCases {
            #expect(
                store.currentProfile.statusItemGeometry[
                    keyPath: field.keyPath
                ] == field.range.upperBound
            )
        }
    }

    @Test @MainActor
    func legacyValuesAreClampedForSliderDisplayWithoutBeingRewritten() {
        let suite = "StatusItemEditorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppearanceStore(defaults: defaults)
        store.updateCurrent {
            $0.statusItemGeometry.cornerRadius = 23
            $0.statusItemGeometry.shadowBlur = 20
        }
        let editor = StatusItemEditorView(
            store: store,
            onBack: {}
        )
        let host = NSHostingView(rootView: editor)
        host.frame = NSRect(
            origin: .zero,
            size: MoreOverlayMetrics.statusItemSize
        )
        host.layoutSubtreeIfNeeded()

        #expect(store.currentProfile.statusItemGeometry.cornerRadius == 23)
        #expect(store.currentProfile.statusItemGeometry.shadowBlur == 20)

        let cornerBinding = editor.statusGeometryBinding(.cornerRadius)
        let blurBinding = editor.statusGeometryBinding(.shadowBlur)

        #expect(cornerBinding.wrappedValue == 12)
        #expect(blurBinding.wrappedValue == 8)
        #expect(store.currentProfile.statusItemGeometry.cornerRadius == 23)
        #expect(store.currentProfile.statusItemGeometry.shadowBlur == 20)

        cornerBinding.wrappedValue = 7

        #expect(store.currentProfile.statusItemGeometry.cornerRadius == 7)
        #expect(store.currentProfile.statusItemGeometry.shadowBlur == 20)
    }
}
