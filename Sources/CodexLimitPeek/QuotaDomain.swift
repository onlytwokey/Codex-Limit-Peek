import AppKit
import Foundation
import SwiftUI

enum RefreshHealth: Sendable, Equatable {
    case live
    case confirmingFailure
    case degraded
    case unavailable

    var showsFailurePattern: Bool {
        self == .degraded || self == .unavailable
    }
}

struct QuotaRefreshResult: Sendable {
    let snapshot: QuotaSnapshot?
    let health: RefreshHealth
    let failure: RefreshFailureCategory?

    static func live(_ snapshot: QuotaSnapshot) -> Self {
        Self(snapshot: snapshot, health: .live, failure: nil)
    }

    static func degraded(
        _ snapshot: QuotaSnapshot?,
        failure: RefreshFailureCategory = .unknown
    ) -> Self {
        Self(snapshot: snapshot, health: .degraded, failure: failure)
    }

    static let unavailable = Self(
        snapshot: nil,
        health: .unavailable,
        failure: .unknown
    )

    var isLive: Bool {
        health == .live
    }
}

protocol QuotaProvider: Sendable {
    func refresh() -> QuotaRefreshResult
}

struct RateLimitRecord {
    let timestamp: Date?
    let fileModifiedAt: Date
    let primary: RateLimitWindow
    let secondary: RateLimitWindow
    let displayMode: QuotaDisplayMode

    var sortDate: Date {
        timestamp ?? fileModifiedAt
    }

    static let maximumFallbackAge: TimeInterval = 15 * 60

    static func isFresh(recordedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(recordedAt)
        return age >= 0 && age <= maximumFallbackAge
    }

    static func normalized(
        timestamp: Date?,
        fileModifiedAt: Date,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?,
        now: Date
    ) -> RateLimitRecord? {
        let nowTimestamp = now.timeIntervalSince1970
        if let primary,
           let secondary,
           primary.windowMinutes == 300,
           secondary.windowMinutes == 10_080,
           primary.resetsAt > nowTimestamp,
           secondary.resetsAt > nowTimestamp {
            return RateLimitRecord(
                timestamp: timestamp,
                fileModifiedAt: fileModifiedAt,
                primary: primary,
                secondary: secondary,
                displayMode: .dualWindow
            )
        }

        guard let weekly = [primary, secondary].compactMap({ $0 }).first(where: {
            $0.windowMinutes == 10_080 && $0.resetsAt > nowTimestamp
        }) else {
            return nil
        }
        return RateLimitRecord(
            timestamp: timestamp,
            fileModifiedAt: fileModifiedAt,
            primary: weekly,
            secondary: weekly,
            displayMode: .weeklyOnly
        )
    }

    func snapshot(recordedAt: Date, sourceName: String) -> QuotaSnapshot {
        let primaryUsed = Int(primary.usedPercent.rounded())
        let weeklyUsed = Int(secondary.usedPercent.rounded())
        return QuotaSnapshot(
            remainingPercent: max(0, min(100, 100 - primaryUsed)),
            weeklyRemainingPercent: max(0, min(100, 100 - weeklyUsed)),
            resetDate: Date(timeIntervalSince1970: primary.resetsAt),
            weeklyResetDate: Date(timeIntervalSince1970: secondary.resetsAt),
            lastUpdated: recordedAt,
            sourceName: sourceName,
            isUnavailable: false,
            displayMode: displayMode
        )
    }
}

struct RateLimitWindow {
    let usedPercent: Double
    let resetsAt: Double
    let windowMinutes: Int?
}

enum QuotaStatusFormatter {
    static func header(
        snapshot: QuotaSnapshot,
        health: RefreshHealth,
        confirmationAttempt: Int = 0,
        timeZone: TimeZone = .current
    ) -> String {
        if health == .confirmingFailure {
            switch confirmationAttempt {
            case 1:
                return "实时读取失败 · 15 秒后重试"
            case 2:
                return "正在确认失败 · 45 秒后重试"
            default:
                return snapshot.isUnavailable
                    ? "正在同步 · 额度未获取"
                    : "正在同步 · 使用上次数据"
            }
        }
        guard !snapshot.isUnavailable else {
            return "刷新失败 · 额度未获取"
        }

        let time = formattedTime(snapshot.lastUpdated, timeZone: timeZone)

        switch health {
        case .live:
            return "\(snapshot.sourceName) · 更新于 \(time)"
        case .degraded:
            if snapshot.sourceName == "Codex 日志"
                || snapshot.sourceName == "Codex 会话" {
                return "本地回退 · 更新于 \(time)"
            }
            return "刷新失败 · 上次成功 \(time)"
        case .unavailable:
            return "刷新失败 · 额度未获取"
        case .confirmingFailure:
            preconditionFailure("Handled above")
        }
    }

    private static func formattedTime(
        _ date: Date,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
