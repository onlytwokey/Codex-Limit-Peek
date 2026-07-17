import AppKit
import SwiftUI
import Testing
@testable import CodexLimitPeek

@MainActor
private final class RecordingColorPanelCoordinator:
    AppearanceColorPanelCoordinating
{
    private(set) var activeContext:
        AppearanceColorPanelEditContext?
    private(set) var closeCount = 0
    private(set) var beginCount = 0
    private var onChange: ((
        AppearanceThemeID,
        AppearanceColorToken,
        AppearanceColor
    ) -> Void)?

    func beginEditing(
        theme: AppearanceThemeID,
        token: AppearanceColorToken,
        color: AppearanceColor,
        above overlayLevel: NSWindow.Level,
        onChange: @escaping (
            AppearanceThemeID,
            AppearanceColorToken,
            AppearanceColor
        ) -> Void
    ) {
        beginCount += 1
        activeContext = AppearanceColorPanelEditContext(
            theme: theme,
            token: token
        )
        self.onChange = onChange
    }

    func close() {
        closeCount += 1
        activeContext = nil
        onChange = nil
    }
}

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
        (MoreOverlayClickRole.hitShield, .keep),
        (MoreOverlayClickRole.visualShield, .keep),
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

    @Test(arguments: [
        (
            NSEvent.EventType.leftMouseDown,
            MoreOverlayClickRole.visualShield,
            true
        ),
        (.rightMouseDown, .visualShield, true),
        (.otherMouseDown, .visualShield, true),
        (.scrollWheel, .visualShield, true),
        (.leftMouseDown, .hitShield, true),
        (.scrollWheel, .hitShield, false),
        (.scrollWheel, .interaction, false),
        (.leftMouseDown, .parentPanel, false)
    ])
    func visualShieldConsumesOnlyProtectedPointerEvents(
        eventType: NSEvent.EventType,
        role: MoreOverlayClickRole,
        expected: Bool
    ) {
        #expect(
            MoreOverlayEventPolicy.shouldConsume(
                eventType: eventType,
                role: role
            ) == expected
        )
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
        #expect(first.hitShield === second.hitShield)
        #expect(first.decoration === second.decoration)
        #expect(!first.interaction.ignoresMouseEvents)
        #expect(!first.hitShield.ignoresMouseEvents)
        #expect(first.decoration.ignoresMouseEvents)
        #expect(first.interaction.backgroundColor.alphaComponent > 0)
        #expect(first.hitShield.backgroundColor.alphaComponent > 0)
        #expect(first.interaction.styleMask.contains(.borderless))
        #expect(first.hitShield.styleMask.contains(.borderless))
        #expect(first.decoration.styleMask.contains(.borderless))
        #expect(!first.interaction.hasShadow)
        #expect(!first.hitShield.hasShadow)
        #expect(!first.decoration.hasShadow)
    }

    @Test @MainActor
    func interactionPanelForwardsScrollToNestedScrollView() throws {
        let panel = MoreInteractionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 548),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 548)
        )
        let wrapper = NSView(frame: container.bounds)
        let scrollView = RecordingScrollView(frame: container.bounds)
        wrapper.addSubview(scrollView)
        container.addSubview(wrapper)
        panel.contentView = container
        let cgEvent = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: 12,
                wheel2: 0,
                wheel3: 0
            )
        )
        let event = try #require(NSEvent(cgEvent: cgEvent))

        panel.sendEvent(event)

        #expect(scrollView.didReceiveScrollWheel)
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
    func colorPanelContextClosesOnNavigationThemeChangeAndOverlayClose() {
        let suite = "MoreOverlayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let appearance = AppearanceStore(defaults: defaults)
        let coordinator = RecordingColorPanelCoordinator()
        let presenter = MoreOverlayPresenter(
            quotaStore: QuotaStore(defaults: defaults),
            appearanceStore: appearance,
            colorPanelCoordinator: coordinator
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
        let container = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 380,
                height: 260
            )
        )
        let anchor = MoreOverlayAnchorView(
            frame: NSRect(
                x: 330,
                y: 220,
                width: 25,
                height: 25
            )
        )
        container.addSubview(anchor)
        parent.contentView = container
        presenter.attach(to: parent)
        presenter.setAnchorView(anchor)
        presenter.present()
        presenter.navigate(to: .appearance)

        presenter.openColorPanel(for: .background)
        #expect(
            coordinator.activeContext
                == AppearanceColorPanelEditContext(
                    theme: .loud,
                    token: .background
                )
        )
        presenter.navigate(to: .stateColors)
        #expect(coordinator.activeContext == nil)

        presenter.openColorPanel(for: .surface)
        #expect(coordinator.activeContext?.token == .surface)
        appearance.select(.bold)
        #expect(coordinator.activeContext == nil)

        presenter.openColorPanel(for: .normal)
        #expect(coordinator.activeContext?.theme == .bold)
        presenter.close()
        #expect(coordinator.activeContext == nil)
    }

    @Test @MainActor
    func openingColorPanelWhileOverlayIsNotPresentedIsANoOp() {
        let suite = "MoreOverlayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = RecordingColorPanelCoordinator()
        let presenter = MoreOverlayPresenter(
            quotaStore: QuotaStore(defaults: defaults),
            appearanceStore: AppearanceStore(defaults: defaults),
            colorPanelCoordinator: coordinator
        )

        presenter.openColorPanel(for: .background)
        presenter.close()
        presenter.close()

        #expect(coordinator.beginCount == 0)
        #expect(coordinator.activeContext == nil)
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
        let appearance = AppearanceStore(defaults: defaults)
        let presenter = MoreOverlayPresenter(
            quotaStore: quota,
            appearanceStore: appearance
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
        #expect(orderedChildren[1] === pair.decoration)
        #expect(orderedChildren[2] === pair.hitShield)
        #expect(orderedChildren.last === pair.interaction)
        #expect(pair.interaction.parent === parent)
        #expect(pair.hitShield.parent === parent)
        #expect(pair.decoration.parent === parent)
        #expect(pair.interaction.level == parent.level)
        #expect(pair.hitShield.level == parent.level)
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
                candidateWindow: pair.hitShield,
                screenPoint: .zero
            ) == .hitShield
        )
        #expect(
            presenter.clickRole(
                candidateWindow: parent,
                screenPoint: NSPoint(
                    x: pair.interaction.frame.midX,
                    y: pair.interaction.frame.midY
                )
            ) == .visualShield
        )
        let shieldedScreenPoint = NSPoint(
            x: pair.interaction.frame.midX,
            y: pair.interaction.frame.midY
        )
        let shieldedClick = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: parent.convertPoint(
                    fromScreen: shieldedScreenPoint
                ),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: parent.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        #expect(presenter.handleLocalEvent(shieldedClick) == nil)
        #expect(presenter.isPresented)
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
        #expect(pair.interaction.hasNestedScrollView)
        #expect(
            pair.decoration.frame
                == pair.interaction.frame.insetBy(
                    dx: -MoreOverlayMetrics.shadowSafetyInset,
                    dy: -MoreOverlayMetrics.shadowSafetyInset
                )
        )
        #expect(
            pair.hitShield.frame
                == MoreOverlayMetrics.visualFrame(
                    around: pair.interaction.frame,
                    shadowInsets: AppearanceResolver.panel(
                        profile: appearance.currentProfile,
                        primaryRemainingPercent:
                            quota.snapshot.remainingPercent,
                        weeklyRemainingPercent:
                            quota.snapshot.weeklyRemainingPercent,
                        isUnavailable: quota.snapshot.isUnavailable
                    ).visuals.panelShell.shadow.visualInsets
                )
        )

        presenter.close()
        #expect(pair.interaction.parent == nil)
        #expect(pair.hitShield.parent == nil)
        #expect(pair.decoration.parent == nil)
        let remainingChildren = try #require(parent.childWindows)
        #expect(remainingChildren.count == 1)
        #expect(remainingChildren.first === mainShadow)

        presenter.present()
        let reused = try #require(presenter.ensureWindowPair())
        #expect(reused.interaction === pair.interaction)
        #expect(reused.hitShield === pair.hitShield)
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
        #expect(pair.hitShield.parent == nil)
        #expect(pair.decoration.parent == nil)
    }

    @Test @MainActor
    func liveAppearanceUpdatesPreserveTheHostedEditorRoot() async {
        let suite = "MoreOverlayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let appearance = AppearanceStore(defaults: defaults)
        let presenter = MoreOverlayPresenter(
            quotaStore: QuotaStore(defaults: defaults),
            appearanceStore: appearance
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
        presenter.navigate(to: .appearance)
        defer { presenter.close() }

        let replacements = presenter.interactionRootReplacementCount
        appearance.updateCurrent { profile in
            profile.geometry.cornerRadius += 1
        }
        await Task.yield()
        await Task.yield()

        #expect(
            presenter.interactionRootReplacementCount == replacements
        )
    }
}

private final class RecordingScrollView: NSScrollView {
    var didReceiveScrollWheel = false

    override func scrollWheel(with event: NSEvent) {
        didReceiveScrollWheel = true
    }
}
