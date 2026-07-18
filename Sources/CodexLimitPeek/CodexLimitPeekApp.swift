import AppKit
import AVFoundation
import Combine
import SwiftUI
import UserNotifications

@main
struct CodexLimitPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

enum PanelMetrics {
    static let cardWidth = ThemePanelLayout.width
    static let cardHeight = ThemePanelLayout.height
    static let shadowInset = ThemePanelLayout.shadowSafetyInset
    static let shadowWidth: CGFloat = cardWidth + shadowInset * 2
    static let shadowHeight: CGFloat = cardHeight + shadowInset * 2
    static let verticalGap: CGFloat = 14
    static let screenPadding: CGFloat = 8

    static func contentFrame(
        relativeTo anchorRect: NSRect,
        within visibleFrame: NSRect,
        shadowInsets: EdgeInsets
    ) -> NSRect {
        let proposedX = anchorRect.midX - cardWidth / 2
        let minimumX = visibleFrame.minX
            + screenPadding
            + shadowInsets.leading
        let maximumX = max(
            minimumX,
            visibleFrame.maxX
                - cardWidth
                - screenPadding
                - shadowInsets.trailing
        )
        let x = min(
            max(proposedX, minimumX),
            maximumX
        )
        let minimumY = visibleFrame.minY
            + screenPadding
            + shadowInsets.bottom
        let maximumY = min(
            anchorRect.minY - cardHeight - verticalGap,
            visibleFrame.maxY
                - cardHeight
                - screenPadding
                - shadowInsets.top
        )
        let y = max(minimumY, maximumY)
        return NSRect(
            x: x,
            y: y,
            width: cardWidth,
            height: cardHeight
        )
    }

    static func shadowFrame(
        around contentFrame: NSRect
    ) -> NSRect {
        contentFrame.insetBy(dx: -shadowInset, dy: -shadowInset)
    }

    static func visualFrame(
        around contentFrame: NSRect,
        shadowInsets: EdgeInsets
    ) -> NSRect {
        NSRect(
            x: contentFrame.minX - shadowInsets.leading,
            y: contentFrame.minY - shadowInsets.bottom,
            width: contentFrame.width
                + shadowInsets.leading
                + shadowInsets.trailing,
            height: contentFrame.height
                + shadowInsets.top
                + shadowInsets.bottom
        )
    }
}

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

final class CompactStatusItemView: NSView {
    var onClick: (() -> Void)?

    private var title = ""
    private var weeklyTitle: String?
    private var resolvedAppearance = AppearanceResolver.status(
        profile: .default(for: .loud),
        primaryRemainingPercent: 100,
        weeklyRemainingPercent: 100,
        isUnavailable: false,
        showsFailurePattern: false
    )
    private var showsFailurePattern = false

    private var horizontalPadding: CGFloat {
        CGFloat(resolvedAppearance.horizontalPadding)
    }

    func update(
        title: String,
        weeklyTitle: String?,
        appearance: ResolvedStatusItemAppearance,
        showsFailurePattern: Bool,
        tooltip: String,
        statusBarThickness: CGFloat = NSStatusBar.system.thickness
    ) {
        self.title = title
        self.weeklyTitle = weeklyTitle
        resolvedAppearance = appearance
        self.showsFailurePattern = showsFailurePattern
        self.toolTip = tooltip
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Codex Limit Peek")
        setAccessibilityValue(
            [title, weeklyTitle]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " | ")
        )
        setAccessibilityHelp(tooltip)

