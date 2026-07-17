import AppKit
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct AppDelegateLifecycleTests {
    @Test @MainActor
    func panelIsCreatedOnDemandAndThenReused() {
        let delegate = AppDelegate()

        #expect(!delegate.isPanelWindowLoaded)

        let firstPanel = delegate.ensurePanelWindow()
        let secondPanel = delegate.ensurePanelWindow()

        #expect(delegate.isPanelWindowLoaded)
        #expect(firstPanel === secondPanel)
    }
}
