import AppKit
import Combine
import SwiftUI

enum MoreOverlayPage: Equatable, Sendable {
    case actions
    case appearance
    case stateColors

    var width: CGFloat {
        switch self {
        case .actions:
            MoreOverlayMetrics.actionsWidth
        case .appearance, .stateColors:
            320
        }
    }

    var fixedSize: NSSize? {
        switch self {
        case .actions:
            nil
        case .appearance:
            MoreOverlayMetrics.appearanceSize
        case .stateColors:
            MoreOverlayMetrics.stateColorsSize
        }
    }
}

struct MoreOverlayLayout: Equatable {
    let interactionFrame: NSRect
    let decorationFrame: NSRect
    let visualFrame: NSRect
}

enum MoreOverlayMetrics {
    static let anchorGap: CGFloat = 8
    static let screenPadding: CGFloat = 8
    static let shadowSafetyInset = ThemePanelLayout.shadowSafetyInset
    static let actionsWidth: CGFloat = 224
    static let appearanceSize = NSSize(width: 320, height: 548)
    static let stateColorsSize = NSSize(width: 320, height: 430)

    static func layout(
        anchorRect: NSRect,
        contentSize: NSSize,
        visibleFrame: NSRect,
        shadowInsets: EdgeInsets
    ) -> MoreOverlayLayout {
        let minimumX = visibleFrame.minX
            + screenPadding
            + shadowInsets.leading
        let maximumX = max(
            minimumX,
            visibleFrame.maxX
                - contentSize.width
                - screenPadding
                - shadowInsets.trailing
        )
        let x = min(
            max(anchorRect.maxX - contentSize.width, minimumX),
            maximumX
        )
        let minimumY = visibleFrame.minY
            + screenPadding
            + shadowInsets.bottom
        let maximumY = visibleFrame.maxY
            - contentSize.height
            - screenPadding
            - shadowInsets.top
        let preferredY = anchorRect.minY
            - anchorGap
            - contentSize.height
        let y = min(max(preferredY, minimumY), maximumY)
        let interaction = NSRect(
            x: x,
            y: y,
            width: contentSize.width,
            height: contentSize.height
        )
        return MoreOverlayLayout(
            interactionFrame: interaction,
            decorationFrame: interaction.insetBy(
                dx: -shadowSafetyInset,
                dy: -shadowSafetyInset
            ),
            visualFrame: visualFrame(
                around: interaction,
                shadowInsets: shadowInsets
            )
        )
    }

    static func visualFrame(
        around interactionFrame: NSRect,
        shadowInsets: EdgeInsets
    ) -> NSRect {
        NSRect(
            x: interactionFrame.minX - shadowInsets.leading,
            y: interactionFrame.minY - shadowInsets.bottom,
            width: interactionFrame.width
                + shadowInsets.leading
                + shadowInsets.trailing,
            height: interactionFrame.height
                + shadowInsets.top
                + shadowInsets.bottom
        )
    }
}

enum MoreOverlayClickRole: Equatable {
    case anchor
    case interaction
    case hitShield
    case visualShield
    case parentPanel
    case colorPanel
    case auxiliaryChild
    case otherApplicationWindow
}

enum MoreOverlayDismissalAction: Equatable {
    case keep
    case closeOverlay
}

enum MoreOverlayDismissalPolicy {
    static func action(
        for role: MoreOverlayClickRole
    ) -> MoreOverlayDismissalAction {
        switch role {
        case
            .anchor,
            .interaction,
            .hitShield,
            .visualShield,
            .colorPanel,
            .auxiliaryChild:
            .keep
        case .parentPanel, .otherApplicationWindow:
            .closeOverlay
        }
    }
}