        let chromeWidth = CGFloat(
            appearance.outlineWidth * 2
                + appearance.shadowDepth
                + appearance.shadowBlur * 2
        )
        let width = ceil(
            attributedTitle.size().width
                + horizontalPadding * 2
                + chromeWidth
        )
        frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: statusBarThickness
        )
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let size = attributedTitle.size()
        let outlineWidth = CGFloat(resolvedAppearance.outlineWidth)
        let shadowDepth = CGFloat(resolvedAppearance.shadowDepth)
        let shadowBlur = CGFloat(resolvedAppearance.shadowBlur)
        let cornerRadius = CGFloat(resolvedAppearance.cornerRadius)
        let availableHeight = max(
            8,
            bounds.height - shadowDepth - shadowBlur * 2 - 1
        )
        let tagHeight = min(
            CGFloat(resolvedAppearance.tagHeight),
            availableHeight
        )
        let drawableHeight = max(1, bounds.height - shadowBlur * 2)
        let tagRect = NSRect(
            x: shadowBlur + outlineWidth / 2,
            y: shadowBlur
                + floor(
                    (drawableHeight - tagHeight + shadowDepth) / 2
                ),
            width: max(
                1,
                bounds.width
                    - shadowDepth
                    - outlineWidth
                    - shadowBlur * 2
            ),
            height: tagHeight
        )
        let tagPath = NSBezierPath(
            roundedRect: tagRect,
            xRadius: min(cornerRadius, tagHeight / 2),
            yRadius: min(cornerRadius, tagHeight / 2)
        )

        NSGraphicsContext.saveGraphicsState()
        if shadowDepth > 0 || shadowBlur > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = resolvedAppearance.outlineColor.nsColor
                .withAlphaComponent(
                    CGFloat(resolvedAppearance.shadowOpacity)
                )
            shadow.shadowOffset = NSSize(width: shadowDepth, height: -shadowDepth)
            shadow.shadowBlurRadius = shadowBlur
            shadow.set()
        }
        let baseFill = showsFailurePattern
            ? resolvedAppearance.unavailableBaseColor.nsColor
            : resolvedAppearance.fillColor.nsColor
        baseFill.setFill()
        tagPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        if showsFailurePattern {
            drawFailurePattern(in: tagRect, clippedBy: tagPath)
        }

        if outlineWidth > 0 {
            resolvedAppearance.outlineColor.nsColor.setStroke()
            tagPath.lineWidth = outlineWidth
            tagPath.stroke()
        }

        let rect = NSRect(
            x: shadowBlur + horizontalPadding + outlineWidth,
            y: floor(tagRect.midY - size.height / 2),
            width: size.width,
            height: size.height
        )
        attributedTitle.draw(in: rect)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onClick?()
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    private func drawFailurePattern(in tagRect: NSRect, clippedBy tagPath: NSBezierPath) {
        NSGraphicsContext.saveGraphicsState()
        tagPath.addClip()
        resolvedAppearance.unavailableBaseColor.nsColor.setFill()
        tagPath.fill()
        resolvedAppearance.unavailableStripeColor.nsColor
            .withAlphaComponent(0.78)
            .setStroke()
        for x in stride(from: tagRect.minX - tagRect.height, through: tagRect.maxX, by: 7) {
            let stripe = NSBezierPath()
            stripe.lineWidth = 2
            stripe.move(to: NSPoint(x: x, y: tagRect.minY))
            stripe.line(to: NSPoint(x: x + tagRect.height, y: tagRect.maxY))
            stripe.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private var attributedTitle: NSAttributedString {
        let font = resolvedStatusFont
        let primaryAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: resolvedAppearance.primaryTextColor.nsColor,
            .kern: -0.2
        ]
        let renderedTitle = NSMutableAttributedString(
            string: title,
            attributes: primaryAttributes
        )

        if let weeklyTitle, !weeklyTitle.isEmpty {
            renderedTitle.append(NSAttributedString(string: " | ", attributes: primaryAttributes))
            renderedTitle.append(
                NSAttributedString(
                    string: weeklyTitle,
                    attributes: [
                        .font: font,
                        .foregroundColor: resolvedAppearance.weeklyTextColor.nsColor,
                        .kern: -0.2
                    ]
                )
            )
        }

        return renderedTitle
    }

    private var resolvedStatusFont: NSFont {
        let size = CGFloat(resolvedAppearance.fontSize)
        let weight: NSFont.Weight = switch resolvedAppearance.fontWeight {
        case .semibold:
            .semibold
        case .bold:
            .bold
        case .heavy:
            .heavy
        case .black:
            .black
        }

        switch resolvedAppearance.fontFamily {
        case .monospaced:
            return NSFont.monospacedSystemFont(
                ofSize: size,
                weight: weight
            )
        case .rounded:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            guard
                let descriptor = base.fontDescriptor.withDesign(.rounded),
                let rounded = NSFont(
                    descriptor: descriptor,
                    size: size
                )
            else {
                return base
            }
            return rounded
        case .system:
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }
}

struct StatusPanelView: View {
    @ObservedObject var store: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    @ObservedObject var moreOverlayPresenter: MoreOverlayPresenter

    private var appearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent: store.snapshot.remainingPercent,
            weeklyRemainingPercent: store.snapshot.weeklyRemainingPercent,
            isUnavailable: store.snapshot.isUnavailable
        )
    }

    var body: some View {
        ThemePanelComposition(
            appearance: appearance,
            data: displayData,
            headerForeground: (
                store.refreshHealth.showsFailurePattern
                    ? appearance.unavailableStripeColor
                    : appearance.backgroundTextColor
            ).swiftUIColor,
            showsOuterChrome: false
        ) {
            HStack(spacing: 8) {
                RefreshIconButton(appearance: appearance) {
                    store.refresh()
                }

                MoreActionsMenu(
                    store: store,
                    appearanceStore: appearanceStore,
                    appearance: appearance,
                    moreOverlayPresenter: moreOverlayPresenter
                )
            }
        }
        .frame(
            width: PanelMetrics.cardWidth,
            height: PanelMetrics.cardHeight
        )
    }

    private var headerText: String {
        QuotaStatusFormatter.header(
            snapshot: store.snapshot,
            health: store.refreshHealth,
            confirmationAttempt: store.confirmationAttempt
        )
    }

    private var displayData: ThemePanelDisplayData {
        ThemePanelDisplayData(
            headerText: headerText,
            percentText: store.snapshot.percentText,
            primaryQuotaLabel: store.snapshot.primaryQuotaLabel,
            shortResetText: store.snapshot.shortResetText,
            primaryResetDetailText: store.snapshot.primaryResetDetailText,
            displayRemainingPercent: store.snapshot.displayRemainingPercent,
            showsSecondaryQuota: store.snapshot.showsSecondaryQuota,
            weeklyPercentText: store.snapshot.weeklyPercentText,
            weeklyResetDateText: store.snapshot.weeklyResetDateText
        )
    }
}

struct StatusPanelShadowView: View {
    @ObservedObject var store: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore

    private var appearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent: store.snapshot.remainingPercent,
            weeklyRemainingPercent: store.snapshot.weeklyRemainingPercent,
            isUnavailable: store.snapshot.isUnavailable
        )
    }

    var body: some View {
        PanelGlassBackground(appearance: appearance)
            .frame(
                width: PanelMetrics.cardWidth,
                height: PanelMetrics.cardHeight
            )
            .padding(PanelMetrics.shadowInset)
            .frame(
                width: PanelMetrics.shadowWidth,
                height: PanelMetrics.shadowHeight
            )
    }
}

struct PanelGlassBackground: View {
    let appearance: ResolvedPanelAppearance
    var includesShadow = true

    private var shell: ThemeChromeRecipe {
        var shell = appearance.visuals.panelShell
        if !includesShadow {
            shell.shadow = .none
        }
        return shell
    }

    var body: some View {
        ThemeSurfaceBackground(
            appearance: appearance,
            chrome: shell,
            fill: appearance.backgroundColor,
            fillStyle: appearance.visuals.panelFill,
            gradientEnd: appearance.panelGradientEndColor,
            rendersHardShadowExplicitly: includesShadow
        )
    }
}

private extension View {
    func themedIconSurface(
        _ appearance: ResolvedPanelAppearance,
        isPressed: Bool,
        isHovered: Bool
    ) -> some View {
        var chrome = appearance.visuals.actionButton
        if isPressed {
            chrome.shadow = .none
        }
        return themeSurface(
            appearance: appearance,
            chrome: chrome,
            fill: appearance.actionAccentColor
        )
            .offset(y: isPressed ? 1 : (isHovered ? -0.5 : 0))
    }
}

struct RefreshIconButton: View {
    let appearance: ResolvedPanelAppearance
    let action: () -> Void
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            PanelIconFrame(
                systemImage: "arrow.clockwise",
                appearance: appearance,
                isPressed: isPressed,
                isHovered: isHovered
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.08)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isPressed == false {
                        withAnimation(.easeOut(duration: 0.035)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.72)) {
                        isPressed = false
                    }
                }
        )
        .help("刷新")
    }
}

