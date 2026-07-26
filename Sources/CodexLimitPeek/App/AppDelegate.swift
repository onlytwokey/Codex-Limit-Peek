import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
#if DEVELOPER_TOOLS
    private let developerPreviewLaunchConfiguration:
        DeveloperPreviewLaunchConfiguration?
    private let developerPreviewLaunchError:
        DeveloperPreviewLaunchError?
    private var developerPreviewCoordinator:
        DeveloperPreviewCoordinator?
#endif
    private lazy var quotaStore = QuotaStore()
    private lazy var appearanceStore = AppearanceStore()
    private lazy var moreOverlayPresenter: MoreOverlayPresenter = {
#if DEVELOPER_TOOLS
        MoreOverlayPresenter(
            quotaStore: quotaStore,
            appearanceStore: appearanceStore,
            onOpenDeveloperPreview: { [weak self] in
                self?.showDeveloperPreview(
                    exitsWhenWindowCloses: false,
                    readinessFilePath: nil
                )
            }
        )
#else
        MoreOverlayPresenter(
            quotaStore: quotaStore,
            appearanceStore: appearanceStore
        )
#endif
    }()
    private var statusItem: NSStatusItem?
    private var statusRenderer: CompactStatusItemView?
    private var panelWindow: NSPanel?
    private var panelShadowWindow: NSPanel?
    private var outsideClickMonitor: Any?
    private var snapshotCancellable: AnyCancellable?
    private var productionRuntimeStarted = false

    override convenience init() {
        self.init(arguments: CommandLine.arguments)
    }

    init(arguments: [String]) {
#if DEVELOPER_TOOLS
        do {
            developerPreviewLaunchConfiguration = try
                DeveloperPreviewLaunchConfiguration.resolve(
                arguments: arguments
            )
            developerPreviewLaunchError = nil
        } catch let error as DeveloperPreviewLaunchError {
            developerPreviewLaunchConfiguration = nil
            developerPreviewLaunchError = error
        } catch {
            developerPreviewLaunchConfiguration = nil
            developerPreviewLaunchError = .unsupportedOption(
                error.localizedDescription
            )
        }
#endif
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEVELOPER_TOOLS
        if let developerPreviewLaunchError {
            writeDeveloperPreviewLaunchError(
                developerPreviewLaunchError
            )
            NSApp.terminate(nil)
            return
        }
#endif

        AppDefaultsIdentityMigration.migrateIfNeeded()
        NSApp.setActivationPolicy(.accessory)

#if DEVELOPER_TOOLS
        if let developerPreviewLaunchConfiguration {
            showDeveloperPreview(
                exitsWhenWindowCloses:
                    developerPreviewLaunchConfiguration
                        .exitsWhenWindowCloses,
                readinessFilePath:
                    developerPreviewLaunchConfiguration
                        .readinessFilePath
            )
            return
        }
#endif

        productionRuntimeStarted = true
        Task { @MainActor [weak self] in
            await Task.yield()
            guard
                let self,
                self.productionRuntimeStarted
            else {
                return
            }
            self.configureStatusItem()
        }
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
#if DEVELOPER_TOOLS
        developerPreviewCoordinator?.tearDown()
        developerPreviewCoordinator = nil
#endif

        guard productionRuntimeStarted else { return }
        moreOverlayPresenter.close()
        appearanceStore.flushPendingSave()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        stopOutsideClickMonitor()
    }

    private func configureStatusItem() {
        guard statusItem == nil else { return }

        let renderer = CompactStatusItemView()
        statusRenderer = renderer
        updateStatusItem(
            with: quotaStore.snapshot,
            health: quotaStore.refreshHealth
        )

        let initialLength = max(
            renderer.frame.width,
            NSStatusItem.squareLength
        )
        let item = NSStatusBar.system.statusItem(withLength: initialLength)
        statusItem = item
        guard let button = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
            statusRenderer = nil
            return
        }
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.isBordered = false
        button.target = self
        button.action = #selector(performStatusItemAction(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateStatusItem(with: quotaStore.snapshot, health: quotaStore.refreshHealth)
    }

    var isPanelWindowLoaded: Bool {
        panelWindow != nil
    }

    var isMoreOverlayWindowLoaded: Bool {
        guard productionRuntimeStarted else { return false }
        return moreOverlayPresenter.isWindowPairLoaded
    }

