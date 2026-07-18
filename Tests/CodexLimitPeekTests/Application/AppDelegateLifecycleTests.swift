import AppKit
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct AppDelegateLifecycleTests {
    @Test @MainActor
    func panelIsCreatedOnDemandAndThenReused() throws {
        let delegate = AppDelegate()

        #expect(!delegate.isPanelWindowLoaded)
        #expect(!delegate.isMoreOverlayWindowLoaded)

        let firstPanel = delegate.ensurePanelWindow()
        let secondPanel = delegate.ensurePanelWindow()

        #expect(delegate.isPanelWindowLoaded)
        #expect(!delegate.isMoreOverlayWindowLoaded)
        #expect(firstPanel === secondPanel)
        let childWindows = try #require(firstPanel.childWindows)
        #expect(childWindows.count == 1)
        #expect(childWindows[0].ignoresMouseEvents)
        #expect(childWindows[0].level == firstPanel.level)
    }

    @Test
    func panelContentStaysBelowTheMenuBarWhileShadowKeepsSafetyBleed() {
        let anchor = NSRect(x: 1_380, y: 900, width: 60, height: 24)
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let visualInsets = ThemeShadowRecipe.soft(
            depth: 10,
            blur: 20,
            opacity: 1
        ).visualInsets

        let content = PanelMetrics.contentFrame(
            relativeTo: anchor,
            within: visibleFrame,
            shadowInsets: visualInsets
        )
        let shadow = PanelMetrics.shadowFrame(around: content)
        let visual = PanelMetrics.visualFrame(
            around: content,
            shadowInsets: visualInsets
        )

        #expect(
            content.maxY
                <= anchor.minY - PanelMetrics.verticalGap
        )
        #expect(
            visual.minX
                >= visibleFrame.minX + PanelMetrics.screenPadding
        )
        #expect(
            visual.maxX
                <= visibleFrame.maxX - PanelMetrics.screenPadding
        )
        #expect(
            visual.minY
                >= visibleFrame.minY + PanelMetrics.screenPadding
        )
        #expect(
            visual.maxY
                <= visibleFrame.maxY - PanelMetrics.screenPadding
        )
        #expect(
            shadow.width
                == ThemePanelLayout.width
                    + ThemePanelLayout.shadowSafetyInset * 2
        )
        #expect(ThemePanelLayout.shadowSafetyInset >= 30)
    }

    @Test @MainActor
    func closingMainPanelResetsMoreNavigation() {
        let delegate = AppDelegate()
        delegate.setMoreOverlayPageForTesting(.stateColors)

        delegate.closePanelForTesting()

        #expect(delegate.moreOverlayPageForTesting == .actions)
    }

    @Test @MainActor
    func closingMainPanelKeepsShadowAttachedForReopen() throws {
        let delegate = AppDelegate()
        let panel = delegate.ensurePanelWindow()
        let shadow = try #require(panel.childWindows?.first)
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }

        #expect(panel.isVisible)
        #expect(shadow.isVisible)

        delegate.closePanelForTesting()

        #expect(!panel.isVisible)
        #expect(!shadow.isVisible)
        #expect(shadow.parent === panel)

        panel.orderFrontRegardless()

        #expect(panel.isVisible)
        #expect(shadow.isVisible)
        #expect(shadow.parent === panel)
    }
}