struct PanelIconFrame: View {
    let systemImage: String
    let appearance: ResolvedPanelAppearance
    var isPressed = false
    var isHovered = false

    var body: some View {
        Image(systemName: systemImage)
            .font(
                .system(
                    size: CGFloat(
                        ThemePanelLayout.actionIconSize
                            * appearance.geometry.fontScale
                    ),
                    weight: .black
                )
            )
            .frame(
                width: ThemePanelLayout.actionSize,
                height: ThemePanelLayout.actionSize
            )
            .contentShape(Rectangle())
            .foregroundStyle(
                appearance.outlineColor.readable(
                    on: appearance.actionAccentColor
                        .composited(over: appearance.backgroundColor)
                        .composited(over: .white)
                ).swiftUIColor
            )
            .themedIconSurface(
                appearance,
                isPressed: isPressed,
                isHovered: isHovered
            )
    }
}

struct MoreActionsMenu: View {
    @ObservedObject var store: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    let appearance: ResolvedPanelAppearance
    @ObservedObject var moreOverlayPresenter: MoreOverlayPresenter
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button {
            moreOverlayPresenter.toggle()
        } label: {
            PanelIconFrame(
                systemImage: "ellipsis",
                appearance: appearance,
                isPressed:
                    isPressed || moreOverlayPresenter.isPresented,
                isHovered:
                    isHovered || moreOverlayPresenter.isPresented
            )
        }
        .buttonStyle(.plain)
        .background {
            MoreOverlayAnchorReader { anchor in
                moreOverlayPresenter.setAnchorView(anchor)
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.08)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isPressed == false {
                        withAnimation(.easeOut(duration: 0.035)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.72)) {
                        isPressed = false
                    }
                }
        )
        .help("更多")
        .accessibilityLabel("更多")
    }
}

struct ActionsPopover: View {
    @ObservedObject var store: QuotaStore
    @ObservedObject var appearanceStore: AppearanceStore
    let appearance: ResolvedPanelAppearance
    let onShowAppearance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                store.toggleVoiceBroadcast()
            } label: {
                ActionMenuRow(
                    systemImage: store.voiceBroadcastEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    title: store.voiceBroadcastEnabled ? "关闭播报" : "开启播报",
                    trailing: store.voiceBroadcastEnabled ? nil : "\(store.voiceBroadcastIntervalMinutes) 分钟",
                    appearance: appearance
                )
            }
            .buttonStyle(.plain)

            if store.voiceBroadcastEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("播报间隔")
                        .font(
                            .system(
                                size: CGFloat(
                                    11 * appearance.geometry.fontScale
                                ),
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            appearance.backgroundTextColor.swiftUIColor
                                .opacity(0.72)
                        )
                        .padding(.horizontal, 6)

                    BroadcastIntervalButton(
                        minutes: 1,
                        store: store,
                        appearance: appearance
                    )
                    BroadcastIntervalButton(
                        minutes: 5,
                        store: store,
                        appearance: appearance
                    )
                    BroadcastIntervalButton(
                        minutes: 10,
                        store: store,
                        appearance: appearance
                    )
                }
            }

            Divider()

            Button {
                withAnimation(.easeOut(duration: 0.12)) {
                    onShowAppearance()
                }
            } label: {
                ActionMenuRow(
                    systemImage: "paintpalette.fill",
                    title: "外观",
                    trailing: appearanceStore.selectedTheme.displayName,
                    appearance: appearance
                )
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                ActionMenuRow(
                    systemImage: "power",
                    title: "退出应用",
                    trailing: nil,
                    appearance: appearance
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
    }
}

struct BroadcastIntervalButton: View {
    let minutes: Int
    @ObservedObject var store: QuotaStore
    let appearance: ResolvedPanelAppearance

    var body: some View {
        Button {
            store.setVoiceBroadcastInterval(minutes: minutes)
        } label: {
            ActionMenuRow(
                systemImage: store.voiceBroadcastIntervalMinutes == minutes ? "checkmark.circle.fill" : "circle",
                title: "\(minutes) 分钟",
                trailing: nil,
                appearance: appearance
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActionMenuRow: View {
    let systemImage: String
    let title: String
    let trailing: String?
    let appearance: ResolvedPanelAppearance

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(
                    .system(
                        size: CGFloat(
                            13 * appearance.geometry.fontScale
                        ),
                        weight: .bold
                    )
                )
                .frame(width: 18)
            Text(title)
                .font(
                    .system(
                        size: CGFloat(
                            13 * appearance.geometry.fontScale
                        ),
                        weight: .semibold
                    )
                )
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(
                        .system(
                            size: CGFloat(
                                11 * appearance.geometry.fontScale
                            ),
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        appearance.textColor.swiftUIColor.opacity(0.72)
                    )
            }
        }
        .foregroundStyle(appearance.textColor.swiftUIColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .themeSurface(
            appearance: appearance,
            chrome: appearance.visuals.menuRow,
            fill: appearance.surfaceColor
        )
    }
}

@MainActor
final class QuotaStore: ObservableObject {
    @Published var snapshot: QuotaSnapshot
    @Published private(set) var refreshHealth: RefreshHealth
    @Published private(set) var confirmationAttempt = 0
    @Published private(set) var lastFailureCategory: RefreshFailureCategory?
    @Published var voiceBroadcastEnabled = false
    @Published var voiceBroadcastIntervalMinutes: Int

    private var timer: Timer?
    private var voiceTimer: Timer?
    private var hasStarted = false
    private var lastRefreshStartedAt: Date?
    private var pendingRefreshTask: Task<Void, Never>?
    private var pendingRefreshIsForced = false
    private var failureRetryTask: Task<Void, Never>?
    private var failureTracker = RefreshFailureTracker()
    private(set) var isRefreshing = false
    private(set) var speakAfterRefresh = false
    private let refreshQueue = DispatchQueue(label: "io.github.onlytwokey.CodexLimitPeek.refresh", qos: .utility)
    private(set) var speechSynthesizer: AVSpeechSynthesizer?
    private var notifiedLevels = Set<Int>()
    private let provider: QuotaProvider
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let monotonicNow: @Sendable () -> TimeInterval
    private let minimumRefreshInterval: TimeInterval
    private let sleep: @Sendable (TimeInterval) async -> Void

    init(
        provider: QuotaProvider = CompositeQuotaProvider(),
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() },
        monotonicNow: @escaping @Sendable () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        },
        minimumRefreshInterval: TimeInterval = 10,
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            try? await Task.sleep(for: .seconds(delay))
        }
    ) {
        self.provider = provider
        self.defaults = defaults
        self.now = now
        self.monotonicNow = monotonicNow
        self.minimumRefreshInterval = max(0, minimumRefreshInterval)
        self.sleep = sleep
        if let cached = QuotaSnapshot.cached(defaults: defaults) {
            self.snapshot = cached
        } else {
            self.snapshot = QuotaSnapshot.unavailable()
        }
        self.refreshHealth = .confirmingFailure
        self.lastFailureCategory = defaults.string(forKey: CacheKey.lastFailureCategory)
            .flatMap(RefreshFailureCategory.init(rawValue:))
        let savedInterval = defaults.integer(forKey: CacheKey.voiceBroadcastIntervalMinutes)
        self.voiceBroadcastIntervalMinutes = Self.allowedVoiceBroadcastIntervals.contains(savedInterval) ? savedInterval : 1
    }

