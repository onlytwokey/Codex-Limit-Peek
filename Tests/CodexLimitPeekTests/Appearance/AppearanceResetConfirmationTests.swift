import Testing
@testable import CodexLimitPeek

struct AppearanceResetConfirmationTests {
    @Test
    func requestRequiresAResettableTheme() {
        var state = AppearanceResetConfirmationState()

        state.request(for: .loud, canReset: false)
        #expect(state.requestedTheme == nil)

        state.request(for: .loud, canReset: true)
        #expect(state.requestedTheme == .loud)
    }

    @Test
    func switchingThemesDismissesThePendingConfirmation() {
        var state = AppearanceResetConfirmationState()
        state.request(for: .loud, canReset: true)

        state.selectedThemeDidChange(to: .bold)

        #expect(state.requestedTheme == nil)
    }

    @Test
    func confirmingConsumesOnlyTheCurrentlySelectedTheme() {
        var state = AppearanceResetConfirmationState()
        state.request(for: .loud, canReset: true)

        let mismatchedConfirmation = state.confirm(for: .bold)
        #expect(!mismatchedConfirmation)
        #expect(state.requestedTheme == nil)

        state.request(for: .loud, canReset: true)
        let matchingConfirmation = state.confirm(for: .loud)
        #expect(matchingConfirmation)
        #expect(state.requestedTheme == nil)
    }

    @Test
    func cancelDismissesThePendingConfirmation() {
        var state = AppearanceResetConfirmationState()
        state.request(for: .frost, canReset: true)

        state.cancel()

        #expect(state.requestedTheme == nil)
    }
}