#if DEVELOPER_TOOLS
    var developerPreviewConfigurationForTesting:
        DeveloperPreviewLaunchConfiguration?
    {
        developerPreviewLaunchConfiguration
    }

    var developerPreviewLaunchErrorForTesting:
        DeveloperPreviewLaunchError?
    {
        developerPreviewLaunchError
    }

    var isDeveloperPreviewWindowLoaded: Bool {
        developerPreviewCoordinator?.isWindowLoaded ?? false
    }

    var isProductionRuntimeStartedForTesting: Bool {
        productionRuntimeStarted
    }

    func openDeveloperPreviewForTesting() {
        showDeveloperPreview(
            exitsWhenWindowCloses: false,
            readinessFilePath: nil
        )
    }

    func closeDeveloperPreviewForTesting() {
        developerPreviewCoordinator?.tearDown()
        developerPreviewCoordinator = nil
    }

    func configureStatusItemForTesting() {
        configureStatusItem()
    }

    var statusItemUsesButtonHostForTesting: Bool {
        guard
            let statusItem,
            let statusRenderer,
            let button = statusItem.button
        else {
            return false
        }
        return statusRenderer.superview == nil
            && button.target === self
            && button.action == #selector(performStatusItemAction(_:))
            && button.image?.isTemplate == false
            && (button.image?.size.width ?? 0) > 0
            && (button.image?.size.height ?? 0) > 0
    }

    var statusItemLengthForTesting: CGFloat? {
        statusItem?.length
    }

    var statusItemIdentityForTesting: ObjectIdentifier? {
        statusItem.map(ObjectIdentifier.init)
    }

    var statusItemIsVisibleForTesting: Bool {
        statusItem?.isVisible == true
    }

    var statusItemButtonHasWindowForTesting: Bool {
        statusItem?.button?.window != nil
    }

    var statusItemButtonHasImageForTesting: Bool {
        statusItem?.button?.image != nil
    }

    func removeStatusItemForTesting() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        statusRenderer = nil
    }
#endif

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
        panel.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.001)
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
        statusRenderer?.update(
            title: title,
            weeklyTitle: weeklyTitle,
            appearance: appearance,
            showsFailurePattern: isFailure,
            tooltip: tooltip
        )
        statusItem?.length = statusRenderer?.frame.width
            ?? NSStatusItem.variableLength
        if
            let statusRenderer,
            let button = statusItem?.button
        {
            button.image = statusRenderer.renderedStatusImage()
            button.toolTip = tooltip
            button.setAccessibilityLabel("Codex Limit Peek")
            button.setAccessibilityValue(
                [title, weeklyTitle]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " | ")
            )
            button.setAccessibilityHelp(tooltip)
        }
    }

    @objc private func performStatusItemAction(_ sender: NSStatusBarButton) {
        togglePanel()
    }

    private func togglePanel() {
        guard let statusButton = statusItem?.button else { return }
        let panelWindow = ensurePanelWindow()

        if panelWindow.isVisible {
            closePanel()
        } else {
            positionPanel(relativeTo: statusButton)
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
                let statusButton = self.statusItem?.button
            else {
                return
            }
            self.positionPanel(relativeTo: statusButton)
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

#if DEVELOPER_TOOLS
    private func showDeveloperPreview(
        exitsWhenWindowCloses: Bool,
        readinessFilePath: String?
    ) {
        if productionRuntimeStarted {
            closePanel()
            moreOverlayPresenter.close()
        }

        if let developerPreviewCoordinator {
            developerPreviewCoordinator.show()
            writeDeveloperPreviewReadinessFile(
                at: readinessFilePath
            )
            return
        }

        let coordinator = DeveloperPreviewCoordinator(
            onClose: { [weak self] in
                self?.developerPreviewCoordinator = nil
                if exitsWhenWindowCloses {
                    NSApplication.shared.terminate(nil)
                }
            }
        )
        developerPreviewCoordinator = coordinator
        coordinator.show()
        writeDeveloperPreviewReadinessFile(at: readinessFilePath)
    }

    private func writeDeveloperPreviewReadinessFile(
        at path: String?
    ) {
        guard let path else { return }

        do {
            try Data("ready\n".utf8).write(
                to: URL(fileURLWithPath: path),
                options: .withoutOverwriting
            )
        } catch {
            let message = "Codex Limit Peek could not signal developer "
                + "preview readiness: \(error)\n"
            FileHandle.standardError.write(Data(message.utf8))
            NSApplication.shared.terminate(nil)
        }
    }

    private func writeDeveloperPreviewLaunchError(
        _ error: DeveloperPreviewLaunchError
    ) {
        let message = "Codex Limit Peek developer launch failed: \(error)\n"
        FileHandle.standardError.write(Data(message.utf8))
    }
#endif

    @objc private func refreshAfterSleepOrUnlock(_ notification: Notification) {
        quotaStore.refresh()
    }
}