    func start(requestNotificationPermission: Bool = true) {
        guard !hasStarted else { return }
        hasStarted = true
        timer = Timer.scheduledTimer(withTimeInterval: Self.automaticRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        refresh(bypassCooldown: true)
        if requestNotificationPermission {
            self.requestNotificationPermission()
        }
    }

    func refresh(force: Bool = true, bypassCooldown: Bool = false) {
        guard isRefreshing == false else { return }

        if !force, canReuseRecentLiveSnapshot {
            handleReusedSnapshot()
            return
        }

        if !bypassCooldown, let delay = refreshCooldownDelay {
            scheduleRefresh(force: force, after: delay)
            return
        }

        cancelPendingRefresh()
        beginRefresh()
    }

    private func beginRefresh() {
        cancelFailureRetry()
        isRefreshing = true
        lastRefreshStartedAt = now()
        let provider = provider

        refreshQueue.async { [weak self] in
            let result = provider.refresh()

            DispatchQueue.main.async {
                guard let self else { return }
                let shouldSpeak = self.speakAfterRefresh
                self.speakAfterRefresh = false
                if result.isLive, let refreshed = result.snapshot {
                    self.handleLiveSuccess(refreshed)
                } else {
                    self.handleLiveFailure(result)
                }
                self.isRefreshing = false
                self.evaluateNotifications()
                if shouldSpeak, self.voiceBroadcastEnabled {
                    self.speak(self.snapshot)
                }
            }
        }
    }

    private func handleLiveSuccess(_ refreshed: QuotaSnapshot) {
        snapshot = refreshed
        refreshed.cache(defaults: defaults)
        failureTracker.recordLiveSuccess()
        confirmationAttempt = 0
        lastFailureCategory = nil
        refreshHealth = .live
        cancelFailureRetry()
        defaults.set(0, forKey: CacheKey.consecutiveFailures)
        if hasStarted {
            timer?.fireDate = Date().addingTimeInterval(Self.automaticRefreshInterval)
        }
    }

    private func handleLiveFailure(_ result: QuotaRefreshResult) {
        let failure = result.failure ?? .unknown
        let decision = failureTracker.recordFailure(failure, at: monotonicNow())
        lastFailureCategory = failure
        persistFailureDiagnostic(failure)
        timer?.fireDate = .distantFuture

        switch decision {
        case let .confirming(attempt, retryAfter):
            confirmationAttempt = attempt
            refreshHealth = .confirmingFailure
            if snapshot.isUnavailable, let local = result.snapshot {
                snapshot = local
                local.cache(defaults: defaults)
            }
            scheduleFailureRetry(after: retryAfter)

        case let .confirmed(retryAfter):
            confirmationAttempt = 0
            if let local = result.snapshot {
                snapshot = local
                local.cache(defaults: defaults)
            }
            refreshHealth = snapshot.isUnavailable ? .unavailable : .degraded
            scheduleFailureRetry(after: retryAfter)
        }
    }

    private func scheduleFailureRetry(after delay: TimeInterval) {
        guard hasStarted else { return }
        cancelFailureRetry()
        let sleepOperation = sleep
        failureRetryTask = Task { @MainActor [weak self] in
            await sleepOperation(delay)
            guard !Task.isCancelled, let self else { return }
            self.failureRetryTask = nil
            self.refresh(force: true)
        }
    }

    private func cancelFailureRetry() {
        failureRetryTask?.cancel()
        failureRetryTask = nil
    }

    private func persistFailureDiagnostic(_ failure: RefreshFailureCategory) {
        defaults.set(failure.rawValue, forKey: CacheKey.lastFailureCategory)
        defaults.set(now().timeIntervalSince1970, forKey: CacheKey.lastFailureAt)
        defaults.set(
            failureTracker.consecutiveFailures,
            forKey: CacheKey.consecutiveFailures
        )
    }

    private var refreshCooldownDelay: TimeInterval? {
        guard minimumRefreshInterval > 0, let lastRefreshStartedAt else { return nil }
        let elapsed = now().timeIntervalSince(lastRefreshStartedAt)
        guard elapsed < minimumRefreshInterval else { return nil }
        return elapsed < 0 ? minimumRefreshInterval : minimumRefreshInterval - elapsed
    }

    private func scheduleRefresh(force: Bool, after delay: TimeInterval) {
        pendingRefreshIsForced = pendingRefreshIsForced || force
        guard pendingRefreshTask == nil else { return }
        let sleepOperation = sleep
        pendingRefreshTask = Task { @MainActor [weak self] in
            await sleepOperation(delay)
            guard !Task.isCancelled, let self else { return }
            self.runPendingRefresh()
        }
    }

    private func runPendingRefresh() {
        let force = pendingRefreshIsForced
        pendingRefreshTask = nil
        pendingRefreshIsForced = false

        if !force, canReuseRecentLiveSnapshot {
            handleReusedSnapshot()
            return
        }
        guard !isRefreshing else { return }
        beginRefresh()
    }

    private func cancelPendingRefresh() {
        pendingRefreshTask?.cancel()
        pendingRefreshTask = nil
        pendingRefreshIsForced = false
    }

    private func handleReusedSnapshot() {
        let shouldSpeak = speakAfterRefresh
        speakAfterRefresh = false
        if shouldSpeak, voiceBroadcastEnabled {
            speak(snapshot)
        }
    }

    deinit {
        pendingRefreshTask?.cancel()
        failureRetryTask?.cancel()
    }

    func toggleVoiceBroadcast() {
        if voiceBroadcastEnabled {
            stopVoiceBroadcast()
        } else {
            startVoiceBroadcast()
        }
    }

    private func startVoiceBroadcast() {
        voiceBroadcastEnabled = true
        requestVoiceBroadcast()
        scheduleVoiceTimer()
    }

    private func scheduleVoiceTimer() {
        voiceTimer?.invalidate()
        voiceTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(voiceBroadcastIntervalMinutes * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.requestVoiceBroadcast()
            }
        }
    }