enum MoreOverlayEventPolicy {
    static func shouldConsume(
        eventType: NSEvent.EventType,
        role: MoreOverlayClickRole
    ) -> Bool {
        switch role {
        case .hitShield:
            switch eventType {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                return true
            default:
                return false
            }
        case .visualShield:
            switch eventType {
            case
                .leftMouseDown,
                .rightMouseDown,
                .otherMouseDown,
                .scrollWheel:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
}

final class MoreInteractionPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var hasNestedScrollView: Bool {
        contentView?.firstNestedScrollView != nil
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel, hasNestedScrollView {
            forwardScrollWheel(event)
            return
        }
        super.sendEvent(event)
    }

    func forwardScrollWheel(_ event: NSEvent) {
        contentView?.firstNestedScrollView?.scrollWheel(with: event)
    }
}

final class MoreOverlayHitShieldPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class MoreOverlayHitShieldView: NSView {
    weak var interactionPanel: MoreInteractionPanel?

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {}

    override func rightMouseDown(with event: NSEvent) {}

    override func otherMouseDown(with event: NSEvent) {}

    override func scrollWheel(with event: NSEvent) {
        interactionPanel?.forwardScrollWheel(event)
    }
}

private extension NSView {
    var firstNestedScrollView: NSScrollView? {
        if let scrollView = self as? NSScrollView {
            return scrollView
        }
        for subview in subviews {
            if let scrollView = subview.firstNestedScrollView {
                return scrollView
            }
        }
        return nil
    }
}

final class MoreOverlayAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    var screenRect: NSRect? {
        guard let window else { return nil }
        return window.convertToScreen(convert(bounds, to: nil))
    }
}

struct MoreOverlayAnchorReader: NSViewRepresentable {
    let onResolve: (MoreOverlayAnchorView?) -> Void

    func makeNSView(context: Context) -> MoreOverlayAnchorView {
        let view = MoreOverlayAnchorView()
        DispatchQueue.main.async {
            onResolve(view)
        }
        return view
    }

    func updateNSView(
        _ nsView: MoreOverlayAnchorView,
        context: Context
    ) {
        DispatchQueue.main.async {
            onResolve(nsView)
        }
    }
}

struct MoreOverlayWindowPair {
    let interaction: MoreInteractionPanel
    let hitShield: MoreOverlayHitShieldPanel
    let decoration: NSPanel
}

@MainActor
final class MoreOverlayPresenter: ObservableObject {
    @Published private(set) var isPresented = false
    @Published private(set) var page: MoreOverlayPage = .actions

    private let quotaStore: QuotaStore
    private let appearanceStore: AppearanceStore
    private weak var parentWindow: NSPanel?
    private weak var anchorView: MoreOverlayAnchorView?
    private var windowPair: MoreOverlayWindowPair?
    private var interactionHost:
        NSHostingController<MoreOverlayInteractionView>?
    private var decorationHost:
        NSHostingController<MoreOverlayDecorationView>?
    private var localEventMonitor: Any?
    private var repositionTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var protectedVisualFrame: NSRect?
    private(set) var interactionRootReplacementCount = 0

    init(
        quotaStore: QuotaStore,
        appearanceStore: AppearanceStore
    ) {
        self.quotaStore = quotaStore
        self.appearanceStore = appearanceStore

        appearanceStore.$revision
            .sink { [weak self] _ in
                self?.scheduleReposition()
            }
            .store(in: &cancellables)

        quotaStore.$voiceBroadcastEnabled
            .sink { [weak self] _ in
                guard self?.page == .actions else { return }
                self?.scheduleReposition()
            }
            .store(in: &cancellables)
    }

    var isWindowPairLoaded: Bool {
        windowPair != nil
    }

    var hasLocalEventMonitor: Bool {
        localEventMonitor != nil
    }

    func attach(to parentWindow: NSPanel) {
        self.parentWindow = parentWindow
    }

    func setAnchorView(_ view: MoreOverlayAnchorView?) {
        anchorView = view
        scheduleReposition()
    }

    func toggle() {
        isPresented ? close() : present()
    }

    func present() {
        guard
            parentWindow != nil,
            anchorView?.screenRect != nil,
            ensureWindowPair() != nil
        else {
            return
        }
        page = .actions
        isPresented = true
        replaceInteractionRoot()
        updateRootsAndFrames()
        if parentWindow?.isVisible == true {
            windowPair?.interaction.makeKeyAndOrderFront(nil)
            if let interactionHost {
                windowPair?.interaction.makeFirstResponder(
                    interactionHost.view
                )
            }
        }
        installLocalEventMonitor()
    }

    func navigate(to newPage: MoreOverlayPage) {
        page = newPage
        guard isPresented else { return }
        replaceInteractionRoot()
        updateRootsAndFrames()
    }

