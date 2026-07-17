import AppKit

struct AppearanceColorPanelEditContext: Equatable, Sendable {
    let theme: AppearanceThemeID
    let token: AppearanceColorToken
}

@MainActor
protocol AppearanceColorPanelDriving: AnyObject {
    var color: NSColor { get set }
    var level: NSWindow.Level { get set }
    var showsAlpha: Bool { get set }
    var isContinuous: Bool { get set }
    var onColorChange: ((NSColor, CGFloat) -> Void)? { get set }
    var onClose: (() -> Void)? { get set }

    func present()
    func orderOut()
}

@MainActor
final class SystemAppearanceColorPanelDriver:
    NSObject,
    AppearanceColorPanelDriving
{
    private let notificationCenter: NotificationCenter
    private let panelProvider: () -> NSColorPanel
    private var isObserving = false
    private lazy var panel = panelProvider()

    var onColorChange: ((NSColor, CGFloat) -> Void)?
    var onClose: (() -> Void)?

    init(
        notificationCenter: NotificationCenter = .default,
        panelProvider: @escaping () -> NSColorPanel = {
            NSColorPanel.shared
        }
    ) {
        self.notificationCenter = notificationCenter
        self.panelProvider = panelProvider
    }

    var color: NSColor {
        get { panel.color }
        set { panel.color = newValue }
    }

    var level: NSWindow.Level {
        get { panel.level }
        set { panel.level = newValue }
    }

    var showsAlpha: Bool {
        get { panel.showsAlpha }
        set { panel.showsAlpha = newValue }
    }

    var isContinuous: Bool {
        get { panel.isContinuous }
        set { panel.isContinuous = newValue }
    }

    func present() {
        startObserving()
        panel.makeKeyAndOrderFront(nil)
    }

    func orderOut() {
        stopObserving()
        panel.orderOut(nil)
    }

    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        notificationCenter.addObserver(
            self,
            selector: #selector(colorDidChange(_:)),
            name: NSColorPanel.colorDidChangeNotification,
            object: panel
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(panelWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: panel
        )
    }

    private func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        notificationCenter.removeObserver(
            self,
            name: NSColorPanel.colorDidChangeNotification,
            object: panel
        )
        notificationCenter.removeObserver(
            self,
            name: NSWindow.willCloseNotification,
            object: panel
        )
    }

    @objc
    private func colorDidChange(_ notification: Notification) {
        onColorChange?(panel.color, panel.alpha)
    }

    @objc
    private func panelWillClose(_ notification: Notification) {
        let callback = onClose
        stopObserving()
        callback?()
    }
}

@MainActor
protocol AppearanceColorPanelCoordinating: AnyObject {
    var activeContext: AppearanceColorPanelEditContext? { get }

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
    )

    func close()
}

@MainActor
final class AppearanceColorPanelCoordinator:
    AppearanceColorPanelCoordinating
{
    private struct SavedPanelState {
        let level: NSWindow.Level
        let showsAlpha: Bool
        let isContinuous: Bool
    }

    private let driver: any AppearanceColorPanelDriving
    private var savedState: SavedPanelState?
    private var onChange: ((
        AppearanceThemeID,
        AppearanceColorToken,
        AppearanceColor
    ) -> Void)?

    private(set) var activeContext:
        AppearanceColorPanelEditContext?

    init(
        driver: any AppearanceColorPanelDriving
            = SystemAppearanceColorPanelDriver()
    ) {
        self.driver = driver
    }

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
        close()
        savedState = SavedPanelState(
            level: driver.level,
            showsAlpha: driver.showsAlpha,
            isContinuous: driver.isContinuous
        )
        activeContext = AppearanceColorPanelEditContext(
            theme: theme,
            token: token
        )
        self.onChange = onChange
        driver.color = color.nsColor
        driver.showsAlpha = true
        driver.isContinuous = true
        driver.level = NSWindow.Level(
            rawValue: overlayLevel.rawValue + 1
        )
        driver.onColorChange = { [weak self] color, alpha in
            self?.receive(color: color, alpha: alpha)
        }
        driver.onClose = { [weak self] in
            self?.finish(orderOut: false)
        }
        driver.present()
    }

    func close() {
        guard activeContext != nil || savedState != nil else {
            return
        }
        finish(orderOut: true)
    }

    private func receive(
        color: NSColor,
        alpha: CGFloat
    ) {
        guard let activeContext else { return }
        var appearanceColor = AppearanceColor(nsColor: color)
        appearanceColor.alpha = Double(alpha)
        onChange?(
            activeContext.theme,
            activeContext.token,
            appearanceColor.clamped()
        )
    }

    private func finish(orderOut: Bool) {
        let state = savedState
        driver.onColorChange = nil
        driver.onClose = nil
        if orderOut {
            driver.orderOut()
        }
        if let state {
            driver.level = state.level
            driver.showsAlpha = state.showsAlpha
            driver.isContinuous = state.isContinuous
        }
        savedState = nil
        activeContext = nil
        onChange = nil
    }
}