    private func stopVoiceBroadcast() {
        voiceBroadcastEnabled = false
        speakAfterRefresh = false
        voiceTimer?.invalidate()
        voiceTimer = nil
        speechSynthesizer?.stopSpeaking(at: .immediate)
    }

    func setVoiceBroadcastInterval(minutes: Int) {
        guard Self.allowedVoiceBroadcastIntervals.contains(minutes) else { return }
        voiceBroadcastIntervalMinutes = minutes
        defaults.set(minutes, forKey: CacheKey.voiceBroadcastIntervalMinutes)
        if voiceBroadcastEnabled {
            scheduleVoiceTimer()
        }
    }

    private func requestVoiceBroadcast() {
        speakAfterRefresh = true
        refresh(force: false)
    }

    private var canReuseRecentLiveSnapshot: Bool {
        guard refreshHealth == .live, !snapshot.isUnavailable else { return false }
        let age = now().timeIntervalSince(snapshot.lastUpdated)
        return age >= 0 && age < Self.recentLiveReuseInterval
    }

    private func speak(_ snapshot: QuotaSnapshot) {
        guard !snapshot.isUnavailable else { return }
        let utterance = AVSpeechUtterance(string: snapshot.voiceBroadcastText)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.48
        let synthesizer = speechSynthesizer ?? AVSpeechSynthesizer()
        speechSynthesizer = synthesizer
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    private func evaluateNotifications() {
        guard !snapshot.isUnavailable else { return }
        let remaining = snapshot.remainingPercent
        let quotaName = snapshot.notificationQuotaName

        if remaining <= 10 {
            notifyOnce(level: 10, title: "Codex 额度接近耗尽", body: "当前 \(quotaName) 剩余 \(remaining)%，建议放慢高消耗任务。")
        } else if remaining <= 20 {
            notifyOnce(level: 20, title: "Codex 额度偏低", body: "当前 \(quotaName) 剩余 \(remaining)%，距离额度恢复 \(snapshot.resetText)。")
        }
    }

    private func notifyOnce(level: Int, title: String, body: String) {
        guard notifiedLevels.insert(level).inserted else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codex-limit-peek-\(level)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static let automaticRefreshInterval: TimeInterval = 5 * 60
    private static let recentLiveReuseInterval: TimeInterval = 60
    private static let allowedVoiceBroadcastIntervals = [1, 5, 10]
}

enum RefreshHealth: Sendable, Equatable {
    case live
    case confirmingFailure
    case degraded
    case unavailable

    var showsFailurePattern: Bool {
        self == .degraded || self == .unavailable
    }
}

struct QuotaRefreshResult: Sendable {
    let snapshot: QuotaSnapshot?
    let health: RefreshHealth
    let failure: RefreshFailureCategory?

    static func live(_ snapshot: QuotaSnapshot) -> Self {
        Self(snapshot: snapshot, health: .live, failure: nil)
    }

    static func degraded(
        _ snapshot: QuotaSnapshot?,
        failure: RefreshFailureCategory = .unknown
    ) -> Self {
        Self(snapshot: snapshot, health: .degraded, failure: failure)
    }

    static let unavailable = Self(
        snapshot: nil,
        health: .unavailable,
        failure: .unknown
    )

    var isLive: Bool {
        health == .live
    }
}

protocol QuotaProvider: Sendable {
    func refresh() -> QuotaRefreshResult
}

struct CompositeQuotaProvider: QuotaProvider {
    private let appServerProvider = AppServerQuotaProvider()
    private let logProvider = CodexLogQuotaProvider()
    private let sessionProvider = CodexSessionQuotaProvider()

    func refresh() -> QuotaRefreshResult {
        let live = appServerProvider.refresh()
        if live.isLive {
            return live
        }
        let failure = live.failure ?? .unknown
        if let local = logProvider.currentSnapshot() ?? sessionProvider.currentSnapshot() {
            return .degraded(local, failure: failure)
        }
        return .degraded(nil, failure: failure)
    }
}

struct CodexLogQuotaProvider {
    func currentSnapshot() -> QuotaSnapshot? {
        guard let record = newestHeaderRateLimitRecord(),
              let recordedAt = record.timestamp else {
            return nil
        }

        let now = Date()
        guard RateLimitRecord.isFresh(recordedAt: recordedAt, now: now) else {
            return nil
        }
        return record.snapshot(recordedAt: recordedAt, sourceName: "Codex 日志")
    }

    private func newestHeaderRateLimitRecord() -> RateLimitRecord? {
        let databaseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/logs_2.sqlite")
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return nil
        }

        let query = """
        select ts || char(9) || feedback_log_body from logs
        where feedback_log_body like '%x-codex-primary-used-percent%'
           or feedback_log_body like '%x-codex-secondary-used-percent%'
        order by ts desc, ts_nanos desc, id desc
        limit 1;
        """
        guard let output = runSQLite(databasePath: databaseURL.path, query: query) else {
            return nil
        }

        let parts = output.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let timestamp = TimeInterval(parts[0]) else {
            return nil
        }

        let body = String(parts[1])
        let recordedAt = Date(timeIntervalSince1970: timestamp)
        return RateLimitRecord.normalized(
            timestamp: Date(timeIntervalSince1970: timestamp),
            fileModifiedAt: recordedAt,
            primary: Self.headerWindow("primary", in: body),
            secondary: Self.headerWindow("secondary", in: body),
            now: Date()
        )
    }

    private func runSQLite(databasePath: String, query: String) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", databasePath, query]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func headerDouble(_ name: String, in text: String) -> Double? {
        guard let value = headerValue(name, in: text) else { return nil }
        return Double(value)
    }

