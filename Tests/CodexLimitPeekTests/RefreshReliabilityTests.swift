import Foundation
import Testing
@testable import CodexLimitPeek

struct RefreshReliabilityTests {
    private let start: TimeInterval = 1_000

    @Test
    func confirmsOnlyOnThirdFailureAtSixtySeconds() {
        var tracker = RefreshFailureTracker()

        #expect(
            tracker.recordFailure(.timeout, at: start)
                == .confirming(attempt: 1, retryAfter: 15)
        )
        #expect(
            tracker.recordFailure(.timeout, at: start + 15)
                == .confirming(attempt: 2, retryAfter: 45)
        )
        #expect(
            tracker.recordFailure(.timeout, at: start + 60)
                == .confirmed(retryAfter: 120)
        )
    }

    @Test
    func earlyManualFailuresCannotConfirmBeforeSixtySeconds() {
        var tracker = RefreshFailureTracker()
        _ = tracker.recordFailure(.timeout, at: start)
        _ = tracker.recordFailure(.timeout, at: start + 5)

        #expect(
            tracker.recordFailure(.timeout, at: start + 10)
                == .confirming(attempt: 2, retryAfter: 50)
        )
        #expect(!tracker.isConfirmed)
    }

    @Test
    func confirmedFailureBacksOffToFiveMinuteCap() {
        var tracker = RefreshFailureTracker()
        _ = tracker.recordFailure(.timeout, at: start)
        _ = tracker.recordFailure(.timeout, at: start + 15)
        _ = tracker.recordFailure(.timeout, at: start + 60)

        #expect(
            tracker.recordFailure(.protocolError, at: start + 180)
                == .confirmed(retryAfter: 300)
        )
        #expect(
            tracker.recordFailure(.protocolError, at: start + 480)
                == .confirmed(retryAfter: 300)
        )
    }

    @Test
    func liveSuccessResetsFailureState() {
        var tracker = RefreshFailureTracker()
        _ = tracker.recordFailure(.timeout, at: start)
        tracker.recordLiveSuccess()

        #expect(tracker.consecutiveFailures == 0)
        #expect(tracker.firstFailureInstant == nil)
        #expect(tracker.lastFailure == nil)
        #expect(!tracker.isConfirmed)
    }
}
