import Foundation
import Darwin

enum AppServerQuotaError: Error, Equatable {
    case executableNotFound
    case launchFailed
    case timeout
    case unexpectedEOF
    case protocolError
    case invalidRateLimits
    case authenticationFailed
}

extension AppServerQuotaError {
    var failureCategory: RefreshFailureCategory {
        switch self {
        case .executableNotFound:
            return .executableNotFound
        case .launchFailed:
            return .launchFailed
        case .timeout:
            return .timeout
        case .unexpectedEOF:
            return .unexpectedEOF
        case .protocolError:
            return .protocolError
        case .invalidRateLimits:
            return .invalidRateLimits
        case .authenticationFailed:
            return .authenticationFailed
        }
    }
}

enum AppServerRateLimitDecoder {
    private struct ValidWindow {
        let remainingPercent: Int
        let resetDate: Date
    }

    private struct Envelope: Decodable {
        let id: Int?
        let result: Response?
    }

    private struct Response: Decodable {
        let rateLimits: Snapshot?
        let rateLimitsByLimitId: [String: Snapshot]?
    }

    private struct Snapshot: Decodable {
        let limitId: String?
        let primary: Window?
        let secondary: Window?
    }

    private struct Window: Decodable {
        let usedPercent: Int
        let resetsAt: Int64?
    }

    static func decode(_ data: Data, fetchedAt: Date) throws -> QuotaSnapshot {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw AppServerQuotaError.protocolError
        }

        guard envelope.id == 2, let response = envelope.result else {
            throw AppServerQuotaError.protocolError
        }

        let bucket: Snapshot
        if let buckets = response.rateLimitsByLimitId, !buckets.isEmpty {
            guard let aggregate = buckets["codex"] else {
                throw AppServerQuotaError.invalidRateLimits
            }
            bucket = aggregate
        } else {
            guard let legacy = response.rateLimits,
                  legacy.limitId == nil || legacy.limitId == "codex" else {
                throw AppServerQuotaError.invalidRateLimits
            }
            bucket = legacy
        }

        let primary = try validWindow(bucket.primary, fetchedAt: fetchedAt)
        let secondary = try validWindow(bucket.secondary, fetchedAt: fetchedAt)

        switch (primary, secondary) {
        case let (.some(primary), .some(secondary)):
            return QuotaSnapshot(
                remainingPercent: primary.remainingPercent,
                weeklyRemainingPercent: secondary.remainingPercent,
                resetDate: primary.resetDate,
                weeklyResetDate: secondary.resetDate,
                lastUpdated: fetchedAt,
                sourceName: "Codex 实时额度",
                isUnavailable: false,
                displayMode: .dualWindow
            )
        case let (.some(window), .none), let (.none, .some(window)):
            return QuotaSnapshot(
                remainingPercent: window.remainingPercent,
                weeklyRemainingPercent: window.remainingPercent,
                resetDate: window.resetDate,
                weeklyResetDate: window.resetDate,
                lastUpdated: fetchedAt,
                sourceName: "Codex 实时额度",
                isUnavailable: false,
                displayMode: .weeklyOnly
            )
        case (.none, .none):
            throw AppServerQuotaError.invalidRateLimits
        }
    }

    private static func validWindow(_ window: Window?, fetchedAt: Date) throws -> ValidWindow? {
        guard let window else { return nil }
        guard let resetsAt = window.resetsAt,
              TimeInterval(resetsAt) > fetchedAt.timeIntervalSince1970 else {
            throw AppServerQuotaError.invalidRateLimits
        }
        return ValidWindow(
            remainingPercent: 100 - min(max(window.usedPercent, 0), 100),
            resetDate: Date(timeIntervalSince1970: TimeInterval(resetsAt))
        )
    }
}

enum CodexExecutableLocator {
    static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        appBundleCandidate: URL = URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex")
    ) -> URL? {
        if let override = environment["CODEX_LIMIT_PEEK_CODEX_PATH"] {
            let url = URL(fileURLWithPath: override)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        for directory in (environment["PATH"] ?? "").split(separator: ":") {
            let url = URL(fileURLWithPath: String(directory)).appendingPathComponent("codex")
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return fileManager.isExecutableFile(atPath: appBundleCandidate.path)
            ? appBundleCandidate
            : nil
    }
}

protocol AppServerTransport: Sendable {
    func readRateLimits(executableURL: URL) throws -> Data
}

private final class JSONLineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let signal = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var lines: [Data] = []
    private var reachedEOF = false

    func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        lock.unlock()
        signal.signal()
    }

    func finish() {
        lock.lock()
        reachedEOF = true
        lock.unlock()
        signal.signal()
    }

    func readLine(until deadline: Date) throws -> Data? {
        while true {
            lock.lock()
            if !lines.isEmpty {
                let line = lines.removeFirst()
                lock.unlock()
                return line
            }
            let finished = reachedEOF
            lock.unlock()

            if finished {
                return nil
            }

            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                throw AppServerQuotaError.timeout
            }
            if signal.wait(timeout: .now() + remaining) == .timedOut {
                throw AppServerQuotaError.timeout
            }
        }
    }
}

