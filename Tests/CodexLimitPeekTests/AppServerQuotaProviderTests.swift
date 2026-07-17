import Foundation
import Testing
@testable import CodexLimitPeek

@Suite(.serialized)
struct AppServerQuotaProviderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func defaultTransportAllowsSlowColdStart() {
        #expect(StdioAppServerTransport().timeout == 12)
    }

    @Test
    func decoderPrefersAggregateCodexBucket() throws {
        let data = Data(#"{"id":2,"result":{"rateLimits":{"limitId":"codex_bengalfox","primary":{"usedPercent":90,"resetsAt":1800010000},"secondary":{"usedPercent":80,"resetsAt":1800500000}},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":39,"resetsAt":1800010800},"secondary":{"usedPercent":26,"resetsAt":1800432000}}}}}"#.utf8)

        let snapshot = try AppServerRateLimitDecoder.decode(data, fetchedAt: now)

        #expect(snapshot.remainingPercent == 61)
        #expect(snapshot.weeklyRemainingPercent == 74)
        #expect(snapshot.sourceName == "Codex 实时额度")
        #expect(snapshot.lastUpdated == now)
        #expect(snapshot.displayMode == .dualWindow)
    }

    @Test
    func decoderAcceptsPrimaryOnlyAsWeeklyQuota() throws {
        let data = Data(#"{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":18,"resetsAt":1800432000},"secondary":null}}}}"#.utf8)

        let snapshot = try AppServerRateLimitDecoder.decode(data, fetchedAt: now)

        #expect(snapshot.displayMode == .weeklyOnly)
        #expect(snapshot.remainingPercent == 82)
        #expect(snapshot.weeklyRemainingPercent == 82)
        #expect(snapshot.resetDate == Date(timeIntervalSince1970: 1_800_432_000))
        #expect(snapshot.weeklyResetDate == snapshot.resetDate)
    }

    @Test
    func decoderAcceptsSecondaryOnlyAsWeeklyQuota() throws {
        let data = Data(#"{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":null,"secondary":{"usedPercent":21,"resetsAt":1800432000}}}}}"#.utf8)

        let snapshot = try AppServerRateLimitDecoder.decode(data, fetchedAt: now)

        #expect(snapshot.displayMode == .weeklyOnly)
        #expect(snapshot.remainingPercent == 79)
        #expect(snapshot.weeklyRemainingPercent == 79)
    }

    @Test
    func decoderAcceptsLegacyAggregateBucketWhenMapIsAbsent() throws {
        let data = Data(#"{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":10,"resetsAt":1800010800},"secondary":{"usedPercent":20,"resetsAt":1800432000}}}}"#.utf8)

        let snapshot = try AppServerRateLimitDecoder.decode(data, fetchedAt: now)

        #expect(snapshot.remainingPercent == 90)
        #expect(snapshot.weeklyRemainingPercent == 80)
    }

    @Test
    func decoderRejectsNonAggregateLegacyBucket() {
        let data = Data(#"{"id":2,"result":{"rateLimits":{"limitId":"codex_bengalfox","primary":{"usedPercent":10,"resetsAt":1800010800},"secondary":{"usedPercent":20,"resetsAt":1800432000}}}}"#.utf8)

        #expect(throws: AppServerQuotaError.self) {
            try AppServerRateLimitDecoder.decode(data, fetchedAt: now)
        }
    }

    @Test
    func decoderRejectsMissingOrExpiredWindows() {
        let noWindows = Data(#"{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"primary":null,"secondary":null}}}}"#.utf8)
        let missingReset = Data(#"{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":10},"secondary":null}}}}"#.utf8)
        let expired = Data(#"{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":10,"resetsAt":1799999999},"secondary":null}}}}"#.utf8)

        for data in [noWindows, missingReset, expired] {
            #expect(throws: AppServerQuotaError.self) {
                try AppServerRateLimitDecoder.decode(data, fetchedAt: now)
            }
        }
    }

    @Test
    func locatorUsesExplicitExecutableBeforePathAndAppBundle() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: temporary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let located = CodexExecutableLocator.locate(
            environment: ["CODEX_LIMIT_PEEK_CODEX_PATH": temporary.path, "PATH": ""],
            fileManager: .default,
            appBundleCandidate: URL(fileURLWithPath: "/missing/codex")
        )

        #expect(located == temporary)
    }

    @Test
    func transportTimesOutAndKillsChild() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pidFile = directory.appendingPathComponent("pid")
        let executable = directory.appendingPathComponent("codex-stub")
        let script = "#!/bin/sh\necho $$ > '\(pidFile.path)'\nIFS= read -r initialize\nexec /bin/sleep 30\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        do {
            _ = try StdioAppServerTransport(timeout: 3, shutdownGrace: 0.1)
                .readRateLimits(executableURL: executable)
            Issue.record("Expected transport timeout")
        } catch {
            #expect(error as? AppServerQuotaError == .timeout)
        }

        guard let pidText = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = Int32(pidText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            Issue.record("Stub did not record its process id")
            return
        }
        #expect(kill(pid, 0) == -1)
        #expect(errno == ESRCH)
    }

    @Test
    func transportPerformsInitializeThenRateLimitRead() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = directory.appendingPathComponent("trace")
        let executable = directory.appendingPathComponent("codex-stub")
        let script = """
        #!/bin/sh
        IFS= read -r initialize
        printf '%s\n' "$initialize" >> '\(trace.path)'
        printf '%s\n' '{"id":1,"result":{"userAgent":"stub","platformOs":"macos","platformFamily":"unix","codexHome":"/tmp"}}'
        IFS= read -r initialized
        printf '%s\n' "$initialized" >> '\(trace.path)'
        IFS= read -r read_limits
        printf '%s\n' "$read_limits" >> '\(trace.path)'
        printf '%s\n' '{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":39,"resetsAt":1800010800},"secondary":{"usedPercent":26,"resetsAt":1800432000}}},"rateLimits":{}}}'
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let data = try StdioAppServerTransport(timeout: 3, shutdownGrace: 0.1)
            .readRateLimits(executableURL: executable)
        let requests = try String(contentsOf: trace, encoding: .utf8)
        let methods = requests.split(separator: "\n").compactMap { line -> String? in
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return object["method"] as? String
        }

        #expect(methods == ["initialize", "initialized", "account/rateLimits/read"])
        #expect(try AppServerRateLimitDecoder.decode(data, fetchedAt: now).remainingPercent == 61)
    }

    @Test
    func transportCleansUpAfterUnexpectedEOF() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("codex-stub")
        try Data("#!/bin/sh\nexit 7\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        do {
            _ = try StdioAppServerTransport(timeout: 1, shutdownGrace: 0.05)
                .readRateLimits(executableURL: executable)
            Issue.record("Expected unexpected EOF")
        } catch {
            #expect(error as? AppServerQuotaError == .unexpectedEOF)
        }
    }

    @Test
    func transportClassifiesAuthenticationError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("codex-stub")
        let script = """
        #!/bin/sh
        IFS= read -r initialize
        printf '%s\n' '{"id":1,"result":{}}'
        IFS= read -r initialized
        IFS= read -r read_limits
        printf '%s\n' '{"id":2,"error":{"code":401,"message":"authentication required"}}'
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        do {
            _ = try StdioAppServerTransport(timeout: 1, shutdownGrace: 0.05)
                .readRateLimits(executableURL: executable)
            Issue.record("Expected authentication failure")
        } catch {
            #expect(error as? AppServerQuotaError == .authenticationFailed)
        }
    }

    @Test
    func liveProviderReturnsLiveSnapshot() {
        let data = Data(#"{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":39,"resetsAt":1800010800},"secondary":{"usedPercent":26,"resetsAt":1800432000}}},"rateLimits":{}}}"#.utf8)
        let provider = AppServerQuotaProvider(
            executableURL: URL(fileURLWithPath: "/test/codex"),
            transport: StubTransport(result: .success(data)),
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        let result = provider.refresh()

        #expect(result.isLive)
        #expect(result.snapshot?.remainingPercent == 61)
    }

    @Test
    func liveProviderDegradesWhenExecutableIsMissing() {
        let provider = AppServerQuotaProvider(
            executableURL: nil,
            transport: StubTransport(result: .failure(.launchFailed)),
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        let result = provider.refresh()

        #expect(result.health == .degraded)
        #expect(result.snapshot == nil)
        #expect(result.failure == .executableNotFound)
    }

    @Test
    func liveProviderPreservesTypedTransportFailure() {
        let provider = AppServerQuotaProvider(
            executableURL: URL(fileURLWithPath: "/test/codex"),
            transport: StubTransport(result: .failure(.timeout)),
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        let result = provider.refresh()

        #expect(result.health == .degraded)
        #expect(result.failure == .timeout)
    }

    @Test
    func liveProviderDegradesOnMalformedResponse() {
        let provider = AppServerQuotaProvider(
            executableURL: URL(fileURLWithPath: "/test/codex"),
            transport: StubTransport(result: .success(Data("not-json".utf8))),
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        let result = provider.refresh()

        #expect(result.health == .degraded)
        #expect(result.snapshot == nil)
        #expect(result.failure == .protocolError)
    }
}

private struct StubTransport: AppServerTransport {
    let result: Result<Data, AppServerQuotaError>

    func readRateLimits(executableURL: URL) throws -> Data {
        try result.get()
    }
}