    func close(resetPage: Bool = true) {
        repositionTask?.cancel()
        repositionTask = nil
        protectedVisualFrame = nil
        appearanceStore.flushPendingSave()
        NSColorPanel.shared.orderOut(nil)
        windowPair?.interaction.orderOut(nil)
        windowPair?.hitShield.orderOut(nil)
        windowPair?.decoration.orderOut(nil)
        if let interaction = windowPair?.interaction {
            parentWindow?.removeChildWindow(interaction)
        }
        if let hitShield = windowPair?.hitShield {
            parentWindow?.removeChildWindow(hitShield)
        }
        if let decoration = windowPair?.decoration {
            parentWindow?.removeChildWindow(decoration)
        }
        removeLocalEventMonitor()
        isPresented = false
        if resetPage {
            page = .actions
        }
    }

    func reposition() {
        guard isPresented else { return }
        updateRootsAndFrames()
    }

    @discardableResult
    func ensureWindowPair() -> MoreOverlayWindowPair? {
        if let windowPair {
            return windowPair
        }

        let interaction = MoreInteractionPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let hitShield = MoreOverlayHitShieldPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let decoration = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        for panel in [interaction, hitShield, decoration] {
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .transient
            ]
        }
        interaction.backgroundColor = NSColor(
            calibratedWhite: 0,
            alpha: 0.001
        )
        hitShield.backgroundColor = NSColor(
            calibratedWhite: 0,
            alpha: 0.001
        )
        decoration.ignoresMouseEvents = true
        let hitShieldView = MoreOverlayHitShieldView()
        hitShieldView.interactionPanel = interaction
        hitShield.contentView = hitShieldView
        interaction.onEscape = { [weak self] in
            self?.close()
        }

        let interactionHost = NSHostingController(
            rootView: makeInteractionRoot(page: .actions)
        )
        interaction.initialFirstResponder = interactionHost.view
        interaction.autorecalculatesKeyViewLoop = true
        let initialSize = NSSize(
            width: MoreOverlayMetrics.actionsWidth,
            height: 180
        )
        let decorationHost = NSHostingController(
            rootView: MoreOverlayDecorationView(
                quotaStore: quotaStore,
                appearanceStore: appearanceStore,
                contentSize: initialSize
            )
        )
        interaction.contentViewController = interactionHost
        decoration.contentViewController = decorationHost

        self.interactionHost = interactionHost
        self.decorationHost = decorationHost
        let pair = MoreOverlayWindowPair(
            interaction: interaction,
            hitShield: hitShield,
            decoration: decoration
        )
        windowPair = pair
        return pair
    }

    private func makeInteractionRoot(
        page: MoreOverlayPage
    ) -> MoreOverlayInteractionView {
        MoreOverlayInteractionView(
            quotaStore: quotaStore,
            appearanceStore: appearanceStore,
            page: page,
            onNavigate: { [weak self] page in
                self?.navigate(to: page)
            }
        )
    }

    private func replaceInteractionRoot() {
        interactionHost?.rootView = makeInteractionRoot(page: page)
        interactionRootReplacementCount &+= 1
    }

    private var resolvedAppearance: ResolvedPanelAppearance {
        AppearanceResolver.panel(
            profile: appearanceStore.currentProfile,
            primaryRemainingPercent:
                quotaStore.snapshot.remainingPercent,
            weeklyRemainingPercent:
                quotaStore.snapshot.weeklyRemainingPercent,
            isUnavailable: quotaStore.snapshot.isUnavailable
        )
    }

    private func measuredContentSize(
        for page: MoreOverlayPage
    ) -> NSSize {
        if let fixedSize = page.fixedSize {
            return fixedSize
        }
        let measurementHost = NSHostingController(
            rootView: makeInteractionRoot(page: page)
        )
        let measured = measurementHost.sizeThatFits(
            in: NSSize(width: page.width, height: 2_000)
        )
        return NSSize(
            width: page.width,
            height: ceil(max(1, measured.height))
        )
    }

