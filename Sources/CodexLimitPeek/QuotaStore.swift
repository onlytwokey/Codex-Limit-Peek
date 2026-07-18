import AppKit
import AVFoundation
import Combine
import SwiftUI
import UserNotifications

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
