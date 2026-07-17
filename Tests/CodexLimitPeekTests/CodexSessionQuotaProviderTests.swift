import Foundation
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct CodexSessionQuotaProviderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func defaultsUseReleaseReadBounds() {
        #expect(CodexSessionQuotaProvider.maximumCandidateFileAge == 30 * 60)
        #expect(CodexSessionQuotaProvider.maximumCandidateFiles == 20)
        #expect(CodexSessionQuotaProvider.maximumTailBytes == 256 * 1024)
    }

    @Test
    func acceptsRecentRecordWithinTailBound() throws {
        try withTemporaryRoot { root in
            try writeSession(
                quotaLine(at: now),
                named: "recent.jsonl",
                modifiedAt: now.addingTimeInterval(-60),
                under: root
            )
            let provider = provider(roots: [root])

            let snapshot = try #require(provider.currentSnapshot())

            #expect(snapshot.remainingPercent == 61)
            #expect(snapshot.weeklyRemainingPercent == 74)
            #expect(snapshot.sourceName == "Codex 会话")
        }
    }

    @Test
    func ignoresFileOlderThanCandidateWindow() throws {
        try withTemporaryRoot { root in
            try writeSession(
                quotaLine(at: now),
                named: "old.jsonl",
                modifiedAt: now.addingTimeInterval(-(30 * 60 + 1)),
                under: root
            )

            #expect(provider(roots: [root]).currentSnapshot() == nil)
        }
    }

    @Test
    func doesNotReadBeyondTailBound() throws {
        try withTemporaryRoot { root in
            let padding = String(repeating: "x", count: 256 * 1024 + 1)
            try writeSession(
                quotaLine(at: now) + "\n" + padding,
                named: "outside-tail.jsonl",
                modifiedAt: now,
                under: root
            )

            #expect(provider(roots: [root]).currentSnapshot() == nil)
        }
    }

    @Test
    func inspectsOnlyConfiguredNewestCandidates() throws {
        try withTemporaryRoot { root in
            try writeSession(
                quotaLine(at: now),
                named: "oldest-valid.jsonl",
                modifiedAt: now.addingTimeInterval(-3),
                under: root
            )
            try writeSession(
                #"{"payload":{"type":"event"}}"#,
                named: "newer-empty.jsonl",
                modifiedAt: now.addingTimeInterval(-2),
                under: root
            )
            try writeSession(
                #"{"payload":{"type":"event"}}"#,
                named: "newest-empty.jsonl",
                modifiedAt: now.addingTimeInterval(-1),
                under: root
            )
            let currentDate = now
            let provider = CodexSessionQuotaProvider(
                roots: [root],
                now: { currentDate },
                maximumCandidateFiles: 2
            )

            #expect(provider.currentSnapshot() == nil)
        }
    }

    @Test
    func skipsMalformedRecentFile() throws {
        try withTemporaryRoot { root in
            try writeSession(
                #"{"payload":{"rate_limits":"#,
                named: "truncated.jsonl",
                modifiedAt: now,
                under: root
            )

            #expect(provider(roots: [root]).currentSnapshot() == nil)
        }
    }

    private func provider(roots: [URL]) -> CodexSessionQuotaProvider {
        let currentDate = now
        return CodexSessionQuotaProvider(roots: roots, now: { currentDate })
    }

    private func quotaLine(at date: Date) -> String {
        let timestamp = ISO8601DateFormatter().string(from: date)
        let primaryReset = Int(date.addingTimeInterval(10_800).timeIntervalSince1970)
        let weeklyReset = Int(date.addingTimeInterval(432_000).timeIntervalSince1970)
        return """
        {"timestamp":"\(timestamp)","payload":{"rate_limits":{"limit_id":"codex","primary":{"used_percent":39,"resets_at":\(primaryReset),"window_minutes":300},"secondary":{"used_percent":26,"resets_at":\(weeklyReset),"window_minutes":10080}}}}
        """
    }

    private func writeSession(
        _ text: String,
        named name: String,
        modifiedAt: Date,
        under root: URL
    ) throws {
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: modifiedAt],
            ofItemAtPath: url.path
        )
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-limit-peek-session-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
