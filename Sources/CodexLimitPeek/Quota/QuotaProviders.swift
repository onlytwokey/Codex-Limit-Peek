import Foundation

struct CompositeQuotaProvider: QuotaProvider {
    private let appServerProvider = AppServerQuotaProvider()
    private let logProvider = CodexLogQuotaProvider()
    private let sessionProvider = CodexSessionQuotaProvider()

    func refresh() -> QuotaRefreshResult {
        let live = appServerProvider.refresh()
        if live.isLive {
            return live
        }
        let failure = live.failure ?? .unknown
        if let local = logProvider.currentSnapshot() ?? sessionProvider.currentSnapshot() {
            return .degraded(local, failure: failure)
        }
        return .degraded(nil, failure: failure)
    }
}

struct CodexLogQuotaProvider {
    func currentSnapshot() -> QuotaSnapshot? {
        guard let record = newestHeaderRateLimitRecord(),
              let recordedAt = record.timestamp else {
            return nil
        }

        let now = Date()
        guard RateLimitRecord.isFresh(recordedAt: recordedAt, now: now) else {
            return nil
        }
        return record.snapshot(recordedAt: recordedAt, sourceName: "Codex 日志")
    }

    private func newestHeaderRateLimitRecord() -> RateLimitRecord? {
        let databaseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/logs_2.sqlite")
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return nil
        }

        let query = """
        select ts || char(9) || feedback_log_body from logs
        where feedback_log_body like '%x-codex-primary-used-percent%'
           or feedback_log_body like '%x-codex-secondary-used-percent%'
        order by ts desc, ts_nanos desc, id desc
        limit 1;
        """
        guard let output = runSQLite(databasePath: databaseURL.path, query: query) else {
            return nil
        }

        let parts = output.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let timestamp = TimeInterval(parts[0]) else {
            return nil
        }

        let body = String(parts[1])
        let recordedAt = Date(timeIntervalSince1970: timestamp)
        return RateLimitRecord.normalized(
            timestamp: Date(timeIntervalSince1970: timestamp),
            fileModifiedAt: recordedAt,
            primary: Self.headerWindow("primary", in: body),
            secondary: Self.headerWindow("secondary", in: body),
            now: Date()
        )
    }

    private func runSQLite(databasePath: String, query: String) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", databasePath, query]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func headerDouble(_ name: String, in text: String) -> Double? {
        guard let value = headerValue(name, in: text) else { return nil }
        return Double(value)
    }

    private static func headerInt(_ name: String, in text: String) -> Int? {
        guard let value = headerValue(name, in: text) else { return nil }
        return Int(value)
    }

    private static func headerValue(_ name: String, in text: String) -> String? {
        let marker = "\"\(name)\": \""
        guard let markerRange = text.range(of: marker) else {
            return nil
        }
        let valueStart = markerRange.upperBound
        guard let valueEnd = text[valueStart...].firstIndex(of: "\"") else {
            return nil
        }
        return String(text[valueStart..<valueEnd])
    }

    private static func headerWindow(_ name: String, in text: String) -> RateLimitWindow? {
        guard let usedPercent = headerDouble("x-codex-\(name)-used-percent", in: text),
              let resetsAt = headerDouble("x-codex-\(name)-reset-at", in: text),
              let windowMinutes = headerInt("x-codex-\(name)-window-minutes", in: text) else {
            return nil
        }
        return RateLimitWindow(
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            windowMinutes: windowMinutes
        )
    }
}

struct CodexSessionQuotaProvider: Sendable {
    static let maximumCandidateFileAge: TimeInterval = 30 * 60
    static let maximumCandidateFiles = 20
    static let maximumTailBytes: UInt64 = 256 * 1024

    private let roots: [URL]
    private let now: @Sendable () -> Date
    private let candidateFileAge: TimeInterval
    private let candidateFileLimit: Int
    private let tailByteLimit: UInt64

