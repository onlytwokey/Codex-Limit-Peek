import Foundation
import Testing
@testable import CodexLimitPeek

struct QuotaStoreTests {
    @Test
    func testRefreshResultDistinguishesLiveDegradedAndUnavailable() {
        let snapshot = QuotaSnapshot.fixture()

        #expect(QuotaRefreshResult.live(snapshot).isLive)
        #expect(!QuotaRefreshResult.degraded(snapshot).isLive)
        #expect(QuotaRefreshResult.unavailable.snapshot == nil)
    }

    @Test
    func localRecordIsFreshForFifteenMinutesOnly() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(RateLimitRecord.isFresh(recordedAt: now.addingTimeInterval(-899), now: now))
        #expect(RateLimitRecord.isFresh(recordedAt: now.addingTimeInterval(-900), now: now))
        #expect(!RateLimitRecord.isFresh(recordedAt: now.addingTimeInterval(-901), now: now))
    }

    @Test
    func localRecordNormalizesDualWindowQuota() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let record = try #require(RateLimitRecord.normalized(
            timestamp: now,
            fileModifiedAt: now,
            primary: localWindow(used: 39, resetsAt: now.addingTimeInterval(10_800), minutes: 300),
            secondary: localWindow(used: 26, resetsAt: now.addingTimeInterval(432_000), minutes: 10_080),
            now: now
        ))

        #expect(record.displayMode == .dualWindow)
        #expect(record.snapshot(recordedAt: now, sourceName: "Test").remainingPercent == 61)
        #expect(record.snapshot(recordedAt: now, sourceName: "Test").weeklyRemainingPercent == 74)
    }

    @Test
    func localRecordPromotesSoleWeeklyWindow() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let weekly = localWindow(used: 18, resetsAt: now.addingTimeInterval(604_800), minutes: 10_080)
        let record = try #require(RateLimitRecord.normalized(
            timestamp: now,
            fileModifiedAt: now,
            primary: weekly,
            secondary: nil,
            now: now
        ))
        let snapshot = record.snapshot(recordedAt: now, sourceName: "Test")

        #expect(record.displayMode == .weeklyOnly)
        #expect(snapshot.displayMode == .weeklyOnly)
        #expect(snapshot.remainingPercent == 82)
        #expect(snapshot.weeklyRemainingPercent == 82)
        #expect(snapshot.resetDate == snapshot.weeklyResetDate)
    }

    @Test
    func localRecordRejectsSoleFiveHourOrUnknownWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(RateLimitRecord.normalized(
            timestamp: now,
            fileModifiedAt: now,
            primary: localWindow(used: 10, resetsAt: now.addingTimeInterval(10_800), minutes: 300),
            secondary: nil,
            now: now
        ) == nil)
        #expect(RateLimitRecord.normalized(
            timestamp: now,
            fileModifiedAt: now,
            primary: localWindow(used: 10, resetsAt: now.addingTimeInterval(10_800), minutes: 60),
            secondary: nil,
            now: now
        ) == nil)
    }

    @Test @MainActor
    func storeRestoresCacheAndStartsConfirming() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cached = QuotaSnapshot.fixture()
        cached.cache(defaults: defaults)

        let store = QuotaStore(provider: StubProvider(.degraded(nil)), defaults: defaults)

        #expect(store.snapshot.remainingPercent == 61)
        #expect(store.refreshHealth == .confirmingFailure)
    }

    @Test @MainActor
    func storeRestoresLegacyCacheWithoutSourceKey() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cached = QuotaSnapshot.fixture()
        defaults.set(cached.remainingPercent, forKey: "quota.remainingPercent")
        defaults.set(cached.weeklyRemainingPercent, forKey: "quota.weeklyRemainingPercent")
        defaults.set(cached.resetDate.timeIntervalSince1970, forKey: "quota.resetDate")
        defaults.set(cached.weeklyResetDate.timeIntervalSince1970, forKey: "quota.weeklyResetDate")
        defaults.set(cached.lastUpdated.timeIntervalSince1970, forKey: "quota.lastUpdated")

        let store = QuotaStore(provider: StubProvider(.degraded(nil)), defaults: defaults)

        #expect(store.snapshot.remainingPercent == 61)
        #expect(store.snapshot.sourceName == "本机缓存")
    }

    @Test @MainActor
    func cacheRoundTripPreservesWeeklyOnlyMode() {
        let defaults = isolatedDefaults()
        var snapshot = QuotaSnapshot.fixture()
        snapshot.displayMode = .weeklyOnly
        snapshot.cache(defaults: defaults)

        let restored = QuotaSnapshot.cached(defaults: defaults)

        #expect(restored?.displayMode == .weeklyOnly)
    }

    @Test @MainActor
    func legacyCacheDefaultsToDualWindowMode() {
        let defaults = isolatedDefaults()
        let snapshot = QuotaSnapshot.fixture()
        defaults.set(snapshot.remainingPercent, forKey: "quota.remainingPercent")
        defaults.set(snapshot.weeklyRemainingPercent, forKey: "quota.weeklyRemainingPercent")
        defaults.set(snapshot.resetDate.timeIntervalSince1970, forKey: "quota.resetDate")
        defaults.set(snapshot.weeklyResetDate.timeIntervalSince1970, forKey: "quota.weeklyResetDate")
        defaults.set(snapshot.lastUpdated.timeIntervalSince1970, forKey: "quota.lastUpdated")

        #expect(QuotaSnapshot.cached(defaults: defaults)?.displayMode == .dualWindow)
    }

    @Test @MainActor
    func failedRefreshKeepsCacheAndSuccessfulRefreshClearsFailure() async {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cached = QuotaSnapshot.fixture()
        cached.cache(defaults: defaults)
        let provider = SequenceProvider([.degraded(nil), .live(.fixture())])
        let store = QuotaStore(
            provider: provider,
            defaults: defaults,
            minimumRefreshInterval: 0
        )

        store.refresh()
        await waitForRefresh(store)
        #expect(store.refreshHealth == .confirmingFailure)
        #expect(store.snapshot.remainingPercent == 61)

        store.refresh()
        await waitForRefresh(store)
        #expect(store.refreshHealth == .live)
        #expect(store.snapshot.remainingPercent == 61)
    }

    @Test @MainActor
    func threeFailuresOverSixtySecondsConfirmDegradation() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedTestClock(start)
        let sleeper = ManualSleeper()
        let provider = CountingProvider([
            .degraded(nil, failure: .timeout),
            .degraded(nil, failure: .timeout),
            .degraded(nil, failure: .timeout)
        ])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: clock.now,
            monotonicNow: { clock.now().timeIntervalSince1970 },
            minimumRefreshInterval: 10,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.start(requestNotificationPermission: false)
        await waitForRefresh(store)
        #expect(store.refreshHealth == .confirmingFailure)
        #expect(store.confirmationAttempt == 1)
        await waitForSleeps(sleeper, count: 1)
        #expect(sleeper.delays == [15])

        clock.advance(by: 15)
        sleeper.resumeNext()
        await waitForProviderCalls(provider, count: 2)
        #expect(store.refreshHealth == .confirmingFailure)
        #expect(store.confirmationAttempt == 2)
        await waitForSleeps(sleeper, count: 2)
        #expect(sleeper.delays == [15, 45])

        clock.advance(by: 45)
        sleeper.resumeNext()
        await waitForProviderCalls(provider, count: 3)
        #expect(store.refreshHealth == .unavailable)
        await waitForSleeps(sleeper, count: 3)
        #expect(sleeper.delays == [15, 45, 120])
    }

    @Test @MainActor
    func retrySuccessReturnsLiveAndCancelsFailureSequence() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedTestClock(start)
        let sleeper = ManualSleeper()
        let provider = CountingProvider([
            .degraded(nil, failure: .timeout),
            .live(.fixture(now: start.addingTimeInterval(15)))
        ])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: clock.now,
            monotonicNow: { clock.now().timeIntervalSince1970 },
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.start(requestNotificationPermission: false)
        await waitForRefresh(store)
        await waitForSleeps(sleeper, count: 1)
        clock.advance(by: 15)
        sleeper.resumeNext()
        await waitForProviderCalls(provider, count: 2)

        #expect(store.refreshHealth == .live)
        #expect(store.confirmationAttempt == 0)
        #expect(store.lastFailureCategory == nil)
    }

    @Test @MainActor
    func failureDiagnosticsPersistOnlySafeFields() async {
        let defaults = isolatedDefaults()
        let store = QuotaStore(
            provider: StubProvider(.degraded(nil, failure: .timeout)),
            defaults: defaults,
            minimumRefreshInterval: 0
        )

        store.refresh()
        await waitForRefresh(store)

        #expect(defaults.string(forKey: "refresh.lastFailureCategory") == "timeout")
        #expect(defaults.object(forKey: "refresh.lastFailureAt") != nil)
        #expect(defaults.integer(forKey: "refresh.consecutiveFailures") == 1)
    }

    @Test @MainActor
    func cancelledRetryCannotRunAfterManualRecovery() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedTestClock(start)
        let sleeper = ManualSleeper()
        let provider = CountingProvider([
            .degraded(nil, failure: .timeout),
            .live(.fixture(now: start))
        ])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: clock.now,
            monotonicNow: { clock.now().timeIntervalSince1970 },
            minimumRefreshInterval: 0,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.start(requestNotificationPermission: false)
        await waitForRefresh(store)
        await waitForSleeps(sleeper, count: 1)
        store.refresh(bypassCooldown: true)
        await waitForProviderCalls(provider, count: 2)
        #expect(store.refreshHealth == .live)

        sleeper.resumeNext()
        try? await Task.sleep(for: .milliseconds(20))
        #expect(provider.callCount == 2)
    }

    @Test @MainActor
    func freshFallbackDoesNotClearLiveFailure() async {
        let live = QuotaSnapshot.fixture()
        var local = QuotaSnapshot.fixture(
            now: live.lastUpdated.addingTimeInterval(30)
        )
        local.sourceName = "Codex 会话"
        let defaults = isolatedDefaults()
        live.cache(defaults: defaults)
        let store = QuotaStore(
            provider: StubProvider(.degraded(local, failure: .timeout)),
            defaults: defaults,
            minimumRefreshInterval: 0
        )

        store.refresh()
        await waitForRefresh(store)

        #expect(store.refreshHealth == .confirmingFailure)
        #expect(store.snapshot.sourceName == "本机缓存")
    }

    @Test @MainActor
    func confirmedFailureMayDisplayFreshFallback() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedTestClock(start)
        var local = QuotaSnapshot.fixture(now: start)
        local.sourceName = "Codex 会话"
        let provider = SequenceProvider([
            .degraded(local, failure: .timeout),
            .degraded(local, failure: .timeout),
            .degraded(local, failure: .timeout)
        ])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: clock.now,
            monotonicNow: { clock.now().timeIntervalSince1970 },
            minimumRefreshInterval: 0
        )

        store.refresh()
        await waitForRefresh(store)
        clock.advance(by: 15)
        store.refresh()
        await waitForRefresh(store)
        clock.advance(by: 45)
        store.refresh()
        await waitForRefresh(store)

        #expect(store.refreshHealth == .degraded)
        #expect(store.snapshot.sourceName == "Codex 会话")
    }

    @Test @MainActor
    func restartIgnoresPersistedBackoffAndAttemptsImmediately() async {
        let defaults = isolatedDefaults()
        defaults.set("timeout", forKey: "refresh.lastFailureCategory")
        defaults.set(3, forKey: "refresh.consecutiveFailures")
        let provider = CountingProvider([.live(.fixture())])
        let store = QuotaStore(provider: provider, defaults: defaults)

        #expect(store.lastFailureCategory == .timeout)
        store.start(requestNotificationPermission: false)
        await waitForProviderCalls(provider, count: 1)

        #expect(store.refreshHealth == .live)
        #expect(store.lastFailureCategory == nil)
        #expect(defaults.integer(forKey: "refresh.consecutiveFailures") == 0)
    }

    @Test
    func expiredResetUsesDashInsteadOfZeroMinutes() {
        var snapshot = QuotaSnapshot.fixture()
        snapshot.resetDate = Date(timeIntervalSince1970: 1)

        #expect(snapshot.shortResetText == "—")
    }

    @Test
    func degradedHeaderIncludesSourceAndRealTime() {
        let snapshot = QuotaSnapshot.fixture(now: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(
            QuotaStatusFormatter.header(
                snapshot: snapshot,
                health: .degraded,
                timeZone: TimeZone(secondsFromGMT: 0)!
            ) == "刷新失败 · 上次成功 08:00"
        )
    }

    @Test
    func confirmingFailureUsesNeutralPresentationText() {
        let snapshot = QuotaSnapshot.fixture()

        #expect(!RefreshHealth.confirmingFailure.showsFailurePattern)
        #expect(
            QuotaStatusFormatter.header(
                snapshot: snapshot,
                health: .confirmingFailure,
                confirmationAttempt: 1
            ) == "实时读取失败 · 15 秒后重试"
        )
        #expect(
            QuotaStatusFormatter.header(
                snapshot: snapshot,
                health: .confirmingFailure,
                confirmationAttempt: 2
            ) == "正在确认失败 · 45 秒后重试"
        )
    }

    @Test
    func onlyConfirmedStatesUseFailurePattern() {
        #expect(!RefreshHealth.live.showsFailurePattern)
        #expect(!RefreshHealth.confirmingFailure.showsFailurePattern)
        #expect(RefreshHealth.degraded.showsFailurePattern)
        #expect(RefreshHealth.unavailable.showsFailurePattern)
    }

    @Test
    func liveHeaderUsesExistingUpdateLanguage() {
        let snapshot = QuotaSnapshot.fixture(now: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(
            QuotaStatusFormatter.header(
                snapshot: snapshot,
                health: .live,
                timeZone: TimeZone(secondsFromGMT: 0)!
            ) == "Test · 更新于 08:00"
        )
    }

    @Test
    func weeklyOnlySnapshotUsesCountdownThenWeeklyPercent() {
        var snapshot = QuotaSnapshot.fixture()
        snapshot.displayMode = .weeklyOnly
        snapshot.weeklyRemainingPercent = snapshot.remainingPercent
        snapshot.weeklyResetDate = snapshot.resetDate

        #expect(snapshot.menuBarTitle == snapshot.shortResetText)
        #expect(snapshot.menuBarTrailingTitle == snapshot.percentText)
        #expect(snapshot.primaryQuotaLabel == "周额度剩余")
        #expect(snapshot.primaryResetDetailText == snapshot.primaryResetDateText)
        #expect(!snapshot.showsSecondaryQuota)
        #expect(snapshot.voiceBroadcastText.contains("周额度剩余 61%"))
        #expect(snapshot.notificationQuotaName == "周额度")
    }

    @Test
    func dualWindowSnapshotPreservesExistingDisplaySemantics() {
        let snapshot = QuotaSnapshot.fixture()

        #expect(snapshot.menuBarTitle == "\(snapshot.percentText) | \(snapshot.shortResetText)")
        #expect(snapshot.menuBarTrailingTitle == snapshot.weeklyPercentText)
        #expect(snapshot.primaryQuotaLabel == "5 小时剩余")
        #expect(snapshot.primaryResetDetailText == snapshot.resetClockText)
        #expect(snapshot.showsSecondaryQuota)
        #expect(snapshot.voiceBroadcastText.contains("五小时额度剩余 61%"))
        #expect(snapshot.notificationQuotaName == "5h")
    }

    @Test @MainActor
    func recentLiveSnapshotSkipsNonForcedRefresh() async {
        let now = Date(timeIntervalSince1970: 1_800_000_059)
        let snapshot = QuotaSnapshot.fixture(now: Date(timeIntervalSince1970: 1_800_000_000))
        let provider = CountingProvider([.live(snapshot), .live(snapshot)])
        let defaults = isolatedDefaults()
        let store = QuotaStore(provider: provider, defaults: defaults, now: { now })
        store.refresh()
        await waitForRefresh(store)
        let cachedTimestamp = defaults.double(forKey: "quota.lastUpdated")

        store.refresh(force: false)

        #expect(provider.callCount == 1)
        #expect(store.snapshot.lastUpdated == snapshot.lastUpdated)
        #expect(store.refreshHealth == .live)
        #expect(defaults.double(forKey: "quota.lastUpdated") == cachedTimestamp)
    }

    @Test @MainActor
    func liveSnapshotAtSixtySecondsRefreshes() async {
        let now = Date(timeIntervalSince1970: 1_800_000_060)
        let snapshot = QuotaSnapshot.fixture(now: Date(timeIntervalSince1970: 1_800_000_000))
        let provider = CountingProvider([.live(snapshot), .live(snapshot)])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: { now },
            minimumRefreshInterval: 0
        )
        store.refresh()
        await waitForRefresh(store)

        store.refresh(force: false)
        await waitForRefresh(store)

        #expect(provider.callCount == 2)
    }

    @Test @MainActor
    func degradedSnapshotNeverSkipsRefresh() async {
        let now = Date(timeIntervalSince1970: 1_800_000_010)
        let snapshot = QuotaSnapshot.fixture(now: Date(timeIntervalSince1970: 1_800_000_000))
        let provider = CountingProvider([.degraded(snapshot), .live(snapshot)])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: { now },
            minimumRefreshInterval: 0
        )
        store.refresh()
        await waitForRefresh(store)

        store.refresh(force: false)
        await waitForRefresh(store)

        #expect(provider.callCount == 2)
    }

    @Test @MainActor
    func forcedRefreshNeverReusesRecentLiveSnapshot() async {
        let now = Date(timeIntervalSince1970: 1_800_000_010)
        let snapshot = QuotaSnapshot.fixture(now: Date(timeIntervalSince1970: 1_800_000_000))
        let provider = CountingProvider([.live(snapshot), .live(snapshot)])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: { now },
            minimumRefreshInterval: 0
        )
        store.refresh()
        await waitForRefresh(store)

        store.refresh(force: true)
        await waitForRefresh(store)

        #expect(provider.callCount == 2)
    }

    @Test @MainActor
    func futureDatedLiveSnapshotDoesNotReuse() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = QuotaSnapshot.fixture(now: Date(timeIntervalSince1970: 1_800_000_001))
        let provider = CountingProvider([.live(snapshot), .live(snapshot)])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: { now },
            minimumRefreshInterval: 0
        )
        store.refresh()
        await waitForRefresh(store)

        store.refresh(force: false)
        await waitForRefresh(store)

        #expect(provider.callCount == 2)
    }

    @Test @MainActor
    func voiceRequestDuringRefreshWaitsForCompletion() async {
        let provider = BlockingProvider(.degraded(nil))
        let store = QuotaStore(provider: provider, defaults: isolatedDefaults())
        store.refresh()

        store.toggleVoiceBroadcast()
        #expect(store.speakAfterRefresh)
        provider.unblock()
        await waitForRefresh(store)

        #expect(!store.speakAfterRefresh)
        store.toggleVoiceBroadcast()
    }

    @Test @MainActor
    func storeDoesNotCreateSpeechSynthesizerAtInitialization() {
        let store = QuotaStore(provider: StubProvider(.degraded(nil)), defaults: isolatedDefaults())

        #expect(store.speechSynthesizer == nil)
    }

    @Test @MainActor
    func cooldownCoalescesRequestsWithoutMovingDeadline() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedTestClock(start)
        let sleeper = ManualSleeper()
        let provider = CountingProvider([
            .live(.fixture(now: start)),
            .live(.fixture(now: start))
        ])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: clock.now,
            minimumRefreshInterval: 10,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.refresh()
        await waitForRefresh(store)
        store.refresh()
        store.refresh()
        store.refresh(force: false)
        await waitForSleeps(sleeper, count: 1)

        #expect(provider.callCount == 1)
        #expect(sleeper.delays == [10])

        clock.advance(by: 10)
        sleeper.resumeNext()
        await waitForProviderCalls(provider, count: 2)
    }

    @Test @MainActor
    func cooldownBoundaryRefreshesImmediately() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedTestClock(start)
        let sleeper = ManualSleeper()
        let provider = CountingProvider([.degraded(nil), .degraded(nil)])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: clock.now,
            minimumRefreshInterval: 10,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.refresh()
        await waitForRefresh(store)
        clock.advance(by: 10)
        store.refresh()
        await waitForRefresh(store)

        #expect(provider.callCount == 2)
        #expect(sleeper.delays.isEmpty)
    }

    @Test @MainActor
    func bypassRefreshStartsImmediatelyDuringCooldown() async {
        let provider = CountingProvider([.degraded(nil), .degraded(nil)])
        let sleeper = ManualSleeper()
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            minimumRefreshInterval: 10,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.refresh()
        await waitForRefresh(store)
        store.refresh(bypassCooldown: true)
        await waitForRefresh(store)

        #expect(provider.callCount == 2)
        #expect(sleeper.delays.isEmpty)
    }

    @Test @MainActor
    func recentLiveReuseDoesNotCreateCooldownTask() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = CountingProvider([.live(.fixture(now: now))])
        let sleeper = ManualSleeper()
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: { now },
            minimumRefreshInterval: 10,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.refresh()
        await waitForRefresh(store)
        store.refresh(force: false)

        #expect(provider.callCount == 1)
        #expect(sleeper.delays.isEmpty)
    }

    @Test @MainActor
    func forcedRequestUpgradesPendingNonForcedRefresh() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let stale = QuotaSnapshot.fixture(now: start.addingTimeInterval(-61))
        let recent = QuotaSnapshot.fixture(now: start)
        let clock = LockedTestClock(start)
        let sleeper = ManualSleeper()
        let provider = CountingProvider([.live(stale), .live(recent)])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: clock.now,
            minimumRefreshInterval: 10,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.refresh()
        await waitForRefresh(store)
        store.refresh(force: false)
        await waitForSleeps(sleeper, count: 1)
        store.snapshot = recent
        store.refresh(force: true)

        clock.advance(by: 10)
        sleeper.resumeNext()
        await waitForProviderCalls(provider, count: 2)
    }

    @Test @MainActor
    func refreshDuringActiveRequestDoesNotScheduleTrailingWork() async {
        let provider = BlockingProvider(.degraded(nil))
        let sleeper = ManualSleeper()
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            minimumRefreshInterval: 10,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.refresh()
        store.refresh()
        store.refresh(force: false)
        provider.unblock()
        await waitForRefresh(store)

        #expect(provider.callCount == 1)
        #expect(sleeper.delays.isEmpty)
    }

    @Test @MainActor
    func backwardClockWaitsAtMostOneFullCooldown() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedTestClock(start)
        let sleeper = ManualSleeper()
        let provider = CountingProvider([.degraded(nil), .degraded(nil)])
        let store = QuotaStore(
            provider: provider,
            defaults: isolatedDefaults(),
            now: clock.now,
            minimumRefreshInterval: 10,
            sleep: { delay in await sleeper.sleep(for: delay) }
        )

        store.refresh()
        await waitForRefresh(store)
        clock.set(start.addingTimeInterval(-100))
        store.refresh()
        await waitForSleeps(sleeper, count: 1)

        #expect(sleeper.delays == [10])

        sleeper.resumeNext()
        await waitForProviderCalls(provider, count: 2)
    }
}

