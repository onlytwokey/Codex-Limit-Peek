#if DEVELOPER_TOOLS
import AppKit
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct DeveloperPreviewCoordinatorTests {
    @Test @MainActor
    func coordinatorCreatesOneAddressableStandardWindow() throws {
        let coordinator = DeveloperPreviewCoordinator(
            launchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            onClose: {}
        )
        let first = coordinator.ensureWindow()
        let second = coordinator.ensureWindow()
        defer { first.orderOut(nil) }

        #expect(first === second)
        #expect(first.title == DeveloperPreviewCoordinator.windowTitle)
        #expect(first.accessibilityRole() == .window)
        #expect(
            first.accessibilityTitle()
                == DeveloperPreviewCoordinator.windowTitle
        )
        #expect(first.styleMask.contains(.titled))
        #expect(first.styleMask.contains(.closable))
        #expect(!first.styleMask.contains(.nonactivatingPanel))
        #expect(first.canBecomeKey)
        #expect(first.level == .normal)
        #expect(first.contentViewController != nil)
        #expect(!coordinator.isMoreOverlayWindowLoaded)
    }

    @Test @MainActor
    func selectionRebuildsOnlyTheIsolatedEnvironment() {
        let coordinator = DeveloperPreviewCoordinator(
            launchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            onClose: {}
        )
        let original = coordinator.environment
        let primaryTextColor = AppearanceColor(hex: 0x123456)
        original.appearanceStore.setStatusColor(
            primaryTextColor,
            for: .primaryText
        )
        original.appearanceStore.updateCurrent {
            $0.statusItemGeometry.shadowHorizontalOffset = -6
        }
        original.appearanceStore.setEditorFontScale(1.17)

        coordinator.selectScenario(.danger)
        coordinator.selectTheme(.bold)
        coordinator.selectImplementation(.candidate)

        #expect(coordinator.environment !== original)
        #expect(
            coordinator.environment.quotaStore.snapshot.remainingPercent == 7
        )
        #expect(coordinator.environment.appearanceStore.selectedTheme == .bold)
        #expect(coordinator.selection.implementation == .candidate)
        #expect(
            coordinator.environment.appearanceStore
                .profile(for: .loud)
                .statusItemStyle.primaryTextColor == primaryTextColor
        )
        #expect(
            coordinator.environment.appearanceStore
                .profile(for: .loud)
                .statusItemGeometry.shadowHorizontalOffset == -6
        )
        #expect(
            coordinator.environment.appearanceStore.editorFontScale == 1.17
        )
    }

    @Test @MainActor
    func statusItemProjectionUsesFixtureTextAndProductionView() {
        let launchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let coordinator = DeveloperPreviewCoordinator(
            launchedAt: launchedAt,
            onClose: {}
        )

        let projection = coordinator.statusItemProjection
        let view = DeveloperPreviewStatusItemView
            .makeStatusItemViewForTesting(
                projection: projection
            )

        #expect(coordinator.environment.referenceDate == launchedAt)
        #expect(projection.title == "81% | 1h34m")
        #expect(projection.weeklyTitle == "49%")
        #expect(!projection.showsFailurePattern)
        #expect(view.frame.width > 0)
        #expect(view.frame.height == NSStatusBar.system.thickness)
        #expect(
            view.accessibilityIdentifier()
                == "developer-preview-compact-status-item"
        )
        #expect(
            view.accessibilityValue() as? String
                == "81% | 1h34m | 49%"
        )
    }

    @Test @MainActor
    func statusItemProjectionTracksAppearanceRevisionInPlace() {
        let coordinator = DeveloperPreviewCoordinator(
            launchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            onClose: {}
        )
        let environment = coordinator.environment
        let original = coordinator.statusItemProjection

        environment.appearanceStore.updateCurrent {
            $0.statusItemGeometry.fontSize = 13
        }
        let updated = coordinator.statusItemProjection

        #expect(coordinator.environment === environment)
        #expect(
            environment.appearanceStore.currentProfile
                .statusItemGeometry.fontSize == 13
        )
        #expect(
            updated.appearance.fontSize
                > original.appearance.fontSize
        )
        #expect(updated.appearance != original.appearance)
        #expect(
            environment.appearanceStore.revision > 0
        )
    }

    @Test @MainActor
    func failureScenarioProjectsFailurePatternWithoutProductionData() {
        let coordinator = DeveloperPreviewCoordinator(
            selection: DeveloperPreviewSelection(
                theme: .frost,
                scenario: .refreshFailure,
                implementation: .current
            ),
            launchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            onClose: {}
        )

        let projection = coordinator.statusItemProjection

        #expect(projection.title == "63% | 1h34m")
        #expect(projection.weeklyTitle == "38%")
        #expect(projection.showsFailurePattern)
        #expect(coordinator.environment.quotaStore.refreshHealth == .degraded)
    }
}
#endif
