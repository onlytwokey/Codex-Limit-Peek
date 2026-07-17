import AppKit
import SwiftUI
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct MoreOverlayTests {
    @Test
    func preferredLayoutAlignsRightEdgeAndKeepsEightPointGap() {
        let anchor = NSRect(x: 600, y: 760, width: 25, height: 25)
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let layout = MoreOverlayMetrics.layout(
            anchorRect: anchor,
            contentSize: NSSize(width: 224, height: 180),
            visibleFrame: visible,
            shadowInsets: EdgeInsets(
                top: 0,
                leading: 0,
                bottom: 8,
                trailing: 8
            )
        )

        #expect(layout.interactionFrame.maxX == anchor.maxX)
        #expect(
            layout.interactionFrame.maxY
                == anchor.minY - MoreOverlayMetrics.anchorGap
        )
    }

    @Test
    func layoutKeepsFullVisualShadowInsideScreen() {
        let anchor = NSRect(x: 5, y: 660, width: 25, height: 25)
        let visible = NSRect(x: 0, y: 0, width: 800, height: 700)
        let insets = EdgeInsets(
            top: 20,
            leading: 20,
            bottom: 30,
            trailing: 30
        )
        let layout = MoreOverlayMetrics.layout(
            anchorRect: anchor,
            contentSize: MoreOverlayMetrics.appearanceSize,
            visibleFrame: visible,
            shadowInsets: insets
        )

        #expect(
            layout.visualFrame.minX
                >= visible.minX + MoreOverlayMetrics.screenPadding
        )
        #expect(
            layout.visualFrame.minY
                >= visible.minY + MoreOverlayMetrics.screenPadding
        )
        #expect(
            layout.visualFrame.maxX
                <= visible.maxX - MoreOverlayMetrics.screenPadding
        )
        #expect(
            layout.visualFrame.maxY
                <= visible.maxY - MoreOverlayMetrics.screenPadding
        )
        #expect(
            layout.decorationFrame.width
                == layout.interactionFrame.width
                    + MoreOverlayMetrics.shadowSafetyInset * 2
        )
    }

    @Test(arguments: [
        (MoreOverlayClickRole.anchor, MoreOverlayDismissalAction.keep),
        (MoreOverlayClickRole.interaction, .keep),
        (MoreOverlayClickRole.colorPanel, .keep),
        (MoreOverlayClickRole.auxiliaryChild, .keep),
        (MoreOverlayClickRole.parentPanel, .closeOverlay),
        (MoreOverlayClickRole.otherApplicationWindow, .closeOverlay)
    ])
    func dismissalPolicyMatchesApprovedInteraction(
        role: MoreOverlayClickRole,
        expected: MoreOverlayDismissalAction
    ) {
        #expect(MoreOverlayDismissalPolicy.action(for: role) == expected)
    }

    @Test @MainActor
    func windowPairIsLazyReusableAndClickThroughOnlyForDecoration() throws {
        let suite = "MoreOverlayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let presenter = MoreOverlayPresenter(
            quotaStore: QuotaStore(defaults: defaults),
            appearanceStore: AppearanceStore(defaults: defaults)
        )

        #expect(!presenter.isWindowPairLoaded)
        let first = try #require(presenter.ensureWindowPair())
        let second = try #require(presenter.ensureWindowPair())

        #expect(presenter.isWindowPairLoaded)
        #expect(first.interaction === second.interaction)
        #expect(first.decoration === second.decoration)
        #expect(!first.interaction.ignoresMouseEvents)
        #expect(first.decoration.ignoresMouseEvents)
        #expect(first.interaction.styleMask.contains(.borderless))
        #expect(first.decoration.styleMask.contains(.borderless))
        #expect(!first.interaction.hasShadow)
        #expect(!first.decoration.hasShadow)
    }

    @Test @MainActor
    func closingResetsThePageAndFlushesAppearanceChanges() {
        let suite = "MoreOverlayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = AppearanceStore(defaults: defaults)
        let presenter = MoreOverlayPresenter(
            quotaStore: QuotaStore(defaults: defaults),
            appearanceStore: appearance
        )

        appearance.sliderEditingChanged(true)
        appearance.setEditorFontScale(1.4)
        presenter.navigate(to: .appearance)
        presenter.close()

        #expect(presenter.page == .actions)
        #expect(!presenter.isPresented)
        #expect(
            AppearanceStore(defaults: defaults).editorFontScale == 1.4
        )
    }

    @Test @MainActor
    func closingDismissesTheSharedColorPanel() {
        let suite = "MoreOverlayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer {
            NSColorPanel.shared.orderOut(nil)
            defaults.removePersistentDomain(forName: suite)
        }
        let presenter = MoreOverlayPresenter(
            quotaStore: QuotaStore(defaults: defaults),
            appearanceStore: AppearanceStore(defaults: defaults)
        )
        let colorPanel = NSColorPanel.shared

        colorPanel.orderFront(nil)
        #expect(colorPanel.isVisible)

        presenter.close()

        #expect(!colorPanel.isVisible)
    }

    @Test @MainActor
    func presentedPairKeepsDirectOrderingAndUpdatesBothFramesTogether()
        throws
    {
        let suite = "MoreOverlayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let quota = QuotaStore(defaults: defaults)
        let presenter = MoreOverlayPresenter(
            quotaStore: quota,
            appearanceStore: AppearanceStore(defaults: defaults)
        )
        let parent = NSPanel(
            contentRect: NSRect(
                x: 400,
                y: 620,
                width: 380,
                height: 260
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        parent.level = .popUpMenu
        let mainShadow = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        parent.addChildWindow(mainShadow, ordered: .below)

        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: 380, height: 260)
        )
        let anchor = MoreOverlayAnchorView(
            frame: NSRect(x: 330, y: 220, width: 25, height: 25)
        )
        container.addSubview(anchor)
        parent.contentView = container
        presenter.attach(to: parent)
        presenter.setAnchorView(anchor)
        presenter.present()
        defer { presenter.close() }

        let pair = try #require(presenter.ensureWindowPair())
        let orderedChildren = try #require(parent.childWindows)
        #expect(orderedChildren.first === mainShadow)
        #expect(orderedChildren.dropFirst().first === pair.decoration)
        #expect(orderedChildren.last === pair.interaction)
        #expect(pair.interaction.parent === parent)
        #expect(pair.decoration.parent === parent)
        #expect(pair.interaction.level == parent.level)
        #expect(pair.decoration.level == parent.level)

        let anchorRect = try #require(anchor.screenRect)
        #expect(
            presenter.clickRole(
                candidateWindow: parent,
                screenPoint: NSPoint(
                    x: anchorRect.midX,
                    y: anchorRect.midY
                )
            ) == .anchor
        )
        #expect(
            presenter.clickRole(
                candidateWindow: pair.interaction,
                screenPoint: .zero
            ) == .interaction
        )
        #expect(
            presenter.clickRole(
                candidateWindow: NSColorPanel.shared,
                screenPoint: .zero
            ) == .colorPanel
        )
        let auxiliary = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        pair.interaction.addChildWindow(auxiliary, ordered: .above)
        #expect(
            presenter.clickRole(
                candidateWindow: auxiliary,
                screenPoint: .zero
            ) == .auxiliaryChild
        )
        pair.interaction.removeChildWindow(auxiliary)
        #expect(
            presenter.clickRole(
                candidateWindow: parent,
                screenPoint: .zero
            ) == .parentPanel
        )
        let otherWindow = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        #expect(
            presenter.clickRole(
                candidateWindow: otherWindow,
                screenPoint: .zero
            ) == .otherApplicationWindow
        )

        let compactActionsHeight = pair.interaction.frame.height
        quota.voiceBroadcastEnabled = true
        presenter.reposition()
        #expect(pair.interaction.frame.height > compactActionsHeight)

        presenter.navigate(to: .appearance)

        #expect(
            pair.interaction.frame.size
                == MoreOverlayMetrics.appearanceSize
        )
        #expect(
            pair.decoration.frame
                == pair.interaction.frame.insetBy(
                    dx: -MoreOverlayMetrics.shadowSafetyInset,
                    dy: -MoreOverlayMetrics.shadowSafetyInset
                )
        )

        presenter.close()
        #expect(pair.interaction.parent == nil)
        #expect(pair.decoration.parent == nil)
        let remainingChildren = try #require(parent.childWindows)
        #expect(remainingChildren.count == 1)
        #expect(remainingChildren.first === mainShadow)

        presenter.present()
        let reused = try #require(presenter.ensureWindowPair())
        #expect(reused.interaction === pair.interaction)
        #expect(reused.decoration === pair.decoration)
        #expect(parent.childWindows?.last === pair.interaction)
        #expect(presenter.hasLocalEventMonitor)

        let escape = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: pair.interaction.windowNumber,
                context: nil,
                characters: "\u{1B}",
                charactersIgnoringModifiers: "\u{1B}",
                isARepeat: false,
                keyCode: 53
            )
        )
        #expect(presenter.handleLocalEvent(escape) == nil)
        #expect(!presenter.isPresented)
        #expect(!presenter.hasLocalEventMonitor)
        #expect(pair.interaction.parent == nil)
        #expect(pair.decoration.parent == nil)
    }
}