private extension QuotaSnapshot {
    static func fixture(now: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> Self {
        QuotaSnapshot(
            remainingPercent: 61,
            weeklyRemainingPercent: 74,
            resetDate: now.addingTimeInterval(10_800),
            weeklyResetDate: now.addingTimeInterval(432_000),
            lastUpdated: now,
            sourceName: "Test",
            isUnavailable: false
        )
    }
}

private func localWindow(used: Double, resetsAt: Date, minutes: Int) -> RateLimitWindow {
    RateLimitWindow(
        usedPercent: used,
        resetsAt: resetsAt.timeIntervalSince1970,
        windowMinutes: minutes
    )
}

private struct StubProvider: QuotaProvider {
    let result: QuotaRefreshResult

    init(_ result: QuotaRefreshResult) {
        self.result = result
    }

    func refresh() -> QuotaRefreshResult {
        result
    }
}

private final class SequenceProvider: QuotaProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [QuotaRefreshResult]

    init(_ results: [QuotaRefreshResult]) {
        self.results = results
    }

    func refresh() -> QuotaRefreshResult {
        lock.lock()
        defer { lock.unlock() }
        return results.isEmpty ? .unavailable : results.removeFirst()
    }
}

private final class CountingProvider: QuotaProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [QuotaRefreshResult]
    private var calls = 0

    init(_ results: [QuotaRefreshResult]) {
        self.results = results
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func refresh() -> QuotaRefreshResult {
        lock.lock()
        defer { lock.unlock() }
        calls += 1
        return results.isEmpty ? .unavailable : results.removeFirst()
    }
}

