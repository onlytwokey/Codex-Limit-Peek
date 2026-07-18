import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let quotaStore = QuotaStore()
    private let appearanceStore = AppearanceStore()
    private lazy var moreOverlayPresenter = MoreOverlayPresenter(
        quotaStore: quotaStore,
        appearanceStore: appearanceStore
    )
    private var statusItem: NSStatusItem?
    private var statusView: CompactStatusItemView?
    private var panelWindow: NSPanel?
    private var panelShadowWindow: NSPanel?
    private var outsideClickMonitor: Any?
    private var snapshotCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureWakeRefreshObservers()
        quotaStore.start()

        snapshotCancellable = Publishers.CombineLatest3(
            quotaStore.$snapshot,
            quotaStore.$refreshHealth,
            appearanceStore.$revision
        ).sink { [weak self] snapshot, health, _ in
            self?.updateStatusItem(with: snapshot, health: health)
            self?.scheduleVisiblePanelReposition()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        moreOverlayPresenter.close()
        appearanceStore.flushPendingSave()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        stopOutsideClickMonitor()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        let view = CompactStatusItemView()
        view.onClick = { [weak self] in
            self?.togglePanel()
        }
        item.view = view
        statusView = view

        updateStatusItem(with: quotaStore.snapshot, health: quotaStore.refreshHealth)
    }

    var isPanelWindowLoaded: Bool {
        panelWindow != nil
    }

    var isMoreOverlayWindowLoaded: Bool {
        moreOverlayPresenter.isWindowPairLoaded
    }

    var moreOverlayPageForTesting: MoreOverlayPage {
        moreOverlayPresenter.page
    }

    func setMoreOverlayPageForTesting(_ page: MoreOverlayPage) {
        moreOverlayPresenter.navigate(to: page)
    }

    func closePanelForTesting() {
        closePanel()
    }

    @discardableResult
    func ensurePanelWindow() -> NSPanel {
        if let panelWindow {
            return panelWindow
        }

        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PanelMetrics.cardWidth,
                height: PanelMetrics.cardHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = NSHostingController(
            rootView: StatusPanelView(
                store: quotaStore,
                appearanceStore: appearanceStore,
                moreOverlayPresenter: moreOverlayPresenter
            )
                .frame(
                    width: PanelMetrics.cardWidth,
                    height: PanelMetrics.cardHeight
                )
        )

        let shadowPanel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PanelMetrics.shadowWidth,
                height: PanelMetrics.shadowHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        shadowPanel.backgroundColor = .clear
        shadowPanel.isOpaque = false
        shadowPanel.hasShadow = false
        shadowPanel.hidesOnDeactivate = false
        shadowPanel.ignoresMouseEvents = true
        shadowPanel.level = .popUpMenu
        shadowPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        shadowPanel.contentViewController = NSHostingController(
            rootView: StatusPanelShadowView(
                store: quotaStore,
                appearanceStore: appearanceStore
            )
            .frame(
                width: PanelMetrics.shadowWidth,
                height: PanelMetrics.shadowHeight
            )
        )

        panelWindow = panel
        panelShadowWindow = shadowPanel
        panel.addChildWindow(shadowPanel, ordered: .below)
        moreOverlayPresenter.attach(to: panel)
        return panel
    }

    private func configureWakeRefreshObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(refreshAfterSleepOrUnlock),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(refreshAfterSleepOrUnlock),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(refreshAfterSleepOrUnlock),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }

    private func updateStatusItem(with snapshot: QuotaSnapshot, health: RefreshHealth) {
        let title = snapshot.menuBarTitle
        let weeklyTitle = snapshot.menuBarTrailingTitle
        let isFailure = health.showsFailurePattern
        let appearance = AppearanceResolver.status(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent: snapshot.remainingPercent,
            weeklyRemainingPercent: snapshot.weeklyRemainingPercent,
            isUnavailable: snapshot.isUnavailable,
            showsFailurePattern: isFailure
        )
        .fitted(to: Double(NSStatusBar.system.thickness))
        let healthText = QuotaStatusFormatter.header(
            snapshot: snapshot,
            health: health,
            confirmationAttempt: quotaStore.confirmationAttempt
        )
        var tooltip: String
        if snapshot.isUnavailable {
            tooltip = healthText
        } else if isFailure {
            tooltip = "\(healthText)\n当前显示最近一次可用额度"
        } else if health == .confirmingFailure {
            tooltip = "\(healthText)\n当前继续显示最后一次可靠额度"
        } else if snapshot.displayMode == .weeklyOnly {
            tooltip = "周额度剩余 \(snapshot.remainingPercent)% ，\(snapshot.primaryResetDateText)"
        } else {
            tooltip = "5h 额度剩余 \(snapshot.remainingPercent)% ，距离额度恢复 \(snapshot.resetText)\n周额度剩余 \(snapshot.weeklyRemainingPercent)% ，\(snapshot.weeklyResetDateText)"
        }
        if health != .live, let failure = quotaStore.lastFailureCategory {
            tooltip += "\n原因：\(failure.displayText)"
        }
        statusView?.update(
            title: title,
            weeklyTitle: weeklyTitle,
            appearance: appearance,
            showsFailurePattern: isFailure,
            tooltip: tooltip
        )
        statusItem?.length = statusView?.frame.width ?? NSStatusItem.variableLength
    }

    private func togglePanel() {
        guard let statusView else { return }
        let panelWindow = ensurePanelWindow()

        if panelWindow.isVisible {
            closePanel()
        } else {
            positionPanel(relativeTo: statusView)
            if
                let panelShadowWindow,
                panelShadowWindow.parent !== panelWindow
            {
                panelWindow.addChildWindow(
                    panelShadowWindow,
                    ordered: .below
                )
            }
            panelWindow.orderFrontRegardless()
            startOutsideClickMonitor()
            quotaStore.refresh(force: false)
        }
    }

    private func closePanel() {
        moreOverlayPresenter.close()
        panelWindow?.orderOut(nil)
        stopOutsideClickMonitor()
    }

    private func scheduleVisiblePanelReposition() {
        guard panelWindow?.isVisible == true else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            guard
                let self,
                self.panelWindow?.isVisible == true,
                let statusView = self.statusView
            else {
                return
            }
            self.positionPanel(relativeTo: statusView)
        }
    }

    private func positionPanel(relativeTo anchorView: NSView) {
        guard let window = anchorView.window else { return }
        let anchorRectInWindow = anchorView.convert(anchorView.bounds, to: nil)
        let anchorRect = window.convertToScreen(anchorRectInWindow)
        let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let panelAppearance = AppearanceResolver.panel(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent: quotaStore.snapshot.remainingPercent,
            weeklyRemainingPercent: quotaStore.snapshot.weeklyRemainingPercent,
            isUnavailable: quotaStore.snapshot.isUnavailable
        )
        let shadowInsets = panelAppearance.visuals.panelShell.shadow.visualInsets
        let contentFrame = PanelMetrics.contentFrame(
            relativeTo: anchorRect,
            within: visibleFrame,
            shadowInsets: shadowInsets
        )
        panelWindow?.setFrame(contentFrame, display: true)
        panelShadowWindow?.setFrame(
            PanelMetrics.shadowFrame(around: contentFrame),
            display: true
        )
        moreOverlayPresenter.reposition()
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                guard
                    let self,
                    self.moreOverlayPresenter
                        .shouldDismissForGlobalOutsideClick
                else {
                    return
                }
                self.closePanel()
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    @objc private func refreshAfterSleepOrUnlock(_ notification: Notification) {
        quotaStore.refresh()
    }
}