struct StdioAppServerTransport: AppServerTransport {
    let timeout: TimeInterval
    let shutdownGrace: TimeInterval

    init(timeout: TimeInterval = 12, shutdownGrace: TimeInterval = 0.25) {
        self.timeout = timeout
        self.shutdownGrace = shutdownGrace
    }

    func readRateLimits(executableURL: URL) throws -> Data {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = Pipe()

        let collector = JSONLineCollector()
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                collector.finish()
            } else {
                collector.append(data)
            }
        }
        let deadline = Date().addingTimeInterval(timeout)

        do {
            try process.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
            throw AppServerQuotaError.launchFailed
        }

        defer {
            shutdown(process, input: input, output: output)
        }

        do {
            let initialize: [String: Any] = [
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": ["name": "codex-limit-peek", "version": "0.1.0"],
                    "capabilities": ["experimentalApi": true]
                ]
            ]
            try send(initialize, to: input)
            guard try response(id: 1, collector: collector, deadline: deadline) != nil else {
                throw AppServerQuotaError.unexpectedEOF
            }

            try send(["method": "initialized"], to: input)
            try send(
                ["id": 2, "method": "account/rateLimits/read", "params": NSNull()],
                to: input
            )
            guard let quota = try response(id: 2, collector: collector, deadline: deadline) else {
                throw AppServerQuotaError.unexpectedEOF
            }
            return quota
        } catch let error as AppServerQuotaError {
            throw error
        } catch {
            throw AppServerQuotaError.protocolError
        }
    }

    private func send(_ object: [String: Any], to input: Pipe) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func response(
        id: Int,
        collector: JSONLineCollector,
        deadline: Date
    ) throws -> Data? {
        while let line = try collector.readLine(until: deadline) {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  (object["id"] as? Int) == id else {
                continue
            }
            if let error = object["error"] as? [String: Any] {
                let code = error["code"] as? Int
                let message = (error["message"] as? String)?.lowercased() ?? ""
                if code == 401 || code == 403
                    || message.contains("auth")
                    || message.contains("login")
                    || message.contains("logged out") {
                    throw AppServerQuotaError.authenticationFailed
                }
                throw AppServerQuotaError.protocolError
            }
            return line
        }
        return nil
    }

    private func shutdown(_ process: Process, input: Pipe, output: Pipe) {
        try? input.fileHandleForWriting.close()
        if !waitForExit(process, seconds: shutdownGrace), process.isRunning {
            process.terminate()
        }
        if !waitForExit(process, seconds: shutdownGrace), process.isRunning {
            Darwin.kill(process.processIdentifier, SIGKILL)
            _ = waitForExit(process, seconds: shutdownGrace)
        }
        output.fileHandleForReading.readabilityHandler = nil
        try? output.fileHandleForReading.close()
    }

    private func waitForExit(_ process: Process, seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        return !process.isRunning
    }
}

struct AppServerQuotaProvider: QuotaProvider {
    private let executableURL: URL?
    private let transport: any AppServerTransport
    private let now: @Sendable () -> Date

    init(
        executableURL: URL? = CodexExecutableLocator.locate(),
        transport: any AppServerTransport = StdioAppServerTransport(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.executableURL = executableURL
        self.transport = transport
        self.now = now
    }

    func refresh() -> QuotaRefreshResult {
        guard let executableURL else {
            return .degraded(nil, failure: .executableNotFound)
        }

        do {
            let data = try transport.readRateLimits(executableURL: executableURL)
            let snapshot = try AppServerRateLimitDecoder.decode(data, fetchedAt: now())
            return .live(snapshot)
        } catch let error as AppServerQuotaError {
            return .degraded(nil, failure: error.failureCategory)
        } catch {
            return .degraded(nil, failure: .unknown)
        }
    }
}
