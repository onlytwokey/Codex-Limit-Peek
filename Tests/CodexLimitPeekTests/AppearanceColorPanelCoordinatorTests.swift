import AppKit
import Testing
@testable import CodexLimitPeek

@MainActor
private final class FakeAppearanceColorPanelDriver:
    AppearanceColorPanelDriving
{
    var color = NSColor.black
    var level: NSWindow.Level = .floating
    var showsAlpha = false
    var isContinuous = false
    var onColorChange: ((NSColor, CGFloat) -> Void)?
    var onClose: (() -> Void)?
    private(set) var presentCount = 0
    private(set) var orderOutCount = 0

    func present() {
        presentCount += 1
    }

    func orderOut() {
        orderOutCount += 1
    }

    func simulateColor(
        _ color: NSColor,
        alpha: CGFloat
    ) {
        self.color = color
        onColorChange?(color, alpha)
    }

    func simulateUserClose() {
        onClose?()
    }
}

@MainActor
private final class RecordingSystemColorPanel:
    NSObject,
    AppearanceSystemColorPanel
{
    var color = NSColor.black
    var level: NSWindow.Level = .floating
    var showsAlpha = false
    var isContinuous = false
    private(set) var presentCount = 0
    private(set) var orderOutCount = 0

    var alpha: CGFloat {
        color.alphaComponent
    }

    var notificationObject: AnyObject {
        self
    }

    func present() {
        presentCount += 1
    }

    func orderOut() {
        orderOutCount += 1
    }
}

@Suite(.serialized)
struct AppearanceColorPanelCoordinatorTests {
    @Test @MainActor
    func systemDriverResolvesOnePanelAndFiltersColorNotifications() {
        let center = NotificationCenter()
        let panel = RecordingSystemColorPanel()
        let unrelatedPanel = RecordingSystemColorPanel()
        var providerCallCount = 0
        var colorChangeCount = 0
        var closeCount = 0
        var receivedColor: NSColor?
        var receivedAlpha: CGFloat?
        let driver = SystemAppearanceColorPanelDriver(
            notificationCenter: center,
            panelProvider: {
                providerCallCount += 1
                return panel
            }
        )
        driver.onColorChange = { color, alpha in
            colorChangeCount += 1
            receivedColor = color
            receivedAlpha = alpha
        }
        driver.onClose = {
            closeCount += 1
        }

        driver.color = NSColor(
            srgbRed: 0.2,
            green: 0.4,
            blue: 0.6,
            alpha: 0.35
        )
        driver.level = .popUpMenu
        driver.showsAlpha = true
        driver.isContinuous = true
        driver.present()
        driver.present()

        center.post(
            name: NSColorPanel.colorDidChangeNotification,
            object: unrelatedPanel
        )
        #expect(colorChangeCount == 0)
        center.post(
            name: NSColorPanel.colorDidChangeNotification,
            object: panel
        )

        #expect(providerCallCount == 1)
        #expect(panel.presentCount == 2)
        #expect(colorChangeCount == 1)
        #expect(
            abs((receivedColor?.redComponent ?? 0) - 0.2)
                < 0.000_001
        )
        #expect(abs((receivedAlpha ?? 0) - 0.35) < 0.000_001)

        driver.orderOut()
        center.post(
            name: NSColorPanel.colorDidChangeNotification,
            object: panel
        )
        center.post(
            name: NSWindow.willCloseNotification,
            object: panel
        )

