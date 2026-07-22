#if DEVELOPER_TOOLS
import AppKit
import Combine
import SwiftUI

@MainActor
final class DeveloperPreviewCoordinator:
    NSObject,
    NSWindowDelegate,
    ObservableObject
{
    static let windowTitle = "Codex Limit Peek Developer Preview"
    static let contentSize = NSSize(width: 760, height: 540)

    @Published private(set) var selection: DeveloperPreviewSelection
    @Published private(set) var environment: DeveloperPreviewEnvironment
    @Published private(set) var moreOverlayPresenter: MoreOverlayPresenter

    private let launchedAt: Date
    private let onClose: @MainActor () -> Void
    private var appearanceCancellable: AnyCancellable?
    private var window: NSWindow?

    init(
        selection: DeveloperPreviewSelection = DeveloperPreviewSelection(),
        launchedAt: Date = Date(),
        onClose: @escaping @MainActor () -> Void = {}
    ) {
        self.selection = selection
        self.launchedAt = launchedAt
        self.onClose = onClose
        let environment = DeveloperPreviewEnvironment(
            scenario: selection.scenario,
            theme: selection.theme,
            launchedAt: launchedAt
        )
        self.environment = environment
        moreOverlayPresenter = MoreOverlayPresenter(
            quotaStore: environment.quotaStore,
            appearanceStore: environment.appearanceStore
        )
        super.init()
        observeTheme(in: environment)
    }

    var isMoreOverlayWindowLoaded: Bool {
        moreOverlayPresenter.isWindowPairLoaded
    }

    var isWindowLoaded: Bool {
        window != nil
    }

    var statusItemProjection: DeveloperPreviewStatusItemProjection {
        DeveloperPreviewStatusItemProjection(
            quotaStore: environment.quotaStore,
            appearanceStore: environment.appearanceStore,
            referenceDate: environment.referenceDate
        )
    }

    @discardableResult
    func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: Self.contentSize
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable
            ],
            backing: .buffered,
            defer: false
        )
        window.title = Self.windowTitle
        window.setAccessibilityTitle(Self.windowTitle)
        window.setAccessibilityRole(.window)
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.animationBehavior = .none
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentMinSize = Self.contentSize
        window.contentMaxSize = Self.contentSize
        window.setContentSize(Self.contentSize)
        window.contentViewController = NSHostingController(
            rootView: DeveloperPreviewView(coordinator: self)
        )
        window.delegate = self
        moreOverlayPresenter.attach(to: window)
        self.window = window
        return window
    }

    func show() {
        let window = ensureWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func selectTheme(_ theme: AppearanceThemeID) {
        guard selection.theme != theme else { return }
        selection.theme = theme
        environment.appearanceStore.select(theme)
    }

    func selectScenario(_ scenario: DeveloperPreviewScenario) {
        guard selection.scenario != scenario else { return }
        selection.scenario = scenario
        rebuildEnvironment()
    }

    func selectImplementation(
        _ implementation: DeveloperPreviewImplementation
    ) {
        guard selection.implementation != implementation else { return }
        moreOverlayPresenter.close()
        selection.implementation = implementation
    }

    func tearDown() {
        appearanceCancellable?.cancel()
        appearanceCancellable = nil
        moreOverlayPresenter.close()
        environment.appearanceStore.flushPendingSave()
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        moreOverlayPresenter.close()
        environment.appearanceStore.flushPendingSave()
        window = nil
        onClose()
    }

    private func rebuildEnvironment() {
        appearanceCancellable?.cancel()
        moreOverlayPresenter.close()
        environment.appearanceStore.flushPendingSave()
        let appearanceProfiles = environment.appearanceStore.profiles
        let editorFontScale = environment.appearanceStore.editorFontScale

        let environment = DeveloperPreviewEnvironment(
            scenario: selection.scenario,
            theme: selection.theme,
            launchedAt: launchedAt,
            appearanceProfiles: appearanceProfiles,
            editorFontScale: editorFontScale
        )
        self.environment = environment
        let presenter = MoreOverlayPresenter(
            quotaStore: environment.quotaStore,
            appearanceStore: environment.appearanceStore
        )
        if let window {
            presenter.attach(to: window)
        }
        moreOverlayPresenter = presenter
        observeTheme(in: environment)
    }

    private func observeTheme(
        in environment: DeveloperPreviewEnvironment
    ) {
        appearanceCancellable = environment.appearanceStore.$selectedTheme
            .dropFirst()
            .sink { [weak self] theme in
                self?.selection.theme = theme
            }
    }
}
#endif