    private static func headerInt(_ name: String, in text: String) -> Int? {
        guard let value = headerValue(name, in: text) else { return nil }
        return Int(value)
    }

    private static func headerValue(_ name: String, in text: String) -> String? {
        let marker = "\"\(name)\": \""
        guard let markerRange = text.range(of: marker) else {
            return nil
        }
        let valueStart = markerRange.upperBound
        guard let valueEnd = text[valueStart...].firstIndex(of: "\"") else {
            return nil
        }
        return String(text[valueStart..<valueEnd])
    }

    private static func headerWindow(_ name: String, in text: String) -> RateLimitWindow? {
        guard let usedPercent = headerDouble("x-codex-\(name)-used-percent", in: text),
              let resetsAt = headerDouble("x-codex-\(name)-reset-at", in: text),
              let windowMinutes = headerInt("x-codex-\(name)-window-minutes", in: text) else {
            return nil
        }
        return RateLimitWindow(
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            windowMinutes: windowMinutes
        )
    }
}

struct CodexSessionQuotaProvider: Sendable {
    static let maximumCandidateFileAge: TimeInterval = 30 * 60
    static let maximumCandidateFiles = 20
    static let maximumTailBytes: UInt64 = 256 * 1024

    private let roots: [URL]
    private let now: @Sendable () -> Date
    private let candidateFileAge: TimeInterval
    private let candidateFileLimit: Int
    private let tailByteLimit: UInt64

    init(
        roots: [URL]? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        maximumCandidateFileAge: TimeInterval = Self.maximumCandidateFileAge,
        maximumCandidateFiles: Int = Self.maximumCandidateFiles,
        maximumTailBytes: UInt64 = Self.maximumTailBytes
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.roots = roots ?? [
            home.appendingPathComponent(".codex/sessions"),
            home.appendingPathComponent(".codex/archived_sessions")
        ]
        self.now = now
        self.candidateFileAge = max(0, maximumCandidateFileAge)
        self.candidateFileLimit = max(0, maximumCandidateFiles)
        self.tailByteLimit = maximumTailBytes
    }

    func currentSnapshot() -> QuotaSnapshot? {
        let currentDate = now()
        guard let record = newestRateLimitRecord(now: currentDate),
              let recordedAt = record.timestamp,
              RateLimitRecord.isFresh(recordedAt: recordedAt, now: currentDate) else {
            return nil
        }
        return record.snapshot(recordedAt: recordedAt, sourceName: "Codex 会话")
    }

