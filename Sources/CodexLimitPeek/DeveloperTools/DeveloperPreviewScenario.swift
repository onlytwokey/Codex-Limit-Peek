#if DEVELOPER_TOOLS
import Foundation

enum DeveloperPreviewScenario:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case healthyDual
    case weeklyOnly
    case warning
    case danger
    case unavailable
    case refreshFailure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthyDual:
            "双额度"
        case .weeklyOnly:
            "仅周额度"
        case .warning:
            "警告"
        case .danger:
            "危险"
        case .unavailable:
            "不可用"
        case .refreshFailure:
            "刷新失败"
        }
    }

    func fixture(
        launchedAt: Date
    ) -> DeveloperPreviewFixture {
        let weeklyResetDate = launchedAt.addingTimeInterval(432_000)

        switch self {
        case .healthyDual:
            return .live(
                snapshot(
                    remaining: 81,
                    weekly: 49,
                    launchedAt: launchedAt,
                    weeklyResetDate: weeklyResetDate
                )
            )
        case .weeklyOnly:
            return .live(
                QuotaSnapshot(
                    remainingPercent: 49,
                    weeklyRemainingPercent: 49,
                    resetDate: weeklyResetDate,
                    weeklyResetDate: weeklyResetDate,
                    lastUpdated: launchedAt,
                    sourceName: "Codex 示例",
                    isUnavailable: false,
                    displayMode: .weeklyOnly
                )
            )
        case .warning:
            return .live(
                snapshot(
                    remaining: 18,
                    weekly: 41,
                    launchedAt: launchedAt,
                    weeklyResetDate: weeklyResetDate
                )
            )
        case .danger:
            return .live(
                snapshot(
                    remaining: 7,
                    weekly: 12,
                    launchedAt: launchedAt,
                    weeklyResetDate: weeklyResetDate
                )
            )
        case .unavailable:
            let snapshot = QuotaSnapshot(
                remainingPercent: 0,
                weeklyRemainingPercent: 0,
                resetDate: launchedAt,
                weeklyResetDate: launchedAt,
                lastUpdated: launchedAt,
                sourceName: "额度未获取",
                isUnavailable: true,
                displayMode: .dualWindow
            )
            return DeveloperPreviewFixture(
                snapshot: snapshot,
                refreshHealth: .unavailable,
                refreshResult: .unavailable
            )
        case .refreshFailure:
            let snapshot = self.snapshot(
                remaining: 63,
                weekly: 38,
                launchedAt: launchedAt,
                weeklyResetDate: weeklyResetDate
            )
            return DeveloperPreviewFixture(
                snapshot: snapshot,
                refreshHealth: .degraded,
                refreshResult: .degraded(
                    snapshot,
                    failure: .timeout
                )
            )
        }
    }

    private func snapshot(
        remaining: Int,
        weekly: Int,
        launchedAt: Date,
        weeklyResetDate: Date
    ) -> QuotaSnapshot {
        QuotaSnapshot(
            remainingPercent: remaining,
            weeklyRemainingPercent: weekly,
            resetDate: launchedAt.addingTimeInterval(5_640),
            weeklyResetDate: weeklyResetDate,
            lastUpdated: launchedAt,
            sourceName: "Codex 示例",
            isUnavailable: false,
            displayMode: .dualWindow
        )
    }
}

struct DeveloperPreviewFixture: Sendable {
    let snapshot: QuotaSnapshot
    let refreshHealth: RefreshHealth
    let refreshResult: QuotaRefreshResult

    static func live(
        _ snapshot: QuotaSnapshot
    ) -> DeveloperPreviewFixture {
        DeveloperPreviewFixture(
            snapshot: snapshot,
            refreshHealth: .live,
            refreshResult: .live(snapshot)
        )
    }
}
#endif
