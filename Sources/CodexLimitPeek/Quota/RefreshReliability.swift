import Foundation

enum RefreshFailureCategory: String, Sendable, Equatable {
    case executableNotFound
    case launchFailed
    case timeout
    case unexpectedEOF
    case protocolError
    case invalidRateLimits
    case authenticationFailed
    case unknown

    var displayText: String {
        switch self {
        case .executableNotFound:
            return "未找到 Codex CLI"
        case .launchFailed:
            return "app-server 启动失败"
        case .timeout:
            return "app-server 响应超时"
        case .unexpectedEOF:
            return "app-server 意外退出"
        case .protocolError:
            return "app-server 协议异常"
        case .invalidRateLimits:
            return "额度字段无效"
        case .authenticationFailed:
            return "Codex 登录状态失效"
        case .unknown:
            return "未知本地错误"
        }
    }
}

enum RefreshFailureDecision: Sendable, Equatable {
    case confirming(attempt: Int, retryAfter: TimeInterval)
    case confirmed(retryAfter: TimeInterval)
}

struct RefreshFailureTracker: Sendable {
    private(set) var consecutiveFailures = 0
    private(set) var firstFailureInstant: TimeInterval?
    private(set) var lastFailure: RefreshFailureCategory?
    private(set) var isConfirmed = false

    mutating func recordFailure(
        _ failure: RefreshFailureCategory,
        at instant: TimeInterval
    ) -> RefreshFailureDecision {
        consecutiveFailures += 1
        lastFailure = failure
        if firstFailureInstant == nil {
            firstFailureInstant = instant
        }
        let elapsed = max(0, instant - (firstFailureInstant ?? instant))

        if isConfirmed {
            return .confirmed(retryAfter: 5 * 60)
        }
        if consecutiveFailures >= 3, elapsed >= 60 {
            isConfirmed = true
            return .confirmed(retryAfter: 2 * 60)
        }
        if consecutiveFailures == 1 {
            return .confirming(attempt: 1, retryAfter: 15)
        }
        return .confirming(
            attempt: 2,
            retryAfter: max(0, 60 - elapsed)
        )
    }

    mutating func recordLiveSuccess() {
        consecutiveFailures = 0
        firstFailureInstant = nil
        lastFailure = nil
        isConfirmed = false
    }
}
