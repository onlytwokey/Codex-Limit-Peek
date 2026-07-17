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

@Suite(.serialized)
struct AppearanceColorPanelCoordinatorTests {
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
                return NSColorPanel()
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