    private func scheduleReposition() {
        guard isPresented else { return }
        repositionTask?.cancel()
        repositionTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled else { return }
            self?.updateRootsAndFrames()
        }
    }

    private func updateRootsAndFrames() {
        guard
            isPresented,
            let pair = ensureWindowPair(),
            let parentWindow,
            let anchorRect = anchorView?.screenRect
        else {
            return
        }

        let contentSize = measuredContentSize(for: page)
        decorationHost?.rootView = MoreOverlayDecorationView(
            quotaStore: quotaStore,
            appearanceStore: appearanceStore,
            contentSize: contentSize
        )

        let shadowInsets =
            resolvedAppearance.visuals.panelShell.shadow.visualInsets
        let visibleFrame = (
            anchorView?.window?.screen
                ?? parentWindow.screen
                ?? NSScreen.main
        )?.visibleFrame ?? .zero
        let layout = MoreOverlayMetrics.layout(
            anchorRect: anchorRect,
            contentSize: contentSize,
            visibleFrame: visibleFrame,
            shadowInsets: shadowInsets
        )
        protectedVisualFrame = layout.visualFrame

        pair.decoration.level = parentWindow.level
        pair.hitShield.level = parentWindow.level
        pair.interaction.level = parentWindow.level
        if pair.decoration.parent !== parentWindow {
            parentWindow.addChildWindow(
                pair.decoration,
                ordered: .above
            )
        }
        if pair.hitShield.parent !== parentWindow {
            parentWindow.addChildWindow(
                pair.hitShield,
                ordered: .above
            )
        }
        if pair.interaction.parent !== parentWindow {
            parentWindow.addChildWindow(
                pair.interaction,
                ordered: .above
            )
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            pair.interaction.setFrame(
                layout.interactionFrame,
                display: true
            )
            pair.hitShield.setFrame(
                layout.visualFrame,
                display: true
            )
            pair.decoration.setFrame(
                layout.decorationFrame,
                display: true
            )
        }
        pair.decoration.order(
            .above,
            relativeTo: parentWindow.windowNumber
        )
        pair.hitShield.order(
            .above,
            relativeTo: pair.decoration.windowNumber
        )
        pair.interaction.order(
            .above,
            relativeTo: pair.hitShield.windowNumber
        )
    }

    private func installLocalEventMonitor() {
        removeLocalEventMonitor()
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .leftMouseDown,
                .rightMouseDown,
                .otherMouseDown,
                .scrollWheel,
                .keyDown
            ]
        ) { [weak self] event in
            guard let self, Thread.isMainThread else {
                return event
            }
            return self.handleLocalEvent(event)
        }
    }

    private func removeLocalEventMonitor() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

    func handleLocalEvent(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyDown, event.keyCode == 53 {
            close()
            return nil
        }

        switch event.type {
        case
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel:
            let role = clickRole(for: event)
            if MoreOverlayEventPolicy.shouldConsume(
                eventType: event.type,
                role: role
            ) {
                return nil
            }
            if MoreOverlayDismissalPolicy.action(for: role)
                == .closeOverlay,
                event.type != .scrollWheel
            {
                close()
            }
        default:
            break
        }
        return event
    }

    private func clickRole(
        for event: NSEvent
    ) -> MoreOverlayClickRole {
        let screenPoint: NSPoint
        if let eventWindow = event.window {
            screenPoint = eventWindow.convertPoint(
                toScreen: event.locationInWindow
            )
        } else {
            screenPoint = NSEvent.mouseLocation
        }
        return clickRole(
            candidateWindow: event.window,
            screenPoint: screenPoint
        )
    }

    func clickRole(
        candidateWindow candidate: NSWindow?,
        screenPoint: NSPoint
    ) -> MoreOverlayClickRole {
        if anchorView?.screenRect?.contains(screenPoint) == true {
            return .anchor
        }
        if candidate === windowPair?.interaction {
            return .interaction
        }
        if candidate === windowPair?.hitShield {
            return .hitShield
        }
        if candidate === windowPair?.decoration {
            return .visualShield
        }
        if candidate is NSColorPanel {
            return .colorPanel
        }
        if
            containsWindow(
                candidate,
                under: windowPair?.interaction
            )
                || hasColorPanelAncestor(candidate)
        {
            return .auxiliaryChild
        }
        if protectedVisualFrame?.contains(screenPoint) == true {
            return .visualShield
        }
        if candidate === parentWindow {
            return .parentPanel
        }
        return .otherApplicationWindow
    }

    private func containsWindow(
        _ candidate: NSWindow?,
        under root: NSWindow?
    ) -> Bool {
        guard let candidate, let root else { return false }
        if candidate === root {
            return true
        }
        return root.childWindows?.contains {
            containsWindow(candidate, under: $0)
        } ?? false
    }

    private func hasColorPanelAncestor(
        _ candidate: NSWindow?
    ) -> Bool {
        var current = candidate?.parent
        while let window = current {
            if window is NSColorPanel {
                return true
            }
            current = window.parent
        }
        return false
    }
}
