#if DEVELOPER_TOOLS
import Foundation

struct DeveloperPreviewQuotaProvider: QuotaProvider {
    let result: QuotaRefreshResult

    func refresh() -> QuotaRefreshResult {
        result
    }
}

final class DeveloperPreviewInMemoryUserDefaults: UserDefaults {
    private let lock = NSLock()
    private var values: [String: Any]

    init(values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: nil)!
    }

    override func object(forKey defaultName: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return values[defaultName]
    }

    override func set(
        _ value: Any?,
        forKey defaultName: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        if let value {
            values[defaultName] = value
        } else {
            values.removeValue(forKey: defaultName)
        }
    }

    override func removeObject(forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: defaultName)
    }

    override func dictionaryRepresentation() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

@MainActor
final class DeveloperPreviewEnvironment {
    let referenceDate: Date
    let defaults: DeveloperPreviewInMemoryUserDefaults
    let quotaStore: QuotaStore
    let appearanceStore: AppearanceStore

    init(
        scenario: DeveloperPreviewScenario,
        theme: AppearanceThemeID,
        launchedAt: Date = Date(),
        appearanceProfiles: [AppearanceThemeID: AppearanceProfile]? = nil,
        editorFontScale: Double? = nil,
        provider: (any QuotaProvider)? = nil
    ) {
        let fixture = scenario.fixture(launchedAt: launchedAt)
        var appearanceValues: [String: Any] = [
            AppearancePersistenceKey.selectedTheme: theme.rawValue,
            AppearancePersistenceKey.opaqueBackgroundPresetMigration: true
        ]
        if let appearanceProfiles {
            let encoder = JSONEncoder()
            for theme in AppearanceThemeID.allCases {
                guard
                    let profile = appearanceProfiles[theme],
                    let data = try? encoder.encode(
                        profile.validated(for: theme)
                    )
                else {
                    continue
                }
                appearanceValues[
                    AppearancePersistenceKey.profile(theme)
                ] = data
            }
        }
        if let editorFontScale {
            appearanceValues[
                AppearancePersistenceKey.editorFontScale
            ] = NSNumber(value: editorFontScale)
        }
        let defaults = DeveloperPreviewInMemoryUserDefaults(
            values: appearanceValues
        )
        let provider = provider ?? DeveloperPreviewQuotaProvider(
            result: fixture.refreshResult
        )

        referenceDate = launchedAt
        self.defaults = defaults
        quotaStore = QuotaStore(
            provider: provider,
            defaults: defaults,
            now: { launchedAt },
            monotonicNow: { 0 },
            minimumRefreshInterval: 0,
            sleep: { _ in },
            initialSnapshot: fixture.snapshot,
            initialRefreshHealth: fixture.refreshHealth,
            allowsUserFacingSideEffects: false
        )
        appearanceStore = AppearanceStore(
            defaults: defaults,
            saveDelayNanoseconds: 0
        )
    }
}
#endif