private final class BlockingProvider: QuotaProvider, @unchecked Sendable {
    private let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private let result: QuotaRefreshResult
    private var calls = 0

    init(_ result: QuotaRefreshResult) {
        self.result = result
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func unblock() {
        gate.signal()
    }

    func refresh() -> QuotaRefreshResult {
        lock.lock()
        calls += 1
        lock.unlock()
        gate.wait()
        return result
    }
}

private final class LockedTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(interval)
        lock.unlock()
    }

    func set(_ date: Date) {
        lock.lock()
        value = date
        lock.unlock()
    }
}

private final class ManualSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var requestedDelays: [TimeInterval] = []

    var delays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return requestedDelays
    }

    func sleep(for delay: TimeInterval) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            requestedDelays.append(delay)
            continuations.append(continuation)
            lock.unlock()
        }
    }

    func resumeNext() {
        lock.lock()
        let continuation = continuations.isEmpty ? nil : continuations.removeFirst()
        lock.unlock()
        continuation?.resume()
    }
}

private func isolatedDefaults() -> UserDefaults {
    let suite = "CodexLimitPeekTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@MainActor
private func waitForRefresh(
    _ store: QuotaStore,
    timeout: TimeInterval = 1
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while store.isRefreshing, Date() < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
    #expect(!store.isRefreshing)
}

@MainActor
private func waitForProviderCalls(
    _ provider: CountingProvider,
    count: Int,
    timeout: TimeInterval = 1
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while provider.callCount < count, Date() < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
    #expect(provider.callCount == count)
}

@MainActor
private func waitForSleeps(
    _ sleeper: ManualSleeper,
    count: Int,
    timeout: TimeInterval = 1
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while sleeper.delays.count < count, Date() < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
    #expect(sleeper.delays.count == count)
}