    private func newestRateLimitRecord(now currentDate: Date) -> RateLimitRecord? {
        let cutoff = currentDate.addingTimeInterval(-candidateFileAge)
        let files = roots
            .flatMap { recentJSONLFiles(under: $0, modifiedOnOrAfter: cutoff) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(candidateFileLimit)

        var records: [RateLimitRecord] = []
        for file in files {
            records.append(contentsOf: rateLimitRecords(
                in: file.url,
                fileModifiedAt: file.modifiedAt,
                now: currentDate
            ))
        }

        return bestRateLimitRecord(from: records, now: currentDate)
    }

    private func recentJSONLFiles(
        under root: URL,
        modifiedOnOrAfter cutoff: Date
    ) -> [SessionFile] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [SessionFile] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt >= cutoff else {
                continue
            }
            files.append(SessionFile(url: url, modifiedAt: modifiedAt))
        }
        return files
    }

    private func rateLimitRecords(
        in url: URL,
        fileModifiedAt: Date,
        now currentDate: Date
    ) -> [RateLimitRecord] {
        guard let text = readTailText(from: url, maxBytes: tailByteLimit) else {
            return []
        }

        var records: [RateLimitRecord] = []
        for line in text.split(separator: "\n").reversed() {
            guard line.contains("\"rate_limits\"") else { continue }
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = object["payload"] as? [String: Any],
                  let rateLimits = payload["rate_limits"] as? [String: Any],
                  Self.isAggregateCodexLimit(rateLimits),
                  let record = RateLimitRecord.normalized(
                    timestamp: parseDate(object["timestamp"] as? String),
                    fileModifiedAt: fileModifiedAt,
                    primary: parseWindow(rateLimits["primary"]),
                    secondary: parseWindow(rateLimits["secondary"]),
                    now: currentDate
                  ) else {
                continue
            }

            records.append(record)
            if records.count >= 40 {
                break
            }
        }

        return records
    }

    private func bestRateLimitRecord(
        from records: [RateLimitRecord],
        now currentDate: Date
    ) -> RateLimitRecord? {
        let now = currentDate.timeIntervalSince1970
        let currentWindowRecords = records.filter { record in
            record.primary.resetsAt > now && record.secondary.resetsAt > now
        }

        return currentWindowRecords.max { lhs, rhs in
            lhs.sortDate < rhs.sortDate
        }
    }

    private func readTailText(from url: URL, maxBytes: UInt64) -> String? {
        guard maxBytes > 0,
              let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let offset = fileSize > maxBytes ? fileSize - maxBytes : 0
        try? handle.seek(toOffset: offset)

        guard let data = try? handle.readToEnd() else {
            return nil
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func parseWindow(_ value: Any?) -> RateLimitWindow? {
        guard let dictionary = value as? [String: Any],
              let usedPercent = Self.double(dictionary["used_percent"]),
              let resetsAt = Self.double(dictionary["resets_at"]) else {
            return nil
        }
        return RateLimitWindow(
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            windowMinutes: Self.int(dictionary["window_minutes"])
        )
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func isAggregateCodexLimit(_ rateLimits: [String: Any]) -> Bool {
        (rateLimits["limit_id"] as? String) == "codex"
    }

    private static func double(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let double = value as? Double {
            return Int(double)
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }
}

private struct SessionFile {
    let url: URL
    let modifiedAt: Date
}

struct RateLimitRecord {
    let timestamp: Date?
    let fileModifiedAt: Date
    let primary: RateLimitWindow
    let secondary: RateLimitWindow
    let displayMode: QuotaDisplayMode

    var sortDate: Date {
        timestamp ?? fileModifiedAt
    }

    static let maximumFallbackAge: TimeInterval = 15 * 60

    static func isFresh(recordedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(recordedAt)
        return age >= 0 && age <= maximumFallbackAge
    }

    static func normalized(
        timestamp: Date?,
        fileModifiedAt: Date,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?,
        now: Date
    ) -> RateLimitRecord? {
        let nowTimestamp = now.timeIntervalSince1970
        if let primary,
           let secondary,
           primary.windowMinutes == 300,
           secondary.windowMinutes == 10_080,
           primary.resetsAt > nowTimestamp,
           secondary.resetsAt > nowTimestamp {
            return RateLimitRecord(
                timestamp: timestamp,
                fileModifiedAt: fileModifiedAt,
                primary: primary,
                secondary: secondary,
                displayMode: .dualWindow
            )
        }

        guard let weekly = [primary, secondary].compactMap({ $0 }).first(where: {
            $0.windowMinutes == 10_080 && $0.resetsAt > nowTimestamp
        }) else {
            return nil
        }
        return RateLimitRecord(
            timestamp: timestamp,
            fileModifiedAt: fileModifiedAt,
            primary: weekly,
            secondary: weekly,
            displayMode: .weeklyOnly
        )
    }

    func snapshot(recordedAt: Date, sourceName: String) -> QuotaSnapshot {
        let primaryUsed = Int(primary.usedPercent.rounded())
        let weeklyUsed = Int(secondary.usedPercent.rounded())
        return QuotaSnapshot(
            remainingPercent: max(0, min(100, 100 - primaryUsed)),
            weeklyRemainingPercent: max(0, min(100, 100 - weeklyUsed)),
            resetDate: Date(timeIntervalSince1970: primary.resetsAt),
            weeklyResetDate: Date(timeIntervalSince1970: secondary.resetsAt),
            lastUpdated: recordedAt,
            sourceName: sourceName,
            isUnavailable: false,
            displayMode: displayMode
        )
    }
}

struct RateLimitWindow {
    let usedPercent: Double
    let resetsAt: Double
    let windowMinutes: Int?
}

enum QuotaStatusFormatter {
    static func header(
        snapshot: QuotaSnapshot,
        health: RefreshHealth,
        confirmationAttempt: Int = 0,
        timeZone: TimeZone = .current
    ) -> String {
        if health == .confirmingFailure {
            switch confirmationAttempt {
            case 1:
                return "实时读取失败 · 15 秒后重试"
            case 2:
                return "正在确认失败 · 45 秒后重试"
            default:
                return snapshot.isUnavailable
                    ? "正在同步 · 额度未获取"
                    : "正在同步 · 使用上次数据"
            }
        }
        guard !snapshot.isUnavailable else {
            return "刷新失败 · 额度未获取"
        }

        let time = formattedTime(snapshot.lastUpdated, timeZone: timeZone)

        switch health {
        case .live:
            return "\(snapshot.sourceName) · 更新于 \(time)"
        case .degraded:
            if snapshot.sourceName == "Codex 日志"
                || snapshot.sourceName == "Codex 会话" {
                return "本地回退 · 更新于 \(time)"
            }
            return "刷新失败 · 上次成功 \(time)"
        case .unavailable:
            return "刷新失败 · 额度未获取"
        case .confirmingFailure:
            preconditionFailure("Handled above")
        }
    }

    private static func formattedTime(
        _ date: Date,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

enum QuotaDisplayMode: String, Sendable {
    case dualWindow
    case weeklyOnly
}

struct QuotaSnapshot: Sendable {
    var remainingPercent: Int
    var weeklyRemainingPercent: Int
    var resetDate: Date
    var weeklyResetDate: Date
    var lastUpdated: Date
    var sourceName: String
    var isUnavailable: Bool
    var displayMode: QuotaDisplayMode = .dualWindow

    var percentText: String {
        isUnavailable ? "—" : "\(remainingPercent)%"
    }

    var weeklyPercentText: String {
        isUnavailable ? "—" : "\(weeklyRemainingPercent)%"
    }

    var menuBarTitle: String {
        menuBarTitle(relativeTo: Date())
    }

    func menuBarTitle(relativeTo referenceDate: Date) -> String {
        guard !isUnavailable else { return "未同步" }
        switch displayMode {
        case .dualWindow:
            return "\(percentText) | \(shortResetText(relativeTo: referenceDate))"
        case .weeklyOnly:
            return shortResetText(relativeTo: referenceDate)
        }
    }

    var menuBarTrailingTitle: String? {
        guard !isUnavailable else { return nil }
        return displayMode == .dualWindow ? weeklyPercentText : percentText
    }

    var primaryQuotaLabel: String {
        displayMode == .weeklyOnly ? "周额度剩余" : "5 小时剩余"
    }

    var showsSecondaryQuota: Bool {
        !isUnavailable && displayMode == .dualWindow
    }

    var primaryResetDateText: String {
        guard !isUnavailable else { return "—" }
        return formattedResetDate(resetDate)
    }

    var primaryResetDetailText: String {
        displayMode == .weeklyOnly ? primaryResetDateText : resetClockText
    }

    var voiceBroadcastText: String {
        let quotaName = displayMode == .weeklyOnly ? "周额度" : "五小时额度"
        return "Codex \(quotaName)剩余 \(remainingPercent)%，距离额度恢复 \(resetText)。"
    }

    var notificationQuotaName: String {
        displayMode == .weeklyOnly ? "周额度" : "5h"
    }

    var displayRemainingPercent: Int {
        isUnavailable ? 0 : remainingPercent
    }

    var usedPercent: Int {
        100 - remainingPercent
    }

    var weeklyUsedPercent: Int {
        100 - weeklyRemainingPercent
    }

    static func cached(defaults: UserDefaults = .standard) -> QuotaSnapshot? {
        guard defaults.object(forKey: CacheKey.remainingPercent) != nil else {
            return nil
        }

        return QuotaSnapshot(
            remainingPercent: defaults.integer(forKey: CacheKey.remainingPercent),
            weeklyRemainingPercent: defaults.integer(forKey: CacheKey.weeklyRemainingPercent),
            resetDate: Date(timeIntervalSince1970: defaults.double(forKey: CacheKey.resetDate)),
            weeklyResetDate: Date(timeIntervalSince1970: defaults.double(forKey: CacheKey.weeklyResetDate)),
            lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: CacheKey.lastUpdated)),
            sourceName: "本机缓存",
            isUnavailable: false,
            displayMode: defaults.string(forKey: CacheKey.displayMode)
                .flatMap(QuotaDisplayMode.init(rawValue:)) ?? .dualWindow
        )
    }

    func cache(defaults: UserDefaults = .standard) {
        guard !isUnavailable else { return }

        defaults.set(remainingPercent, forKey: CacheKey.remainingPercent)
        defaults.set(weeklyRemainingPercent, forKey: CacheKey.weeklyRemainingPercent)
        defaults.set(resetDate.timeIntervalSince1970, forKey: CacheKey.resetDate)
        defaults.set(weeklyResetDate.timeIntervalSince1970, forKey: CacheKey.weeklyResetDate)
        defaults.set(lastUpdated.timeIntervalSince1970, forKey: CacheKey.lastUpdated)
        defaults.set(sourceName, forKey: CacheKey.sourceName)
        defaults.set(displayMode.rawValue, forKey: CacheKey.displayMode)
    }

    var tint: Color {
        guard !isUnavailable else { return .secondary }
        return Self.tint(for: remainingPercent)
    }

    var tagBackgroundColor: NSColor {
        guard !isUnavailable else { return NSColor(calibratedWhite: 1, alpha: 0.36) }
        return Self.tagBackgroundColor(for: remainingPercent)
    }

    var tagTextColor: NSColor {
        guard !isUnavailable else { return .labelColor }
        return Self.tagTextColor(for: remainingPercent)
    }

    var weeklyTint: Color {
        Self.tint(for: weeklyRemainingPercent)
    }

    private static func tint(for percent: Int) -> Color {
        switch percent {
        case 0...20:
            return .red
        case 21...45:
            return .yellow
        default:
            return .green
        }
    }

    private static func tagBackgroundColor(for percent: Int) -> NSColor {
        switch percent {
        case 0...20:
            return NSColor(calibratedRed: 1.0, green: 0.784, blue: 0.780, alpha: 0.92)
        case 21...45:
            return NSColor(calibratedRed: 0.973, green: 0.910, blue: 0.714, alpha: 0.92)
        default:
            return NSColor(calibratedRed: 0.722, green: 0.953, blue: 0.820, alpha: 0.92)
        }
    }

    private static func tagTextColor(for percent: Int) -> NSColor {
        switch percent {
        case 0...20:
            return NSColor(calibratedRed: 0.290, green: 0.071, blue: 0.075, alpha: 1)
        case 21...45:
            return NSColor(calibratedRed: 0.227, green: 0.176, blue: 0.043, alpha: 1)
        default:
            return NSColor(calibratedRed: 0.063, green: 0.247, blue: 0.157, alpha: 1)
        }
    }

    var resetText: String {
        guard !isUnavailable else { return "暂无重置信息" }
        return relativeResetText(for: resetDate)
    }

    var shortResetText: String {
        shortResetText(relativeTo: Date())
    }

    func shortResetText(relativeTo referenceDate: Date) -> String {
        guard !isUnavailable else { return "—" }
        return compactResetText(
            for: resetDate,
            relativeTo: referenceDate
        )
    }

    var resetClockText: String {
        guard !isUnavailable else { return "未同步" }
        return resetDate.formatted(date: .omitted, time: .shortened)
    }

    var lastUpdatedText: String {
        guard !isUnavailable else { return "未同步" }
        return "更新于 \(lastUpdated.formatted(date: .omitted, time: .shortened))"
    }

    var weeklyResetDateText: String {
        guard !isUnavailable else { return "—" }
        return formattedResetDate(weeklyResetDate)
    }

    private func formattedResetDate(_ date: Date) -> String {
        let dateText = date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .day(.defaultDigits)
                .locale(Locale(identifier: "zh_CN"))
        )
        return "\(dateText)恢复"
    }

    private func relativeResetText(for date: Date) -> String {
        let seconds = max(Int(date.timeIntervalSinceNow), 0)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return "\(days)天\(hours)小时后"
        }
        if hours > 0 {
            return "\(hours)小时\(minutes)分后"
        }
        return "\(minutes)分后"
    }

    private func compactResetText(
        for date: Date,
        relativeTo referenceDate: Date
    ) -> String {
        guard date > referenceDate else { return "—" }
        let seconds = max(
            Int(date.timeIntervalSince(referenceDate)),
            0
        )
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return "\(days)d\(hours)h"
        }
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }
        return "\(minutes)m"
    }

    static func unavailable() -> QuotaSnapshot {
        let now = Date()
        return QuotaSnapshot(
            remainingPercent: 0,
            weeklyRemainingPercent: 0,
            resetDate: now,
            weeklyResetDate: now,
            lastUpdated: now,
            sourceName: "额度未获取",
            isUnavailable: true
        )
    }

}

private enum CacheKey {
    static let remainingPercent = "quota.remainingPercent"
    static let weeklyRemainingPercent = "quota.weeklyRemainingPercent"
    static let resetDate = "quota.resetDate"
    static let weeklyResetDate = "quota.weeklyResetDate"
    static let lastUpdated = "quota.lastUpdated"
    static let sourceName = "quota.sourceName"
    static let displayMode = "quota.displayMode"
    static let voiceBroadcastIntervalMinutes = "voiceBroadcast.intervalMinutes"
    static let lastFailureCategory = "refresh.lastFailureCategory"
    static let lastFailureAt = "refresh.lastFailureAt"
    static let consecutiveFailures = "refresh.consecutiveFailures"
}