        #expect(panel.orderOutCount == 1)
        #expect(colorChangeCount == 1)
        #expect(closeCount == 0)
        #expect(providerCallCount == 1)
    }

    @Test @MainActor
    func systemDriverWillCloseNotifiesOnceAndStopsObserving() {
        let center = NotificationCenter()
        let panel = RecordingSystemColorPanel()
        let unrelatedPanel = RecordingSystemColorPanel()
        let driver = SystemAppearanceColorPanelDriver(
            notificationCenter: center,
            panelProvider: { panel }
        )
        var colorChangeCount = 0
        var closeCount = 0
        driver.onColorChange = { _, _ in
            colorChangeCount += 1
        }
        driver.onClose = {
            closeCount += 1
        }
        driver.present()

        center.post(
            name: NSWindow.willCloseNotification,
            object: unrelatedPanel
        )
        #expect(closeCount == 0)
        center.post(
            name: NSWindow.willCloseNotification,
            object: panel
        )

        #expect(closeCount == 1)
        #expect(panel.orderOutCount == 0)

        center.post(
            name: NSColorPanel.colorDidChangeNotification,
            object: panel
        )
        center.post(
            name: NSWindow.willCloseNotification,
            object: panel
        )

        #expect(colorChangeCount == 0)
        #expect(closeCount == 1)
    }

    @Test @MainActor
    func continuousChangeKeepsCapturedThemeAndToken() {
        let driver = FakeAppearanceColorPanelDriver()
        let coordinator = AppearanceColorPanelCoordinator(
            driver: driver
        )
        var received:
            (AppearanceThemeID, AppearanceColorToken, AppearanceColor)?

        coordinator.beginEditing(
            theme: .bold,
            token: .surface,
            color: AppearanceColor(hex: 0xFFFFFF),
            above: .popUpMenu
        ) {
            received = ($0, $1, $2)
        }
        driver.simulateColor(
            NSColor(
                srgbRed: 0.2,
                green: 0.4,
                blue: 0.6,
                alpha: 1
            ),
            alpha: 0.35
        )

        #expect(received?.0 == .bold)
        #expect(received?.1 == .surface)
        #expect(abs((received?.2.red ?? 0) - 0.2) < 0.000_001)
        #expect(abs((received?.2.green ?? 0) - 0.4) < 0.000_001)
        #expect(abs((received?.2.blue ?? 0) - 0.6) < 0.000_001)
        #expect(abs((received?.2.alpha ?? 0) - 0.35) < 0.000_001)
    }

    @Test @MainActor
    func closeRestoresPanelStateAndClearsContext() {
        let driver = FakeAppearanceColorPanelDriver()
        driver.level = .floating
        let coordinator = AppearanceColorPanelCoordinator(
            driver: driver
        )

        coordinator.beginEditing(
            theme: .loud,
            token: .background,
            color: .white,
            above: .popUpMenu
        ) { _, _, _ in }

        #expect(
            driver.level.rawValue
                == NSWindow.Level.popUpMenu.rawValue + 1
        )
        #expect(driver.showsAlpha)
        #expect(driver.isContinuous)
        #expect(driver.presentCount == 1)

        coordinator.close()

        #expect(driver.level == .floating)
        #expect(!driver.showsAlpha)
        #expect(!driver.isContinuous)
        #expect(driver.orderOutCount == 1)
        #expect(driver.onColorChange == nil)
        #expect(driver.onClose == nil)
        #expect(coordinator.activeContext == nil)
    }

    @Test @MainActor
    func closeRestoresInitiallyEnabledPanelOptions() {
        let driver = FakeAppearanceColorPanelDriver()
        driver.level = .modalPanel
        driver.showsAlpha = true
        driver.isContinuous = true
        let coordinator = AppearanceColorPanelCoordinator(
            driver: driver
        )

        coordinator.beginEditing(
            theme: .loud,
            token: .actionAccent,
            color: AppearanceColor(hex: 0xFF676B),
            above: .popUpMenu
        ) { _, _, _ in }
        driver.showsAlpha = false
        driver.isContinuous = false

        coordinator.close()

        #expect(driver.level == .modalPanel)
        #expect(driver.showsAlpha)
        #expect(driver.isContinuous)
    }

    @Test @MainActor
    func manualPanelCloseRestoresStateWithoutOrderingOutAgain() {
        let driver = FakeAppearanceColorPanelDriver()
        let coordinator = AppearanceColorPanelCoordinator(
            driver: driver
        )
        coordinator.beginEditing(
            theme: .frost,
            token: .normal,
            color: AppearanceColor(hex: 0x4FC9C1),
            above: .popUpMenu
        ) { _, _, _ in }

        driver.simulateUserClose()

        #expect(driver.level == .floating)
        #expect(!driver.showsAlpha)
        #expect(!driver.isContinuous)
        #expect(coordinator.activeContext == nil)
        #expect(driver.orderOutCount == 0)
        #expect(driver.onColorChange == nil)
        #expect(driver.onClose == nil)
    }

    @Test @MainActor
    func beginningAgainClosesOldContextBeforeSavingNewState() {
        let driver = FakeAppearanceColorPanelDriver()
        driver.level = .modalPanel
        driver.showsAlpha = false
        driver.isContinuous = false
        let coordinator = AppearanceColorPanelCoordinator(
            driver: driver
        )
        var received:
            (AppearanceThemeID, AppearanceColorToken, AppearanceColor)?

        coordinator.beginEditing(
            theme: .loud,
            token: .background,
            color: .white,
            above: .popUpMenu
        ) { _, _, _ in }
        coordinator.beginEditing(
            theme: .frost,
            token: .danger,
            color: AppearanceColor(hex: 0xFF676B),
            above: .popUpMenu
        ) {
            received = ($0, $1, $2)
        }

        #expect(driver.orderOutCount == 1)
        #expect(driver.presentCount == 2)
        #expect(
            coordinator.activeContext
                == AppearanceColorPanelEditContext(
                    theme: .frost,
                    token: .danger
                )
        )

        driver.simulateColor(.red, alpha: 0.4)
        #expect(received?.0 == .frost)
        #expect(received?.1 == .danger)

        coordinator.close()

        #expect(driver.orderOutCount == 2)
        #expect(driver.level == .modalPanel)
        #expect(!driver.showsAlpha)
        #expect(!driver.isContinuous)
    }

    @Test @MainActor
    func inactiveCloseDoesNotResolveSystemPanelProvider() {
        var providerCallCount = 0
        let driver = SystemAppearanceColorPanelDriver(
            panelProvider: {
                providerCallCount += 1
                return RecordingSystemColorPanel()
            }
        )
        let coordinator = AppearanceColorPanelCoordinator(
            driver: driver
        )

        coordinator.close()

        #expect(providerCallCount == 0)
        #expect(coordinator.activeContext == nil)
    }
}
