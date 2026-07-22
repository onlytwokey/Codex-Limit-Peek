#if DEVELOPER_TOOLS
import Foundation
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct DeveloperPreviewEnvironmentTests {
    private let launchedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(arguments: [
        (DeveloperPreviewScenario.healthyDual, 81, 49, QuotaDisplayMode.dualWindow, RefreshHealth.live),
        (.weeklyOnly, 49, 49, .weeklyOnly, .live),
        (.warning, 18, 41, .dualWindow, .live),
        (.danger, 7, 12, .dualWindow, .live),
        (.refreshFailure, 63, 38, .dualWindow, .degraded)
    ])
    @MainActor
    func scenarioBuildsExpectedSnapshot(
        scenario: DeveloperPreviewScenario,
        remaining: Int,
        weekly: Int,
        displayMode: QuotaDisplayMode,
        health: RefreshHealth
    ) {
        let environment = DeveloperPreviewEnvironment(
            scenario: scenario,
            theme: .frost,
            launchedAt: launchedAt
        )

        #expect(environment.quotaStore.snapshot.remainingPercent == remaining)
        #expect(
            environment.quotaStore.snapshot.weeklyRemainingPercent == weekly
        )
        #expect(environment.quotaStore.snapshot.displayMode == displayMode)
        #expect(environment.quotaStore.refreshHealth == health)
        #expect(environment.appearanceStore.selectedTheme == .frost)
    }

    @Test @MainActor
    func unavailableScenarioNeverFallsBackToProductionData() {
        let environment = DeveloperPreviewEnvironment(
            scenario: .unavailable,
            theme: .loud,
            launchedAt: launchedAt
        )

        #expect(environment.quotaStore.snapshot.isUnavailable)
        #expect(environment.quotaStore.refreshHealth == .unavailable)
    }

    @Test @MainActor
    func previewPersistenceNeverReachesStandardDefaults() {
        let key = "DeveloperPreviewEnvironmentTests.\(UUID().uuidString)"
        #expect(UserDefaults.standard.object(forKey: key) == nil)

        let environment = DeveloperPreviewEnvironment(
            scenario: .healthyDual,
            theme: .loud,
            launchedAt: launchedAt
        )
        environment.defaults.set("preview", forKey: key)
        environment.appearanceStore.select(.bold)
        environment.appearanceStore.flushPendingSave()

        #expect(environment.defaults.string(forKey: key) == "preview")
        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }

    @Test @MainActor
    func voiceControlsHaveNoSpeechOrRefreshSideEffects() async {
        let provider = DeveloperRecordingQuotaProvider(
            result: DeveloperPreviewScenario.healthyDual.fixture(
                launchedAt: launchedAt
            ).refreshResult
        )
        let environment = DeveloperPreviewEnvironment(
            scenario: .healthyDual,
            theme: .loud,
            launchedAt: launchedAt,
            provider: provider
        )

        environment.quotaStore.toggleVoiceBroadcast()
        await Task.yield()

        #expect(environment.quotaStore.voiceBroadcastEnabled)
        #expect(environment.quotaStore.speechSynthesizer == nil)
        #expect(provider.callCount == 0)
    }
}

private final class DeveloperRecordingQuotaProvider:
    QuotaProvider,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let result: QuotaRefreshResult
    private var calls = 0

    init(result: QuotaRefreshResult) {
        self.result = result
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func refresh() -> QuotaRefreshResult {
        lock.lock()
        calls += 1
        lock.unlock()
        return result
    }
}
#endif