    init(
        roots: [URL]? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        maximumCandidateFileAge: TimeInterval = Self.maximumCandidateFileAge,
        maximumCandidateFiles: Int = Self.maximumCandidateFiles,
        maximumTailBytes: UInt64 = Self.maximumTailBytes
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.roots = roots ?? [
            home.appendingPathComponent(".codex/sessions"),
            home.appendingPathComponent(".codex/archived_sessions")
        ]
        self.now = now
        self.candidateFileAge = max(0, maximumCandidateFileAge)
        self.candidateFileLimit = max(0, maximumCandidateFiles)
        self.tailByteLimit = maximumTailBytes
    }

    func currentSnapshot() -> QuotaSnapshot? {
        let currentDate = now()
        guard let record = newestRateLimitRecord(now: currentDate),
              let recordedAt = record.timestamp,
              RateLimitRecord.isFresh(recordedAt: recordedAt, now: currentDate) else {
            return nil
        }
        return record.snapshot(recordedAt: recordedAt, sourceName: "Codex 会话")
    }

    private func newestRateLimitRecord(now currentDate: Date) -> RateLimitRecord? {
        let cutoff = currentDate.addingTimeInterval(-candidateFileAge)
        let files = roots
            .flatMap { recentJSONLFiles(under: $0, modifiedOnOrAfter: cutoff) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(candidateFileLimit)

        var records: [RateLimitRecord] = []
        for file in files {
            records.append(contentsOf: rateLimitRecords(
                in: file.url,
                fileModifiedAt: file.modifiedAt,
                now: currentDate
            ))
        }

        return bestRateLimitRecord(from: records, now: currentDate)
    }

    private func recentJSONLFiles(
        under root: URL,
        modifiedOnOrAfter cutoff: Date
    ) -> [SessionFile] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [SessionFile] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt >= cutoff else {
                continue
            }
            files.append(SessionFile(url: url, modifiedAt: modifiedAt))
        }
        return files
    }

    private func rateLimitRecords(
        in url: URL,
        fileModifiedAt: Date,
        now currentDate: Date
    ) -> [RateLimitRecord] {
        guard let text = readTailText(from: url, maxBytes: tailByteLimit) else {
            return []
        }

        var records: [RateLimitRecord] = []
        for line in text.split(separator: "\n").reversed() {
            guard line.contains("\"rate_limits\"") else { continue }
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = object["payload"] as? [String: Any],
                  let rateLimits = payload["rate_limits"] as? [String: Any],
                  Self.isAggregateCodexLimit(rateLimits),
                  let record = RateLimitRecord.normalized(
                    timestamp: parseDate(object["timestamp"] as? String),
                    fileModifiedAt: fileModifiedAt,
                    primary: parseWindow(rateLimits["primary"]),
                    secondary: parseWindow(rateLimits["secondary"]),
                    now: currentDate
                  ) else {
                continue
            }

            records.append(record)
            if records.count >= 40 {
                break
            }
        }

        return records
    }

    private func bestRateLimitRecord(
        from records: [RateLimitRecord],
        now currentDate: Date
    ) -> RateLimitRecord? {
        let now = currentDate.timeIntervalSince1970
        let currentWindowRecords = records.filter { record in
            record.primary.resetsAt > now && record.secondary.resetsAt > now
        }

        return currentWindowRecords.max { lhs, rhs in
            lhs.sortDate < rhs.sortDate
        }
    }

    private func readTailText(from url: URL, maxBytes: UInt64) -> String? {
        guard maxBytes > 0,
              let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let offset = fileSize > maxBytes ? fileSize - maxBytes : 0
        try? handle.seek(toOffset: offset)

        guard let data = try? handle.readToEnd() else {
            return nil
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func parseWindow(_ value: Any?) -> RateLimitWindow? {
        guard let dictionary = value as? [String: Any],
              let usedPercent = Self.double(dictionary["used_percent"]),
              let resetsAt = Self.double(dictionary["resets_at"]) else {
            return nil
        }
        return RateLimitWindow(
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            windowMinutes: Self.int(dictionary["window_minutes"])
        )
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func isAggregateCodexLimit(_ rateLimits: [String: Any]) -> Bool {
        (rateLimits["limit_id"] as? String) == "codex"
    }

    private static func double(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let double = value as? Double {
            return Int(double)
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }
}

private struct SessionFile {
    let url: URL
    let modifiedAt: Date
}
